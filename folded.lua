local addonName, AddonNS = ...

local FOLDED_CHANGED = AddonNS.Const.Events.FOLDED_CHANGED;
local UNASSIGNE_CATEGORY_DB_STORAGE_NAME=AddonNS.Const.UNASSIGNE_CATEGORY_DB_STORAGE_NAME
AddonNS.Folded ={}
AddonNS.Folded.foldedMap = {}
function AddonNS.Folded:OnInitialize()
    AddonNS.db.foldedCategories = AddonNS.db.foldedCategories or AddonNS.Folded.foldedMap ;
    AddonNS.Folded.foldedMap = AddonNS.db.foldedCategories
end
AddonNS.Events:OnInitialize(AddonNS.Folded.OnInitialize)
local function getCategorySafeNameForStorage(category)
    return category.name or UNASSIGNE_CATEGORY_DB_STORAGE_NAME;
end
function AddonNS.Folded.isFolded(category)
    return AddonNS.Folded.foldedMap[getCategorySafeNameForStorage(category)];
end

function AddonNS.Folded.toggleFolding(category)
    local name = getCategorySafeNameForStorage(category);
    AddonNS.Folded.foldedMap[name] = not AddonNS.Folded.foldedMap[name] ;
    AddonNS.printDebug("toggleFolding", name);
    AddonNS.Events:TriggerCustomEvent(FOLDED_CHANGED, category);
end