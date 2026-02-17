local addonName, AddonNS = ...

local ITEM_SPACING = AddonNS.Const.ITEM_SPACING
local CATEGORY_HEIGHT = AddonNS.Const.CATEGORY_HEIGHT
local ITEMS_PER_ROW = AddonNS.Const.ITEMS_PER_ROW

local BANK_CHARACTER_SCOPE = "bank-character"
local BANK_ACCOUNT_SCOPE = "bank-account"

local BankView = {
    headerFrames = {},
    currentScope = BANK_CHARACTER_SCOPE,
    refreshQueued = false,
    hooksInstalled = false,
    dataRetryCount = 0,
    scrollOffset = 0,
}

local BANK_VIEWPORT_TOP = -58
local BANK_VIEWPORT_BOTTOM = 40
local BANK_VIEWPORT_LEFT = 16
local BANK_VIEWPORT_RIGHT = -28
local BANK_CONTENT_PADDING_BOTTOM = 8

local function getScopeForBankType(bankType)
    if bankType == Enum.BankType.Account then
        return BANK_ACCOUNT_SCOPE
    end
    return BANK_CHARACTER_SCOPE
end

local function ensureItemButtonBagMethods(itemButton)
    if itemButton.GetBankTabID and itemButton.GetContainerSlotID then
        function itemButton:GetBagID()
            return self:GetBankTabID()
        end
        function itemButton:GetID()
            return self:GetContainerSlotID()
        end
        return
    end
    if not itemButton.GetBagID and itemButton.GetBankTabID then
        function itemButton:GetBagID()
            return self:GetBankTabID()
        end
    end
    if not itemButton.GetID and itemButton.GetContainerSlotID then
        function itemButton:GetID()
            return self:GetContainerSlotID()
        end
    end
end

local function resolveBankButtonContainerSlot(itemButton, selectedTabID)
    local bagID = nil
    if itemButton.GetBankTabID then
        bagID = itemButton:GetBankTabID()
    end
    if bagID == nil and itemButton.GetBagID then
        bagID = itemButton:GetBagID()
    end
    if bagID == nil then
        bagID = selectedTabID
    end

    local slotID = nil
    if itemButton.GetContainerSlotID then
        slotID = itemButton:GetContainerSlotID()
    end
    if slotID == nil and itemButton.GetID then
        slotID = itemButton:GetID()
    end

    if type(bagID) ~= "number" or type(slotID) ~= "number" then
        return nil, nil
    end
    return bagID, slotID
end

local function ensureItemButtonHooks(itemButton)
    if itemButton.myBagAddonHooked then
        return
    end
    itemButton:HookScript("OnDragStart", AddonNS.DragAndDrop.itemStartDrag)
    itemButton:HookScript("OnDragStop", AddonNS.DragAndDrop.itemStopDrag)
    itemButton:HookScript("PreClick", AddonNS.DragAndDrop.itemOnClick)
    itemButton:HookScript("OnReceiveDrag", AddonNS.DragAndDrop.itemOnReceiveDrag)

    if not itemButton.myBagAddonMouseWheelHooked then
        itemButton:EnableMouseWheel(true)
        itemButton:HookScript("OnMouseWheel", function(_, delta)
            local view = AddonNS.BankView
            if view and view.scrollBar then
                view.scrollBar:ScrollStepInDirection(-delta)
            end
        end)
        itemButton.myBagAddonMouseWheelHooked = true
    end

    itemButton.myBagAddonHooked = true
end

local function getActiveBankPanel()
    assert(BankPanel, "BankPanel missing")
    return BankPanel
end

local function hideHeaders(self)
    for index = 1, #self.headerFrames do
        self.headerFrames[index]:Hide()
    end
end

local function hideScrollArea(self)
    if self.scrollViewportBackdrop then
        self.scrollViewportBackdrop:Hide()
    end
end

local function hideAllItemButtons(panel)
    for itemButton in panel:EnumerateValidItems() do
        itemButton:Hide()
    end
end

