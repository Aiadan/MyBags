local addonName, AddonNS = ...

local FOLDED_CHANGED = AddonNS.Const.Events.FOLDED_CHANGED;
AddonNS.Folded ={}
AddonNS.Folded.foldedMap = {}
function AddonNS.Folded:OnInitialize()
    AddonNS.db.foldedCategories = AddonNS.db.foldedCategories or AddonNS.Folded.foldedMap ;
    AddonNS.Folded.foldedMap = AddonNS.db.foldedCategories
end
AddonNS.Events:OnInitialize(AddonNS.Folded.OnInitialize)

function AddonNS.Folded.isFolded(category)
    return AddonNS.Folded.foldedMap[category.name];
end

function AddonNS.Folded.toggleFolding(category)
    AddonNS.Folded.foldedMap[category.name] = not AddonNS.Folded.foldedMap[category.name] ;
    AddonNS.printDebug("toggleFolding", category and category.name);
    AddonNS.Events:TriggerCustomEvent(FOLDED_CHANGED, category);
end