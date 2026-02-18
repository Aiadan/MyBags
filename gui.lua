local addonName, AddonNS = ...
local isCollapsed = AddonNS.Collapsed.isCollapsed;
local ITEM_SPACING = AddonNS.Const.ITEM_SPACING;

local GS = LibStub("MyLibrary_GUI");
local test = {
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local unselectedDarkBackdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    tile = true,
    tileSize = 32,
    edgeSize = 20,
    insets = {
        left = 0,
        right = 0,
        top = 0,
        bottom = 0
    }
}
local protectedCategoryBackdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    tile = true,
    tileSize = 32,
    edgeSize = 20,
    insets = {
        left = 0,
        right = 0,
        top = 0,
        bottom = 0
    }
}
local unprotectedCategoryBackdrop = {
    bgFile = "Interface\\Buttons\\UI-Listbox-Highlight",
    tile = false,
    tileSize = 32,
    edgeSize = 20,
    insets = {
        left = 0,
        right = 0,
        top = 0,
        bottom = 0
    }
}

AddonNS.gui = AddonNS.gui or {}
AddonNS.gui.categoriesFrames = {};
local hoveredCategoryFrame = nil
local backgroundFrame = nil
local EDIT_CATEGORY_TOOLTIP = "Edit"
local DELETE_CATEGORY_TOOLTIP = "Delete"
local DELETE_CATEGORY_HINT = "Hold-shift to skip confirmation prompt"
local HINT_TONE_STYLE = {
    unassigned = { 0.35, 0.58, 0.94, 0.24 },
    assign = { 0.20, 0.85, 0.35, 0.30 },
    blocked = { 0.90, 0.24, 0.24, 0.30 },
}
local ADD_CATEGORY_CONTROL_LABEL = "|cff90ff90+ Add Category|r"
local ADD_CATEGORY_CONTROL_LABEL_HOVER = "|cffffff80+ Add Category|r"
local EXPORT_CATEGORY_CONTROL_LABEL = "|cffffe266Export Categories|r"
local EXPORT_CATEGORY_CONTROL_LABEL_HOVER = "|cffffff9fExport Categories|r"
local IMPORT_CATEGORY_CONTROL_LABEL = "|cffffe266Import Categories|r"
local IMPORT_CATEGORY_CONTROL_LABEL_HOVER = "|cffffff9fImport Categories|r"
local ADD_CATEGORY_CONTROL_BACKDROP = {
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local ADD_CATEGORY_CONTROL_STYLE = {
    normal = {
        bg = { 0.08, 0.18, 0.08, 0.86 },
        border = { 0.30, 0.85, 0.30, 1 },
        label = ADD_CATEGORY_CONTROL_LABEL,
    },
    hover = {
        bg = { 0.14, 0.30, 0.14, 0.92 },
        border = { 0.55, 1, 0.55, 1 },
        label = ADD_CATEGORY_CONTROL_LABEL_HOVER,
    },
}

local CONTROL_STYLE_BY_KIND = {
    add = ADD_CATEGORY_CONTROL_STYLE,
    export = {
        normal = {
            bg = { 0.20, 0.17, 0.06, 0.86 },
            border = { 0.95, 0.82, 0.32, 1 },
            label = EXPORT_CATEGORY_CONTROL_LABEL,
        },
        hover = {
            bg = { 0.32, 0.27, 0.10, 0.92 },
            border = { 1, 0.90, 0.45, 1 },
            label = EXPORT_CATEGORY_CONTROL_LABEL_HOVER,
        },
    },
    import = {
        normal = {
            bg = { 0.20, 0.17, 0.06, 0.86 },
            border = { 0.95, 0.82, 0.32, 1 },
            label = IMPORT_CATEGORY_CONTROL_LABEL,
        },
        hover = {
            bg = { 0.32, 0.27, 0.10, 0.92 },
            border = { 1, 0.90, 0.45, 1 },
            label = IMPORT_CATEGORY_CONTROL_LABEL_HOVER,
        },
    },
}

local function styleCategoryControl(frame, isHovered)
    local kind = frame.controlKind or "add"
    local styleSet = CONTROL_STYLE_BY_KIND[kind] or CONTROL_STYLE_BY_KIND.add
    local style = isHovered and styleSet.hover or styleSet.normal
    frame.addControlBackdrop:SetBackdropColor(style.bg[1], style.bg[2], style.bg[3], style.bg[4])
    frame.addControlBackdrop:SetBackdropBorderColor(style.border[1], style.border[2], style.border[3], style.border[4])
    frame:SetText(style.label)
end

function AddonNS.gui:EnsureCategoryControlBackdrop(frame)
    if frame.addControlBackdrop then
        return
    end
    frame.addControlBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.addControlBackdrop:SetBackdrop(ADD_CATEGORY_CONTROL_BACKDROP)
    frame.addControlBackdrop:SetAllPoints(frame)
    frame.addControlBackdrop:EnableMouse(false)
    frame.addControlBackdrop:SetFrameLevel(frame:GetFrameLevel() - 1)
    frame.addControlBackdrop:Hide()
end

function AddonNS.gui:StyleCategoryControl(frame, isHovered)
    styleCategoryControl(frame, isHovered)
end

local function applyCategoryHint(frame, hint)
    if not frame.hintOverlay then
        return
    end
    if not hint then
        frame.hintOverlay:Hide()
        return
    end
    local color = HINT_TONE_STYLE[hint.tone]
    frame.hintOverlay:SetBackdropColor(color[1], color[2], color[3], color[4])
    frame.hintOverlay:Show()
end

local hintTextFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
local HINT_TEXT_MIN_HEIGHT = 28
local HINT_TEXT_VERTICAL_GAP = 3
local HINT_TEXT_PADDING = 8
hintTextFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
hintTextFrame:SetBackdropColor(0, 0, 0, 0.92)
hintTextFrame:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
hintTextFrame:SetFrameStrata("TOOLTIP")
hintTextFrame:SetFrameLevel(300)
hintTextFrame:EnableMouse(false)
hintTextFrame:SetSize(320, 34)
hintTextFrame:Hide()

hintTextFrame.label = hintTextFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hintTextFrame.label:SetPoint("TOPLEFT", hintTextFrame, "TOPLEFT", 8, -8)
hintTextFrame.label:SetPoint("BOTTOMRIGHT", hintTextFrame, "BOTTOMRIGHT", -8, 8)
hintTextFrame.label:SetJustifyH("LEFT")
hintTextFrame.label:SetJustifyV("MIDDLE")
hintTextFrame.label:SetWordWrap(true)
hintTextFrame.label:SetTextColor(1, 1, 1, 1)

local function layoutHintTextFrame(anchorFrame, text)
    local itemSize = AddonNS.container.Items[1]:GetHeight() + ITEM_SPACING
    local columnPixelWidth = itemSize * AddonNS.Const.ITEMS_PER_ROW + AddonNS.Const.COLUMN_SPACING
    local columnWidth = columnPixelWidth - AddonNS.Const.COLUMN_SPACING
    local offsetX = 0
    local hintWidth = columnWidth
    if not anchorFrame.MyBagsHintAlignToFrame then
        local anchorBackground = anchorFrame.MyBagsHintAnchorFrame or backgroundFrame
        local backgroundLeft = anchorBackground:GetLeft()
        local anchorLeft = anchorFrame:GetLeft()
        local relativeLeft = anchorLeft - backgroundLeft + ITEM_SPACING / 2
        local columnIndex = math.floor(relativeLeft / columnPixelWidth)
        local columnLeft = backgroundLeft + columnIndex * columnPixelWidth - ITEM_SPACING / 2
        offsetX = columnLeft - anchorLeft
    else
        hintWidth = anchorFrame:GetWidth()
    end

    hintTextFrame:SetWidth(hintWidth)
    hintTextFrame.label:SetText(text)

    local textHeight = math.ceil(hintTextFrame.label:GetStringHeight() or 0)
    local frameHeight = textHeight + HINT_TEXT_PADDING * 2
    if frameHeight < HINT_TEXT_MIN_HEIGHT then
        frameHeight = HINT_TEXT_MIN_HEIGHT
    end
    hintTextFrame:SetHeight(frameHeight)

    local uiTop = UIParent:GetTop() or UIParent:GetHeight()
    local anchorTop = anchorFrame:GetTop() or 0
    local hasRoomAbove = (anchorTop + frameHeight + HINT_TEXT_VERTICAL_GAP) <= uiTop

    hintTextFrame:ClearAllPoints()
    if hasRoomAbove then
        hintTextFrame:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", offsetX, HINT_TEXT_VERTICAL_GAP)
    else
        hintTextFrame:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", offsetX, -HINT_TEXT_VERTICAL_GAP)
    end
end

local function getCategoryHoverText(frame)
    local title = frame.ItemCategory:GetDisplayName() or frame.ItemCategory:GetName() or frame.fs:GetText()
    if frame.ItemCategory.description then
        return title .. "\n" .. frame.ItemCategory.description
    end
    return title
end

local function findFocusedCategoryFrame(frame)
    local current = frame
    while current do
        if current.ItemCategory then
            return current
        end
        if not current.GetParent then
            return nil
        end
        current = current:GetParent()
    end
    return nil
end

local function getHoveredCategoryFrameForHints()
    if hoveredCategoryFrame and hoveredCategoryFrame:IsShown() and hoveredCategoryFrame.ItemCategory then
        return hoveredCategoryFrame
    end
    if not AddonNS.DragAndDrop:IsItemDragActive() then
        return nil
    end
    local mouseFoci = GetMouseFoci()
    local focus = mouseFoci and mouseFoci[1] or nil
    return findFocusedCategoryFrame(focus)
end

local function forEachCategoryHintFrame(self, visitor)
    for i = 1, #self.categoriesFrames do
        visitor(self.categoriesFrames[i])
    end
    if AddonNS.BankView and AddonNS.BankView.dropFrames then
        for i = 1, #AddonNS.BankView.dropFrames do
            visitor(AddonNS.BankView.dropFrames[i])
        end
    end
end

function AddonNS.gui:SetHoveredCategoryFrame(frame)
    hoveredCategoryFrame = frame
    self:RefreshCategoryDragHints()
end

function AddonNS.gui:ClearHoveredCategoryFrame(frame)
    if hoveredCategoryFrame == frame then
        hoveredCategoryFrame = nil
    end
    self:RefreshCategoryDragHints()
end

function AddonNS.gui:RefreshCategoryDragHints()
    local hoveredFrame = getHoveredCategoryFrameForHints()
    local hoveredCategoryId = nil
    local hoveredScope = nil
    if hoveredFrame and hoveredFrame.ItemCategory then
        hoveredCategoryId = hoveredFrame.ItemCategory:GetId()
        hoveredScope = hoveredFrame.MyBagsScope
    end
    local shownTextFrame = nil
    local shownText = nil
    forEachCategoryHintFrame(self, function(frame)
        if frame:IsShown() then
            if frame.ItemCategory then
                local isHovered = frame == hoveredFrame
                if not isHovered and hoveredCategoryId and hoveredScope then
                    isHovered = frame.ItemCategory:GetId() == hoveredCategoryId and frame.MyBagsScope == hoveredScope
                end
                local hint = AddonNS.DragAndDrop:GetCategoryDropHint(frame.ItemCategory, isHovered)
                applyCategoryHint(frame, hint)
                if isHovered then
                    shownTextFrame = frame
                    if hint and hint.text then
                        shownText = hint.text
                    else
                        shownText = getCategoryHoverText(frame)
                    end
                end
            else
                applyCategoryHint(frame, nil)
            end
        end
    end)
    if shownTextFrame and shownText then
        layoutHintTextFrame(shownTextFrame, shownText)
        hintTextFrame:Show()
        return
    end
    hintTextFrame:Hide()
end

--- draggable frame 
local draggableFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
local activeDraggedCategoryName = nil
local activeDragShiftState = nil

draggableFrame:SetSize(320, AddonNS.Const.CATEGORY_HEIGHT * 3.2)
draggableFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
draggableFrame:SetBackdropColor(0, 0, 0, 0.9)
draggableFrame:SetMovable(true)
draggableFrame:SetPoint("CENTER")
draggableFrame:Hide()
draggableFrame:SetFrameStrata("TOOLTIP")
draggableFrame.nameLine = draggableFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
draggableFrame.nameLine:SetPoint("TOPLEFT", draggableFrame, "TOPLEFT", 12, -10)
draggableFrame.nameLine:SetPoint("TOPRIGHT", draggableFrame, "TOPRIGHT", -12, -10)
draggableFrame.nameLine:SetJustifyH("LEFT")
draggableFrame.nameLine:SetWordWrap(false)
draggableFrame.nameLine:SetTextColor(1, 1, 1, 1)
draggableFrame.nameLine:SetFontObject("GameFontHighlight")
draggableFrame.nameLine:SetShadowColor(0, 0, 0, 1)
draggableFrame.nameLine:SetShadowOffset(1, -1)

draggableFrame.hintLine = draggableFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
draggableFrame.hintLine:SetPoint("TOPLEFT", draggableFrame.nameLine, "BOTTOMLEFT", 0, -4)
draggableFrame.hintLine:SetPoint("TOPRIGHT", draggableFrame, "TOPRIGHT", -12, -4)
draggableFrame.hintLine:SetJustifyH("LEFT")
draggableFrame.hintLine:SetWordWrap(true)
draggableFrame.hintLine:SetShadowColor(0, 0, 0, 1)
draggableFrame.hintLine:SetShadowOffset(1, -1)

local function refreshDragTooltipText()
    if not activeDraggedCategoryName then
        return
    end
    local categoryNameText = activeDraggedCategoryName .. "|r"
    local shiftDown = IsShiftKeyDown()
    if activeDragShiftState ~= shiftDown then
        activeDragShiftState = shiftDown
        if shiftDown then
            draggableFrame.hintLine:SetText("|cff72f272Moving |r" ..
                categoryNameText .. "|cff72f272 and all categories below it|r")
        else
            draggableFrame.hintLine:SetText("|cff72f272Hold Shift:|r|cffc8c8c8 to move |r" ..
                categoryNameText .. "|cffc8c8c8 and all categories below it|r")
        end
    end
    draggableFrame.nameLine:SetText(activeDraggedCategoryName)
end

function draggableFrame:StartDragging()
    self:SetScript("OnUpdate",
        function()
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
            refreshDragTooltipText()
        end);
end

function draggableFrame:StopDragging()
    self:SetScript("OnUpdate", nil);
    activeDraggedCategoryName = nil
    activeDragShiftState = nil
end

function AddonNS.gui:StartCategoryDragVisual(categoryName)
    activeDraggedCategoryName = categoryName or "Unassigned"
    refreshDragTooltipText()
    draggableFrame:Show()
    draggableFrame:StartDragging()
end

function AddonNS.gui:StopCategoryDragVisual()
    draggableFrame:Hide()
    draggableFrame:StopDragging()
end

backgroundFrame = CreateFrame("Frame", nil, AddonNS.container, "BackdropTemplate")     -- todo: does it need to be some frame with bg, or pure frame would sufficie? I think I was testing it and it didnt work for some reason.
backgroundFrame.MyBagsScope = "bag"
backgroundFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
backgroundFrame:SetBackdropColor(0, 1, 0, 0)
backgroundFrame:EnableMouse(true)
backgroundFrame:SetScript("OnReceiveDrag", AddonNS.DragAndDrop.backgroundOnReceiveDrag)
backgroundFrame:SetScript("OnMouseUp", AddonNS.DragAndDrop.backgroundOnReceiveDrag)

backgroundFrame:SetPoint("BOTTOMRIGHT", AddonNS.container.MoneyFrame, "TOPRIGHT", 0, 0)
backgroundFrame.myBagAddonHooked = true;

local BAG_CAPACITY_LABEL_FORMAT = "%d / %d  Reagents %d / %d"
local freeSlotCountOverlay = CreateFrame("Frame", nil, AddonNS.container)
freeSlotCountOverlay:SetAllPoints(AddonNS.container.MoneyFrame)
freeSlotCountOverlay:SetFrameLevel(AddonNS.container.MoneyFrame:GetFrameLevel() + 10)
freeSlotCountOverlay:EnableMouse(true)

local freeSlotCountLabel = freeSlotCountOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
freeSlotCountLabel:SetPoint("LEFT", freeSlotCountOverlay, "LEFT", 6, 0)
freeSlotCountLabel:SetJustifyH("LEFT")
freeSlotCountLabel:SetTextColor(1, 0.82, 0.2, 1)

function AddonNS.gui:RefreshFreeSlotCountLabel()
    local state = AddonNS.GetBagCapacityState()
    freeSlotCountLabel:SetText(BAG_CAPACITY_LABEL_FORMAT:format(
        state.items.taken,
        state.items.total,
        state.reagents.taken,
        state.reagents.total
    ))
end

freeSlotCountOverlay:SetScript("OnEnter", function(self)
    local state = AddonNS.GetBagCapacityState()
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText("Bag capacity")
    GameTooltip:AddLine(
        "You are using " .. state.items.taken .. " regular bag slots out of " .. state.items.total ..
        " (" .. state.items.free .. " available).",
        1, 1, 1, true
    )
    GameTooltip:AddLine(
        "You are using " .. state.reagents.taken .. " reagent bag slots out of " .. state.reagents.total ..
        " (" .. state.reagents.free .. " available).",
        1, 1, 1, true
    )
    GameTooltip:Show()
end)

freeSlotCountOverlay:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

AddonNS.container:HookScript("OnShow", function()
    AddonNS.gui:RefreshFreeSlotCountLabel()
end)

AddonNS.Events:RegisterEvent("BAG_UPDATE", function()
    if AddonNS.container:IsShown() then
        AddonNS.gui:RefreshFreeSlotCountLabel()
    end
end)

local resizeHandle = CreateFrame("Button", nil, AddonNS.container, "PanelResizeButtonTemplate")
resizeHandle:SetPoint("BOTTOMLEFT", AddonNS.container, "BOTTOMLEFT", 2, 2)
resizeHandle:SetFrameStrata("TOOLTIP")
resizeHandle:SetRotationDegrees(270)
resizeHandle:Hide()

local activeResize = nil
local resizePreviewColumns = {}
local resizePreviewFrame = CreateFrame("Frame", nil, backgroundFrame, "BackdropTemplate")
local RESIZE_PREVIEW_COLORS = {
    neutral = { 0.35, 0.58, 0.94, 0.22 },
    growth = { 0.20, 0.85, 0.35, 0.30 },
    shrink = { 0.90, 0.24, 0.24, 0.30 },
}

resizePreviewFrame:SetAllPoints(backgroundFrame)
resizePreviewFrame:SetFrameStrata("TOOLTIP")
resizePreviewFrame:SetFrameLevel(backgroundFrame:GetFrameLevel() + 20)
resizePreviewFrame:EnableMouse(false)
resizePreviewFrame:Hide()

for index = 1, AddonNS.Const.MAX_NUM_COLUMNS do
    local overlay = CreateFrame("Frame", nil, resizePreviewFrame, "BackdropTemplate")
    overlay:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
    overlay:SetBackdropColor(0, 0, 0, 0)
    overlay:Hide()
    resizePreviewColumns[index] = overlay
end

local function getColumnPixelWidth()
    local itemSize = AddonNS.container.Items[1]:GetHeight() + ITEM_SPACING
    return itemSize * AddonNS.Const.ITEMS_PER_ROW + AddonNS.Const.COLUMN_SPACING
end

local function hideResizePreview()
    for index = 1, #resizePreviewColumns do
        resizePreviewColumns[index]:Hide()
    end
    resizePreviewFrame:Hide()
end

local function setResizePreviewColumnColor(columnFrame, color)
    columnFrame:SetBackdropColor(color[1], color[2], color[3], color[4])
end

local function updateResizePreview(state, currentWidth)
    local visibleColumns = (currentWidth - state.chromeOffset) / state.columnPixelWidth
    local targetColumns, _ = AddonNS.ColumnResize:ClassifyPreview(
        state.startColumns,
        visibleColumns,
        AddonNS.Const.MIN_NUM_COLUMNS,
        AddonNS.Const.MAX_NUM_COLUMNS
    )

    local highestVisiblePreview = math.max(state.startColumns, targetColumns)
    local stableColumns = math.min(state.startColumns, targetColumns)
    local overlayWidth = state.columnPixelWidth - AddonNS.Const.COLUMN_SPACING
    if overlayWidth < 1 then
        overlayWidth = 1
    end

    for index = 1, #resizePreviewColumns do
        local overlay = resizePreviewColumns[index]
        if index <= highestVisiblePreview then
            overlay:ClearAllPoints()
            local offsetX = (index - 1) * state.columnPixelWidth
            overlay:SetPoint("TOPLEFT", resizePreviewFrame, "TOPLEFT", offsetX, 0)
            overlay:SetPoint("BOTTOMLEFT", resizePreviewFrame, "BOTTOMLEFT", offsetX, 0)
            overlay:SetWidth(overlayWidth)

            if index <= stableColumns then
                setResizePreviewColumnColor(overlay, RESIZE_PREVIEW_COLORS.neutral)
            elseif targetColumns > state.startColumns then
                setResizePreviewColumnColor(overlay, RESIZE_PREVIEW_COLORS.growth)
            else
                setResizePreviewColumnColor(overlay, RESIZE_PREVIEW_COLORS.shrink)
            end
            overlay:Show()
        else
            overlay:Hide()
        end
    end

    resizePreviewFrame:Show()
end

local function stopColumnResize(applyChange)
    local state = activeResize
    if not state then
        return
    end
    activeResize = nil
    resizeHandle:SetScript("OnUpdate", nil)
    resizeHandle:SetButtonState("NORMAL", false)
    hideResizePreview()

    local container = AddonNS.container
    container:SetHeight(state.startHeight)

    if not applyChange then
        AddonNS.QueueContainerUpdateItemLayout()
        return
    end

    local visibleColumns = (container:GetWidth() - state.chromeOffset) / state.columnPixelWidth
    local target = AddonNS.ColumnResize:CalculateTarget(
        state.startColumns,
        visibleColumns,
        AddonNS.Const.MIN_NUM_COLUMNS,
        AddonNS.Const.MAX_NUM_COLUMNS
    )
    AddonNS:SetNumColumns(target, "bag")
end

local function updateColumnResize()
    local state = activeResize
    if not state then
        return
    end
    if not IsMouseButtonDown("LeftButton") then
        stopColumnResize(true)
        return
    end

    local cursorX = GetCursorPosition() / state.uiScale
    local deltaX = cursorX - state.startCursorX
    local desiredWidth = state.startWidth - deltaX
    if desiredWidth < state.minWidth then
        desiredWidth = state.minWidth
    end
    if desiredWidth > state.maxWidth then
        desiredWidth = state.maxWidth
    end
    AddonNS.container:SetWidth(desiredWidth)
    AddonNS.container:SetHeight(state.startHeight)
    updateResizePreview(state, desiredWidth)
end

local function startColumnResize()
    if InCombatLockdown() then
        return
    end

    local container = AddonNS.container
    local startColumns = AddonNS.CategoryStore:GetColumnCount("bag")
    local startWidth = container:GetWidth()
    local columnPixelWidth = getColumnPixelWidth()
    activeResize = {
        startCursorX = GetCursorPosition() / UIParent:GetEffectiveScale(),
        uiScale = UIParent:GetEffectiveScale(),
        startWidth = startWidth,
        startHeight = container:GetHeight(),
        startColumns = startColumns,
        columnPixelWidth = columnPixelWidth,
        chromeOffset = startWidth - startColumns * columnPixelWidth,
        minWidth = startWidth - startColumns * columnPixelWidth + AddonNS.Const.MIN_NUM_COLUMNS * columnPixelWidth,
        maxWidth = startWidth - startColumns * columnPixelWidth + AddonNS.Const.MAX_NUM_COLUMNS * columnPixelWidth,
    }
    updateResizePreview(activeResize, startWidth)
    resizeHandle:SetButtonState("PUSHED", true)
    resizeHandle:SetScript("OnUpdate", updateColumnResize)
end

local function refreshResizeHandle()
    local shouldShow = AddonNS.container:IsShown() and not InCombatLockdown()
    if shouldShow then
        resizeHandle:Show()
        resizeHandle:EnableMouse(true)
        return
    end
    stopColumnResize(false)
    resizeHandle:Hide()
    resizeHandle:EnableMouse(false)
end

resizeHandle:SetScript("OnMouseDown", function(_, mouseButtonName)
    if mouseButtonName == "LeftButton" then
        startColumnResize()
    end
end)

resizeHandle:SetScript("OnMouseUp", function(_, mouseButtonName)
    if mouseButtonName == "LeftButton" then
        stopColumnResize(true)
    end
end)

AddonNS.container:HookScript("OnShow", refreshResizeHandle)
AddonNS.container:HookScript("OnHide", function()
    stopColumnResize(false)
    refreshResizeHandle()
end)

AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.BAG_VIEW_MODE_CHANGED, refreshResizeHandle)
AddonNS.Events:RegisterEvent("PLAYER_REGEN_DISABLED", function()
    stopColumnResize(false)
    refreshResizeHandle()
end)
AddonNS.Events:RegisterEvent("PLAYER_REGEN_ENABLED", refreshResizeHandle)


