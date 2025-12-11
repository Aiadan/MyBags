local addonName, AddonNS = ...

AddonNS.CategorShowAlways = {};

local function toCategory(categoryOrId)
    if not categoryOrId then
        return nil
    end
    if type(categoryOrId) == "table" and categoryOrId.GetId then
        return categoryOrId
    end
    return AddonNS.CategoryStore:Get(categoryOrId)
end

function AddonNS.CategorShowAlways:GetAlwaysShownCategories()
    local collection = {}
    local customWrappers = {}
    if AddonNS.CategoryStore.GetByCategorizer then
        customWrappers = AddonNS.CategoryStore:GetByCategorizer("cus") or {}
    end
    for _, category in ipairs(customWrappers) do
        if category:IsAlwaysVisible() then
            collection[category:GetId()] = true
        end
    end
    return collection
end

function AddonNS.CategorShowAlways:ShouldAlwaysShow(categoryOrId)
    local category = toCategory(categoryOrId)
    return category and category:IsAlwaysVisible() or false
end

function AddonNS.CategorShowAlways:SetAlwaysShow(categoryOrId, show)
    local category = toCategory(categoryOrId)
    if not category then
        return
    end
    local id = category:GetId()
    local rawId = id:match("^[^%-]+%-(.+)$") or id
    local categorizerId = id:match("^([^%-]+)-")
    if categorizerId == "cus" then
        AddonNS.CustomCategories:SetAlwaysVisible(rawId, show)
    end
end
