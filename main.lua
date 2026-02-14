local addonName, AddonNS = ...
local isCollapsed = AddonNS.Collapsed.isCollapsed;

local ITEM_SPACING = AddonNS.Const.ITEM_SPACING;
AddonNS.itemButtonPlaceholder = {}
local refreshProfile = nil

local function profilingEnabled()
    return AddonNS.Profiling and AddonNS.Profiling.enabled
end

local function profileNowMs()
    return debugprofilestop()
end

local container = ContainerFrameCombinedBags;
AddonNS.container = container;

local function triggerContainerOnTokenWatchChanged()
    AddonNS.printDebug("triggerContainerOnTokenWatchChanged fired")
    securecallfunction(container.OnTokenWatchChanged, container);
end

AddonNS.TriggerContainerOnTokenWatchChanged = triggerContainerOnTokenWatchChanged;

local function triggerContainerUpdateItemLayout()
    securecallfunction(container.UpdateItemLayout, container);
end

AddonNS.TriggerContainerUpdateItemLayout = triggerContainerUpdateItemLayout;

local function queueContainerUpdateItemLayout()
    RunNextFrame(function()
        AddonNS.printDebug("QueueContainerUpdateItemLayout fired");
        triggerContainerUpdateItemLayout();
    end);
end

AddonNS.QueueContainerUpdateItemLayout = queueContainerUpdateItemLayout;

local function addCategoriesToTooltip(tooltip)
    local owner = tooltip:GetOwner();
    if not owner or not owner.ItemCategories or #owner.ItemCategories == 0 then return end
    GameTooltip_AddBlankLineToTooltip(tooltip);
    local assigned = owner.ItemCategories[1];

    if #owner.ItemCategories > 0 then
        GameTooltip_AddNormalLine(tooltip, "MyBags matched categories: ");
        for i = 1, #owner.ItemCategories do
            GameTooltip_AddNormalLine(tooltip, i .. ". " .. owner.ItemCategories[i].name);
        end
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, addCategoriesToTooltip)

local freeBagSlots = 10000;
local lockedUpdates = false;
function AddonNS.Events:BAG_UPDATE(event, bagID)
    AddonNS.printDebug("BAG_UPDATE", bagID)

    if (container.MyBags.updateItemLayoutCalledAtLeastOnce) then -- todo: reading this after a while - what the hell is this :D once i know i have to add here proper comments lol
        local newFreeBagSlots = CalculateTotalNumberOfFreeBagSlots()

        AddonNS.printDebug("FREE BAGS", newFreeBagSlots, freeBagSlots)
        if newFreeBagSlots <= freeBagSlots and not lockedUpdates then
            queueContainerUpdateItemLayout();
        end
        lockedUpdates = true;
        RunNextFrame(function()
            lockedUpdates = false; -- and also why is this not in the run next frame above? eh
        end);
        freeBagSlots = newFreeBagSlots;
    end
end

local function updateOnTokenWatchChangedOnNextFrame(event) -- todo: i just copied and modified the function from above - but it needs comments or fixing following the comments I just added there above
    AddonNS.printDebug("updateOnTokenWatchChangedOnNextFrame and locked: ", lockedUpdates)
    if not lockedUpdates then
        RunNextFrame(function()
            AddonNS.printDebug("updateOnTokenWatchChangedOnNextFrame FIRED")
            triggerContainerOnTokenWatchChanged();
        end);
    end
    lockedUpdates = true;
    RunNextFrame(function()
        lockedUpdates = false;
    end);
end

function AddonNS.Events:INVENTORY_SEARCH_UPDATE(event, bagID)
    AddonNS.printDebug("INVENTORY_SEARCH_UPDATE", bagID)
    triggerContainerUpdateItemLayout();
end

AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CATEGORIZER_CATEGORIES_UPDATED,
updateOnTokenWatchChangedOnNextFrame);
AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.COLLAPSED_CHANGED, updateOnTokenWatchChangedOnNextFrame);

AddonNS.Events:RegisterEvent("INVENTORY_SEARCH_UPDATE");

AddonNS.Events:RegisterEvent("BAG_UPDATE");
function container:GetColumns()
    return AddonNS.Const.NUM_ITEM_COLUMNS
end

local it = container:EnumerateValidItems()