function AddonNS.gui:RegenerateCategories(yFrameOffset, categoriesGUIInfo)
    local moneyFrame = AddonNS.container.MoneyFrame;
    local customCategories = AddonNS.CustomCategories:GetCategories()
    AddonNS.printDebug("money frame:", moneyFrame, AddonNS.container.MoneyFrame)
    backgroundFrame:SetPoint("TOPLEFT", moneyFrame, "TOPLEFT", 0, yFrameOffset)
    for i = 1, #categoriesGUIInfo, 1 do
        local categoryGUIInfo = categoriesGUIInfo[i];
        if not AddonNS.gui.categoriesFrames[i] then
            local f = CreateFrame("Frame", nil, backgroundFrame, "BackdropTemplate")


            f:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
            f:SetBackdropColor(1, 0, 0, 0)
            local fs = f:CreateFontString(nil, "ARTWORK", "GameFontNormal");
            fs:SetPoint("TOPLEFT", f, "TOPLEFT", ITEM_SPACING / 2, -ITEM_SPACING / 2)
            fs:SetPoint("TOPRIGHT", f, "TOPRIGHT", -ITEM_SPACING / 2, -ITEM_SPACING / 2)
            fs:SetJustifyH("LEFT")
            fs:SetJustifyV("TOP")
            fs:SetWordWrap(false);

            local deleteButton = CreateFrame("Button", nil, f)
            deleteButton:SetSize(16, 16)
            deleteButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -3)
            deleteButton:SetFrameLevel(f:GetFrameLevel() + 25)
            deleteButton:Hide()

            deleteButton.Icon = deleteButton:CreateTexture(nil, "ARTWORK")
            deleteButton.Icon:SetAllPoints()
            deleteButton.Icon:SetAtlas("common-icon-delete")

            deleteButton.Highlight = deleteButton:CreateTexture(nil, "HIGHLIGHT")
            deleteButton.Highlight:SetAllPoints()
            deleteButton.Highlight:SetAtlas("common-icon-delete")
            deleteButton.Highlight:SetAlpha(0.45)
            deleteButton.Highlight:SetBlendMode("ADD")

            local editButton = CreateFrame("Button", nil, f)
            editButton:SetSize(16, 16)
            editButton:SetPoint("TOPRIGHT", deleteButton, "TOPLEFT", -2, 0)
            editButton:SetFrameLevel(f:GetFrameLevel() + 25)
            editButton:Hide()

            editButton.Icon = editButton:CreateTexture(nil, "ARTWORK")
            editButton.Icon:SetPoint("TOPLEFT", editButton, "TOPLEFT", -4, 4)
            editButton.Icon:SetPoint("BOTTOMRIGHT", editButton, "BOTTOMRIGHT", 4, -4)
            editButton.Icon:SetAtlas("GM-icon-settings")
            editButton.Icon:SetVertexColor(1, 0.85, 0.2, 1)

            editButton.Highlight = editButton:CreateTexture(nil, "HIGHLIGHT")
            editButton.Highlight:SetPoint("TOPLEFT", editButton, "TOPLEFT", -2, 2)
            editButton.Highlight:SetPoint("BOTTOMRIGHT", editButton, "BOTTOMRIGHT", 2, -2)
            editButton.Highlight:SetAtlas("GM-icon-settings")
            editButton.Highlight:SetVertexColor(1, 0.85, 0.2, 1)
            editButton.Highlight:SetAlpha(0.45)
            editButton.Highlight:SetBlendMode("ADD")

            editButton:SetScript("OnEnter", function(self)
                local category = self:GetParent().ItemCategory
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(EDIT_CATEGORY_TOOLTIP .. " \"" .. category:GetName() .. "\" category")
                GameTooltip:Show()
            end)
            editButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            editButton:SetScript("OnClick", function(self)
                local category = self:GetParent().ItemCategory
                AddonNS.CategoriesGUI:SelectCategoryById(category:GetId())
            end)

            deleteButton:SetScript("OnEnter", function(self)
                local category = self:GetParent().ItemCategory
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(DELETE_CATEGORY_TOOLTIP .. " \"" .. category:GetName() .. "\" category")
                GameTooltip:AddLine(DELETE_CATEGORY_HINT, 1, 0.82, 0, true)
                GameTooltip:Show()
            end)
            deleteButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            deleteButton:SetScript("OnClick", function(self)
                local category = self:GetParent().ItemCategory
                if IsShiftKeyDown() then
                    StaticPopupDialogs["DELETE_CATEGORY_CONFIRM"].OnAccept(nil, category)
                    return
                end
                local dialog = StaticPopup_Show("DELETE_CATEGORY_CONFIRM", category:GetName() or "")
                if dialog then
                    dialog.data = category
                end
            end)

            local function applyCategoryTextLayout()
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", f, "TOPLEFT", ITEM_SPACING / 2, -ITEM_SPACING / 2)
                fs:SetPoint("TOPRIGHT", f, "TOPRIGHT", -ITEM_SPACING / 2, -ITEM_SPACING / 2)
                fs:SetJustifyH("LEFT")
                fs:SetJustifyV("TOP")
                fs:SetFontObject("GameFontNormal")
            end

            local function applyCategoryTextLayoutWithDeleteButton()
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", f, "TOPLEFT", ITEM_SPACING / 2, -ITEM_SPACING / 2)
                fs:SetPoint("TOPRIGHT", deleteButton, "TOPLEFT", -4, -ITEM_SPACING / 2)
                fs:SetJustifyH("LEFT")
                fs:SetJustifyV("TOP")
                fs:SetFontObject("GameFontNormal")
            end

            local function applyCategoryTextLayoutWithEditButton()
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", f, "TOPLEFT", ITEM_SPACING / 2, -ITEM_SPACING / 2)
                fs:SetPoint("TOPRIGHT", editButton, "TOPLEFT", -4, -ITEM_SPACING / 2)
                fs:SetJustifyH("LEFT")
                fs:SetJustifyV("TOP")
                fs:SetFontObject("GameFontNormal")
            end

            local function applyCategoryTextLayoutWithEditAndDeleteButtons()
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", f, "TOPLEFT", ITEM_SPACING / 2, -ITEM_SPACING / 2)
                fs:SetPoint("TOPRIGHT", editButton, "TOPLEFT", -4, -ITEM_SPACING / 2)
                fs:SetJustifyH("LEFT")
                fs:SetJustifyV("TOP")
                fs:SetFontObject("GameFontNormal")
            end

            local function applyAddControlTextLayout()
                fs:ClearAllPoints()
                fs:SetPoint("LEFT", f, "LEFT", 6, 0)
                fs:SetPoint("RIGHT", f, "RIGHT", -6, 0)
                fs:SetJustifyH("CENTER")
                fs:SetJustifyV("MIDDLE")
                fs:SetFontObject("GameFontHighlight")
            end

            f.bg = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
            f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -AddonNS.Const.CATEGORY_HEIGHT + AddonNS.Const.COLUMN_SPACING / 2)
            f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, AddonNS.Const.COLUMN_SPACING / 2)
            f.bg:Hide();

            AddonNS.gui:EnsureCategoryControlBackdrop(f)

            f.hintOverlay = CreateFrame("Frame", nil, f, "BackdropTemplate")
            f.hintOverlay:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
            f.hintOverlay:SetAllPoints(f)
            f.hintOverlay:EnableMouse(false)
            f.hintOverlay:Hide()

            AddonNS.gui.categoriesFrames[i] = f;
            function f:SetText(text) fs:SetText(text) end
            f.ApplyCategoryTextLayout = applyCategoryTextLayout
            f.ApplyCategoryTextLayoutWithDeleteButton = applyCategoryTextLayoutWithDeleteButton
            f.ApplyCategoryTextLayoutWithEditButton = applyCategoryTextLayoutWithEditButton
            f.ApplyCategoryTextLayoutWithEditAndDeleteButtons = applyCategoryTextLayoutWithEditAndDeleteButtons
            f.ApplyAddControlTextLayout = applyAddControlTextLayout
            f.isAddCategoryControl = false
            f.MyBagsScope = "bag"
            f.MyBagsContainerRef = AddonNS.container
            f.deleteButton = deleteButton
            f.editButton = editButton

            f:EnableMouse(true)
            f:SetScript("OnEnter",
                function(self)
                    hoveredCategoryFrame = self
                    if self.isAddCategoryControl then
                        styleCategoryControl(self, true)
                    end
                    AddonNS.gui:RefreshCategoryDragHints()
                end)
            f:SetScript("OnLeave",
                function(self)
                    -- self:SetBackdrop(test)
                    -- self:SetBackdropColor(0, 0, 1, .5)
                    if hoveredCategoryFrame == self then
                        hoveredCategoryFrame = nil
                    end
                    if self.isAddCategoryControl then
                        styleCategoryControl(self, false)
                    end
                    AddonNS.gui:RefreshCategoryDragHints()
                end)

            f:SetScript("OnMouseUp", AddonNS.DragAndDrop.categoryOnMouseUp)
            f:SetScript("OnReceiveDrag", AddonNS.DragAndDrop.categoryOnReceiveDrag)


            f:RegisterForDrag("LeftButton")
            f:SetScript("OnDragStart", function(self, button)
                -- adjustDraggableFramePositionToMouse()
                AddonNS.gui:StartCategoryDragVisual(self.ItemCategory:GetDisplayName() or "Unassigned")
                AddonNS.DragAndDrop.categoryStartDrag(self);
                PlaySound(1183 );
                AddonNS.printDebug("OnDragStart", button)
            end)
            f:SetScript("OnDragStop", function(self)
                AddonNS.gui:StopCategoryDragVisual()
                PlaySound(1200);
                AddonNS.printDebug("OnDragStop")
            end)
            f.fs = fs;
        end

        local f = AddonNS.gui.categoriesFrames[i];
        f:SetPoint("TOPLEFT", backgroundFrame, "TOPLEFT", categoryGUIInfo.x, -categoryGUIInfo.y)
        -- if categoryGUIInfo.last then
        --     f:SetPoint("BOTTOM", relativeTo, "TOP", 0, 0)
        -- end
        -- AddonNS.printDebug(categories[i], pos[i].x, pos[i].y)
        f:SetWidth(categoryGUIInfo.width)
        -- fs.fs:SetWidth(categoryGUIInfo.width)
        f:SetHeight(categoryGUIInfo.height)

        if categoryGUIInfo.isAddCategoryControl or categoryGUIInfo.isExportCategoryControl or categoryGUIInfo.isImportCategoryControl then
            f.ItemCategory = nil
            f.isAddCategoryControl = true
            f.MyBagsScope = categoryGUIInfo.scope or "bag"
            f.MyBagsContainerRef = AddonNS.container
            if categoryGUIInfo.isExportCategoryControl then
                f.controlKind = "export"
            elseif categoryGUIInfo.isImportCategoryControl then
                f.controlKind = "import"
            else
                f.controlKind = "add"
            end
            f.bg:Hide()
            f.addControlBackdrop:Show()
            f.editButton:Hide()
            f.deleteButton:Hide()
            f:ApplyAddControlTextLayout()
            styleCategoryControl(f, false)
            f:RegisterForDrag("LeftButton")
            f:SetScript("OnMouseUp", function(_, button)
                if button == "LeftButton" then
                    if f.controlKind == "add" then
                        StaticPopup_Show("CREATE_CATEGORY_CONFIRM")
                    elseif f.controlKind == "export" then
                        AddonNS.CategoriesGUI:ToggleExportFrame()
                    elseif f.controlKind == "import" then
                        AddonNS.CategoriesGUI:ToggleImportFrame()
                    end
                end
            end)
            f:SetScript("OnReceiveDrag", nil)
            f:SetScript("OnDragStart", nil)
            f:SetScript("OnDragStop", nil)
            f:Show()
        else
            f.ItemCategory = categoryGUIInfo.category;
            f.isAddCategoryControl = false
            f.MyBagsScope = categoryGUIInfo.scope or "bag"
            f.MyBagsContainerRef = AddonNS.container
            f.controlKind = nil
            f.bg:Hide()
            f.addControlBackdrop:Hide()
            local categoryId = f.ItemCategory:GetId()
            local canEditCategory = AddonNS.BagViewState:IsCategoriesConfigMode() and
                customCategories[categoryId] ~= nil
            local canDeleteCategory = canEditCategory and
                not f.ItemCategory:IsProtected()
            f.editButton:SetShown(canEditCategory)
            f.deleteButton:SetShown(canDeleteCategory)
            if canEditCategory and canDeleteCategory then
                f:ApplyCategoryTextLayoutWithEditAndDeleteButtons()
            elseif canEditCategory then
                f:ApplyCategoryTextLayoutWithEditButton()
            elseif canDeleteCategory then
                f:ApplyCategoryTextLayoutWithDeleteButton()
            else
                f:ApplyCategoryTextLayout()
            end
            f:RegisterForDrag("LeftButton")
            f:SetScript("OnMouseUp", AddonNS.DragAndDrop.categoryOnMouseUp)
            f:SetScript("OnReceiveDrag", AddonNS.DragAndDrop.categoryOnReceiveDrag)
            f:SetScript("OnDragStart", function(self, button)
                AddonNS.gui:StartCategoryDragVisual(self.ItemCategory:GetDisplayName() or "Unassigned")
                AddonNS.DragAndDrop.categoryStartDrag(self);
                PlaySound(1183 );
                AddonNS.printDebug("OnDragStart", button)
            end)
            f:SetScript("OnDragStop", function(self)
                AddonNS.gui:StopCategoryDragVisual()
                PlaySound(1200);
                AddonNS.printDebug("OnDragStop")
            end)
            local label = categoryGUIInfo.category:GetDisplayName(categoryGUIInfo.itemsCount) or "Unassigned"
            if isCollapsed(categoryGUIInfo.category) then
                label = label .. " (" .. categoryGUIInfo.itemsCount .. ") |A:glues-characterSelect-icon-arrowDown:19:19:0:4|a"
            end
            f:SetText(label); -- .
            f:Show()
        end
        -- f:Raise();
    end
    -- backgroundFrame:Lower();
    for i = #categoriesGUIInfo + 1, #AddonNS.gui.categoriesFrames, 1 do
        if hoveredCategoryFrame == AddonNS.gui.categoriesFrames[i] then
            hoveredCategoryFrame = nil
        end
        AddonNS.gui.categoriesFrames[i]:Hide();
    end
    AddonNS.gui:RefreshCategoryDragHints()
end
