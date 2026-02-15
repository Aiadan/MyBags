local addonName, AddonNS = ...
local GS = LibStub("MyLibrary_GUI");

--- @type WowList
local WowList = LibStub("WowList-1.5");
AddonNS.CategoriesGUI = AddonNS.CategoriesGUI or {}

function AddonNS.createGUI()
    local container = AddonNS.container;
    local lastSelectedCategoryId = nil
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
        containerFrame:Show()
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
        StaticPopup_Hide("CREATE_CATEGORY_CONFIRM")
        StaticPopup_Hide("RENAME_CATEGORY_CONFIRM")
        StaticPopup_Hide("DELETE_CATEGORY_CONFIRM")
    end)
    AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.BAG_VIEW_MODE_CHANGED, refreshEditModeVisuals)
    refreshEditModeVisuals()

    containerFrame.Inset:SetPoint("BOTTOMRIGHT", -6, 126)
    containerFrame.categoriesContainer = CreateFrame("Frame", addonName .. "-reagentsContainer", containerFrame)
    local categoriesContainter = containerFrame.categoriesContainer;
    categoriesContainter:SetPoint("TOPLEFT", 16, -65)
    categoriesContainter:SetPoint("BOTTOMRIGHT")

    local list
    do
        categoriesContainter.list = WowList:CreateNew(addonName .. "_categoriesList",
            {
                height = 400,
                rows = 20,
                columns = {
                    {
                        name = "Name",
                        width = 230,
                        displayFunction = function(cellData, rowData)
                            local displayName = rowData.name or "(unnamed)"
                            return displayName, { 1, 1, 1, 1 }
                        end,
                    },
                    {
                        name = "Show",
                        width = 90,
                        displayFunction = function(cellData, rowData)
                            if rowData.alwaysVisible then
                                return "Always", { 0, 1, 0, 1 }
                            end
                            return "With items", { 1, 1, 0, 1 }
                        end,
                    },
                },
            }, categoriesContainter)

        list = categoriesContainter.list;
        list:SetPoint('TOPLEFT', categoriesContainter, 'TOPLEFT', 0, 0)
        list:SetMultiSelection(false)
        list:SetButtonOnMouseDownFunction(function(rowData, button)
            AddonNS.DragAndDrop.customCategoryGUIOnMouseUp(rowData.id, button)
        end, true)

        list:SetButtonOnReceiveDragFunction(function(rowData)
            AddonNS.DragAndDrop.customCategoryGUIOnReceiveDrag(rowData.id)
        end)
    end

    local function getSelectedRow()
        local selection = list:GetSelected()
        return selection and selection[1] or nil
    end

    local function getSelectedCategory()
        local row = getSelectedRow()
        if not row then
            return nil
        end
        return AddonNS.CategoryStore:Get(row.id)
    end

    local function selectCategoryById(categoryId)
        list:SelectRowByPredicate(function(row)
            return row.id == categoryId
        end)
    end

    local function selectCategory(category)
        selectCategoryById(category and category:GetId() or nil)
    end

    function list:RefreshList()
        list:RemoveAll()
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
        for _, category in ipairs(entries) do
            list:AddData({
                id = category.id,
                name = category:GetName(),
                alwaysVisible = category.alwaysVisible or false,
            })
        end
        list:UpdateView()
        return entries
    end

    containerFrame:SetScript("OnShow", function()
        local entries = list:RefreshList()
        if lastSelectedCategoryId then
            selectCategoryById(lastSelectedCategoryId)
        end
        if not getSelectedRow() and entries[1] then
            selectCategory(entries[1])
        end
        AddonNS.QueueContainerUpdateItemLayout();
    end)

    containerFrame:SetScript("OnHide", function()
        lastSelectedCategoryId = nil
        queryHelpFrame:Hide()
        AddonNS.QueueContainerUpdateItemLayout();
    end)

    --- [[ save button]]
    local renameButton = CreateFrame("Button", nil, containerFrame, "UIPanelButtonTemplate")
    renameButton:SetPoint("TOPLEFT", containerFrame.Inset, "BOTTOMLEFT", 0, -6);

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

    local function getSelectedCategoryId()
        local category = getSelectedCategory()
        return category and category.id or nil
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
        list:RefreshList()
        selectCategoryById(categoryId)
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


    renameButton:Disable()
    deleteButton:Disable()
    alwaysShowCheckbox:Disable()
    saveQueryButton:Disable()
    savePriorityButton:Disable()
    priorityEditBox:Disable()
    list:RegisterCallback("SelectionChanged", function()
        local category = getSelectedCategory()
        local selectedCategoryId = category and category.id or nil
        if category then
            renameButton:Enable()
            alwaysShowCheckbox:Enable()
            alwaysShowCheckbox:SetChecked(AddonNS.CategorShowAlways:ShouldAlwaysShow(category))
            deleteButton:Enable()
            saveQueryButton:Enable()
            savePriorityButton:Enable()
            priorityEditBox:Enable()
            containerFrame.textScrollFrame.EditBox:SetText(AddonNS.CustomCategories:GetQuery(category))
            containerFrame.priorityEditBox:SetText(tostring(AddonNS.CustomCategories:GetEffectivePriority(category)))
        else
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
        if lastSelectedCategoryId ~= selectedCategoryId then
            lastSelectedCategoryId = selectedCategoryId
            AddonNS.QueueContainerUpdateItemLayout();
        end
    end)







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
                list:RefreshList()
                if category then
                    selectCategoryById(category.id)
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
                list:RefreshList();
                selectCategory(data)
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
            AddonNS.CustomCategories:DeleteCategory(data);
            AddonNS.QueueContainerUpdateItemLayout();
            list:RefreshList();
            renameButton:Disable()
            deleteButton:Disable()
            alwaysShowCheckbox:SetChecked(false)
            alwaysShowCheckbox:Disable()
            saveQueryButton:Disable()
            savePriorityButton:Disable()
            priorityEditBox:Disable()
            containerFrame.textScrollFrame.EditBox:SetText("")
            containerFrame.priorityEditBox:SetText("")
        end,
        enterClicksFirstButton = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3, -- Avoids some UI taint issues
    }

    function AddonNS.CategoriesGUI:SelectCategoryById(categoryId)
        if not containerFrame:IsShown() then
            containerFrame:Show()
        end
        selectCategoryById(categoryId)
    end

    function AddonNS.CategoriesGUI:IsShown()
        return containerFrame:IsShown()
    end

    function AddonNS.CategoriesGUI:GetSelectedCategoryId()
        return getSelectedCategoryId()
    end
end

AddonNS.createGUI()
