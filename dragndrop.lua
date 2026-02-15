local addonName, AddonNS = ...

AddonNS.DragAndDrop = {};
local toggleCollapsed = AddonNS.Collapsed.toggleCollapsed;


local rows = 0;
local height = 0;
local pickedItemID = nil;
local pickedItemCategory = nil;
local pickedItemButton = nil;
local container = AddonNS.container;

local recentAt = 0
local TTL = 0.10 -- 100 ms
local cachedInfoType, cachedItemID, cachedItemLink;

local function getCachedCursorInfo()
    local now = GetTime();
    if (now - recentAt > TTL) then
        cachedInfoType, cachedItemID, cachedItemLink = GetCursorInfo();
        recentAt = now;
    end
    return cachedInfoType, cachedItemID, cachedItemLink;
end

local function resolveCategory(category)
    if not category then
        return nil
    end
    if type(category) == "table" then
        return category
    end
    return AddonNS.CategoryStore:Get(category)
end

local function getCategoryId(category)
    if type(category) == "table" and category.GetId then
        return category:GetId()
    end
    return category and category.id or nil
end

local function canTriggerItemMove(sourceCategory, targetCategory)
    if targetCategory and targetCategory:IsProtected() then
        return false
    end
    return true
end

local function triggerItemMoved(itemID, targetedItemID, sourceCategory, targetCategory, pickedItemButton, targetItemButton)
    local source = resolveCategory(sourceCategory)
    local target = resolveCategory(targetCategory)
    if not canTriggerItemMove(source, target) then
        return
    end
    AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.ITEM_MOVED, itemID, targetedItemID, source, target,
        pickedItemButton,
        targetItemButton);
end

function AddonNS.DragAndDrop.cleanUp()
    AddonNS.printDebug("cleanUp")
    pickedItemButton = nil;
    pickedItemID = nil
    pickedItemCategory = nil;
end

--[[
unknown item -> item
- assign new category to item
- refresh gear (buttons) ItemCategories
- change button order

item -> item
- assign new category to item
- refresh gear (buttons) ItemCategories
- change button order

item -> category
- assign new category to item

category -> item
- change category order

category -> category
- change category order

]]

hooksecurefunc(C_Container, "SplitContainerItem",
    function(bag, slot, amount) -- to force placement onto an emptyItemButton
        pickedItemButton = nil;
    end)

local function getItemIdFromButton(buttonItem)
    local info = buttonItem and buttonItem.GetBagID and
        C_Container.GetContainerItemInfo(buttonItem:GetBagID(), buttonItem:GetID());
    return info and info.itemID
end

function AddonNS.DragAndDrop.itemOnClick(self, button)
    AddonNS.printDebug("itemOnClick")
    if button == "LeftButton" then
        local infoType, itemID, itemLink = getCachedCursorInfo()
        AddonNS.printDebug(pickedItemButton, infoType, itemID, itemLink)
        if (infoType) then
            if (pickedItemButton and itemID ~= getItemIdFromButton(self)) then
                ClearCursor(); -- [faster movement feature] see INFO in itemOnReceiveDrag function
            end
            AddonNS.DragAndDrop.itemOnReceiveDrag(self)
        else
            AddonNS.DragAndDrop.itemStartDrag(self);
        end
    end
end

local function isMouseOverHookedFrame(targetedItemID)
    local mouseFoci = GetMouseFoci()
    local f = mouseFoci[1]
    if f and (f.myBagAddonHooked or f.ItemCategory) then
        if (getItemIdFromButton(f)) then
            return getItemIdFromButton(f) ~= targetedItemID;
        end
        return true
    end
    return false
end
function AddonNS.DragAndDrop.itemStopDrag(self)                 -- its only here to refresh cursor as we are hooking to onreceiveddrag and that means that cursor is cleared by the time it arrives to our code. Hence we will Cache it and use that instead.
    getCachedCursorInfo()                                       -- this is here to cache the value even when it would be removed by Blizzard code
    if (isMouseOverHookedFrame(getItemIdFromButton(self))) then -- [faster movement feature]
        ClearCursor();                                          -- see INFO in itemOnReceiveDrag function
    end
end

