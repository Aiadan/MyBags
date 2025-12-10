local addonName, AddonNS = ...

local NewItemCategorizer = {};

AddonNS.Categories:RegisterCategorizer("New", NewItemCategorizer, true, "Right-click to reset new items.");

local newItems = {};
local newCategoryId = "sys:new"

local function resetItem(bagID, slotIndex)
    C_NewItems.RemoveNewItem(bagID, slotIndex)
    newItems[bagID] = newItems[bagID] or {};
    newItems[bagID][slotIndex] = nil
end

local function resetFromContext(context)
    if not context then
        return
    end
    local sourceButton = context.pickedItemButton or context.targetItemButton
    if not sourceButton then
        return
    end
    resetItem(sourceButton:GetBagID(), sourceButton:GetID())
end

local function ensureNewCategory()
    return AddonNS.CategoryStore:RecordDynamicCategory({
        id = newCategoryId,
        name = "|cff9999ffNew",
        categorizer = "system:new",
        protected = true,
        alwaysVisible = true,
        OnItemUnassigned = function(_, _, _, context)
            resetFromContext(context)
        end,
    })
end

function NewItemCategorizer:Categorize(itemID, itemButton)
    local containerIndex = itemButton:GetBagID();
    local slotIndex = itemButton:GetID();
    local isNew = C_NewItems.IsNewItem(containerIndex, slotIndex);
    if (isNew) then
        newItems[containerIndex] = newItems[containerIndex] or {};
        newItems[containerIndex][slotIndex] = itemID;
    end
    local category = ensureNewCategory()
    if newItems[containerIndex] and newItems[containerIndex][slotIndex] == itemID then
        return category
    end
    return nil
end

function NewItemCategorizer:OnRightClick()
    AddonNS.printDebug("Clearing NEW")
    C_NewItems.ClearAll()
    newItems = {};
    return true;
end

function NewItemCategorizer:CheckNewItems(bagID)
    AddonNS.printDebug("NewItemCategorizer CheckNewItems BAG_UPDATE", bagID)
    newItems[bagID] = newItems[bagID] or {};
    for slotIndex, expectedItemID in pairs(newItems[bagID]) do
        local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotIndex);
        if (not itemLocation:IsValid() or expectedItemID ~= C_Item.GetItemID(itemLocation)) then
            newItems[bagID][slotIndex] = nil;
        end
    end
end

AddonNS.Events:RegisterEvent("BAG_UPDATE", NewItemCategorizer.CheckNewItems);
