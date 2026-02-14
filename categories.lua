local addonName, AddonNS = ...

AddonNS.Categories = AddonNS.Categories or {}

local categorizers = OrderedMap:new()

local function wrap_raw_result(categorizerId, result, output, seen)
    if not result then
        return
    end
    if type(result) == "table" and result[1] then
        for i = 1, #result do
            wrap_raw_result(categorizerId, result[i], output, seen)
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
    if seen[wrapper:GetId()] then
        return
    end
    seen[wrapper:GetId()] = true
    table.insert(output, wrapper)
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

function AddonNS.Categories:GetConstantCategories()
    local constant = {}
    local seen = {}
    for _, record in categorizers:iterate() do
        ensure_wrapped(record)
        if record.categorizer.GetAlwaysVisibleCategories then
            local rawList = record.categorizer:GetAlwaysVisibleCategories() or {}
            for index = 1, #rawList do
                local wrapper = AddonNS.CategoryStore:GetWrapperForRaw(record.id, rawList[index])
                if wrapper and not seen[wrapper:GetId()] then
                    table.insert(constant, wrapper)
                    seen[wrapper:GetId()] = true
                end
            end
        end
    end
    return constant
end

function AddonNS.Categories:Categorize(itemID, itemButton)
    local matches = {}
    local seen = {}
    for _, record in categorizers:iterate() do
        ensure_wrapped(record)
        local result = record.categorizer:Categorize(itemID, itemButton)
        wrap_raw_result(record.id, result, matches, seen)
    end
    if itemButton then
        itemButton.ItemCategories = matches
    end
    if matches[1] then
        return matches[1]
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
    if target and target.IsProtected and target:IsProtected() then
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