AddonNS.emptyItemButton = nil
local function newIterator(container, index)
    local arrangedItems = container.MyBags.arrangedItems;
    local positionsInBags = container.MyBags.positionsInBags;
    local index, itemButton = it(container, index);
    if (index == 1) then
        AddonNS.emptyItemButton = nil -- reset itemButom
        if profilingEnabled() then
            refreshProfile = {
                startedAt = profileNowMs(),
                itemsSeen = 0,
                categorizeMs = 0,
                arrangeMs = 0,
                placeMs = 0,
                totalMs = 0,
            }
        else
            refreshProfile = nil
        end
    end
    if (itemButton) then
        -- [[ checking hooks]]
        if (not itemButton.myBagAddonHooked) then
            -- TODO: prolly need to remove this hook when not merged bags are used to not destroy by accident proper categorisations?
            -- todo: this should be done once during these creation steps, not here.

            itemButton:HookScript("OnDragStart", AddonNS.DragAndDrop.itemStartDrag);
            itemButton:HookScript("OnDragStop", AddonNS.DragAndDrop.itemStopDrag);
            itemButton:HookScript("PreClick", AddonNS.DragAndDrop.itemOnClick);
            itemButton:HookScript("OnReceiveDrag", AddonNS.DragAndDrop.itemOnReceiveDrag);
            itemButton.myBagAddonHooked = true;
        end


        -- [[ CATEGORISATION ]]
        local info = C_Container.GetContainerItemInfo(itemButton:GetBagID(), itemButton:GetID());
        itemButton.ItemCategory = nil;
        if (info and not info.isFiltered) then
            itemButton._myBagsItemId = info.itemID
            local categorizeStartedAt = refreshProfile and profileNowMs() or nil
            itemButton.ItemCategory = AddonNS.Categories:Categorize(info.itemID, itemButton);
            if refreshProfile then
                refreshProfile.itemsSeen = refreshProfile.itemsSeen + 1
                refreshProfile.categorizeMs = refreshProfile.categorizeMs + (profileNowMs() - categorizeStartedAt)
            end
            arrangedItems[itemButton.ItemCategory] = arrangedItems[itemButton.ItemCategory] or
                {}

            table.insert(arrangedItems[itemButton.ItemCategory], itemButton);
        elseif itemButton:GetBagID() ~= Enum.BagIndex.ReagentBag then
            AddonNS.emptyItemButton = itemButton;
        end
    else --[[ iterator finished so we can now tackle the list and calcualte the positions of items, as we now have all the items]]
        local itemSize = container.Items[1]:GetHeight() + ITEM_SPACING;
        container.MyBags.rows = 0;
        container.MyBags.height = 0;
        container.MyBags.categoryPositions = {};
        local function placeItemsInGrid(categoriesObj, columnStartX)
            local currentRow = {}
            local itemPlaceholder = AddonNS.itemButtonPlaceholder;
            local currentRowWidth = 0
            local currentRowY = 0
            local rowWithNewCategory = false;
            local currentRowNo = 0;
            local function flushCurrentRow()
                local xOffset = 0
                for _, item in ipairs(currentRow) do
                    if item ~= itemPlaceholder then
                        positionsInBags[item:GetBagID()] = positionsInBags[item:GetBagID()] or {};
                        positionsInBags[item:GetBagID()][item:GetID()] = {
                            id = item:GetID(),
                            x = columnStartX + xOffset,
                            y = currentRowY,
                        };
                    end
                    xOffset = xOffset + itemSize
                end
                currentRow = {}
                currentRowWidth = 0
                currentRowY = currentRowY + itemSize
                rowWithNewCategory = false;
                currentRowNo = currentRowNo + 1;
            end

            for i, categoryObj in ipairs(categoriesObj) do
                local categoryItemsCount = categoryObj.itemsCount or #categoryObj.items;
                local isCategoryCollapsed = isCollapsed(categoryObj.category);
                local isCategoryHeaderOnly =categoryObj.itemsCount == 0;
                local categoryRenderedAsRowHeader = isCategoryCollapsed or isCategoryHeaderOnly;
                local categoryRequiresNewLine = categoryRenderedAsRowHeader or categoryObj.category.separateLine;
                local requiredNewLine =
                    categoryRequiresNewLine
                    or #currentRow == 0
                    or #currentRow > 0 and
                    (rowWithNewCategory and currentRowWidth + itemSize * (categoryItemsCount) > AddonNS.Const.ITEMS_PER_ROW * itemSize or not rowWithNewCategory)

                if (i == 1) then
                    currentRowY = currentRowY + AddonNS.Const.CATEGORY_HEIGHT;
                elseif requiredNewLine then
                    if (#currentRow > 0) then
                        flushCurrentRow();
                    end
                    currentRowY = currentRowY + AddonNS.Const.CATEGORY_HEIGHT + AddonNS.Const.COLUMN_SPACING;
                end
                local nextCategoryExists = categoriesObj[i + 1] and true or false; -- to be explict, for increased readability

                local expandCategoryToRightColumnBoundary =
                    (#currentRow + categoryItemsCount < AddonNS.Const.ITEMS_PER_ROW and
                        (
                            categoryRenderedAsRowHeader
                            or (not nextCategoryExists)
                            or isCollapsed(categoriesObj[i + 1].category)
                            or categoriesObj[i + 1].itemsCount == 0
                            or categoriesObj[i + 1].category.separateLine
                            or #currentRow + categoryItemsCount + #categoriesObj[i + 1].items > AddonNS.Const.ITEMS_PER_ROW
                        )
                    )
                    and (AddonNS.Const.ITEMS_PER_ROW - #currentRow - categoryItemsCount) or 0
                table.insert(container.MyBags.categoryPositions,
                    {
                        category = categoryObj.category,
                        itemsCount = categoryItemsCount,
                        x = columnStartX + itemSize * #currentRow - ITEM_SPACING / 2,
                        y = currentRowY - AddonNS.Const.CATEGORY_HEIGHT,
                        width = itemSize *
                            (categoryItemsCount > AddonNS.Const.ITEMS_PER_ROW and AddonNS.Const.ITEMS_PER_ROW or categoryItemsCount + expandCategoryToRightColumnBoundary),
                        height = AddonNS.Const.CATEGORY_HEIGHT + ((not categoryRenderedAsRowHeader and
                            math.ceil(categoryItemsCount / AddonNS.Const.ITEMS_PER_ROW) *
                            itemSize) or 0),
                    });
                rowWithNewCategory = true;
                local items = categoryObj.items;
                if (not categoryRenderedAsRowHeader) then
                    for j = #items, 1, -1 do
                        local item = items[j];
                        table.insert(currentRow, item)
                        currentRowWidth = currentRowWidth + itemSize
                        if #currentRow >= AddonNS.Const.ITEMS_PER_ROW then
                            flushCurrentRow()
                        end
                    end
                end
            end

            if #currentRow > 0 then
                flushCurrentRow()
            end
            if (container.MyBags.height <= currentRowY) then
                container.MyBags.height = currentRowY;
                container.MyBags.rows = currentRowNo;
            end
        end

        -- Calculate positions for each column
        local categoryAssignments = {}
        local arrangeStartedAt = refreshProfile and profileNowMs() or nil
        categoryAssignments = AddonNS.Categories:ArrangeCategoriesIntoColumns(arrangedItems) -- todo: this object is quite weird. Why is it a local global used among two functions :/
        if refreshProfile then
            refreshProfile.arrangeMs = refreshProfile.arrangeMs + (profileNowMs() - arrangeStartedAt)
        end


        local columnSize = itemSize * AddonNS.Const.ITEMS_PER_ROW + AddonNS.Const.COLUMN_SPACING;
        local placeStartedAt = refreshProfile and profileNowMs() or nil
        for colIndex, categoryObjs in ipairs(categoryAssignments) do
            local columnStartX = (colIndex - 1) * columnSize
            placeItemsInGrid(categoryObjs, columnStartX)
        end
        if refreshProfile then
            refreshProfile.placeMs = refreshProfile.placeMs + (profileNowMs() - placeStartedAt)
            refreshProfile.totalMs = profileNowMs() - refreshProfile.startedAt
            AddonNS.printDebug(
                "PROFILE bag refresh",
                "items=" .. refreshProfile.itemsSeen,
                string.format("categorize=%.2fms", refreshProfile.categorizeMs),
                string.format("arrange=%.2fms", refreshProfile.arrangeMs),
                string.format("place=%.2fms", refreshProfile.placeMs),
                string.format("total=%.2fms", refreshProfile.totalMs)
            )
        end
    end
    return index, itemButton;
end

function AddonNS.newEnumerateValidItems(container)
    return newIterator, container, 0;
end
