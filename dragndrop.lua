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

hooksecurefunc(C_Container, "SplitContainerItem", function(bag, slot, amount) -- to force placement onto an emptyItemButton
  pickedItemButton = nil;
end)


function AddonNS.DragAndDrop.itemOnClick(self, button)
    AddonNS.printDebug("itemOnClick")
    if button == "LeftButton" then
        local infoType, itemID, itemLink = getCachedCursorInfo()
        AddonNS.printDebug(pickedItemButton, infoType, itemID, itemLink)
        if (infoType) then
            ClearCursor();
            AddonNS.DragAndDrop.itemOnReceiveDrag(self)
        else
            AddonNS.DragAndDrop.itemStartDrag(self);
        end
    end
end

function AddonNS.DragAndDrop.itemStopDrag(self) -- its only here to refresh cursor as we are hooking to onreceiveddrag and that means that cursor is cleared by the time it arrives to our code. Hence we will Cache it and use that instead.
    getCachedCursorInfo()
    ClearCursor(); -- see INFO in itemOnReceiveDrag function
end

function AddonNS.DragAndDrop.itemStartDrag(self)
    AddonNS.DragAndDrop.cleanUp()
    AddonNS.printDebug("itemStartDrag")
    local info = C_Container.GetContainerItemInfo(self:GetBagID(), self:GetID());
    if (info) then
        pickedItemButton = self;
        pickedItemID = info.itemID
        pickedItemCategory = self.ItemCategory;
    end
end

function AddonNS.DragAndDrop.itemOnReceiveDrag(self, ...)
    print("itemOnReceiveDrag")
    

    local targetItemCategory = self.ItemCategory;

    local infoType, itemID, itemLink = getCachedCursorInfo()
    if (infoType == "merchant") then
        itemID = GetMerchantItemID(itemID)
        infoType = "item";
    else 
    elseif(pickedItemButton) then
        --[[ INFO: this magic here is because in AddonNS.DragAndDrop.itemStopDrag we added cleraring curosor, 
        so then main game uses PickupContainerItem which pickups item on which drag ends, 
        so this function here is to put that item back... :D but because of that the movement of items 
        between slots is much faster as it does not require a sync to a server, as the item physicially 
        does not move, we change only the location of itembuttons hence it is super quick ]]
        C_Container.PickupContainerItem(self:GetBagID(), self:GetID()) 
    end
    print("infotype",infoType)

    if (infoType == "item") then
        if (pickedItemButton and itemID ~= pickedItemID) then
            AddonNS.DragAndDrop.cleanUp()
        end
        local info = C_Container.GetContainerItemInfo(self:GetBagID(), self:GetID());
        local targetedItemID = info and info.itemID or nil;
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.ITEM_MOVED, itemID, targetedItemID,
            pickedItemCategory, targetItemCategory, pickedItemButton, self);
    elseif pickedItemCategory then -- category frame
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CATEGORY_MOVED,
            pickedItemCategory, targetItemCategory);
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
            toggleCollapsed(self.ItemCategory);
        elseif button == "RightButton" then
            if (self.OnRightClick) then
                refreshView = self:OnRightClick(container);
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
        if (pickedItemButton and itemID ~= pickedItemID) then -- todo: jak to jest sytuacja? chyba ze idzie z banku lub od vendora - w kazdym razie nie z naszego buttona
            AddonNS.DragAndDrop.cleanUp()
        end
        if not pickedItemButton and AddonNS.emptyItemButton then -- why is this here, this causes problems now, lol.... - it should not be from reagents bag. and it should only click, when the item is not taken from the bag
            ContainerFrameItemButton_OnClick(AddonNS.emptyItemButton, "LeftButton")
        end
        AddonNS.CustomCategories:AssignToCategory(self.ItemCategory, itemID)
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.ITEM_CATEGORY_CHANGED, pickedItemID, pickedItemButton)
        ClearCursor();
        AddonNS.QueueContainerUpdateItemLayout();
    elseif pickedItemCategory and (pickedItemCategory ~= targetItemCategory) then -- category frame
        AddonNS.printDebug("sending CATEGORY_MOVED", AddonNS.Const.Events.CATEGORY_MOVED)
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CATEGORY_MOVED,
            pickedItemCategory, targetItemCategory);
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

    return math.floor(relativeX * AddonNS.Const.NUM_COLUMNS / frameWidth) + 1
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
            AddonNS.CustomCategories:AssignToCategory(targetCategory, itemID)
            AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.ITEM_CATEGORY_CHANGED, pickedItemID, pickedItemButton)
            ClearCursor();
            AddonNS.QueueContainerUpdateItemLayout();
        elseif pickedItemCategory then -- category frame
            AddonNS.printDebug("sending CATEGORY_MOVED_TO_COLUMN", AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN)
            AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN,
                pickedItemCategory, columnNo);
            -- ClearCursor();
            RunNextFrame(function()
                AddonNS.TriggerContainerOnTokenWatchChanged();
            end);
        end
        AddonNS.DragAndDrop.cleanUp()
    end
end

function AddonNS.DragAndDrop.customCategoryGUIOnMouseUp(targetItemCategoryName, button)
    AddonNS.printDebug("customCategoryGUIOnMouseUp", button)
    if button == "LeftButton" then
        AddonNS.DragAndDrop.customCategoryGUIOnReceiveDrag(targetItemCategoryName)
    end
end

function AddonNS.DragAndDrop.customCategoryGUIOnReceiveDrag(targetItemCategoryName)
    AddonNS.printDebug("customCategoryGUIOnReceiveDrag", pickedItemCategory, targetItemCategoryName)

    if (pickedItemButton) then -- button
        local infoType, itemID, itemLink = getCachedCursorInfo()
        if infoType == "item" and itemID == pickedItemID then
            local cat = AddonNS.Categories:GetCategoryByName(targetItemCategoryName);
            AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.ITEM_CATEGORY_CHANGED, pickedItemID, pickedItemButton)
            if cat then
                AddonNS.CustomCategories:AssignToCategory(cat, itemID)
            else
                AddonNS.CustomCategories:AssignToCategoryByName(targetItemCategoryName, itemID)
            end
            ClearCursor();
            AddonNS.QueueContainerUpdateItemLayout();
        end
    end

    AddonNS.DragAndDrop.cleanUp()
end