function AddonNS.DragAndDrop.itemStartDrag(self)
    AddonNS.DragAndDrop.cleanUp()
    AddonNS.printDebug("itemStartDrag")
    local itemID = getItemIdFromButton(self)
    if (itemID) then
        pickedItemButton = self;
        pickedItemID = itemID;
        pickedItemCategory = self.ItemCategory;
    end
end

function AddonNS.DragAndDrop.itemOnReceiveDrag(self)
    AddonNS.printDebug("itemOnReceiveDrag")

    local targetItemCategory = self.ItemCategory;

    local infoType, itemID, itemLink = getCachedCursorInfo()
    if (infoType == "merchant") then
        itemID = GetMerchantItemID(itemID)
        infoType = "item";
    end

    if (infoType == "item") then
        local info = C_Container.GetContainerItemInfo(self:GetBagID(), self:GetID());
        local targetedItemID = info and info.itemID or nil;
        if (pickedItemButton) then
            if (itemID ~= pickedItemID) then -- i think this is here to prevent some weird situation when pickeditembutton is not cleared, but now I am going to extend it with check for faster movement feature
                AddonNS.DragAndDrop.cleanUp()
            end
            if itemID ~= getItemIdFromButton(self) then
                --[[ INFO: this magic here is because in AddonNS.DragAndDrop.itemStopDrag we added cleraring curosor,
        so then main game uses PickupContainerItem which pickups item on which drag ends,
        so this function here is to put that item back... :D but because of that the movement of items
        between slots is much faster as it does not require a sync to a server, as the item physicially
        does not move, we change only the location of itembuttons hence it is super quick ]]
                C_Container.PickupContainerItem(self:GetBagID(), self:GetID()) -- [faster movement feature]
            end
        end
        triggerItemMoved(itemID, targetedItemID, pickedItemCategory, targetItemCategory, pickedItemButton, self);
    elseif pickedItemCategory then -- category frame
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CATEGORY_MOVED,
            getCategoryId(pickedItemCategory), getCategoryId(targetItemCategory));
    end
    AddonNS.QueueContainerUpdateItemLayout();
    AddonNS.DragAndDrop.cleanUp()
end

function AddonNS.DragAndDrop.categoryStartDrag(self)
    AddonNS.DragAndDrop.cleanUp()
    AddonNS.printDebug("categoryStartDrag")
    pickedItemCategory = self.ItemCategory;
    AddonNS.printDebug("categoryStartDrag", pickedItemCategory)
end

function AddonNS.DragAndDrop.categoryOnMouseUp(self, button)
    AddonNS.printDebug("categoryOnMouseUp")
    local infoType = getCachedCursorInfo()
    if infoType then
        if button == "LeftButton" then
            AddonNS.DragAndDrop.categoryOnReceiveDrag(self)
        end
    else
        local refreshView = false
        if button == "LeftButton" then
            if AddonNS.BagViewState:IsCategoriesConfigMode() then
                local category = self.ItemCategory
                category:OnLeftClickConfigMode(container)
                return
            end
            toggleCollapsed(self.ItemCategory);
        elseif button == "RightButton" then
            local category = self.ItemCategory
            if category and category.OnRightClick then
                refreshView = category:OnRightClick(container)
            end
        end

        if (refreshView) then
            AddonNS.QueueContainerUpdateItemLayout();
        end
    end
end

function AddonNS.DragAndDrop.categoryOnReceiveDrag(self)
    AddonNS.printDebug("categoryOnReceiveDrag")

    local targetItemCategory = self.ItemCategory;

    AddonNS.printDebug("categoryOnReceiveDrag", targetItemCategory)

    local infoType, itemID = getCachedCursorInfo()
    if (infoType == "merchant") then
        itemID = GetMerchantItemID(itemID)
        infoType = "item";
    end
    if (infoType == "item") then
        if (pickedItemButton and itemID ~= pickedItemID) then
            AddonNS.DragAndDrop.cleanUp()
        end
        if not pickedItemButton and AddonNS.emptyItemButton then
            ContainerFrameItemButton_OnClick(AddonNS.emptyItemButton, "LeftButton")
        end
        triggerItemMoved(itemID, nil, pickedItemCategory, targetItemCategory, pickedItemButton, nil);
        ClearCursor();
        AddonNS.QueueContainerUpdateItemLayout();
    elseif pickedItemCategory and (pickedItemCategory ~= targetItemCategory) then -- category frame
        local moveTail = IsShiftKeyDown()
        AddonNS.printDebug("sending CATEGORY_MOVED", AddonNS.Const.Events.CATEGORY_MOVED)
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CATEGORY_MOVED,
            getCategoryId(pickedItemCategory), getCategoryId(targetItemCategory), moveTail);
        RunNextFrame(function() -- todo: maybe these actually should be triggered at the point where action is processed... hmm
            AddonNS.TriggerContainerOnTokenWatchChanged();
            -- container:UpdateContainerFrameAnchors();
        end);
    end

    AddonNS.DragAndDrop.cleanUp()
