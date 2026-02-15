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

AddonNS.gui = {}
AddonNS.gui.categoriesFrames = {};

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
            draggableFrame.hintLine:SetText("|cffc8c8c8Hold Shift: move |r" ..
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

local backgroundFrame = nil;
backgroundFrame = CreateFrame("Frame", nil, AddonNS.container, "BackdropTemplate")     -- todo: does it need to be some frame with bg, or pure frame would sufficie? I think I was testing it and it didnt work for some reason.
backgroundFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
backgroundFrame:SetBackdropColor(0, 1, 0, 0)
backgroundFrame:EnableMouse(true)
backgroundFrame:SetScript("OnReceiveDrag", AddonNS.DragAndDrop.backgroundOnReceiveDrag)
backgroundFrame:SetScript("OnMouseUp", AddonNS.DragAndDrop.backgroundOnReceiveDrag)

backgroundFrame:SetPoint("BOTTOMRIGHT", AddonNS.container.MoneyFrame, "TOPRIGHT", 0, 0)
backgroundFrame.myBagAddonHooked = true;

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
    AddonNS:SetNumColumns(target)
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
    if not AddonNS.BagViewState:IsCategoriesConfigMode() then
        return
    end

    local container = AddonNS.container
    local startColumns = AddonNS:GetNumColumns()
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
    local shouldShow = AddonNS.container:IsShown() and AddonNS.BagViewState:IsCategoriesConfigMode() and not InCombatLockdown()
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

            f.bg = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
            f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -AddonNS.Const.CATEGORY_HEIGHT + AddonNS.Const.COLUMN_SPACING / 2)
            f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, AddonNS.Const.COLUMN_SPACING / 2)
            f.bg:Hide();
            AddonNS.gui.categoriesFrames[i] = f;
            function f:SetText(text) fs:SetText(text) end

            f:EnableMouse(true)
            f:SetScript("OnEnter",
                function(self)
                    -- local infoType, itemID, itemLink = GetCursorInfo()
                    -- if infoType == "item" then
                    --     if self.ItemCategory.protected then
                    --         self:SetBackdrop(protectedCategoryBackdrop)
                    --     else
                    --         self:SetBackdrop(unprotectedCategoryBackdrop)
                    --     end
                    -- end
                    -- self:SetBackdropColor(0, 0, 0, .5)
                    GameTooltip:SetOwner(self);
                    --GameTooltip_SetTitle(GameTooltip, BAG_CLEANUP_BAGS, HIGHLIGHT_FONT_COLOR);
                    GameTooltip_AddNormalLine(GameTooltip, self.fs:GetText());
                    if (self.ItemCategory.description) then
                        GameTooltip_AddNormalLine(GameTooltip, self.ItemCategory.description);
                    end

                    GameTooltip:Show();
                end)
            f:SetScript("OnLeave",
                function(self)
                    -- self:SetBackdrop(test)
                    -- self:SetBackdropColor(0, 0, 1, .5)
                    GameTooltip_Hide()
                end)

            f:SetScript("OnMouseUp", AddonNS.DragAndDrop.categoryOnMouseUp)
            f:SetScript("OnReceiveDrag", AddonNS.DragAndDrop.categoryOnReceiveDrag)


            f:RegisterForDrag("LeftButton")
            f:SetScript("OnDragStart", function(self, button)
                -- adjustDraggableFramePositionToMouse()
                activeDraggedCategoryName = self.ItemCategory:GetDisplayName() or "Unassigned"
                refreshDragTooltipText()
                -- draggableFrame:SetWidth(self:GetWidth());
                draggableFrame:Show()
                draggableFrame:StartDragging()
                AddonNS.DragAndDrop.categoryStartDrag(self);
                PlaySound(1183 );
                AddonNS.printDebug("OnDragStart", button)
            end)
            f:SetScript("OnDragStop", function(self)
                draggableFrame:Hide()
                draggableFrame:StopDragging()
                PlaySound(1200);
                AddonNS.printDebug("OnDragStop")
            end)
            f.fs = fs;
        end

        local f = AddonNS.gui.categoriesFrames[i];
        f.ItemCategory = categoryGUIInfo.category;
        f:SetPoint("TOPLEFT", backgroundFrame, "TOPLEFT", categoryGUIInfo.x, -categoryGUIInfo.y)
        -- if categoryGUIInfo.last then
        --     f:SetPoint("BOTTOM", relativeTo, "TOP", 0, 0)
        -- end
        -- AddonNS.printDebug(categories[i], pos[i].x, pos[i].y)
        f:SetWidth(categoryGUIInfo.width)
        -- fs.fs:SetWidth(categoryGUIInfo.width)
        f:SetHeight(categoryGUIInfo.height)
        local label = categoryGUIInfo.category:GetDisplayName(categoryGUIInfo.itemsCount) or "Unassigned"
        if isCollapsed(categoryGUIInfo.category) then
            label = label .. " (" .. categoryGUIInfo.itemsCount .. ") |A:glues-characterSelect-icon-arrowDown:19:19:0:4|a"
        end
        f:SetText(label); -- .
        f:Show()
        -- f:Raise();
    end
    -- backgroundFrame:Lower();
    for i = #categoriesGUIInfo + 1, #AddonNS.gui.categoriesFrames, 1 do
        AddonNS.gui.categoriesFrames[i]:Hide();
    end
end
