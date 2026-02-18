local addonName, AddonNS = ...

AddonNS.ResizeHandle = AddonNS.ResizeHandle or {}

local DEFAULT_PREVIEW_COLORS = {
    neutral = { 0.35, 0.58, 0.94, 0.22 },
    growth = { 0.20, 0.85, 0.35, 0.30 },
    shrink = { 0.90, 0.24, 0.24, 0.30 },
}

local function clampWidth(width, minWidth, maxWidth)
    if width < minWidth then
        return minWidth
    end
    if width > maxWidth then
        return maxWidth
    end
    return width
end

local function calculateWidthBounds(startWidth, startColumns, columnPixelWidth, minColumns, maxColumns)
    local chromeOffset = startWidth - startColumns * columnPixelWidth
    local minWidth = chromeOffset + minColumns * columnPixelWidth
    local maxWidth = chromeOffset + maxColumns * columnPixelWidth
    return chromeOffset, minWidth, maxWidth
end

local function calculateTargetColumns(currentWidth, chromeOffset, columnPixelWidth, startColumns, minColumns, maxColumns)
    local visibleColumns = (currentWidth - chromeOffset) / columnPixelWidth
    return AddonNS.ColumnResize:CalculateTarget(startColumns, visibleColumns, minColumns, maxColumns)
end

local function classifyPreviewTarget(currentWidth, chromeOffset, columnPixelWidth, startColumns, minColumns, maxColumns)
    local visibleColumns = (currentWidth - chromeOffset) / columnPixelWidth
    return AddonNS.ColumnResize:ClassifyPreview(startColumns, visibleColumns, minColumns, maxColumns)
end

local function normalizeCursorX(cursorX, effectiveScale)
    return cursorX / effectiveScale
end

