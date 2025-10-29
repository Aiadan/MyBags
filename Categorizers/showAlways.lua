local addonName, AddonNS = ...

AddonNS.CategorShowAlways = {};

local function toCategory(categoryOrId)
    if not categoryOrId then
        return nil
    end
    if type(categoryOrId) == "table" then
        return categoryOrId
    end
    return AddonNS.CategoryStore:Get(categoryOrId)
end

function AddonNS.CategorShowAlways:GetAlwaysShownCategories()
    local collection = {}
    for category in AddonNS.CategoryStore:All() do
        if category.alwaysVisible then
            collection[category.id] = true
        end
    end
    return collection
end

function AddonNS.CategorShowAlways:ShouldAlwaysShow(categoryOrId)
    local category = toCategory(categoryOrId)
    return category and category.alwaysVisible or false
end

function AddonNS.CategorShowAlways:SetAlwaysShow(categoryOrId, show)
    local category = toCategory(categoryOrId)
    if not category then
        return
    end
    AddonNS.CategoryStore:SetAlwaysVisible(category.id, show)
end
