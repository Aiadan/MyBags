local addonName, AddonNS = ...

local COLLAPSED_CHANGED = AddonNS.Const.Events.COLLAPSED_CHANGED;
local UNASSIGNE_CATEGORY_DB_STORAGE_NAME=AddonNS.Const.UNASSIGNE_CATEGORY_DB_STORAGE_NAME
AddonNS.Collapsed ={}
AddonNS.Collapsed.collapsedMap = {}
function AddonNS.Collapsed:OnInitialize()
    AddonNS.db.collapsedCategories = AddonNS.db.collapsedCategories or AddonNS.Collapsed.collapsedMap ;
    AddonNS.Collapsed.collapsedMap = AddonNS.db.collapsedCategories
end
AddonNS.Events:OnInitialize(AddonNS.Collapsed.OnInitialize)
local function getCategorySafeNameForStorage(category)
    return category.name or UNASSIGNE_CATEGORY_DB_STORAGE_NAME;
end
function AddonNS.Collapsed.isCollapsed(category)
    return AddonNS.Collapsed.collapsedMap[getCategorySafeNameForStorage(category)];
end

function AddonNS.Collapsed.toggleCollapsed(category)
    local name = getCategorySafeNameForStorage(category);
    AddonNS.Collapsed.collapsedMap[name] = not AddonNS.Collapsed.collapsedMap[name] ;
    AddonNS.printDebug("toggleCollapsed", name);
    AddonNS.Events:TriggerCustomEvent(COLLAPSED_CHANGED, category);
end