function AddonNS.ResizeHandle:Create(config)
    local minColumns = config.minColumns or AddonNS.Const.MIN_NUM_COLUMNS
    local maxColumns = config.maxColumns or AddonNS.Const.MAX_NUM_COLUMNS
    local previewColors = config.previewColors or DEFAULT_PREVIEW_COLORS

    local handle = CreateFrame("Button", nil, config.parentFrame, "PanelResizeButtonTemplate")
    handle:SetPoint(
        config.anchor.point,
        config.anchor.relativeTo,
        config.anchor.relativePoint,
        config.anchor.x,
        config.anchor.y
    )
    if config.rotationDegrees then
        handle:SetRotationDegrees(config.rotationDegrees)
    end
    handle:SetFrameStrata("TOOLTIP")
    handle:Hide()

    local previewFrame = CreateFrame("Frame", nil, config.previewParent, "BackdropTemplate")
    previewFrame:SetAllPoints(config.previewParent)
    previewFrame:SetFrameStrata("TOOLTIP")
    previewFrame:SetFrameLevel(config.previewParent:GetFrameLevel() + 20)
    previewFrame:EnableMouse(false)
    previewFrame:Hide()

    local previewColumns = {}
    for index = 1, maxColumns do
        local overlay = CreateFrame("Frame", nil, previewFrame, "BackdropTemplate")
        overlay:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background" })
        overlay:SetBackdropColor(0, 0, 0, 0)
        overlay:Hide()
        previewColumns[index] = overlay
    end

    local activeResize = nil

    local function hidePreview()
        for index = 1, #previewColumns do
            previewColumns[index]:Hide()
        end
        previewFrame:Hide()
    end

    local function setPreviewColor(frame, color)
        frame:SetBackdropColor(color[1], color[2], color[3], color[4])
    end

    local function updatePreview(state, currentWidth)
        local targetColumns = classifyPreviewTarget(
            currentWidth,
            state.chromeOffset,
            state.columnPixelWidth,
            state.startColumns,
            minColumns,
            maxColumns
        )

        local highestVisiblePreview = math.max(state.startColumns, targetColumns)
        local stableColumns = math.min(state.startColumns, targetColumns)
        local overlayWidth = state.columnPixelWidth - AddonNS.Const.COLUMN_SPACING
        if overlayWidth < 1 then
            overlayWidth = 1
        end

        for index = 1, #previewColumns do
            local overlay = previewColumns[index]
            if index <= highestVisiblePreview then
                overlay:ClearAllPoints()
                local offsetX = (index - 1) * state.columnPixelWidth
                overlay:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", offsetX, 0)
                overlay:SetPoint("BOTTOMLEFT", previewFrame, "BOTTOMLEFT", offsetX, 0)
                overlay:SetWidth(overlayWidth)

                if index <= stableColumns then
                    setPreviewColor(overlay, previewColors.neutral)
                elseif targetColumns > state.startColumns then
                    setPreviewColor(overlay, previewColors.growth)
                else
                    setPreviewColor(overlay, previewColors.shrink)
                end
                overlay:Show()
            else
                overlay:Hide()
            end
        end

        previewFrame:Show()
    end

    local function stopResize(applyChange)
        local state = activeResize
        if not state then
            return
        end
        activeResize = nil
        handle:SetScript("OnUpdate", nil)
        handle:SetButtonState("NORMAL", false)
        hidePreview()

        config.SetHeight(state.startHeight)

        if not applyChange then
            if config.OnCancel then
                config.OnCancel()
            end
            return
        end

        local target = calculateTargetColumns(
            config.GetWidth(),
            state.chromeOffset,
            state.columnPixelWidth,
            state.startColumns,
            minColumns,
            maxColumns
        )
        config.ApplyTargetColumns(target)
        if config.OnApplied then
            config.OnApplied(target)
        end
    end

    local function updateResize()
        local state = activeResize
        if not state then
            return
        end
        if not IsMouseButtonDown("LeftButton") then
            stopResize(true)
            return
        end

        local cursorX = normalizeCursorX(GetCursorPosition(), state.uiScale)
        local deltaX = cursorX - state.startCursorX
        local desiredWidth = config.CalculateDesiredWidth(state.startWidth, deltaX)
        desiredWidth = clampWidth(desiredWidth, state.minWidth, state.maxWidth)

        config.SetWidth(desiredWidth)
        config.SetHeight(state.startHeight)
        updatePreview(state, desiredWidth)
    end

    local function startResize()
        if config.IsDisabled and config.IsDisabled() then
            return
        end

        local startColumns = config.GetCurrentColumns()
        local startWidth = config.GetWidth()
        local columnPixelWidth = config.GetColumnPixelWidth()
        if not columnPixelWidth or columnPixelWidth <= 0 then
            return
        end

        local chromeOffset, minWidth, maxWidth = calculateWidthBounds(
            startWidth,
            startColumns,
            columnPixelWidth,
            minColumns,
            maxColumns
        )

        activeResize = {
            startCursorX = normalizeCursorX(GetCursorPosition(), config.parentFrame:GetEffectiveScale()),
            uiScale = config.parentFrame:GetEffectiveScale(),
            startWidth = startWidth,
            startHeight = config.GetHeight(),
            startColumns = startColumns,
            columnPixelWidth = columnPixelWidth,
            chromeOffset = chromeOffset,
            minWidth = minWidth,
            maxWidth = maxWidth,
        }
        updatePreview(activeResize, startWidth)
        handle:SetButtonState("PUSHED", true)
        handle:SetScript("OnUpdate", updateResize)
    end

    local function refresh()
        local shouldShow = config.ShouldShow and config.ShouldShow() or false
        if shouldShow then
            handle:Show()
            handle:EnableMouse(true)
            return
        end
        stopResize(false)
        handle:Hide()
        handle:EnableMouse(false)
    end

    handle:SetScript("OnMouseDown", function(_, mouseButtonName)
        if mouseButtonName == "LeftButton" then
            startResize()
        end
    end)

    handle:SetScript("OnMouseUp", function(_, mouseButtonName)
        if mouseButtonName == "LeftButton" then
            stopResize(true)
        end
    end)

    return {
        handle = handle,
        Refresh = refresh,
        Stop = function()
            stopResize(false)
        end,
    }
end

AddonNS._Test = AddonNS._Test or {}
AddonNS._Test.ResizeHandle = {
    ClampWidth = clampWidth,
    CalculateWidthBounds = calculateWidthBounds,
    CalculateTargetColumns = calculateTargetColumns,
    ClassifyPreviewTarget = classifyPreviewTarget,
    NormalizeCursorX = normalizeCursorX,
}
