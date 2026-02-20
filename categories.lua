local addonName, AddonNS = ...

AddonNS.Categories = AddonNS.Categories or {}

local categorizers = OrderedMap:new()

local function normalizeScope(scope)
    if scope == nil or scope == "" then
        return "bag"
    end
    return scope
end

local function scopeFromItemButton(itemButton)
    if itemButton and itemButton.MyBagsScope then
        return normalizeScope(itemButton.MyBagsScope)
    end
    return "bag"
end

local function wrap_raw_result(categorizerId, result, output, seen, allowDuplicateCategoryIds)
    if not result then
        return
    end
    if type(result) == "table" and result[1] then
        for i = 1, #result do
            wrap_raw_result(categorizerId, result[i], output, seen, allowDuplicateCategoryIds)
        end
        return
    end
    if type(result) ~= "table" or not result.GetId then
        return
    end
    local wrapper = AddonNS.CategoryStore:GetWrapperForRaw(categorizerId, result)
    if not wrapper then
        return
    end
    if (not allowDuplicateCategoryIds) and seen[wrapper:GetId()] then
        return
    end
    if not allowDuplicateCategoryIds then
        seen[wrapper:GetId()] = true
    end
    table.insert(output, wrapper)
end

local function wrap_single_raw_result(categorizerId, result)
    if not result then
        return nil
    end
    if type(result) == "table" and result[1] then
        result = result[1]
    end
    if type(result) ~= "table" or not result.GetId then
        return nil
    end
    return AddonNS.CategoryStore:GetWrapperForRaw(categorizerId, result)
end

function AddonNS.Categories:RegisterCategorizer(name, categorizer, categorizerId)
    local id = categorizerId or name
    categorizers:set(id, { id = id, categorizer = categorizer, name = name })
end

local function refresh_categorizer(record)
    if not record then
        return {}
    end
    local list = {}
    if record.categorizer.ListCategories then
        local rawList = record.categorizer:ListCategories()
        list = AddonNS.CategoryStore:RefreshCategorizer(record.id, rawList or {})
    end
    return list
end

local function ensure_wrapped(record)
    if not record then
        return
    end
    local existing = AddonNS.CategoryStore:GetByCategorizer(record.id)
    if not existing or #existing == 0 then
        refresh_categorizer(record)
    end
end

function AddonNS.Categories:GetConstantCategories(scope)
    local normalizedScope = normalizeScope(scope)
    local configModeActive = AddonNS.BagViewState and AddonNS.BagViewState:IsCategoriesConfigMode()
    local showScopeDisabledInConfigMode = AddonNS.BagViewState and AddonNS.BagViewState:ShouldShowScopeDisabledInConfigMode()
    local constant = {}
    local seen = {}
    for _, record in categorizers:iterate() do
        ensure_wrapped(record)
        if record.categorizer.GetAlwaysVisibleCategories then
            local rawList = record.categorizer:GetAlwaysVisibleCategories() or {}
            for index = 1, #rawList do
                local wrapper = AddonNS.CategoryStore:GetWrapperForRaw(record.id, rawList[index])
                local includeInScope = wrapper and wrapper:IsVisibleInScope(normalizedScope)
                if (not includeInScope) and configModeActive and showScopeDisabledInConfigMode and record.id == "cus" then
                    includeInScope = true
                end
                if wrapper and includeInScope and not seen[wrapper:GetId()] then
                    table.insert(constant, wrapper)
                    seen[wrapper:GetId()] = true
                end
            end
        end
    end
    return constant
end

function AddonNS.Categories:GetMatches(itemID, itemButton, options)
    options = options or {}
    local normalizedScope = normalizeScope(options.scope or scopeFromItemButton(itemButton))
    local includeScopeDisabled = options.includeScopeDisabled == true
    local matches = {}
    local seen = {}
    local allowDuplicateCategoryIds = options.allowDuplicateCategoryIds
    for _, record in categorizers:iterate() do
        ensure_wrapped(record)
        local result
        if record.categorizer.GetMatches then
            result = record.categorizer:GetMatches(itemID, itemButton)
        else
            result = record.categorizer:Categorize(itemID, itemButton)
        end
        wrap_raw_result(record.id, result, matches, seen, allowDuplicateCategoryIds)
    end
    if includeScopeDisabled then
        return matches
    end
    local filtered = {}
    for index = 1, #matches do
        local category = matches[index]
        if category:IsVisibleInScope(normalizedScope) then
            table.insert(filtered, category)
        end
    end
    return filtered
end

function AddonNS.Categories:Categorize(itemID, itemButton)
    local normalizedScope = scopeFromItemButton(itemButton)
    for _, record in categorizers:iterate() do
        ensure_wrapped(record)
        local result = record.categorizer:Categorize(itemID, itemButton)
        local wrapped = wrap_single_raw_result(record.id, result)
        if wrapped and wrapped:IsVisibleInScope(normalizedScope) then
            return wrapped
        end
    end
    return AddonNS.CategoryStore:GetUnassigned()
end

AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CATEGORIZER_CATEGORIES_UPDATED, function(_, categorizerRef)
    for _, record in categorizers:iterate() do
        if record.categorizer == categorizerRef then
            refresh_categorizer(record)
            break
        end
    end
end)

AddonNS.Events:OnInitialize(function()
    for _, record in categorizers:iterate() do
        refresh_categorizer(record)
    end
end)

function AddonNS.Categories:GetCategoryById(categoryId)
    return AddonNS.CategoryStore:Get(categoryId)
end

function AddonNS.Categories:GetCategoryByName(categoryName)
    if categoryName == AddonNS.Const.UNASSIGNE_CATEGORY_DB_STORAGE_NAME then
        return AddonNS.CategoryStore:GetUnassigned()
    end
    return AddonNS.CategoryStore:GetByName(categoryName)
end

function AddonNS.Categories:HandleItemReassignment(eventName, itemId, targetedItemId, sourceCategory, targetCategory,
                                                   sourceButton, targetButton)
    if not itemId then
        return
    end
    local target = targetCategory or AddonNS.CategoryStore:GetUnassigned()
    local scope = scopeFromItemButton(targetButton or sourceButton)
    if target and target.IsProtected and target:IsProtected() then
        return
    end
    if target and not target:IsVisibleInScope(scope) then
        return
    end
    if sourceCategory and target and sourceCategory:GetId() == target:GetId() then
        return
    end
    local context = {
        pickedItemButton = sourceButton,
        targetItemButton = targetButton,
        targetedItemId = targetedItemId,
    }
    if sourceCategory and sourceCategory.OnItemUnassigned then
        sourceCategory:OnItemUnassigned(itemId, context)
    end
    if target and target.OnItemAssigned then
        target:OnItemAssigned(itemId, context)
    end
end

AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.ITEM_MOVED, function(...)
    AddonNS.Categories:HandleItemReassignment(...)
end)
