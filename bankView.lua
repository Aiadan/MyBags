local addonName, AddonNS = ...

local ITEM_SPACING = AddonNS.Const.ITEM_SPACING
local CATEGORY_HEIGHT = AddonNS.Const.CATEGORY_HEIGHT
local ITEMS_PER_ROW = AddonNS.Const.ITEMS_PER_ROW

local BANK_CHARACTER_SCOPE = "bank-character"
local BANK_ACCOUNT_SCOPE = "bank-account"

local BankView = {
    headerFrames = {},
    dropFrames = {},
    currentScope = BANK_CHARACTER_SCOPE,
    visibleTabIds = {},
    refreshQueued = false,
    hooksInstalled = false,
    dataRetryCount = 0,
    scrollOffset = 0,
    itemButtonsSignature = nil,
}

local BANK_VIEWPORT_TOP = -58
local BANK_VIEWPORT_BOTTOM = 40
local BANK_VIEWPORT_LEFT = 26
local BANK_VIEWPORT_RIGHT = -28
local BANK_CONTENT_PADDING_BOTTOM = 8
local SHOW_COLUMN_DROP_AREAS = true
local BANK_CONTENT_LEFT_PADDING = 6
local BANK_CONTENT_FIRST_ROW_Y = 30

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

local function resolveBankButtonContainerSlot(itemButton)
    local bagID = nil
    if itemButton.GetBankTabID then
        bagID = itemButton:GetBankTabID()
    end
    if bagID == nil and itemButton.GetBagID then
        bagID = itemButton:GetBagID()
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

local function getPurchasedTabIdsForActiveType(panel)
    local tabData = panel.purchasedBankTabData
    if type(tabData) ~= "table" then
        tabData = C_Bank.FetchPurchasedBankTabData(panel:GetActiveBankType()) or {}
    end

    local tabIds = {}
    for index = 1, #tabData do
        local id = tabData[index] and tabData[index].ID
        if type(id) == "number" and id > 0 then
            table.insert(tabIds, id)
        end
    end
    return tabIds, tabData
end

local function buildVisibleTabIds(tabIds)
    local set = {}
    for index = 1, #tabIds do
        set[tabIds[index]] = true
    end
    return set
end

local function shouldRefreshForBagUpdate(visibleTabIds, bagID)
    if bagID == nil then
        return true
    end
    return visibleTabIds[bagID] == true
end

local function generateAllTabItemButtons(panel, activeBankType, tabIds)
    panel.itemButtonPool:ReleaseAll()
    for tabIndex = 1, #tabIds do
        local tabID = tabIds[tabIndex]
        local slots = C_Container.GetContainerNumSlots(tabID)
        if type(slots) == "number" and slots > 0 then
            for containerSlotID = 1, slots do
                local button = panel.itemButtonPool:Acquire()
                button:Init(activeBankType, tabID, containerSlotID)
                button:Show()
            end
        end
    end
end

local function hasAnyActiveItemButtons(panel)
    for _ in panel:EnumerateValidItems() do
        return true
    end
    return false
end

local function countActiveItemButtons(panel)
    local count = 0
    for _ in panel:EnumerateValidItems() do
        count = count + 1
    end
    return count
end

local function countExpectedButtonsForTabs(tabIds)
    local expected = 0
    for index = 1, #tabIds do
        local tabID = tabIds[index]
        local slotCount = C_Container.GetContainerNumSlots(tabID) or 0
        if slotCount > 0 then
            expected = expected + slotCount
        end
    end
    return expected
end

local function buildItemButtonsSignature(activeBankType, tabIds)
    local parts = { tostring(activeBankType) }
    for index = 1, #tabIds do
        local tabID = tabIds[index]
        local slotCount = C_Container.GetContainerNumSlots(tabID) or 0
        table.insert(parts, tostring(tabID) .. ":" .. tostring(slotCount))
    end
    return table.concat(parts, "|")
end

local function applyCachedIncludeInSearch(panel)
    for itemButton in panel:EnumerateValidItems() do
        itemButton:SetMatchesSearch(true)
    end
end

local function hideBlizzardBankTabs(panel)
    for tabButton in panel.bankTabPool:EnumerateActive() do
        tabButton:Hide()
    end
    panel.PurchaseTab:Hide()
end

