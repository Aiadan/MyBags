local addonName, AddonNS = ...
local GS = LibStub("MyLibrary_GUI");

--- @type WowList
local WowList = LibStub("WowList-1.5");

function AddonNS.createGUI()
    local container = AddonNS.container;

    local containerFrame = GS:CreateButtonFrame(addonName, 360, 580, true);
    containerFrame:SetPoint("TOPRIGHT", container, "TOPLEFT", 0, -30);
    containerFrame:EnableMouse(true)
    containerFrame:Hide();

    local settingsButton = CreateFrame("Button", nil, container, "UIPanelIconDropdownButtonTemplate")
    settingsButton:SetSize(20, 20)
    settingsButton:SetPoint("TOPRIGHT", container, "TOPRIGHT", -9, -34)
    settingsButton:SetScript("OnClick", function(self, button)
        if containerFrame:IsShown() then containerFrame:Hide() else containerFrame:Show() end
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

    containerFrame.Inset:SetPoint("BOTTOMRIGHT", -6, 106)
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
    end

    containerFrame:SetScript("OnShow", function()
        list:RefreshList()
    end)

    -- new button
    local newButton = CreateFrame("Button", nil, containerFrame, "UIPanelButtonTemplate")
    newButton:SetPoint("TOPLEFT", containerFrame.Inset,
        "BOTTOMLEFT", 0, -6);

    newButton:SetSize(60, 20)
    newButton:SetText("New")

    newButton:SetScript("OnClick", function(self)
        StaticPopup_Show("CREATE_CATEGORY_CONFIRM");
    end)

    --- [[ save button]]
    local renameButton = CreateFrame("Button", nil, containerFrame, "UIPanelButtonTemplate")
    renameButton:SetPoint("TOPLEFT", newButton, "TOPRIGHT", 5, 0);

    renameButton:SetSize(60, 20)
    renameButton:SetText("Rename")

    renameButton:SetScript("OnClick", function(self, button)
        local category = getSelectedCategory()
        if not category then
            return
        end
        local dialog = StaticPopup_Show("RENAME_CATEGORY_CONFIRM", category:GetName() or "")
        if dialog then
            dialog.data = category.id
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
            dialog.data = category.id
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
    local queryLabel = containerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
    queryLabel:SetText("Query:");
    queryLabel:SetPoint("TOPLEFT", newButton, "BOTTOMLEFT", 4, -5);
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


    renameButton:Disable()
    deleteButton:Disable()
    alwaysShowCheckbox:Disable()
    saveQueryButton:Disable()
    list:RegisterCallback("SelectionChanged", function()
        local category = getSelectedCategory()
        if category then
            renameButton:Enable()
            alwaysShowCheckbox:Enable()
            alwaysShowCheckbox:SetChecked(AddonNS.CategorShowAlways:ShouldAlwaysShow(category))
            deleteButton:Enable()
            saveQueryButton:Enable()
            containerFrame.textScrollFrame.EditBox:SetText(AddonNS.CustomCategories:GetQuery(category))
        else
            alwaysShowCheckbox:SetChecked(false)
            alwaysShowCheckbox:Disable()
            renameButton:Disable()
            deleteButton:Disable()
            saveQueryButton:Disable()
            containerFrame.textScrollFrame.EditBox:SetText("")
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
                    list:SelectRowByPredicate(function(row)
                        return row.id == category.id
                    end)
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
                list:SelectRowByPredicate(function(row)
                    return row.id == data
                end)
            else
                AddonNS.printDebug("Please enter a category name.")
            end
        end,
        OnShow = function(self, data)
            local category = AddonNS.CategoryStore:Get(data)
            self:GetEditBox():SetText(category and category:GetName() or "")
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
            containerFrame.textScrollFrame.EditBox:SetText("")
        end,
        enterClicksFirstButton = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3, -- Avoids some UI taint issues
    }
end

AddonNS.createGUI()
