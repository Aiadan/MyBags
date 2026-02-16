local addonName, AddonNS = ...
local GS = LibStub("MyLibrary_GUI");

--- @type WowList
local WowList = LibStub("WowList-1.5");
AddonNS.CategoriesGUI = AddonNS.CategoriesGUI or {}

function AddonNS.CategoriesGUI:IsQueryEditorFocused()
    return false
end

function AddonNS.createGUI()
    local container = AddonNS.container;
    local selectedCategoryId = nil
    local queryEditorFocused = false
    local COLOR_COG_NORMAL = { 0.78, 0.78, 0.78, 1 }
    local COLOR_COG_EDIT = { 1, 0.85, 0.2, 1 }

    local isHelpPlateLoaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_HelpPlate")
    if not isHelpPlateLoaded then
        local isLoaded, reason
        if C_AddOns and C_AddOns.LoadAddOn then
            isLoaded, reason = C_AddOns.LoadAddOn("Blizzard_HelpPlate")
        else
            isLoaded, reason = LoadAddOn("Blizzard_HelpPlate")
        end
        assert(isLoaded, "Failed to load Blizzard_HelpPlate: " .. tostring(reason))
    end
    local queryHelpText = assert(AddonNS.QueryHelpDocs and AddonNS.QueryHelpDocs.text,
        "MyBags query help docs not loaded. Run: lua tools/generate_query_help.lua")

    local exportFrame
    local importFrame
    local containerFrame = CreateFrame("Frame", addonName .. "_CategoryEditorFrame", UIParent, "DefaultPanelFlatTemplate")
    containerFrame:SetSize(520, 360)
    containerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    containerFrame:SetFrameStrata("DIALOG")
    containerFrame:EnableMouse(true)
    containerFrame:SetMovable(true)
    containerFrame:SetClampedToScreen(true)
    containerFrame:RegisterForDrag("LeftButton")
    containerFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    containerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    containerFrame:Hide()

    local requestCloseCategoryEditor = function(afterClose)
        containerFrame:Hide()
        if afterClose then
            afterClose()
        end
    end
    local closeButton = CreateFrame("Button", nil, containerFrame, "UIPanelCloseButtonDefaultAnchors")
    closeButton:SetScript("OnClick", function()
        requestCloseCategoryEditor()
    end)

    local panelTitle = containerFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    panelTitle:SetPoint("TOPLEFT", containerFrame, "TOPLEFT", 32, -8)
    panelTitle:SetPoint("TOPRIGHT", containerFrame, "TOPRIGHT", -32, -8)
    panelTitle:SetJustifyH("CENTER")
    panelTitle:SetText("Category: (none)")

    local function createQueryHelpFrame()
        local frame = GS:CreateButtonFrame(addonName .. "_queryHelp", 520, 620, true)
        frame:SetPoint("TOPLEFT", containerFrame, "TOPRIGHT", 8, 0)
        frame:EnableMouse(true)
        frame:Hide()

        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 4, -8)
        title:SetText("Query Help")

        local helpScrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        helpScrollFrame:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        helpScrollFrame:SetPoint("BOTTOMRIGHT", frame.Inset, "BOTTOMRIGHT", -28, 8)

        local helpScrollContent = CreateFrame("Frame", nil, helpScrollFrame)
        helpScrollFrame:SetScrollChild(helpScrollContent)

        local helpText = helpScrollContent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        helpText:SetPoint("TOPLEFT", helpScrollContent, "TOPLEFT", 0, 0)
        helpText:SetJustifyH("LEFT")
        helpText:SetJustifyV("TOP")
        helpText:SetText(queryHelpText)

        local function refreshQueryHelpFrameLayout()
            local availableWidth = helpScrollFrame:GetWidth() - 16
            if availableWidth <= 0 then
                return
            end
            helpScrollContent:SetWidth(availableWidth)
            helpText:SetWidth(availableWidth)
            helpScrollContent:SetHeight(helpText:GetStringHeight() + 8)
        end

        helpScrollFrame:SetScript("OnSizeChanged", refreshQueryHelpFrameLayout)
        frame:HookScript("OnShow", function()
            refreshQueryHelpFrameLayout()
            helpScrollFrame:SetVerticalScroll(0)
        end)

        return frame
    end

    local queryHelpFrame = createQueryHelpFrame()

    local settingsButton = CreateFrame("Button", nil, container, "UIPanelIconDropdownButtonTemplate")
    settingsButton:SetSize(20, 20)
    settingsButton:SetPoint("TOPRIGHT", container, "TOPRIGHT", -9, -34)

    local editModeBadge = CreateFrame("Button", nil, container, "BackdropTemplate")
    editModeBadge:SetPoint("RIGHT", settingsButton, "LEFT", -4, 0)
    editModeBadge:SetSize(72, 18)
    editModeBadge:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    editModeBadge:SetBackdropColor(1, 0.78, 0.1, 0.85)
    editModeBadge:SetBackdropBorderColor(1, 0.9, 0.4, 1)
    editModeBadge:Hide()
    editModeBadge:SetScript("OnClick", function()
        settingsButton:Click()
    end)

    local editModeBadgeText = editModeBadge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    editModeBadgeText:SetPoint("CENTER", editModeBadge, "CENTER", 0, 0)
    editModeBadgeText:SetText("Edit mode")

    local function setCogColor(color)
        settingsButton.Icon:SetVertexColor(color[1], color[2], color[3], color[4])
    end

    local function refreshEditModeVisuals()
        if AddonNS.BagViewState:IsCategoriesConfigMode() then
            editModeBadge:Show()
            setCogColor(COLOR_COG_EDIT)
            return
        end
        editModeBadge:Hide()
        setCogColor(COLOR_COG_NORMAL)
    end

    settingsButton:SetScript("OnClick", function(self, button)
        if AddonNS.BagViewState:IsCategoriesConfigMode() then
            requestCloseCategoryEditor(function()
                AddonNS.BagViewState:SetMode("normal")
            end)
            return
        end
        AddonNS.BagViewState:SetMode("categories_config")
    end)

    local function updateTopRightButtons()
        if container:IsShown() and BagItemAutoSortButton:GetParent() == container then
            BagItemAutoSortButton:Hide()
            settingsButton:Show()
            settingsButton:ClearAllPoints()
            settingsButton:SetPoint("TOPRIGHT", container, "TOPRIGHT", -9, -38)
        end
    end

    container:HookScript("OnShow", updateTopRightButtons)
    hooksecurefunc(container, "UpdateSearchBox", updateTopRightButtons)
    container:HookScript("OnHide", function()
        AddonNS.BagViewState:SetMode("normal")
        containerFrame:Hide()
        queryHelpFrame:Hide()
        if exportFrame then
            exportFrame:Hide()
        end
        if importFrame then
            importFrame:Hide()
        end
        StaticPopup_Hide("CREATE_CATEGORY_CONFIRM")
        StaticPopup_Hide("DELETE_CATEGORY_CONFIRM")
        StaticPopup_Hide("IMPORT_CATEGORIES_CONFIRM")
        StaticPopup_Hide("CATEGORY_EDITOR_UNSAVED_CHANGES_CONFIRM")
    end)
    AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.BAG_VIEW_MODE_CHANGED, refreshEditModeVisuals)
    refreshEditModeVisuals()

    local function getSelectedCategory()
        if not selectedCategoryId then
            return nil
        end
        return AddonNS.CategoryStore:Get(selectedCategoryId)
    end

    local function getSelectedCategoryId()
        return selectedCategoryId
    end

    local function resolveValidSelectedCategoryId(categoryId)
        if not categoryId then
            return nil
        end
        local category = AddonNS.CategoryStore:Get(categoryId)
        if not category then
            return nil
        end
        local customCategories = AddonNS.CustomCategories:GetCategories()
        if customCategories[category:GetId()] == nil then
            return nil
        end
        return category:GetId()
    end

    local selectedCategoryBaseline = nil
    local suspendControlHandlers = false
    local cancelNameCommitOnFocusLost = false

    local editorContent = CreateFrame("Frame", nil, containerFrame, "InsetFrameTemplate3")
    editorContent:SetPoint("TOPLEFT", containerFrame, "TOPLEFT", 12, -34)
    editorContent:SetPoint("BOTTOMRIGHT", containerFrame, "BOTTOMRIGHT", -12, 12)

    local selectedCategoryTitle = editorContent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    selectedCategoryTitle:SetPoint("TOPLEFT", editorContent, "TOPLEFT", 12, -10)
    selectedCategoryTitle:SetPoint("TOPRIGHT", editorContent, "TOPRIGHT", -12, -10)
    selectedCategoryTitle:SetJustifyH("LEFT")
    selectedCategoryTitle:SetText("|cffffd34fCategory:|r |cffbbbbbb(none)|r")

    local function collectSortedCustomCategories()
        local entries = {}
        for _, category in pairs(AddonNS.CustomCategories:GetCategories()) do
            table.insert(entries, category)
        end
        table.sort(entries, function(left, right)
            local leftName = left:GetName() or ""
            local rightName = right:GetName() or ""
            leftName = string.lower(leftName)
            rightName = string.lower(rightName)
            if leftName == rightName then
                return left.id < right.id
            end
            return leftName < rightName
        end)
        return entries
    end

    local function createExportFrame()
        local frame = GS:CreateButtonFrame(addonName .. "_exportCategories", 500, 560, true)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:EnableMouse(true)
        frame:Hide()

        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 4, -8)
        title:SetText("Export Categories")

        local exportList = WowList:CreateNew(addonName .. "_exportList", {
            height = 180,
            rows = 8,
            columns = {
                {
                    name = "Name",
                    width = 458,
                    displayFunction = function(cellData, rowData)
                        return rowData.name, { 1, 1, 1, 1 }
                    end,
                },
            },
        }, frame)
        exportList:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        exportList:SetMultiSelection(true)

        local outputScroll = CreateFrame("ScrollFrame", nil, frame, "InputScrollFrameTemplate")
        outputScroll.hideCharCount = true
        outputScroll:SetPoint("TOPLEFT", exportList, "BOTTOMLEFT", 0, -8)
        outputScroll:SetPoint("BOTTOMRIGHT", frame.Inset, "BOTTOMRIGHT", -10, 36)
        local outputLoaded = false
        outputScroll:SetScript("OnShow", function()
            if not outputLoaded then
                outputLoaded = true
                InputScrollFrame_OnLoad(outputScroll)
            end
        end)
        outputScroll.EditBox:SetFontObject(NumberFont_Shadow_Tiny)
        outputScroll.EditBox:SetAutoFocus(false)

        local function refreshExportList()
            exportList:RemoveAll()
            for _, category in ipairs(collectSortedCustomCategories()) do
                exportList:AddData({
                    id = category:GetId(),
                    name = category:GetName() or "",
                })
            end
            exportList:UpdateView()
            outputScroll.EditBox:SetText("")
        end

        local exportButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        exportButton:SetSize(130, 20)
        exportButton:SetPoint("BOTTOMLEFT", frame.Inset, "BOTTOMLEFT", 4, 8)
        exportButton:SetText("Generate Export")
        exportButton:SetScript("OnClick", function()
            local selectedRows = exportList:GetSelected() or {}
            local selectedCategoryIds = {}
            for _, row in ipairs(selectedRows) do
                table.insert(selectedCategoryIds, row.id)
            end
            local payload = AddonNS.CustomCategories:BuildExportPayload(selectedCategoryIds)
            outputScroll.EditBox:SetText(AddonNS.CustomCategories:EncodeExportPayload(payload))
            outputScroll.EditBox:HighlightText(0)
            outputScroll.EditBox:SetFocus()
        end)

        local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        closeButton:SetSize(80, 20)
        closeButton:SetPoint("LEFT", exportButton, "RIGHT", 8, 0)
        closeButton:SetText("Close")
        closeButton:SetScript("OnClick", function()
            frame:Hide()
        end)

        frame:SetScript("OnShow", refreshExportList)
        return frame
    end

    local function createImportFrame()
        local frame = GS:CreateButtonFrame(addonName .. "_importCategories", 520, 560, true)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:EnableMouse(true)
        frame:Hide()

        local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", frame.Inset, "TOPLEFT", 4, -8)
        title:SetText("Import Categories")

        local inputScroll = CreateFrame("ScrollFrame", nil, frame, "InputScrollFrameTemplate")
        inputScroll.hideCharCount = true
        inputScroll:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        inputScroll:SetPoint("TOPRIGHT", frame.Inset, "TOPRIGHT", -10, -36)
        inputScroll:SetHeight(330)
        local inputLoaded = false
        inputScroll:SetScript("OnShow", function()
            if not inputLoaded then
                inputLoaded = true
                InputScrollFrame_OnLoad(inputScroll)
            end
        end)
        inputScroll.EditBox:SetFontObject(NumberFont_Shadow_Tiny)
        inputScroll.EditBox:SetAutoFocus(false)

        local previewScroll = CreateFrame("ScrollFrame", nil, frame, "InputScrollFrameTemplate")
        previewScroll.hideCharCount = true
        previewScroll:SetPoint("TOPLEFT", inputScroll, "BOTTOMLEFT", 0, -8)
        previewScroll:SetPoint("BOTTOMRIGHT", frame.Inset, "BOTTOMRIGHT", -10, 36)
        local previewLoaded = false
        previewScroll:SetScript("OnShow", function()
            if not previewLoaded then
                previewLoaded = true
                InputScrollFrame_OnLoad(previewScroll)
            end
        end)
        previewScroll.EditBox:SetFontObject(NumberFont_Shadow_Tiny)
        previewScroll.EditBox:SetAutoFocus(false)
        previewScroll.EditBox:EnableMouse(false)
        previewScroll.EditBox:SetScript("OnEditFocusGained", function(self)
            self:ClearFocus()
        end)

        local function setPreviewText(value)
            previewScroll.EditBox:SetText(value or "")
            previewScroll:SetVerticalScroll(0)
        end

        local importPreview = nil
        local analyzeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        analyzeButton:SetSize(120, 20)
        analyzeButton:SetPoint("BOTTOMLEFT", frame.Inset, "BOTTOMLEFT", 4, 8)
        analyzeButton:SetText("Analyze Import")

        local applyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        applyButton:SetSize(110, 20)
        applyButton:SetPoint("LEFT", analyzeButton, "RIGHT", 8, 0)
        applyButton:SetText("Apply Import")
        applyButton:Disable()

        local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        closeButton:SetSize(80, 20)
        closeButton:SetPoint("LEFT", applyButton, "RIGHT", 8, 0)
        closeButton:SetText("Close")
        closeButton:SetScript("OnClick", function()
            frame:Hide()
        end)

        analyzeButton:SetScript("OnClick", function()
            importPreview = nil
            applyButton:Disable()
            local ok, previewOrErr = pcall(function()
                return AddonNS.CustomCategories:PreviewImport(inputScroll.EditBox:GetText())
            end)
            if not ok then
                setPreviewText("Import error: " .. tostring(previewOrErr))
                return
            end
            importPreview = previewOrErr
            local createCount = #importPreview.toCreate
            local lines = { string.format("Ready to import (%d categories):", createCount) }
            for _, entry in ipairs(importPreview.toCreate) do
                lines[#lines + 1] = "• " .. tostring(entry.name or "(unnamed)")
            end
            setPreviewText(table.concat(lines, "\n"))
            applyButton:Enable()
        end)

        applyButton:SetScript("OnClick", function()
            if not importPreview then
                return
            end
            local dialog = StaticPopup_Show("IMPORT_CATEGORIES_CONFIRM", tostring(#importPreview.toCreate))
            if dialog then
                dialog.data = importPreview
            end
        end)

        frame:SetScript("OnShow", function()
            setPreviewText("")
            importPreview = nil
            applyButton:Disable()
        end)

        return frame
    end


    local function toggleExportFrame()
        if not exportFrame then
            exportFrame = createExportFrame()
        end
        if exportFrame:IsShown() then
            exportFrame:Hide()
            return
        end
        exportFrame:Show()
    end

    local function toggleImportFrame()
        if not importFrame then
            importFrame = createImportFrame()
        end
        if importFrame:IsShown() then
            importFrame:Hide()
            return
        end
        importFrame:Show()
    end

    local nameLabel = editorContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", selectedCategoryTitle, "BOTTOMLEFT", 0, -16)
    nameLabel:SetText("Name")
    nameLabel:EnableMouse(true)

    local nameEditBox = CreateFrame("EditBox", nil, editorContent, "InputBoxTemplate")
    nameEditBox:SetAutoFocus(false)
    nameEditBox:SetMaxLetters(64)
    nameEditBox:SetSize(340, 20)
    nameEditBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 4, -6)

    local alwaysShowCheckbox = CreateFrame("CheckButton", nil, editorContent, "ChatConfigCheckButtonTemplate")
    alwaysShowCheckbox:SetPoint("TOPLEFT", nameEditBox, "BOTTOMLEFT", -2, -10)
    alwaysShowCheckbox:SetSize(30, 30)
    alwaysShowCheckbox.Text:SetText("Always show")
    alwaysShowCheckbox.tooltip =
    "Enabling this will make this category always visible, even when no items currently associated with it."

    local priorityLabel = editorContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    priorityLabel:SetPoint("TOPLEFT", alwaysShowCheckbox, "BOTTOMLEFT", 2, -14)
    priorityLabel:SetText("Priority")
    priorityLabel:EnableMouse(true)

    local priorityEditBox = CreateFrame("EditBox", nil, editorContent, "InputBoxTemplate")
    priorityEditBox:SetAutoFocus(false)
    priorityEditBox:SetNumeric(true)
    priorityEditBox:SetMaxLetters(9)
    priorityEditBox:SetSize(120, 20)
    priorityEditBox:SetPoint("TOPLEFT", priorityLabel, "BOTTOMLEFT", 4, -6)

    local queryLabel = editorContent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    queryLabel:SetPoint("TOPLEFT", priorityEditBox, "BOTTOMLEFT", -4, -18)
    queryLabel:SetText("Query")
    queryLabel:EnableMouse(true)

    local queryEditBox = CreateFrame("EditBox", nil, editorContent, "SearchBoxTemplate")
    queryEditBox:SetSize(420, 26)
    queryEditBox:SetPoint("TOPLEFT", queryLabel, "BOTTOMLEFT", 0, -6)
    queryEditBox:SetAutoFocus(false)
    queryEditBox:SetMaxLetters(255)
    queryEditBox.instructionText = "Query expression"
    queryEditBox.Instructions:SetText(queryEditBox.instructionText)

    local helpButton = CreateFrame("Button", nil, editorContent, "MainHelpPlateButton")
    helpButton:SetPoint("LEFT", queryEditBox, "RIGHT", 2, 0)
    helpButton:SetSize(64, 64)
    helpButton:SetScale(0.45)
    helpButton.mainHelpPlateButtonTooltipText = "Open query syntax and priority help"
    helpButton:SetScript("OnClick", function()
        if queryHelpFrame:IsShown() then
            queryHelpFrame:Hide()
            return
        end
        queryHelpFrame:Show()
    end)

    local saveButton = CreateFrame("Button", nil, editorContent, "UIPanelButtonTemplate")
    saveButton:SetSize(100, 22)
    saveButton:SetPoint("BOTTOMRIGHT", editorContent, "BOTTOMRIGHT", -14, 14)
    saveButton:SetText("Save")

    local revertButton = CreateFrame("Button", nil, editorContent, "UIPanelButtonTemplate")
    revertButton:SetSize(160, 22)
    revertButton:SetPoint("RIGHT", saveButton, "LEFT", -8, 0)
    revertButton:SetText("Revert Changes")

    local function normalizeCategoryState(category)
        return {
            name = category:GetName() or "",
            query = AddonNS.CustomCategories:GetQuery(category),
            priority = AddonNS.CustomCategories:GetEffectivePriority(category),
            alwaysShow = AddonNS.CategorShowAlways:ShouldAlwaysShow(category) == true,
        }
    end

    local function categoryStateEquals(left, right)
        return left
            and right
            and left.name == right.name
            and left.query == right.query
            and left.priority == right.priority
            and left.alwaysShow == right.alwaysShow
    end

    local function applyQueryTextToBagSearch(queryText)
        queryText = queryText or ""
        if BagItemSearchBox:GetText() ~= queryText then
            BagItemSearchBox:SetText(queryText)
            return
        end
    end

    local function showAnchorTooltip(owner, title, text)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(text, 1, 1, 1, true)
        GameTooltip:Show()
    end

    local function readDraftState()
        local rawPriority = priorityEditBox:GetText()
        return {
            name = nameEditBox:GetText() or "",
            query = queryEditBox:GetText() or "",
            priority = rawPriority ~= "" and tonumber(rawPriority) or nil,
            alwaysShow = alwaysShowCheckbox:GetChecked() == true,
        }
    end

    local function hasPendingChanges()
        local category = getSelectedCategory()
        if not category or not selectedCategoryBaseline then
            return false
        end
        return not categoryStateEquals(readDraftState(), selectedCategoryBaseline)
    end

    local function refreshActionButtonsState()
        local category = getSelectedCategory()
        if not category then
            revertButton:Disable()
            saveButton:Disable()
            return
        end
        if hasPendingChanges() then
            revertButton:Enable()
            saveButton:Enable()
            return
        end
        revertButton:Disable()
        saveButton:Disable()
    end

    local function applyStateToControls(state)
        suspendControlHandlers = true
        nameEditBox:SetText(state.name)
        queryEditBox:SetText(state.query)
        priorityEditBox:SetText(tostring(state.priority))
        alwaysShowCheckbox:SetChecked(state.alwaysShow)
        suspendControlHandlers = false
        refreshActionButtonsState()
    end

    local function saveSelectedCategoryDraft()
        local category = getSelectedCategory()
        if not category then
            return false
        end
        local currentState = normalizeCategoryState(category)
        local draftState = readDraftState()
        if draftState.name == "" then
            draftState.name = currentState.name
        end
        local changed = false
        if draftState.name ~= currentState.name then
            AddonNS.CustomCategories:RenameCategory(category, draftState.name)
            changed = true
        end
        if draftState.query ~= currentState.query then
            AddonNS.CustomCategories:SetQuery(category, draftState.query)
            changed = true
        end
        if draftState.priority ~= currentState.priority then
            AddonNS.CustomCategories:SetPriority(category, draftState.priority)
            changed = true
        end
        if draftState.alwaysShow ~= currentState.alwaysShow then
            AddonNS.CategorShowAlways:SetAlwaysShow(category, draftState.alwaysShow)
            changed = true
        end
        if changed then
            AddonNS.QueueContainerUpdateItemLayout()
        end
        selectedCategoryBaseline = normalizeCategoryState(category)
        local savedName = selectedCategoryBaseline.name or "(unnamed)"
        panelTitle:SetText(savedName)
        selectedCategoryTitle:SetText("|cffffd34fCategory:|r " .. savedName)
        applyStateToControls(selectedCategoryBaseline)
        return true
    end

    local skipUnsavedClosePrompt = false
    local pendingCloseAfterSave = nil
    local pendingCloseDiscard = nil

    local function closeCategoryEditorNow(afterClose)
        skipUnsavedClosePrompt = true
        containerFrame:Hide()
        skipUnsavedClosePrompt = false
        if afterClose then
            afterClose()
        end
    end

    requestCloseCategoryEditor = function(afterClose)
        if skipUnsavedClosePrompt or not containerFrame:IsShown() then
            closeCategoryEditorNow(afterClose)
            return
        end
        if hasPendingChanges() then
            pendingCloseAfterSave = afterClose
            pendingCloseDiscard = afterClose
            StaticPopup_Show("CATEGORY_EDITOR_UNSAVED_CHANGES_CONFIRM")
            return
        end
        closeCategoryEditorNow(afterClose)
    end

    nameEditBox:SetScript("OnEnterPressed", function(self)
        cancelNameCommitOnFocusLost = false
        self:ClearFocus()
    end)
    nameEditBox:SetScript("OnEditFocusLost", function()
        if cancelNameCommitOnFocusLost then
            cancelNameCommitOnFocusLost = false
        end
    end)
    nameEditBox:SetScript("OnEscapePressed", function(self)
        cancelNameCommitOnFocusLost = true
        local baselineState = selectedCategoryBaseline
        if baselineState then
            suspendControlHandlers = true
            self:SetText(baselineState.name)
            suspendControlHandlers = false
        end
        self:ClearFocus()
    end)
    nameEditBox:HookScript("OnTextChanged", function(self, userInput)
        if userInput and not suspendControlHandlers then
            refreshActionButtonsState()
        end
    end)
    local function showNameTooltip(owner)
        showAnchorTooltip(owner, "Category Name", "Display name used for this category header.")
    end
    nameLabel:SetScript("OnEnter", function(self)
        showNameTooltip(self)
    end)
    nameLabel:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    nameEditBox:SetScript("OnEnter", function(self)
        showNameTooltip(self)
    end)
    nameEditBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    alwaysShowCheckbox:SetScript("OnClick", function(self)
        if suspendControlHandlers then
            return
        end
        refreshActionButtonsState()
    end)

    priorityEditBox:SetScript("OnTextChanged", function(self, userInput)
        if suspendControlHandlers or not userInput then
            return
        end
        refreshActionButtonsState()
    end)
    local function showPriorityTooltip(owner)
        showAnchorTooltip(owner, "Priority",
            "Used when multiple query categories match the same item that is not manually assigned. The item is categorized under the highest-priority matching category. Ties are resolved alphabetically.")
    end
    priorityLabel:SetScript("OnEnter", function(self)
        showPriorityTooltip(self)
    end)
    priorityLabel:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    priorityEditBox:SetScript("OnEnter", function(self)
        showPriorityTooltip(self)
    end)
    priorityEditBox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    queryEditBox:HookScript("OnEditFocusGained", function(self)
        queryEditorFocused = true
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CUSTOM_QUERY_EDITOR_FOCUS_CHANGED, true)
        applyQueryTextToBagSearch(self:GetText())
    end)
    queryEditBox:HookScript("OnEditFocusLost", function()
        local queryText = queryEditBox:GetText() or ""
        if BagItemSearchBox:GetText() == queryText then
            applyQueryTextToBagSearch("")
        end
        queryEditorFocused = false
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CUSTOM_QUERY_EDITOR_FOCUS_CHANGED, false)
    end)
    queryEditBox:HookScript("OnTextChanged", function(self, userInput)
        if suspendControlHandlers then
            return
        end
        if userInput then
            applyQueryTextToBagSearch(self:GetText())
            refreshActionButtonsState()
        end
    end)
    queryLabel:SetScript("OnEnter", function(self)
        showAnchorTooltip(self, "Query", "Rules used to automatically match items to this category.")
    end)
    queryLabel:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    saveButton:SetScript("OnClick", function()
        saveSelectedCategoryDraft()
    end)

    revertButton:SetScript("OnClick", function()
        if not selectedCategoryBaseline then
            return
        end
        applyStateToControls(selectedCategoryBaseline)
    end)

    local function refreshSelectedCategoryControls()
        local category = getSelectedCategory()
        suspendControlHandlers = true
        if category then
            local categoryName = category:GetName() or "(unnamed)"
            panelTitle:SetText(categoryName)
            selectedCategoryTitle:SetText("|cffffd34fCategory:|r " .. categoryName)
            nameEditBox:Enable()
            alwaysShowCheckbox:Enable()
            priorityEditBox:Enable()
            queryEditBox:Enable()
            local state = normalizeCategoryState(category)
            applyStateToControls(state)
            return
        end

        panelTitle:SetText("Category Editor")
        selectedCategoryTitle:SetText("|cffffd34fCategory:|r |cffbbbbbb(none)|r")
        nameEditBox:SetText("")
        alwaysShowCheckbox:SetChecked(false)
        queryEditBox:SetText("")
        priorityEditBox:SetText("")
        nameEditBox:Disable()
        alwaysShowCheckbox:Disable()
        priorityEditBox:Disable()
        queryEditBox:Disable()
        suspendControlHandlers = false
        refreshActionButtonsState()
    end

    local function setSelectedCategoryById(categoryId)
        local resolvedId = resolveValidSelectedCategoryId(categoryId)
        if selectedCategoryId == resolvedId then
            refreshSelectedCategoryControls()
            return
        end
        selectedCategoryId = resolvedId
        local category = getSelectedCategory()
        if category then
            selectedCategoryBaseline = normalizeCategoryState(category)
        else
            selectedCategoryBaseline = nil
        end
        refreshSelectedCategoryControls()
        AddonNS.QueueContainerUpdateItemLayout()
    end

    containerFrame:SetScript("OnShow", function()
        setSelectedCategoryById(selectedCategoryId)
    end)

    containerFrame:SetScript("OnHide", function()
        selectedCategoryId = nil
        selectedCategoryBaseline = nil
        refreshSelectedCategoryControls()
        queryEditorFocused = false
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CUSTOM_QUERY_EDITOR_FOCUS_CHANGED, false)
        AddonNS.QueueContainerUpdateItemLayout()
    end)

    refreshSelectedCategoryControls()







    -- popup definition
    StaticPopupDialogs["CREATE_CATEGORY_CONFIRM"] = {
        text = "Enter the name of the new category:",
        button1 = "Create",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(self)
            local categoryName = self:GetEditBox():GetText()
            if categoryName and categoryName ~= "" then
                local category = AddonNS.CustomCategories:NewCategory(categoryName)
                if category and containerFrame:IsShown() then
                    setSelectedCategoryById(category:GetId())
                end
            else
                AddonNS.printDebug("Please enter a category name.")
            end
        end,
        enterClicksFirstButton = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3, -- Avoids some UI taint issues
        EditBoxOnEnterPressed = function(self)
            self:GetParent():GetButton1():Click();
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide();
            ClearCursor();
        end
    }
    StaticPopupDialogs["CATEGORY_EDITOR_UNSAVED_CHANGES_CONFIRM"] = {
        text = "If you exit now you will lose any unsaved changes.\nHow would you like to proceed?",
        button1 = "Save and Exit",
        button2 = "Exit",
        OnAccept = function()
            saveSelectedCategoryDraft()
            local callback = pendingCloseAfterSave
            pendingCloseAfterSave = nil
            pendingCloseDiscard = nil
            closeCategoryEditorNow(callback)
        end,
        OnCancel = function()
            local callback = pendingCloseDiscard
            pendingCloseAfterSave = nil
            pendingCloseDiscard = nil
            closeCategoryEditorNow(callback)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
    }
    StaticPopupDialogs["DELETE_CATEGORY_CONFIRM"] = {
        text = "Please confirm you want to remove \"%s\" category.",
        button1 = "Confirm deletion",
        button2 = "Cancel",
        OnAccept = function(self, data)
            AddonNS.printDebug("Category deleted: ", data)
            local deletedCategoryId = data and data.GetId and data:GetId() or nil
            AddonNS.CustomCategories:DeleteCategory(data);
            if deletedCategoryId and getSelectedCategoryId() == deletedCategoryId then
                setSelectedCategoryById(nil)
            else
                refreshSelectedCategoryControls()
                AddonNS.QueueContainerUpdateItemLayout();
            end
        end,
        enterClicksFirstButton = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3, -- Avoids some UI taint issues
    }
    StaticPopupDialogs["IMPORT_CATEGORIES_CONFIRM"] = {
        text = "Import will create %s categories. Continue?",
        button1 = "Apply Import",
        button2 = "Cancel",
        OnAccept = function(self, data)
            local preview = data or self.data
            local ok, err = pcall(function()
                AddonNS.CustomCategories:ApplyImportPreview(preview)
            end)
            if not ok then
                AddonNS.printDebug("Import failed:", err)
                return
            end
            refreshSelectedCategoryControls()
            AddonNS.QueueContainerUpdateItemLayout()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    function AddonNS.CategoriesGUI:SelectCategoryById(categoryId)
        if not containerFrame:IsShown() then
            containerFrame:Show()
        end
        setSelectedCategoryById(categoryId)
    end

    function AddonNS.CategoriesGUI:ClearSelection()
        setSelectedCategoryById(nil)
    end

    function AddonNS.CategoriesGUI:IsShown()
        return containerFrame:IsShown()
    end

    function AddonNS.CategoriesGUI:GetSelectedCategoryId()
        return getSelectedCategoryId()
    end

    function AddonNS.CategoriesGUI:ToggleExportFrame()
        toggleExportFrame()
    end

    function AddonNS.CategoriesGUI:ToggleImportFrame()
        toggleImportFrame()
    end

    function AddonNS.CategoriesGUI:IsQueryEditorFocused()
        return queryEditorFocused
    end
end

AddonNS.createGUI()
