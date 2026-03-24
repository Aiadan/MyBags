local addonName, AddonNS = ...

local COLLAPSED_CHANGED = AddonNS.Const.Events.COLLAPSED_CHANGED;
AddonNS.Collapsed ={}
function AddonNS.Collapsed.isCollapsed(category, scope)
    if not category then
        return false
    end
    return AddonNS.CategoryStore:IsCollapsed(category.id, scope);
end

function AddonNS.Collapsed.toggleCollapsed(category, scope)
    if not category then
        return
    end
    local collapsed = AddonNS.CategoryStore:IsCollapsed(category.id, scope);
    AddonNS.CategoryStore:SetCollapsed(category.id, not collapsed, scope);
    AddonNS.Events:TriggerCustomEvent(COLLAPSED_CHANGED, category, scope);
end
