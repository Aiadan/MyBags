local addonName, AddonNS = ...

local EquipmentSet = {}
local CATEGORIZER_ID = "eq"

local equipmentCategories = {}
local itemSets = {}

local function new_raw(equipmentSetID, name, iconFileID)
    local iconString = "|T" .. iconFileID .. ":16:16:0:2:64:64:4:60:4:60|t "
    local raw = {
        _id = tostring(equipmentSetID),
        _name = iconString .. "|CFFFF2459" .. name,
    }
    function raw:GetId()
        return self._id
    end
    function raw:GetName()
        return self._name
    end
    function raw:IsProtected()
        return true
    end
    function raw:IsAlwaysVisible()
        return true
    end
    return raw
end

local function setItemCategoryIfEmpty(bag, slot, rawCategory)
    itemSets[bag] = itemSets[bag] or {}
    if not itemSets[bag][slot] then
        itemSets[bag][slot] = rawCategory
    end
end

local function refreshEquipmentSets()
    equipmentCategories = {}
    itemSets = {}
    local equipmentSetIDs = C_EquipmentSet.GetEquipmentSetIDs()
    for _, equipmentSetID in pairs(equipmentSetIDs) do
        local name, iconFileID = C_EquipmentSet.GetEquipmentSetInfo(equipmentSetID)
        local raw = new_raw(equipmentSetID, name, iconFileID)
        equipmentCategories[raw:GetId()] = raw

        local locations = C_EquipmentSet.GetItemLocations(equipmentSetID)
        for inventorySlotID, location in ipairs(locations) do
            if (location > 1 or location < -1) then
                local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(location)
                if bag then
                    setItemCategoryIfEmpty(bag, slot, raw)
                end
            end
        end
    end
    AddonNS.CategoryStore:RefreshCategorizer(CATEGORIZER_ID, EquipmentSet:ListCategories())
    AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CATEGORIZER_CATEGORIES_UPDATED, EquipmentSet)
end

function EquipmentSet:ListCategories()
    local list = {}
    for _, raw in pairs(equipmentCategories) do
        table.insert(list, raw)
    end
    return list
end

function EquipmentSet:GetAlwaysVisibleCategories()
    return self:ListCategories()
end

function EquipmentSet:Categorize(itemID, itemButton)
    local bagMap = itemSets[itemButton:GetBagID()]
    if not bagMap then
        return nil
    end
    return bagMap[itemButton:GetID()]
end

AddonNS.Categories:RegisterCategorizer("EquipmentSet", EquipmentSet, CATEGORIZER_ID)

refreshEquipmentSets()
AddonNS.Events:RegisterEvent("BAG_UPDATE_DELAYED", refreshEquipmentSets)
AddonNS.Events:RegisterEvent("EQUIPMENT_SETS_CHANGED", refreshEquipmentSets)