local function addActionsMenuItems(rootDescription, panel, activeBankType, tabData)
    assert(BankPanelTabSettingsMenuMixin and BankPanelTabSettingsMenuMixin.Event and BankPanelTabSettingsMenuMixin.Event.OpenTabSettingsRequested,
        "BankPanelTabSettingsMenuMixin OpenTabSettingsRequested event missing")
    local eventName = BankPanelTabSettingsMenuMixin.Event.OpenTabSettingsRequested

    rootDescription:CreateTitle("Tab Settings")

    for index = 1, #tabData do
        local currentTab = tabData[index]
        local tabID = currentTab and currentTab.ID
        if type(tabID) == "number" and tabID > 0 then
            rootDescription:CreateButton(currentTab.name or ("Tab " .. tabID), function()
                    panel.TabSettingsMenu:TriggerEvent(eventName, tabID)
                end)
        end
    end

    rootDescription:CreateDivider()

    local canPurchase = C_Bank.CanPurchaseBankTab(activeBankType)
    local hasMaxTabs = C_Bank.HasMaxBankTabs(activeBankType)
    local purchaseButton = rootDescription:CreateButton("Purchase Next Tab", function()
            StaticPopup_Show("CONFIRM_BUY_BANK_TAB", nil, nil, { bankType = activeBankType })
        end)
    purchaseButton:SetEnabled((canPurchase and not hasMaxTabs) == true)
end

local function ensureActionsButton(self, panel)
    if self.actionsButton then
        return self.actionsButton
    end

    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(58, 20)
    assert(BankItemSearchBox, "BankItemSearchBox missing")
    button:SetPoint("RIGHT", BankItemSearchBox, "LEFT", -8, 0)
    button:SetText("Actions")
    button:Hide()
    self.actionsButton = button
    return button
end

local function showActionsButton(self, panel, activeBankType, tabData)
    local button = ensureActionsButton(self, panel)
    button:SetScript("OnClick", function()
        MenuUtil.CreateContextMenu(button, function(_, rootDescription)
            addActionsMenuItems(rootDescription, panel, activeBankType, tabData)
        end)
    end)
    button:Show()
end

local function hideActionsButton(self)
    if self.actionsButton then
        self.actionsButton:Hide()
    end
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
    for index = 1, #self.dropFrames do
        self.dropFrames[index]:Hide()
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

local function evaluateSearchVisibility(defaultMatch, searchEvaluator, itemInfo, itemButton)
    local includeInSearch = defaultMatch
    local queryMatch = false
    if not defaultMatch and searchEvaluator then
        local payload = AddonNS.CustomCategories:GetItemQueryPayload(itemInfo.itemID, itemButton, itemInfo)
        includeInSearch, queryMatch = AddonNS.QueryCategories:EvaluateSearchUnion(defaultMatch, searchEvaluator, payload)
    end
    return includeInSearch, queryMatch
end

local function applySearchUnionMatchState(panel, searchEvaluator)
    if not searchEvaluator then
        return
    end
    for itemButton in panel:EnumerateValidItems() do
        local bagID, slotID = resolveBankButtonContainerSlot(itemButton)
        if bagID and slotID then
            local info = C_Container.GetContainerItemInfo(bagID, slotID)
            if info then
                local defaultMatch = not info.isFiltered
                local includeInSearch = evaluateSearchVisibility(defaultMatch, searchEvaluator, info, itemButton)
                itemButton:SetMatchesSearch(true)
            end
        end
    end
end

local function ensureDropAreaOverlay(self, index)
    if self.dropAreaOverlays[index] then
        return self.dropAreaOverlays[index]
    end

    local overlay = CreateFrame("Frame", nil, self.scrollFrame, "BackdropTemplate")
    overlay:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10 })
    overlay:SetBackdropColor(0.22, 0.45, 0.95, 0.08)
    overlay:SetBackdropBorderColor(0.38, 0.62, 1, 0.28)
    overlay:EnableMouse(false)

    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOP", overlay, "TOP", 0, -4)
    label:SetTextColor(0.75, 0.86, 1, 0.75)
    overlay.label = label

    self.dropAreaOverlays[index] = overlay
    return overlay
end

local function hideDropAreaOverlays(self)
    if not self.dropAreaOverlays then
        return
    end
    for index = 1, #self.dropAreaOverlays do
        self.dropAreaOverlays[index]:Hide()
    end
end

