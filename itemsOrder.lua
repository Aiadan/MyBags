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
local sortProfile = {
    calls = 0,
    totalMs = 0,
    maxMs = 0,
    rebuildMs = 0,
    mapMs = 0,
    sortMs = 0,
    comparatorMs = 0,
    appendMs = 0,
    uncountedMs = 0,
}

local function profilingEnabled()
    return AddonNS.Profiling and AddonNS.Profiling.enabled
end

local function profileNowMs()
    return debugprofilestop()
end

local function getItemIdOrError(itemButton)
    local itemID = itemButton and itemButton._myBagsItemId
    if not itemID then
        error("ItemsOrder:Sort missing cached item id on item button")
    end
    return itemID
end

local function recreateAnOrderMapIfNeeded()
    if order_map_changed then
        local startedAt = profilingEnabled() and profileNowMs() or nil
        order_map = {};
        for index, id in ipairs(items_current_order) do
            order_map[id] = index
        end
        order_map_changed = false;
        if startedAt then
            return profileNowMs() - startedAt
        end
    end
    return 0
end

function AddonNS.ItemsOrder:Sort(itemButtonsList)
    local startedAt = profilingEnabled() and profileNowMs() or nil
    -- Create a map for quick lookup of the order positions
    if (itemButtonsList[1] == AddonNS.itemButtonPlaceholder) then return; end;
    if #itemButtonsList <= 1 then
        return
    end

    local rebuildMs = recreateAnOrderMapIfNeeded()
    local itemToItemIDMap = {};
    local mapBuildMs = 0
    local sortMs = 0
    local comparatorMs = 0
    local appendMs = 0

    local mapStartedAt = startedAt and profileNowMs() or nil
    for i = #itemButtonsList, 1, -1 do
        local itemButton = itemButtonsList[i]
        local itemID = getItemIdOrError(itemButton)
        itemToItemIDMap[itemButton] = itemID
    end
    if mapStartedAt then
        mapBuildMs = profileNowMs() - mapStartedAt
    end

    -- Fast path for tiny lists to avoid table.sort overhead.
    if #itemButtonsList == 2 then
        local itemButtonA = itemButtonsList[1]
        local itemButtonB = itemButtonsList[2]
        local itemA_ID = itemToItemIDMap[itemButtonA]
        local itemB_ID = itemToItemIDMap[itemButtonB]
        local posA = order_map[itemA_ID]
        local posB = order_map[itemB_ID]
        local inOrder = false

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
        local sortStartedAt = startedAt and profileNowMs() or nil

        if startedAt then
            table.sort(itemButtonsList, function(itemButtonA, itemButtonB)
                local comparatorStartedAt = profileNowMs()
                local itemA_ID = itemToItemIDMap[itemButtonA];
                local itemB_ID = itemToItemIDMap[itemButtonB];
                local posA = order_map[itemA_ID]
                local posB = order_map[itemB_ID]
                local result
                if posA and posB then
                    result = posA < posB
                elseif posA then
                    result = true
                elseif posB then
                    result = false
                else
                    result = itemA_ID < itemB_ID
                end
                comparatorMs = comparatorMs + (profileNowMs() - comparatorStartedAt)
                return result
            end)
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
        if sortStartedAt then
            sortMs = profileNowMs() - sortStartedAt
        end
    end

    local last_index = 0
    local orderChanged = false
    local appendStartedAt = startedAt and profileNowMs() or nil
    for i = #itemButtonsList, 1, -1 do
        local id = itemToItemIDMap[itemButtonsList[i]]
        if order_map[id] then
            last_index = order_map[id]
            break
        end
    end

    for _, item in ipairs(itemButtonsList) do
        -- AddonNS.printDebug(item, itemToItemIDMap[item], order_map[itemToItemIDMap[item]]);
        if not order_map[itemToItemIDMap[item]] then
            table.insert(items_current_order, last_index + 1, itemToItemIDMap[item])
            last_index = last_index + 1
            orderChanged = true
        end
    end
    if orderChanged then
        order_map_changed = true
    end
    if appendStartedAt then
        appendMs = profileNowMs() - appendStartedAt
    end

    if startedAt then
        local elapsed = profileNowMs() - startedAt
        sortProfile.calls = sortProfile.calls + 1
        sortProfile.totalMs = sortProfile.totalMs + elapsed
        if elapsed > sortProfile.maxMs then
            sortProfile.maxMs = elapsed
        end
        sortProfile.rebuildMs = sortProfile.rebuildMs + rebuildMs
        sortProfile.mapMs = sortProfile.mapMs + mapBuildMs
        sortProfile.sortMs = sortProfile.sortMs + sortMs
        sortProfile.comparatorMs = sortProfile.comparatorMs + comparatorMs
        sortProfile.appendMs = sortProfile.appendMs + appendMs
        local uncountedMs = elapsed - rebuildMs - mapBuildMs - sortMs - comparatorMs - appendMs
        if uncountedMs < 0 then
            uncountedMs = 0
        end
        sortProfile.uncountedMs = sortProfile.uncountedMs + uncountedMs
        if sortProfile.calls >= 20 then
            AddonNS.printDebug(
                "PROFILE ItemsOrder:Sort",
                "calls=" .. sortProfile.calls,
                string.format("avg=%.3fms", sortProfile.totalMs / sortProfile.calls),
                string.format("max=%.3fms", sortProfile.maxMs),
                string.format("rebuildAvg=%.3fms", sortProfile.rebuildMs / sortProfile.calls),
                string.format("mapAvg=%.3fms", sortProfile.mapMs / sortProfile.calls),
                string.format("sortAvg=%.3fms", sortProfile.sortMs / sortProfile.calls),
                string.format("comparatorAvg=%.3fms", sortProfile.comparatorMs / sortProfile.calls),
                string.format("appendAvg=%.3fms", sortProfile.appendMs / sortProfile.calls),
                string.format("uncountedAvg=%.3fms", sortProfile.uncountedMs / sortProfile.calls)
            )
            sortProfile.calls = 0
            sortProfile.totalMs = 0
            sortProfile.maxMs = 0
            sortProfile.rebuildMs = 0
            sortProfile.mapMs = 0
            sortProfile.sortMs = 0
            sortProfile.comparatorMs = 0
            sortProfile.appendMs = 0
            sortProfile.uncountedMs = 0
        end
    end
end

local function ItemsMoved(previousItemID, pickedItemID, changedCategory)
    if not previousItemID then return end;
    AddonNS.printDebug("ItemsMoved", previousItemID, pickedItemID, changedCategory)
    recreateAnOrderMapIfNeeded();
    local prevNo = order_map[previousItemID];
    local pickedNo = order_map[pickedItemID];

    AddonNS.printDebug("ItemsMoved2", prevNo, pickedNo)
    if not prevNo or not pickedNo then
        -- Missing from order map; ignore to avoid breaking reassignment.
        return
    end

    if changedCategory then
        table.remove(items_current_order, pickedNo)
        AddonNS.printDebug(prevNo, pickedNo, (prevNo > pickedNo and 1 or 0))
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
