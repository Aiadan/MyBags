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

local function profilingEnabled()
    return AddonNS.Profiling and AddonNS.Profiling.enabled
end

local function profileNowMs()
    return debugprofilestop()
end

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

local function addCategoryToColumn(categoryAssignmentsForColumn, category, items, profile)
    local startedAt = profile and profileNowMs() or nil
    local itemCount = #items
    local displayItems = items
    if isCollapsed(category) then
        displayItems = { AddonNS.itemButtonPlaceholder }
    end
    local sortStartedAt = profile and profileNowMs() or nil
    AddonNS.ItemsOrder:Sort(displayItems)
    if profile then
        profile.sortMs = profile.sortMs + (profileNowMs() - sortStartedAt)
    end
    table.insert(categoryAssignmentsForColumn, { category = category, items = displayItems, itemsCount = itemCount })
    if profile then
        profile.addCategoryCalls = profile.addCategoryCalls + 1
        profile.addCategoryMs = profile.addCategoryMs + (profileNowMs() - startedAt)
        profile.itemsTotal = profile.itemsTotal + itemCount
    end
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
    local profile = nil
    if profilingEnabled() then
        profile = {
            startedAt = profileNowMs(),
            constantsMs = 0,
            ensureConstantsMs = 0,
            layoutMatchMs = 0,
            unmatchedBuildMs = 0,
            unmatchedSortMs = 0,
            unmatchedInsertMs = 0,
            sortMs = 0,
            addCategoryMs = 0,
            addCategoryCalls = 0,
            itemsTotal = 0,
        }
    end

    ensureRuntimeColumns()
    local constantsStartedAt = profile and profileNowMs() or nil
    local constantCategories = AddonNS.Categories:GetConstantCategories()
    if profile then
        profile.constantsMs = profileNowMs() - constantsStartedAt
    end
    local ensureConstantsStartedAt = profile and profileNowMs() or nil
    for _, category in ipairs(constantCategories) do
        if not arrangedItems[category] then
            arrangedItems[category] = {}
        end
    end
    if profile then
        profile.ensureConstantsMs = profileNowMs() - ensureConstantsStartedAt
    end

    categoryAssignments = { {}, {}, {} }
    local known = {}

    local layoutMatchStartedAt = profile and profileNowMs() or nil
    for columnIndex = 1, NUM_COLUMNS do
        local assignmentsForColumn = categoryAssignments[columnIndex]
        local ids = runtimeColumns[columnIndex]
        for _, id in ipairs(ids) do
            local category = AddonNS.CategoryStore:Get(id)
            if category and arrangedItems[category] then
                addCategoryToColumn(assignmentsForColumn, category, arrangedItems[category], profile)
                known[category] = true
            end
        end
    end
    if profile then
        profile.layoutMatchMs = profileNowMs() - layoutMatchStartedAt
    end

    local unmatched = {}
    local unmatchedBuildStartedAt = profile and profileNowMs() or nil
    for category in pairs(arrangedItems) do
        if not known[category] then
            table.insert(unmatched, category)
        end
    end
    if profile then
        profile.unmatchedBuildMs = profileNowMs() - unmatchedBuildStartedAt
    end

    local unmatchedSortStartedAt = profile and profileNowMs() or nil
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
    if profile then
        profile.unmatchedSortMs = profileNowMs() - unmatchedSortStartedAt
    end

    local targetColumn = 1
    local unmatchedInsertStartedAt = profile and profileNowMs() or nil
    for _, category in ipairs(unmatched) do
        addCategoryToColumn(categoryAssignments[targetColumn], category, arrangedItems[category] or {}, profile)
        appendToLayout(targetColumn, category:GetId())
        targetColumn = targetColumn % NUM_COLUMNS + 1
    end
    if profile then
        profile.unmatchedInsertMs = profileNowMs() - unmatchedInsertStartedAt
        local totalMs = profileNowMs() - profile.startedAt
        AddonNS.printDebug(
            "PROFILE ArrangeCategoriesIntoColumns",
            string.format("constants=%.2fms", profile.constantsMs),
            string.format("ensureConstants=%.2fms", profile.ensureConstantsMs),
            string.format("layoutMatch=%.2fms", profile.layoutMatchMs),
            string.format("unmatchedBuild=%.2fms", profile.unmatchedBuildMs),
            string.format("unmatchedSort=%.2fms", profile.unmatchedSortMs),
            string.format("unmatchedInsert=%.2fms", profile.unmatchedInsertMs),
            string.format("sortOnly=%.2fms", profile.sortMs),
            string.format("addCategory=%.2fms", profile.addCategoryMs),
            "addCalls=" .. profile.addCategoryCalls,
            "items=" .. profile.itemsTotal,
            string.format("total=%.2fms", totalMs)
        )
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
    table.insert(targetColumnRef, targetRow, pickedCategoryId)
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
