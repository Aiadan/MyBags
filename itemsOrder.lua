local addonName, AddonNS = ...

-- events
AddonNS.ItemsOrder = {};

local items_current_order = {};
function AddonNS.ItemsOrder:OnInitialize()
    AddonNS.db.itemOrder = AddonNS.db.itemOrder or items_current_order;
    items_current_order = AddonNS.db.itemOrder;
end

AddonNS.Events:OnInitialize(AddonNS.ItemsOrder.OnInitialize)


-- The first list (items to be sorted)
local order_map = {}
local order_map_changed = true;
local function getItemIdOrError(itemButton)
    local itemID = itemButton and itemButton._myBagsItemId
    if not itemID then
        error("ItemsOrder:Sort missing cached item id on item button")
    end
    return itemID
end

local function recreateAnOrderMapIfNeeded()
    if order_map_changed then
        order_map = {};
        for index, id in ipairs(items_current_order) do
            order_map[id] = index
        end
        order_map_changed = false;
    end
end

function AddonNS.ItemsOrder:Sort(itemButtonsList)
    -- Create a map for quick lookup of the order positions
    if (itemButtonsList[1] == AddonNS.itemButtonPlaceholder) then return; end;
    if #itemButtonsList <= 1 then
        return
    end

    recreateAnOrderMapIfNeeded()
    local itemToItemIDMap = {};

    for i = #itemButtonsList, 1, -1 do
        local itemButton = itemButtonsList[i]
        local itemID = getItemIdOrError(itemButton)
        itemToItemIDMap[itemButton] = itemID
    end

    -- Fast path for tiny lists to avoid table.sort overhead.
    if #itemButtonsList == 2 then
        local itemButtonA = itemButtonsList[1]
        local itemButtonB = itemButtonsList[2]
        local itemA_ID = itemToItemIDMap[itemButtonA]
        local itemB_ID = itemToItemIDMap[itemButtonB]
        local posA = order_map[itemA_ID]
        local posB = order_map[itemB_ID]
        local inOrder

        if posA and posB then
            inOrder = posA < posB
        elseif posA then
            inOrder = true
        elseif posB then
            inOrder = false
        else
            inOrder = itemA_ID < itemB_ID
        end

        if not inOrder then
            itemButtonsList[1], itemButtonsList[2] = itemButtonsList[2], itemButtonsList[1]
        end
    else
        table.sort(itemButtonsList, function(itemButtonA, itemButtonB)
            local itemA_ID = itemToItemIDMap[itemButtonA];
            local itemB_ID = itemToItemIDMap[itemButtonB];
            local posA = order_map[itemA_ID]
            local posB = order_map[itemB_ID]
            if posA and posB then
                return posA < posB
            end
            if posA then
                return true
            end
            if posB then
                return false
            end
            return itemA_ID < itemB_ID
        end)
    end

    local last_index = 0
    local orderChanged = false
    for i = #itemButtonsList, 1, -1 do
        local id = itemToItemIDMap[itemButtonsList[i]]
        if order_map[id] then
            last_index = order_map[id]
            break
        end
    end

    for _, item in ipairs(itemButtonsList) do
        if not order_map[itemToItemIDMap[item]] then
            table.insert(items_current_order, last_index + 1, itemToItemIDMap[item])
            last_index = last_index + 1
            orderChanged = true
        end
    end
    if orderChanged then
        order_map_changed = true
    end
end

local function ItemsMoved(previousItemID, pickedItemID, changedCategory)
    recreateAnOrderMapIfNeeded();
    local pickedNo = order_map[pickedItemID];
    if changedCategory and not previousItemID then
        if not pickedNo then
            return
        end
        table.insert(items_current_order, 1, table.remove(items_current_order, pickedNo))
        order_map_changed = true
        return
    end
    if not previousItemID then
        return
    end
    local prevNo = order_map[previousItemID];

    if not prevNo or not pickedNo then
        -- Missing from order map; ignore to avoid breaking reassignment.
        return
    end

    if changedCategory then
        table.remove(items_current_order, pickedNo)
        table.insert(items_current_order, prevNo + (prevNo > pickedNo and 0 or 1), pickedItemID)
    else
        table.insert(items_current_order, prevNo, table.remove(items_current_order, pickedNo))
    end
    order_map_changed = true;
end

local function itemMoved(eventName, pickedItemID, targetedItemID, pickedCategoryId, targetCategoryId,
                         pickedItemButton,
                         targetItemButton)
    local function resolveCategory(categoryOrId)
        if not categoryOrId then
            return nil
        end
        if type(categoryOrId) == "table" then
            return categoryOrId
        end
        return AddonNS.CategoryStore:Get(categoryOrId)
    end

    local pickedCategory = resolveCategory(pickedCategoryId)
    local targetCategory = resolveCategory(targetCategoryId)
    local sameCategory = pickedCategory and targetCategory and pickedCategory:GetId() == targetCategory:GetId()
    local targetProtected = targetCategory and targetCategory:IsProtected() or false
    local pickedProtected = pickedCategory and pickedCategory:IsProtected() or false
    if sameCategory or (not targetProtected and not pickedProtected) then
        ItemsMoved(targetedItemID, pickedItemID, not sameCategory)
    end
end
AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.ITEM_MOVED, itemMoved)