local function updateDropAreaOverlays(self, scope)
    if not SHOW_COLUMN_DROP_AREAS then
        hideDropAreaOverlays(self)
        return
    end

    local columnCount = AddonNS.CategoryStore:GetColumnCount(scope)
    local areaWidth = self.scrollFrame:GetWidth() or 0
    local areaHeight = self.scrollFrame:GetHeight() or 0
    local columnPixelWidth = self.columnPixelWidth
    local firstColumnStartX = self.firstColumnStartX
    if columnCount <= 0 or areaWidth <= 0 or areaHeight <= 0 or not columnPixelWidth or not firstColumnStartX then
        hideDropAreaOverlays(self)
        return
    end

    for index = 1, columnCount do
        local overlay = ensureDropAreaOverlay(self, index)
        local startX = firstColumnStartX + (index - 1) * columnPixelWidth
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", self.scrollFrame, "TOPLEFT", startX, 0)
        overlay:SetSize(columnPixelWidth, areaHeight)
        overlay.label:SetText(index)
        overlay:Show()
    end
    for index = columnCount + 1, #self.dropAreaOverlays do
        self.dropAreaOverlays[index]:Hide()
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
    viewportBackdrop:SetClipsChildren(false)

    local scrollFrame = CreateFrame("ScrollFrame", nil, viewportBackdrop)
    scrollFrame:SetPoint("TOPLEFT", viewportBackdrop, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", viewportBackdrop, "BOTTOMRIGHT", 0, 0)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:EnableMouse(true)
    scrollFrame:SetScript("OnReceiveDrag", AddonNS.DragAndDrop.backgroundOnReceiveDrag)
    scrollFrame:SetScript("OnMouseUp", AddonNS.DragAndDrop.backgroundOnReceiveDrag)
    scrollFrame.myBagAddonHooked = true

    local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
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
    self.dropAreaOverlays = self.dropAreaOverlays or {}
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

    local hintOverlay = CreateFrame("Frame", nil, headerFrame, "BackdropTemplate")
    hintOverlay:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    hintOverlay:SetAllPoints(headerFrame)
    hintOverlay:EnableMouse(false)
    hintOverlay:Hide()

    headerFrame:EnableMouse(true)
    headerFrame:RegisterForDrag("LeftButton")
    headerFrame:SetScript("OnEnter", function(frame)
        AddonNS.gui:SetHoveredCategoryFrame(frame)
    end)
    headerFrame:SetScript("OnLeave", function(frame)
        AddonNS.gui:ClearHoveredCategoryFrame(frame)
    end)
    headerFrame:HookScript("OnHide", function(frame)
        AddonNS.gui:ClearHoveredCategoryFrame(frame)
    end)
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
    headerFrame.hintOverlay = hintOverlay
    self.headerFrames[index] = headerFrame
    return headerFrame
end

local function ensureDropFrame(self, index)
    if self.dropFrames[index] then
        return self.dropFrames[index]
    end

    local dropFrame = CreateFrame("Frame", nil, self.backgroundFrame, "BackdropTemplate")
    local dropFrameLevel = self.backgroundFrame:GetFrameLevel() - 1
    if dropFrameLevel < 0 then
        dropFrameLevel = 0
    end
    dropFrame:SetFrameLevel(dropFrameLevel)

    local hintOverlay = CreateFrame("Frame", nil, dropFrame, "BackdropTemplate")
    hintOverlay:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    hintOverlay:SetAllPoints(dropFrame)
    hintOverlay:EnableMouse(false)
    hintOverlay:Hide()

    dropFrame:EnableMouse(true)
    dropFrame:SetScript("OnEnter", function(frame)
        AddonNS.gui:SetHoveredCategoryFrame(frame)
    end)
    dropFrame:SetScript("OnLeave", function(frame)
        AddonNS.gui:ClearHoveredCategoryFrame(frame)
    end)
    dropFrame:HookScript("OnHide", function(frame)
        AddonNS.gui:ClearHoveredCategoryFrame(frame)
    end)
    dropFrame:SetScript("OnReceiveDrag", AddonNS.DragAndDrop.categoryOnReceiveDrag)
    dropFrame:SetScript("OnMouseUp", function(frame, button)
        if button == "LeftButton" and GetCursorInfo() then
            AddonNS.DragAndDrop.categoryOnReceiveDrag(frame)
        end
    end)

    dropFrame.hintOverlay = hintOverlay
    self.dropFrames[index] = dropFrame
    return dropFrame
end

local function placeItemsAndBuildHeaders(scope, panel, categoryAssignments, itemSize)
    local categoryPositions = {}
    local positions = {}
    local columnsBottom = {}
    local leftPadding = BANK_CONTENT_LEFT_PADDING
    local firstRowY = BANK_CONTENT_FIRST_ROW_Y
    local columnPixelWidth = itemSize * ITEMS_PER_ROW + AddonNS.Const.COLUMN_SPACING

    local function placeColumn(columnIndex, categories)
        local columnStartX = leftPadding + (columnIndex - 1) * columnPixelWidth
        local currentY = firstRowY

        for index, categoryObj in ipairs(categories) do
            local category = categoryObj.category
            local items = categoryObj.items
            local itemsCount = categoryObj.itemsCount or #items
            local collapsed = AddonNS.Collapsed.isCollapsed(category, scope)
            local rowCount = collapsed and 0 or math.ceil(itemsCount / ITEMS_PER_ROW)

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
                blockHeight = CATEGORY_HEIGHT + rowCount * itemSize,
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

function BankView:ResolveDropColumn(relativeX, scope, frameWidth)
    local columnCount = AddonNS.CategoryStore:GetColumnCount(scope)
    if columnCount <= 0 then
        return nil
    end

    local columnPixelWidth = self.columnPixelWidth
    local firstColumnStartX = self.firstColumnStartX
    if not columnPixelWidth or not firstColumnStartX or columnPixelWidth <= 0 then
        local fallback = math.floor(relativeX * columnCount / frameWidth) + 1
        if fallback < 1 then
            fallback = 1
        elseif fallback > columnCount then
            fallback = columnCount
        end
        return fallback
    end

    local resolved = math.floor((relativeX - firstColumnStartX) / columnPixelWidth) + 1
    if resolved < 1 then
        return 1
    end
    if resolved > columnCount then
        return columnCount
    end
    return resolved
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
        local dropFrame = ensureDropFrame(self, index)
        frame.ItemCategory = categoryPosition.category
        frame.MyBagsScope = scope
        frame.MyBagsContainerRef = panel
        frame.MyBagsHintAnchorFrame = self.backgroundFrame
        frame.MyBagsHintAlignToFrame = true
        frame:SetPoint("TOPLEFT", self.backgroundFrame, "TOPLEFT", categoryPosition.x, -categoryPosition.y)
        frame:SetSize(categoryPosition.width, CATEGORY_HEIGHT)

        dropFrame.ItemCategory = categoryPosition.category
        dropFrame.MyBagsScope = scope
        dropFrame.MyBagsContainerRef = panel
        dropFrame.MyBagsHintAnchorFrame = self.backgroundFrame
        dropFrame.MyBagsHintAlignToFrame = true
        dropFrame:SetPoint("TOPLEFT", self.backgroundFrame, "TOPLEFT", categoryPosition.x, -categoryPosition.y)
        dropFrame:SetSize(categoryPosition.width, categoryPosition.blockHeight)
        dropFrame:Show()

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
    for index = #categoryPositions + 1, #self.dropFrames do
        self.dropFrames[index]:Hide()
    end
end

function BankView:Refresh(scope)
    AddonNS.printDebug("MyBags BankView:Refresh start", scope)
    local panel = getActiveBankPanel()
    if not BankFrame:IsShown() or not panel:IsShown() then
        AddonNS.printDebug("MyBags BankView:Refresh skipped; frame hidden")
        hideHeaders(self)
        hideScrollArea(self)
        hideActionsButton(self)
        return
    end

    local activeBankType = BankFrame:GetActiveBankType()
    local activeScope = scope or getScopeForBankType(activeBankType)
    local tabIds, tabData = getPurchasedTabIdsForActiveType(panel)
    self.visibleTabIds = buildVisibleTabIds(tabIds)
    self.currentScope = activeScope
    AddonNS:SetCurrentLayoutScope(activeScope)

    ensureScrollArea(self, panel)
    self.scrollFrame.MyBagsScope = activeScope
    ensureBackground(self, self.scrollContentFrame)
    hideBlizzardBankTabs(panel)
    showActionsButton(self, panel, activeBankType, tabData)
    self.scrollViewportBackdrop:Show()
    self.scrollFrame:Show()
    self.backgroundFrame:Show()
    updateDropAreaOverlays(self, activeScope)
    local itemButtonsSignature = buildItemButtonsSignature(activeBankType, tabIds)
    local expectedButtons = countExpectedButtonsForTabs(tabIds)
    local shouldRegenerateButtons =
        self.itemButtonsSignature ~= itemButtonsSignature
        or not hasAnyActiveItemButtons(panel)
        or countActiveItemButtons(panel) ~= expectedButtons
    if shouldRegenerateButtons then
        generateAllTabItemButtons(panel, activeBankType, tabIds)
        self.itemButtonsSignature = itemButtonsSignature
    end
    local searchText = BankItemSearchBox:GetText() or ""
    local searchEvaluator = AddonNS.QueryCategories:CompileAdHoc(searchText)

    local arrangedItems = {}
    local firstItemButton = nil

    AddonNS.emptyItemButton = nil
    for itemButton in panel:EnumerateValidItems() do
        ensureItemButtonBagMethods(itemButton)
        ensureItemButtonHooks(itemButton)
        itemButton:Refresh()
        itemButton.MyBagsScope = activeScope

        itemButton.ItemCategory = nil
        local bagID, slotID = resolveBankButtonContainerSlot(itemButton)
        if bagID and slotID then
            local info = C_Container.GetContainerItemInfo(bagID, slotID)
            if info then
                local defaultMatch = not info.isFiltered
                local includeInSearch = evaluateSearchVisibility(defaultMatch, searchEvaluator, info, itemButton)
                itemButton:SetMatchesSearch(true)
                if includeInSearch then
                    itemButton._myBagsItemId = info.itemID
                    itemButton.ItemCategory = AddonNS.Categories:Categorize(info.itemID, itemButton)
                    arrangedItems[itemButton.ItemCategory] = arrangedItems[itemButton.ItemCategory] or {}
                    table.insert(arrangedItems[itemButton.ItemCategory], itemButton)
                    firstItemButton = firstItemButton or itemButton
                else
                    AddonNS.emptyItemButton = itemButton
                end
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
    self.columnPixelWidth = itemSize * ITEMS_PER_ROW + AddonNS.Const.COLUMN_SPACING
    self.firstColumnStartX = BANK_CONTENT_LEFT_PADDING - ITEM_SPACING / 2
    local categoryAssignments = AddonNS.Categories:ArrangeCategoriesIntoColumns(arrangedItems, activeScope)
    local positions, categoryPositions, contentBottom = placeItemsAndBuildHeaders(activeScope, panel, categoryAssignments, itemSize)
    AddonNS.printDebug("MyBags BankView:Refresh rendered categories", #categoryPositions, "scope", activeScope)

    updateScrollMetrics(self, contentBottom)
    updateDropAreaOverlays(self, activeScope)
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
        hideDropAreaOverlays(BankView)
        hideActionsButton(BankView)
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
    hooksecurefunc(BankPanel, "UpdateSearchResults", function()
        applyCachedIncludeInSearch(BankPanel)
    end)
    hooksecurefunc(BankPanel, "Clean", function()
        BankView:QueueRefresh()
    end)

    AddonNS.Events:RegisterEvent("BAG_UPDATE", function(_, bagID)
        if not BankFrame:IsShown() then
            return
        end
        if shouldRefreshForBagUpdate(BankView.visibleTabIds, bagID) then
            BankView:QueueRefresh()
        end
    end)

    AddonNS.Events:RegisterEvent("INVENTORY_SEARCH_UPDATE", function()
        if BankFrame:IsShown() then
            BankView:RefreshNow(BankView.currentScope)
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
AddonNS.BankViewTestHooks = {
    GetPurchasedTabIdsForActiveType = getPurchasedTabIdsForActiveType,
    BuildVisibleTabIds = buildVisibleTabIds,
    ShouldRefreshForBagUpdate = shouldRefreshForBagUpdate,
    GenerateAllTabItemButtons = generateAllTabItemButtons,
    BuildItemButtonsSignature = buildItemButtonsSignature,
    ApplyCachedIncludeInSearch = applyCachedIncludeInSearch,
    HasAnyActiveItemButtons = hasAnyActiveItemButtons,
    CountActiveItemButtons = countActiveItemButtons,
    CountExpectedButtonsForTabs = countExpectedButtonsForTabs,
    EvaluateSearchVisibility = evaluateSearchVisibility,
    ApplySearchUnionMatchState = applySearchUnionMatchState,
}

AddonNS.Events:OnInitialize(function()
    AddonNS.Categories:SetColumnCount(4, BANK_CHARACTER_SCOPE)
    AddonNS.Categories:SetColumnCount(4, BANK_ACCOUNT_SCOPE)
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