local function ensureBackground(self, parentFrame)
    if self.backgroundFrame then
        return
    end

    local backgroundFrame = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    backgroundFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, 0)
    backgroundFrame:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", 0, 0)
    backgroundFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    backgroundFrame:SetBackdropColor(0, 0, 0, 0)
    backgroundFrame:EnableMouse(false)

    self.backgroundFrame = backgroundFrame
end

local function ensureScrollArea(self, panel)
    if self.scrollFrame then
        return
    end

    local viewportBackdrop = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    viewportBackdrop:SetPoint("TOPLEFT", panel, "TOPLEFT", BANK_VIEWPORT_LEFT, BANK_VIEWPORT_TOP)
    viewportBackdrop:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", BANK_VIEWPORT_RIGHT, BANK_VIEWPORT_BOTTOM)
    viewportBackdrop:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    viewportBackdrop:SetBackdropColor(0.02, 0.02, 0.02, 0.82)
    viewportBackdrop:EnableMouse(false)
    viewportBackdrop:SetClipsChildren(true)

    local scrollFrame = CreateFrame("ScrollFrame", nil, viewportBackdrop)
    scrollFrame:SetPoint("TOPLEFT", viewportBackdrop, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", viewportBackdrop, "BOTTOMRIGHT", -24, 0)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:EnableMouse(true)
    scrollFrame:SetScript("OnReceiveDrag", AddonNS.DragAndDrop.backgroundOnReceiveDrag)
    scrollFrame:SetScript("OnMouseUp", AddonNS.DragAndDrop.backgroundOnReceiveDrag)
    scrollFrame.myBagAddonHooked = true

    local scrollBar = CreateFrame("EventFrame", nil, viewportBackdrop, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 5, -8)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 5, 5)
    scrollBar:SetFrameStrata(scrollFrame:GetFrameStrata())
    scrollBar:SetFrameLevel(scrollFrame:GetFrameLevel() + 10)

    ScrollUtil.InitScrollFrameWithScrollBar(scrollFrame, scrollBar)
    scrollFrame:HookScript("OnVerticalScroll", function(_, offset)
        self.scrollOffset = offset
    end)

    local scrollContentFrame = CreateFrame("Frame", nil, scrollFrame)
    scrollContentFrame:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
    scrollContentFrame:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 0, 0)
    scrollContentFrame:SetHeight(1)
    scrollContentFrame:SetClipsChildren(false)
    scrollFrame:SetScrollChild(scrollContentFrame)

    self.scrollViewportBackdrop = viewportBackdrop
    self.scrollFrame = scrollFrame
    self.scrollBar = scrollBar
    self.scrollContentFrame = scrollContentFrame
end

local function updateScrollMetrics(self, contentBottomY)
    local viewportHeight = self.scrollFrame:GetHeight() or 0
    local viewportWidth = self.scrollFrame:GetWidth() or 0
    local contentHeight = math.max(viewportHeight, contentBottomY + BANK_CONTENT_PADDING_BOTTOM)
    local maxScroll = math.max(0, contentHeight - viewportHeight)

    self.scrollContentFrame:SetWidth(math.max(1, viewportWidth))
    self.scrollContentFrame:SetHeight(contentHeight)

    local clampedOffset = self.scrollOffset
    if clampedOffset > maxScroll then
        clampedOffset = maxScroll
    end
    if clampedOffset < 0 then
        clampedOffset = 0
    end
    self.scrollOffset = clampedOffset
    self.scrollFrame:SetVerticalScroll(clampedOffset)
end

