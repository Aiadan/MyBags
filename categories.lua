local addonName, AddonNS = ...

AddonNS.Categories = {};

local categorizers = OrderedMap:new()

local function resolveCategoryIdentifier(categoryOrId)
    if not categoryOrId then
        return nil
    end
    if type(categoryOrId) == "table" then
        return categoryOrId
    end
    return AddonNS.CategoryStore:Get(categoryOrId)
end

local function resolveCategory(result, output, seen)
    if not result then
        return
    end
    local category
    local resultType = type(result)
    if resultType == "string" then
        category = AddonNS.CategoryStore:Get(result)
    elseif resultType == "table" and result.id and (getmetatable(result) or result._record or result._metadata) then
        category = result
    elseif resultType == "table" and result[1] then
        for index = 1, #result do
            resolveCategory(result[index], output, seen)
        end
        return
    end
    if not category then
        return
    end
    if seen[category.id] then
        return
    end
    seen[category.id] = true
    table.insert(output, category)
end

function AddonNS.Categories:RegisterCategorizer(name, categorizer)
    categorizers:set(name, categorizer);
end

function AddonNS.Categories:GetConstantCategories()
    local constant = {}
    for category in AddonNS.CategoryStore:All() do
        if category.alwaysVisible then
            table.insert(constant, category)
        end
    end
    return constant
end

function AddonNS.Categories:Categorize(itemID, itemButton)
    local matches = {}
    local seen = {}
    for _, categorizer in categorizers:iterate() do
        local result = categorizer:Categorize(itemID, itemButton)
        resolveCategory(result, matches, seen)
    end
    if itemButton then
        itemButton.ItemCategories = matches
    end
    if matches[1] then
        return matches[1]
    end
    return AddonNS.CategoryStore:GetUnassigned()
end

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
    local source = resolveCategoryIdentifier(sourceCategory)
    local target = resolveCategoryIdentifier(targetCategory) or AddonNS.CategoryStore:GetUnassigned()
    if target and target:IsProtected() then
        return
    end
    if source and target and source.id == target.id then
        return
    end
    local context = {
        pickedItemButton = sourceButton,
        targetItemButton = targetButton,
        targetedItemId = targetedItemId,
    }
    if source and source.OnItemUnassigned then
        source:OnItemUnassigned(itemId, target, context)
    end
    if target and target.OnItemAssigned then
        target:OnItemAssigned(itemId, source, context)
    end
end

AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.ITEM_MOVED,
    function(...)
        AddonNS.Categories:HandleItemReassignment(...)
    end)
