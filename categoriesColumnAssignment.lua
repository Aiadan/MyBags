local addonName, AddonNS = ...

-- NOTE: This module intentionally keeps runtime column state as category IDs,
-- not category wrapper references.
-- Rationale:
-- 1) IDs are the persisted shape used by SavedVariables.
-- 2) IDs do not depend on wrapper lifecycle/refresh timing.
-- 3) This avoids hidden load-order coupling between wrapper readiness and layout logic.
-- Convert IDs to category objects only at the rendering/arrangement boundary.

AddonNS.Categories = AddonNS.Categories or {}

local NUM_COLUMNS = AddonNS.Const.NUM_COLUMNS
local isCollapsed = AddonNS.Collapsed.isCollapsed
local runtimeColumns = {}
local runtimeColumnsLoaded = false

local categoryAssignments

local function ensureRuntimeColumns()
    if runtimeColumnsLoaded then
        return
    end
    local persistedColumns = AddonNS.CategoryStore:GetLayoutColumns()
    runtimeColumns = {}
    for index = 1, NUM_COLUMNS do
        runtimeColumns[index] = {}
        for _, categoryId in ipairs(persistedColumns[index] or {}) do
            table.insert(runtimeColumns[index], categoryId)
        end
    end
    runtimeColumnsLoaded = true
end

local function persistRuntimeColumns()
    if not runtimeColumnsLoaded then
        return
    end
    local serialized = {}
    for index = 1, NUM_COLUMNS do
        serialized[index] = {}
        for _, categoryId in ipairs(runtimeColumns[index] or {}) do
            table.insert(serialized[index], categoryId)
        end
    end
    AddonNS.CategoryStore:SetLayoutColumns(serialized)
end

local function categoryId(input)
    if not input then
        return nil
    end
    if type(input) == "string" then
        return input
    end
    if type(input) == "table" then
        if input.GetId then
            return input:GetId()
        end
        if input.id then
            return input.id
        end
    end
    return nil
end

local function addCategoryToColumn(categoryAssignmentsForColumn, category, items)
    local itemCount = #items
    local displayItems = items
    if isCollapsed(category) then
        displayItems = { AddonNS.itemButtonPlaceholder }
    end
    AddonNS.ItemsOrder:Sort(displayItems)
    table.insert(categoryAssignmentsForColumn, { category = category, items = displayItems, itemsCount = itemCount })
end

function AddonNS.Categories:GetLastCategoryInColumn(columnNo)
    ensureRuntimeColumns()
    local column = categoryAssignments and categoryAssignments[columnNo]
    if not column or #column == 0 then
        return AddonNS.CategoryStore:GetUnassigned()
    end
    return column[#column].category
end

local function appendToLayout(columnIndex, categoryIdValue)
    ensureRuntimeColumns()
    local id = categoryId(categoryIdValue)
    if not id then
        return
    end
    local column = runtimeColumns[columnIndex]
    for _, existing in ipairs(column) do
        if existing == id then
            return
        end
    end
    table.insert(column, id)
end

function AddonNS.Categories:ArrangeCategoriesIntoColumns(arrangedItems)
    ensureRuntimeColumns()
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
        local ids = runtimeColumns[columnIndex]
        for _, id in ipairs(ids) do
            local category = AddonNS.CategoryStore:Get(id)
            if category and arrangedItems[category] then
                addCategoryToColumn(assignmentsForColumn, category, arrangedItems[category])
                known[category] = true
            end
        end
    end

    local unmatched = {}
    for category in pairs(arrangedItems) do
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
        appendToLayout(targetColumn, category:GetId())
        targetColumn = targetColumn % NUM_COLUMNS + 1
    end

    return categoryAssignments
end

local function findCategoryPosition(categoryIdValue)
    ensureRuntimeColumns()
    local id = categoryId(categoryIdValue)
    if not id then
        return nil
    end
    for columnIndex = 1, NUM_COLUMNS do
        local column = runtimeColumns[columnIndex]
        for rowIndex = 1, #column do
            if column[rowIndex] == id then
                return columnIndex, rowIndex, column
            end
        end
    end
    return nil
end

local function categoryMoved(eventName, pickedCategory, targetCategory)
    AddonNS.printDebug(eventName)
    local pickedCategoryId = categoryId(pickedCategory)
    local targetCategoryId = categoryId(targetCategory)
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
    local targetColumnRef = runtimeColumns[targetColumn]
    if pickedColumn and pickedColumn == targetColumn and pickedRow < targetRow then
        targetRow = targetRow - 1
    end
    table.insert(targetColumnRef, targetRow + 1, pickedCategoryId)
end

local function categoryMovedToColumn(eventName, pickedCategory, columnIndex)
    AddonNS.printDebug(eventName)
    local pickedCategoryId = categoryId(pickedCategory)
    if not pickedCategoryId or not columnIndex then
        return
    end
    ensureRuntimeColumns()
    local pickedColumn, pickedRow, pickedColumnRef = findCategoryPosition(pickedCategoryId)
    if pickedColumn and pickedColumnRef then
        table.remove(pickedColumnRef, pickedRow)
    end
    table.insert(runtimeColumns[columnIndex], pickedCategoryId)
end

local function categoryDeleted(eventName, category)
    AddonNS.printDebug(eventName)
    local categoryIdValue = categoryId(category)
    if not categoryIdValue then
        return
    end
    local columnIndex, rowIndex, column = findCategoryPosition(categoryIdValue)
    if columnIndex and column then
        table.remove(column, rowIndex)
    end
end

AddonNS.Events:OnInitialize(function()
    ensureRuntimeColumns()
end)

AddonNS.Events:RegisterEvent("PLAYER_LOGOUT", function()
    persistRuntimeColumns()
end)

AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CUSTOM_CATEGORY_DELETED, categoryDeleted)
AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CATEGORY_MOVED, categoryMoved)
AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN, categoryMovedToColumn)
