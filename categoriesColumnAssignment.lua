local addonName, AddonNS = ...

local NUM_COLUMNS = AddonNS.Const.NUM_COLUMNS;
local isCollapsed = AddonNS.Collapsed.isCollapsed;
local layoutColumns = AddonNS.CategoryStore:GetLayoutColumns();

local categoryAssignments;

local function ensureColumns()
    layoutColumns = AddonNS.CategoryStore:GetLayoutColumns();
    for index = 1, NUM_COLUMNS do
        layoutColumns[index] = layoutColumns[index] or {}
    end
end

local function resolveCategoryId(input)
    if not input then
        return nil
    end
    local inputType = type(input)
    if inputType == "string" then
        return input
    end
    if inputType == "table" then
        if input.id then
            return input.id
        end
        if input.name then
            local category = AddonNS.Categories:GetCategoryByName(input.name)
            return category and category.id or nil
        end
    end
    return nil
end

local function addCategoryToColumn(categoryAssignmentsForColumn, category, items)
    local itemCount = #items;
    local displayItems = items;
    if isCollapsed(category) then
        displayItems = { AddonNS.itemButtonPlaceholder }
    end
    AddonNS.ItemsOrder:Sort(displayItems);
    table.insert(categoryAssignmentsForColumn, { category = category, items = displayItems, itemsCount = itemCount });
end

function AddonNS.Categories:GetLastCategoryInColumn(columnNo)
    ensureColumns()
    local column = categoryAssignments and categoryAssignments[columnNo]
    if not column or #column == 0 then
        return AddonNS.CategoryStore:GetUnassigned()
    end
    return column[#column].category
end

local function appendToLayout(columnIndex, categoryId)
    ensureColumns()
    local column = layoutColumns[columnIndex]
    for _, id in ipairs(column) do
        if id == categoryId then
            return
        end
    end
    table.insert(column, categoryId)
end

function AddonNS.Categories:ArrangeCategoriesIntoColumns(arrangedItems)
    ensureColumns()
    local constantCategories = AddonNS.Categories:GetConstantCategories()
    for _, category in ipairs(constantCategories) do
        if not arrangedItems[category] then
            arrangedItems[category] = { AddonNS.itemButtonPlaceholder }
        end
    end

    categoryAssignments = { {}, {}, {} }
    local known = {}

    for columnIndex = 1, NUM_COLUMNS do
        local assignmentsForColumn = categoryAssignments[columnIndex]
        local ids = layoutColumns[columnIndex]
        for _, categoryId in ipairs(ids) do
            local category = AddonNS.CategoryStore:Get(categoryId)
            if category and arrangedItems[category] then
                addCategoryToColumn(assignmentsForColumn, category, arrangedItems[category])
                known[category] = true
            end
        end
    end

    local unmatched = {}
    for category, items in pairs(arrangedItems) do
        if not known[category] then
            table.insert(unmatched, category)
        end
    end
    table.sort(unmatched, function(left, right)
        local leftName = left:GetName()
        local rightName = right:GetName()
        if leftName == nil then
            return false
        end
        if rightName == nil then
            return true
        end
        return leftName < rightName
    end)

    local targetColumn = 1
    for _, category in ipairs(unmatched) do
        addCategoryToColumn(categoryAssignments[targetColumn], category, arrangedItems[category] or {})
        appendToLayout(targetColumn, category.id)
        targetColumn = targetColumn % NUM_COLUMNS + 1
    end

    return categoryAssignments
end

local function findCategoryPosition(categoryId)
    ensureColumns()
    for columnIndex = 1, NUM_COLUMNS do
        local column = layoutColumns[columnIndex]
        for rowIndex = 1, #column do
            if column[rowIndex] == categoryId then
                return columnIndex, rowIndex, column
            end
        end
    end
    return nil
end

local function categoryMoved(eventName, pickedCategory, targetCategory)
    AddonNS.printDebug(eventName)
    local pickedCategoryId = resolveCategoryId(pickedCategory)
    local targetCategoryId = resolveCategoryId(targetCategory)
    if not pickedCategoryId or not targetCategoryId or pickedCategoryId == targetCategoryId then
        return
    end
    local pickedColumn, pickedRow, pickedColumnRef = findCategoryPosition(pickedCategoryId)
    local targetColumn, targetRow = findCategoryPosition(targetCategoryId)
    if not targetColumn then
        return
    end
    if pickedColumn then
        table.remove(pickedColumnRef, pickedRow)
    end
    local targetColumnRef = layoutColumns[targetColumn]
    local placeAbove = 0
    if pickedColumn and pickedColumn == targetColumn and pickedRow < targetRow then
        placeAbove = 1
    end
    table.insert(targetColumnRef, targetRow + placeAbove, pickedCategoryId)
end

local function categoryMovedToColumn(eventName, pickedCategory, columnIndex)
    AddonNS.printDebug(eventName)
    local pickedCategoryId = resolveCategoryId(pickedCategory)
    if not pickedCategoryId or not columnIndex then
        return
    end
    ensureColumns()
    local pickedColumn, pickedRow, pickedColumnRef = findCategoryPosition(pickedCategoryId)
    if pickedColumn and pickedColumnRef then
        table.remove(pickedColumnRef, pickedRow)
    end
    table.insert(layoutColumns[columnIndex], pickedCategoryId)
end

local function categoryDeleted(eventName, category)
    AddonNS.printDebug(eventName)
    local categoryId = resolveCategoryId(category)
    if not categoryId then
        return
    end
    local columnIndex, rowIndex, column = findCategoryPosition(categoryId)
    if columnIndex and column then
        table.remove(column, rowIndex)
    end
end

AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CUSTOM_CATEGORY_DELETED, categoryDeleted)
AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CATEGORY_MOVED, categoryMoved)
AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN, categoryMovedToColumn)
