local addonName, AddonNS = ...

AddonNS.SearchCategoryBaseline = AddonNS.SearchCategoryBaseline or {}

function AddonNS.SearchCategoryBaseline:Add(arrangedItems, category, itemButton, includeInSearch, searchActive)
    if not category then
        return false
    end
    if searchActive then
        arrangedItems[category] = arrangedItems[category] or {}
    end
    if includeInSearch then
        arrangedItems[category] = arrangedItems[category] or {}
        table.insert(arrangedItems[category], itemButton)
        return true
    end
    return false
end