end

local function GetMouseSectionRelativeToFrame(frame)
    -- Get the cursor position in screen coordinates
    local cursorX, cursorY = GetCursorPosition()

    -- Get the frame's scale (useful if the frame or UI is scaled)
    local scale = frame:GetEffectiveScale()

    -- Convert cursor coordinates to UI scale
    cursorX = cursorX / scale
    cursorY = cursorY / scale

    -- Get frame position and dimensions
    local frameLeft = frame:GetLeft()
    local frameBottom = frame:GetBottom()
    local frameWidth = frame:GetWidth()
    local frameHeight = frame:GetHeight()

    -- Calculate the relative position within the frame
    local relativeX = cursorX - frameLeft
    local relativeY = cursorY - frameBottom

    -- Ensure the coordinates are within the frame boundaries
    if relativeX < 0 or relativeX > frameWidth or relativeY < 0 or relativeY > frameHeight then
        return nil -- Cursor is outside the frame
    end

    -- Determine which section (column) the mouse is in

    return math.floor(relativeX * AddonNS.CategoryStore:GetColumnCount() / frameWidth) + 1
end



function AddonNS.DragAndDrop.backgroundOnReceiveDrag(self)
    AddonNS.printDebug("backgroundOnReceiveDrag")
    local columnNo = GetMouseSectionRelativeToFrame(self)
    if (columnNo) then
        local infoType, itemID, itemLink = getCachedCursorInfo()
        if (infoType == "merchant") then
            itemID = GetMerchantItemID(itemID)
            infoType = "item";
        end
        if (infoType == "item") then
            if (pickedItemButton and itemID ~= pickedItemID) then
                AddonNS.DragAndDrop.cleanUp()
            end
            if not pickedItemButton and AddonNS.emptyItemButton then
                ContainerFrameItemButton_OnClick(AddonNS.emptyItemButton, "LeftButton")
            end
            local targetCategory = AddonNS.Categories:GetLastCategoryInColumn(columnNo);
            triggerItemMoved(itemID, nil, pickedItemCategory, targetCategory, pickedItemButton, nil);
            ClearCursor();
            AddonNS.QueueContainerUpdateItemLayout();
        elseif pickedItemCategory then -- category frame
            local moveTail = IsShiftKeyDown()
            AddonNS.printDebug("sending CATEGORY_MOVED_TO_COLUMN", AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN)
            AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN,
                getCategoryId(pickedItemCategory), columnNo, moveTail);
            -- ClearCursor();
            RunNextFrame(function()
                AddonNS.TriggerContainerOnTokenWatchChanged();
            end);
        end
        AddonNS.DragAndDrop.cleanUp()
    end
end

function AddonNS.DragAndDrop.customCategoryGUIOnMouseUp(targetCategoryId, button)
    AddonNS.printDebug("customCategoryGUIOnMouseUp", button)
    if button == "LeftButton" then
        AddonNS.DragAndDrop.customCategoryGUIOnReceiveDrag(targetCategoryId)
    end
end

function AddonNS.DragAndDrop.customCategoryGUIOnReceiveDrag(targetCategoryId)
    AddonNS.printDebug("customCategoryGUIOnReceiveDrag", pickedItemCategory, targetCategoryId)

    if (pickedItemButton) then -- button
        local infoType, itemID, itemLink = getCachedCursorInfo()
        if infoType == "item" and itemID == pickedItemID then
            local targetCategory = AddonNS.CategoryStore:Get(targetCategoryId)
            triggerItemMoved(itemID, nil, pickedItemCategory, targetCategory, pickedItemButton, nil);
            ClearCursor();
            AddonNS.QueueContainerUpdateItemLayout();
        end
    end

    AddonNS.DragAndDrop.cleanUp()
end