local function ensureHeaderFrame(self, index)
    if self.headerFrames[index] then
        return self.headerFrames[index]
    end

    local headerFrame = CreateFrame("Frame", nil, self.backgroundFrame, "BackdropTemplate")
    headerFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    headerFrame:SetBackdropColor(1, 0, 0, 0)

    local label = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", ITEM_SPACING / 2, -ITEM_SPACING / 2)
    label:SetPoint("TOPRIGHT", headerFrame, "TOPRIGHT", -ITEM_SPACING / 2, -ITEM_SPACING / 2)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetWordWrap(false)

    headerFrame:EnableMouse(true)
    headerFrame:RegisterForDrag("LeftButton")
    headerFrame:SetScript("OnMouseUp", AddonNS.DragAndDrop.categoryOnMouseUp)
    headerFrame:SetScript("OnReceiveDrag", AddonNS.DragAndDrop.categoryOnReceiveDrag)
    headerFrame:SetScript("OnDragStart", function(frame)
        AddonNS.gui:StartCategoryDragVisual(frame.ItemCategory:GetDisplayName() or "Unassigned")
        AddonNS.DragAndDrop.categoryStartDrag(frame)
        PlaySound(1183)
    end)
    headerFrame:SetScript("OnDragStop", function()
        AddonNS.gui:StopCategoryDragVisual()
        PlaySound(1200)
    end)
    headerFrame:EnableMouseWheel(true)
    headerFrame:SetScript("OnMouseWheel", function(_, delta)
        self.scrollBar:ScrollStepInDirection(-delta)
    end)

    function headerFrame:SetText(text)
        label:SetText(text)
    end

    headerFrame.label = label
    self.headerFrames[index] = headerFrame
    return headerFrame
end

local function placeItemsAndBuildHeaders(scope, panel, categoryAssignments, itemSize)
    local categoryPositions = {}
    local positions = {}
    local columnsBottom = {}
    local leftPadding = 22
    local firstRowY = 30
    local columnPixelWidth = itemSize * ITEMS_PER_ROW + AddonNS.Const.COLUMN_SPACING

    local function placeColumn(columnIndex, categories)
        local columnStartX = leftPadding + (columnIndex - 1) * columnPixelWidth
        local currentY = firstRowY

        for index, categoryObj in ipairs(categories) do
            local category = categoryObj.category
            local items = categoryObj.items
            local itemsCount = categoryObj.itemsCount or #items
            local collapsed = AddonNS.Collapsed.isCollapsed(category, scope)

            if index > 1 then
                currentY = currentY + CATEGORY_HEIGHT + AddonNS.Const.COLUMN_SPACING
            end

            table.insert(categoryPositions, {
                category = category,
                itemsCount = itemsCount,
                x = columnStartX - ITEM_SPACING / 2,
                y = currentY - CATEGORY_HEIGHT,
                width = itemSize * ITEMS_PER_ROW,
                height = CATEGORY_HEIGHT,
                scope = scope,
            })

            if not collapsed then
                local rowIndex = 0
                local colIndex = 0
                for itemIndex = #items, 1, -1 do
                    local itemButton = items[itemIndex]
                    if itemButton ~= AddonNS.itemButtonPlaceholder then
                        local y = currentY + rowIndex * itemSize
                        local x = columnStartX + colIndex * itemSize
                        positions[itemButton] = { x = x, y = y }
                    end
                    colIndex = colIndex + 1
                    if colIndex >= ITEMS_PER_ROW then
                        colIndex = 0
                        rowIndex = rowIndex + 1
                    end
                end
                local rowCount = math.ceil(itemsCount / ITEMS_PER_ROW)
                currentY = currentY + rowCount * itemSize
            end
        end

        columnsBottom[columnIndex] = currentY
    end

    for columnIndex, categories in ipairs(categoryAssignments) do
        placeColumn(columnIndex, categories)
    end

    local contentBottom = 0
    for index = 1, #columnsBottom do
        if columnsBottom[index] > contentBottom then
            contentBottom = columnsBottom[index]
        end
    end

    return positions, categoryPositions, contentBottom
end

local function applyItemPositions(panel, parentFrame, positions)
    for itemButton, position in pairs(positions) do
        if itemButton:GetParent() ~= parentFrame then
            itemButton:SetParent(parentFrame)
        end
        itemButton:ClearAllPoints()
        itemButton:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", position.x, -position.y)
        itemButton:Show()
    end

    for itemButton in panel:EnumerateValidItems() do
        if not positions[itemButton] then
            itemButton:Hide()
        end
    end
end

