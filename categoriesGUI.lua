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
    local containerFrame = GS:CreateButtonFrame(addonName, 440, 620, true);
    containerFrame:SetPoint("TOPRIGHT", container, "TOPLEFT", 0, -30);
    containerFrame:EnableMouse(true)
    containerFrame:Hide();

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
            AddonNS.BagViewState:SetMode("normal")
            containerFrame:Hide()
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
        StaticPopup_Hide("RENAME_CATEGORY_CONFIRM")
        StaticPopup_Hide("DELETE_CATEGORY_CONFIRM")
        StaticPopup_Hide("IMPORT_CATEGORIES_CONFIRM")
    end)
    AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.BAG_VIEW_MODE_CHANGED, refreshEditModeVisuals)
    refreshEditModeVisuals()

    containerFrame.Inset:SetPoint("BOTTOMRIGHT", -6, 126)
    local selectedCategoryTitle = containerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    selectedCategoryTitle:SetPoint("TOPLEFT", containerFrame.Inset, "TOPLEFT", 4, -8)
    selectedCategoryTitle:SetText("Category: (none)")

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

    --- [[ save button]]
    local renameButton = CreateFrame("Button", nil, containerFrame, "UIPanelButtonTemplate")
    renameButton:SetPoint("TOPLEFT", selectedCategoryTitle, "BOTTOMLEFT", -4, -8);

    renameButton:SetSize(60, 20)
    renameButton:SetText("Rename")

    renameButton:SetScript("OnClick", function(self, button)
        local category = getSelectedCategory()
        if not category then
            return
        end
        local dialog = StaticPopup_Show("RENAME_CATEGORY_CONFIRM", category:GetName() or "")
        if dialog then
            dialog.data = category
        end
    end)

    --- [[ delete button]]
    local deleteButton = CreateFrame("Button", nil, containerFrame, "UIPanelButtonTemplate")
    deleteButton:SetPoint("TOPLEFT", renameButton, "TOPRIGHT", 5, 0);

    deleteButton:SetSize(60, 20)
    deleteButton:SetText("Delete")

    deleteButton:SetScript("OnClick", function(self, button)
        local category = getSelectedCategory()
        if not category then
            return
        end
        local dialog = StaticPopup_Show("DELETE_CATEGORY_CONFIRM", category:GetName() or "")
        if dialog then
            dialog.data = category
        end
    end)

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


    --- [[always show checkbox]]
    -- Create a new frame
    local alwaysShowCheckbox = CreateFrame("CheckButton", nil, containerFrame, "ChatConfigCheckButtonTemplate")

    -- Set the position of the checkbox (parent, anchor, relative to, x offset, y offset)
    alwaysShowCheckbox:SetPoint("LEFT", deleteButton, "RIGHT", 5, 0);

    -- Set the size of the checkbox
    alwaysShowCheckbox:SetSize(30, 30)

    -- Set the label for the checkbox (text next to the checkbox)
    alwaysShowCheckbox.Text:SetText("Always show")

    -- Tooltip for the checkbox
    alwaysShowCheckbox.tooltip =
    "Enabling this will make this category always visible, even when no items currently associated with it."

    -- Function to run when the checkbox is clicked
    alwaysShowCheckbox:SetScript("OnClick", function(self)
        local categoryId = getSelectedCategoryId()
        if categoryId then
            AddonNS.CategorShowAlways:SetAlwaysShow(categoryId, self:GetChecked())
            AddonNS.QueueContainerUpdateItemLayout();
        end
    end)

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


    --- [[ Query label ]]
    local priorityLabel = containerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
    priorityLabel:SetText("Priority:");
    priorityLabel:SetPoint("TOPLEFT", renameButton, "BOTTOMLEFT", 4, -5);

    local priorityEditBox = CreateFrame("EditBox", nil, containerFrame, "InputBoxTemplate")
    priorityEditBox:SetAutoFocus(false)
    priorityEditBox:SetNumeric(true)
    priorityEditBox:SetMaxLetters(9)
    priorityEditBox:SetSize(80, 20)
    priorityEditBox:SetPoint("LEFT", priorityLabel, "RIGHT", 6, 0)
    containerFrame.priorityEditBox = priorityEditBox

    --- [[ Query label ]]
    local queryLabel = containerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
    queryLabel:SetText("Query:");
    queryLabel:SetPoint("TOPLEFT", priorityLabel, "BOTTOMLEFT", 0, -6);
    containerFrame.queryLabel = queryLabel


    -- [[ GUI - textScrollFrame]]
    --  local function createEditBox(frame, posX, posY, height)
    local textScrollFrame = CreateFrame("ScrollFrame", nil, containerFrame, "InputScrollFrameTemplate")
    textScrollFrame.hideCharCount = true;
    -- textScrollFrame:SetHeight(height)
    textScrollFrame:SetPoint("TOPLEFT", queryLabel, "BOTTOMLEFT", 2, -8);
    textScrollFrame:SetPoint("BOTTOMRIGHT", containerFrame, "BOTTOMRIGHT", -10, 30);
    -- textScrollFrame:SetPoint("RIGHT", containerFrame, "RIGHT", -posX, posY);
    -- textScrollFrame:SetPoint("LEFT", containerFrame, "LEFT", -posX, posY);
    local textScrollFrameLoaded = false;

    textScrollFrame:SetScript("OnShow", function()
        if not textScrollFrameLoaded then
            textScrollFrameLoaded = true;
            InputScrollFrame_OnLoad(textScrollFrame);
        end
    end)
    textScrollFrame.EditBox:SetFontObject(NumberFont_Shadow_Tiny)

    local function applyQueryTextToBagSearch(queryText)
        queryText = queryText or ""
        if BagItemSearchBox:GetText() ~= queryText then
            BagItemSearchBox:SetText(queryText)
            return
        end
    end

    textScrollFrame.EditBox:HookScript("OnEditFocusGained", function(self)
        queryEditorFocused = true
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CUSTOM_QUERY_EDITOR_FOCUS_CHANGED, true)
        applyQueryTextToBagSearch(self:GetText())
    end)

    textScrollFrame.EditBox:HookScript("OnEditFocusLost", function()
        queryEditorFocused = false
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CUSTOM_QUERY_EDITOR_FOCUS_CHANGED, false)
    end)

    textScrollFrame.EditBox:HookScript("OnTextChanged", function(self, userInput)
        if userInput then
            applyQueryTextToBagSearch(self:GetText())
        end
    end)

    containerFrame.textScrollFrame = textScrollFrame
    -- end
    -- containerFrame.textScrollFrame = createEditBox(containerFrame, 25, -60, 60)


    --- [[ saveQueryButton button]]
    local saveQueryButton = CreateFrame("Button", nil, containerFrame, "UIPanelButtonTemplate")
    saveQueryButton:SetPoint("TOP", containerFrame.textScrollFrame, "BOTTOM", 0, -5);

    saveQueryButton:SetSize(100, 20)
    saveQueryButton:SetText("Save Query")

    saveQueryButton:SetScript("OnClick", function(self, button)
        local categoryId = getSelectedCategoryId()
        if categoryId then
            AddonNS.CustomCategories:SetQuery(categoryId, containerFrame.textScrollFrame.EditBox:GetText())
            AddonNS.QueueContainerUpdateItemLayout();
        end
    end)

    local savePriorityButton = CreateFrame("Button", nil, containerFrame, "UIPanelButtonTemplate")
    savePriorityButton:SetPoint("LEFT", priorityEditBox, "RIGHT", 8, 0)
    savePriorityButton:SetSize(100, 20)
    savePriorityButton:SetText("Save Priority")
    local helpButton = CreateFrame("Button", nil, containerFrame, "MainHelpPlateButton")
    helpButton:SetPoint("LEFT", savePriorityButton, "RIGHT", 8, 0)
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
    local function savePrioritySelection()
        local categoryId = getSelectedCategoryId()
        if not categoryId then
            return
        end
        local rawText = containerFrame.priorityEditBox:GetText()
        if rawText == "" then
            AddonNS.CustomCategories:SetPriority(categoryId, nil)
        else
            AddonNS.CustomCategories:SetPriority(categoryId, tonumber(rawText))
        end
        AddonNS.QueueContainerUpdateItemLayout();
    end
    savePriorityButton:SetScript("OnClick", function(self, button)
        savePrioritySelection()
    end)
    priorityEditBox:SetScript("OnEditFocusLost", function(self)
        if getSelectedCategoryId() then
            savePrioritySelection()
        end
    end)
    priorityEditBox:SetScript("OnEnterPressed", function(self)
        savePrioritySelection()
        self:ClearFocus()
    end)

    local function refreshSelectedCategoryControls()
        local category = getSelectedCategory()
        if category then
            selectedCategoryTitle:SetText("|cffffd34fCategory:|r " .. (category:GetName() or "(unnamed)"))
            renameButton:Enable()
            alwaysShowCheckbox:Enable()
            alwaysShowCheckbox:SetChecked(AddonNS.CategorShowAlways:ShouldAlwaysShow(category))
            deleteButton:Enable()
            saveQueryButton:Enable()
            savePriorityButton:Enable()
            priorityEditBox:Enable()
            containerFrame.textScrollFrame.EditBox:SetText(AddonNS.CustomCategories:GetQuery(category))
            containerFrame.priorityEditBox:SetText(tostring(AddonNS.CustomCategories:GetEffectivePriority(category)))
            return
        end

        selectedCategoryTitle:SetText("|cffffd34fCategory:|r |cffbbbbbb(none)|r")
        alwaysShowCheckbox:SetChecked(false)
        alwaysShowCheckbox:Disable()
        renameButton:Disable()
        deleteButton:Disable()
        saveQueryButton:Disable()
        savePriorityButton:Disable()
        priorityEditBox:Disable()
        containerFrame.textScrollFrame.EditBox:SetText("")
        containerFrame.priorityEditBox:SetText("")
    end

    local function setSelectedCategoryById(categoryId)
        local resolvedId = resolveValidSelectedCategoryId(categoryId)
        if selectedCategoryId == resolvedId then
            refreshSelectedCategoryControls()
            return
        end
        selectedCategoryId = resolvedId
        refreshSelectedCategoryControls()
        AddonNS.QueueContainerUpdateItemLayout()
    end

    containerFrame:SetScript("OnShow", function()
        setSelectedCategoryById(selectedCategoryId)
    end)

    containerFrame:SetScript("OnHide", function()
        selectedCategoryId = nil
        refreshSelectedCategoryControls()
        queryEditorFocused = false
        AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CUSTOM_QUERY_EDITOR_FOCUS_CHANGED, false)
        AddonNS.QueueContainerUpdateItemLayout();
    end)

    renameButton:Disable()
    deleteButton:Disable()
    alwaysShowCheckbox:Disable()
    saveQueryButton:Disable()
    savePriorityButton:Disable()
    priorityEditBox:Disable()
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
    StaticPopupDialogs["RENAME_CATEGORY_CONFIRM"] = {
        text = "Enter the new name for \"%s\" category:",
        button1 = "Rename",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(self, data)
            local categoryName = self:GetEditBox():GetText()
            if categoryName and categoryName ~= "" then
                AddonNS.printDebug("Category renamed: ", data, categoryName)
                AddonNS.CustomCategories:RenameCategory(data, categoryName);
                AddonNS.QueueContainerUpdateItemLayout();
                refreshSelectedCategoryControls()
            else
                AddonNS.printDebug("Please enter a category name.")
            end
        end,
        OnShow = function(self, data)
            self:GetEditBox():SetText(data and data:GetName() or "")
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
