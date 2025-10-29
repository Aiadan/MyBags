local addonName, AddonNS = ...

local COLLAPSED_CHANGED = AddonNS.Const.Events.COLLAPSED_CHANGED;
AddonNS.Collapsed ={}
function AddonNS.Collapsed.isCollapsed(category)
    if not category then
        return false
    end
    return AddonNS.CategoryStore:IsCollapsed(category.id);
end

function AddonNS.Collapsed.toggleCollapsed(category)
    if not category then
        return
    end
    local collapsed = AddonNS.CategoryStore:IsCollapsed(category.id);
    AddonNS.CategoryStore:SetCollapsed(category.id, not collapsed);
    AddonNS.printDebug("toggleCollapsed", category.id);
    AddonNS.Events:TriggerCustomEvent(COLLAPSED_CHANGED, category);
end