local function renderHeaders(self, scope, panel, categoryPositions)
    self.backgroundFrame.MyBagsScope = scope

    for index = 1, #categoryPositions do
        local categoryPosition = categoryPositions[index]
        local frame = ensureHeaderFrame(self, index)
        frame.ItemCategory = categoryPosition.category
        frame.MyBagsScope = scope
        frame.MyBagsContainerRef = panel
        frame:SetPoint("TOPLEFT", self.backgroundFrame, "TOPLEFT", categoryPosition.x, -categoryPosition.y)
        frame:SetSize(categoryPosition.width, categoryPosition.height)

        local label = categoryPosition.category:GetDisplayName(categoryPosition.itemsCount) or categoryPosition.category:GetName()
        if AddonNS.Collapsed.isCollapsed(categoryPosition.category, scope) then
            label = label .. " (" .. categoryPosition.itemsCount .. ") |A:glues-characterSelect-icon-arrowDown:19:19:0:4|a"
        end
        frame:SetText(label)
        frame:Show()
    end

    for index = #categoryPositions + 1, #self.headerFrames do
        self.headerFrames[index]:Hide()
    end
end

function BankView:Refresh(scope)
    AddonNS.printDebug("MyBags BankView:Refresh start", scope)
    local panel = getActiveBankPanel()
    if not BankFrame:IsShown() or not panel:IsShown() then
        AddonNS.printDebug("MyBags BankView:Refresh skipped; frame hidden")
        hideHeaders(self)
        hideScrollArea(self)
        return
    end

    local selectedTabID = panel:GetSelectedTabID()
    if type(selectedTabID) ~= "number" then
        AddonNS.printDebug("MyBags BankView:Refresh skipped; invalid selectedTabID", selectedTabID)
        hideHeaders(self)
        hideScrollArea(self)
        hideAllItemButtons(panel)
        return
    end
    local slots = C_Container.GetContainerNumSlots(selectedTabID)
    if type(slots) ~= "number" or slots <= 0 then
        AddonNS.printDebug("MyBags BankView:Refresh skipped; no slots for tab", selectedTabID, slots)
        hideHeaders(self)
        hideScrollArea(self)
        hideAllItemButtons(panel)
        return
    end

    local activeBankType = BankFrame:GetActiveBankType()
    local activeScope = scope or getScopeForBankType(activeBankType)
    self.currentScope = activeScope
    AddonNS:SetCurrentLayoutScope(activeScope)

    ensureScrollArea(self, panel)
    ensureBackground(self, self.scrollContentFrame)
    self.scrollViewportBackdrop:Show()
    self.scrollFrame:Show()
    self.backgroundFrame:Show()

    local arrangedItems = {}
    local firstItemButton = nil

    AddonNS.emptyItemButton = nil
    for itemButton in panel:EnumerateValidItems() do
        ensureItemButtonBagMethods(itemButton)
        ensureItemButtonHooks(itemButton)
        itemButton.MyBagsScope = activeScope

        itemButton.ItemCategory = nil
        local bagID, slotID = resolveBankButtonContainerSlot(itemButton, selectedTabID)
        if bagID and slotID then
            local info = C_Container.GetContainerItemInfo(bagID, slotID)
            if info and not info.isFiltered then
                itemButton._myBagsItemId = info.itemID
                itemButton.ItemCategory = AddonNS.Categories:Categorize(info.itemID, itemButton)
                arrangedItems[itemButton.ItemCategory] = arrangedItems[itemButton.ItemCategory] or {}
                table.insert(arrangedItems[itemButton.ItemCategory], itemButton)
                firstItemButton = firstItemButton or itemButton
            else
                AddonNS.emptyItemButton = itemButton
            end
        end
    end

    if not firstItemButton then
        AddonNS.printDebug("MyBags BankView:Refresh no visible item buttons after classify")
        local hadAnyButtons = false
        for _ in panel:EnumerateValidItems() do
            hadAnyButtons = true
            break
        end
        if hadAnyButtons and self.dataRetryCount < 6 then
            self.dataRetryCount = self.dataRetryCount + 1
            self:QueueRefresh(activeScope)
        else
            self.dataRetryCount = 0
        end
        hideHeaders(self)
        hideAllItemButtons(panel)
        return
    end
    self.dataRetryCount = 0

    local itemSize = firstItemButton:GetHeight() + ITEM_SPACING
    local categoryAssignments = AddonNS.Categories:ArrangeCategoriesIntoColumns(arrangedItems, activeScope)
    local positions, categoryPositions, contentBottom = placeItemsAndBuildHeaders(activeScope, panel, categoryAssignments, itemSize)
    AddonNS.printDebug("MyBags BankView:Refresh rendered categories", #categoryPositions, "scope", activeScope)

    updateScrollMetrics(self, contentBottom)
    applyItemPositions(panel, self.scrollContentFrame, positions)
    renderHeaders(self, activeScope, panel, categoryPositions)
end

function BankView:QueueRefresh(scope)
    if self.refreshQueued then
        return
    end
    self.refreshQueued = true
    RunNextFrame(function()
        self.refreshQueued = false
        self:Refresh(scope)
    end)
end

function BankView:GetCurrentScope()
    return self.currentScope
end

function BankView:RefreshNow(scope)
    self.refreshQueued = false
    self:Refresh(scope)
end

local function tryInstallHooks()
    if BankView.hooksInstalled then
        return true
    end
    if not BankPanel or not BankFrame then
        AddonNS.printDebug("MyBags BankView:hooks not ready; missing BankPanel/BankFrame")
        return false
    end

    BankFrame:HookScript("OnShow", function()
        BankView:RefreshNow()
    end)
    BankFrame:HookScript("OnHide", function()
        hideHeaders(BankView)
        hideScrollArea(BankView)
        if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
            AddonNS:SetCurrentLayoutScope("bag")
        end
    end)

    hooksecurefunc(BankPanel, "RefreshBankPanel", function()
        BankView:QueueRefresh()
    end)
    hooksecurefunc(BankPanel, "SelectTab", function()
        BankView:RefreshNow()
    end)
    hooksecurefunc(BankPanel, "GenerateItemSlotsForSelectedTab", function()
        for itemButton in BankPanel:EnumerateValidItems() do
            itemButton:Hide()
        end
        BankView:RefreshNow()
    end)
    hooksecurefunc(BankPanel, "Clean", function()
        BankView:QueueRefresh()
    end)

    AddonNS.Events:RegisterEvent("BAG_UPDATE", function(_, bagID)
        if not BankFrame:IsShown() then
            return
        end
        local selectedTabID = BankPanel and BankPanel.GetSelectedTabID and BankPanel:GetSelectedTabID() or nil
        if type(selectedTabID) ~= "number" then
            return
        end
        if bagID == nil or bagID == selectedTabID then
            BankView:QueueRefresh()
        end
    end)

    AddonNS.Events:RegisterEvent("INVENTORY_SEARCH_UPDATE", function()
        if BankFrame:IsShown() then
            BankView:QueueRefresh(BankView.currentScope)
        end
    end)

    AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.COLLAPSED_CHANGED, function(_, _, scope)
        if scope == BANK_CHARACTER_SCOPE or scope == BANK_ACCOUNT_SCOPE then
            BankView:QueueRefresh(scope)
        end
    end)

    AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CATEGORIZER_CATEGORIES_UPDATED, function()
        if BankFrame:IsShown() then
            BankView:QueueRefresh(BankView.currentScope)
        end
    end)

    AddonNS.printDebug("MyBags BankView:hooks installed")
    BankView.hooksInstalled = true
    return true
end

AddonNS.BankView = BankView

    AddonNS.Events:OnInitialize(function()
    tryInstallHooks()
    if BankFrame_Open then
        hooksecurefunc("BankFrame_Open", function()
            AddonNS.printDebug("MyBags BankView:BankFrame_Open hook")
            tryInstallHooks()
            BankView:RefreshNow()
        end)
    end
    AddonNS.Events:RegisterEvent("BANKFRAME_OPENED", function()
        AddonNS.printDebug("MyBags BankView:BANKFRAME_OPENED")
        tryInstallHooks()
        BankView:RefreshNow()
    end)
end)
