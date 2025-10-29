local addonName, AddonNS = ...

-- events
local EquipmentSet = {};
local CATEGORIZER_CATEGORIES_UPDATED = AddonNS.Const.Events.CATEGORIZER_CATEGORIES_UPDATED;

AddonNS.Categories:RegisterCategorizer("EquipmentSet", EquipmentSet, true);

local itemSets = {};

function EquipmentSet:Categorize(itemID, itemButton)
    local bagMap = itemSets[itemButton:GetBagID()]
    if not bagMap then
        return nil
    end
    return bagMap[itemButton:GetID()]
end

local function setItemCategoryIfEmpty(bag, slot, category)
    itemSets[bag] = itemSets[bag] or {};
    if (not itemSets[bag][slot]) then
        itemSets[bag][slot] = category;
    end
end
local function ensureEquipmentCategory(equipmentSetID, name, iconFileID)
    local iconString = "|T" .. iconFileID .. ":16:16:0:2:64:64:4:60:4:60|t "
    return AddonNS.CategoryStore:RecordDynamicCategory({
        id = "sys:equip:" .. equipmentSetID,
        name = iconString .. "|CFFFF2459" .. name,
        categorizer = "system:equipment",
        protected = true,
        alwaysVisible = true,
    })
end

local function refreshEquipmentSets()
    itemSets = {};
    local equipmentSetIDs = C_EquipmentSet.GetEquipmentSetIDs()
    for _, equipmentSetID in pairs(equipmentSetIDs) do
        local name, iconFileID = C_EquipmentSet.GetEquipmentSetInfo(equipmentSetID)
        local category = ensureEquipmentCategory(equipmentSetID, name, iconFileID)

        local locations = C_EquipmentSet.GetItemLocations(equipmentSetID)

        for inventorySlotID, location in ipairs(locations) do
            if (location > 1 or location < -1) then
                local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(location);
                if bag then
                    setItemCategoryIfEmpty(bag, slot, category)
                end
            end
        end
    end
end

local function refreshEquipmentSetsAndRefresh()
    refreshEquipmentSets()
    AddonNS.Events:TriggerCustomEvent(CATEGORIZER_CATEGORIES_UPDATED, EquipmentSet);
end

refreshEquipmentSets();
AddonNS.Events:RegisterEvent("BAG_UPDATE_DELAYED", refreshEquipmentSets);
AddonNS.Events:RegisterEvent("EQUIPMENT_SETS_CHANGED", refreshEquipmentSetsAndRefresh);
