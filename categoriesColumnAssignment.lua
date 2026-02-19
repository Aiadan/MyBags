local addonName, AddonNS = ...

-- NOTE: This module intentionally keeps runtime column state as category IDs,
-- not category wrapper references.
-- Rationale:
-- 1) IDs are the persisted shape used by SavedVariables.
-- 2) IDs do not depend on wrapper lifecycle/refresh timing.
-- 3) This avoids hidden load-order coupling between wrapper readiness and layout logic.
-- Convert IDs to category objects only at the rendering/arrangement boundary.

AddonNS.Categories = AddonNS.Categories or {}

local isCollapsed = AddonNS.Collapsed.isCollapsed
local runtimeColumnsByScope = {}
local runtimeColumnsLoadedByScope = {}
local categoryAssignmentsByScope = {}

local function profilingEnabled()
    return AddonNS.Profiling and AddonNS.Profiling.enabled
end

local function profileNowMs()
    return debugprofilestop()
end

local function getLayoutScope(scope)
    if scope and scope ~= "" then
        return scope
    end
    if AddonNS.GetCurrentLayoutScope then
        return AddonNS.GetCurrentLayoutScope()
    end
    return "bag"
end

local function getNumColumns(scope)
    return AddonNS.CategoryStore:GetColumnCount(getLayoutScope(scope))
end

local function ensureRuntimeColumns(scope)
    local normalizedScope = getLayoutScope(scope)
    if runtimeColumnsLoadedByScope[normalizedScope] then
        return
    end
    local persistedColumns = AddonNS.CategoryStore:GetLayoutColumns(normalizedScope)
    local numColumns = getNumColumns(normalizedScope)
    runtimeColumnsByScope[normalizedScope] = {}
    for index = 1, numColumns do
        runtimeColumnsByScope[normalizedScope][index] = {}
        for _, categoryId in ipairs(persistedColumns[index] or {}) do
            table.insert(runtimeColumnsByScope[normalizedScope][index], categoryId)
        end
    end
    runtimeColumnsLoadedByScope[normalizedScope] = true
end

function AddonNS.Categories:ReloadRuntimeColumnsFromStore(scope)
    local normalizedScope = getLayoutScope(scope)
    runtimeColumnsByScope[normalizedScope] = nil
    runtimeColumnsLoadedByScope[normalizedScope] = false
    ensureRuntimeColumns(normalizedScope)
end

local function persistRuntimeColumns(scope)
    local normalizedScope = getLayoutScope(scope)
    if not runtimeColumnsLoadedByScope[normalizedScope] then
        return
    end
    local runtimeColumns = runtimeColumnsByScope[normalizedScope]
    local numColumns = getNumColumns(normalizedScope)
    local serialized = {}
    for index = 1, numColumns do
        serialized[index] = {}
        for _, categoryId in ipairs(runtimeColumns[index] or {}) do
            table.insert(serialized[index], categoryId)
        end
    end
    AddonNS.CategoryStore:SetLayoutColumns(serialized, normalizedScope)
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

local function addCategoryToColumn(categoryAssignmentsForColumn, category, items, profile, scope)
    local startedAt = profile and profileNowMs() or nil
    local itemCount = #items
    local displayItems = items
    if isCollapsed(category, scope) then
        displayItems = { AddonNS.itemButtonPlaceholder }
    end
    local sortStartedAt = profile and profileNowMs() or nil
    AddonNS.ItemsOrder:Sort(displayItems)
    if profile then
        profile.sortMs = profile.sortMs + (profileNowMs() - sortStartedAt)
    end
    table.insert(categoryAssignmentsForColumn, { category = category, items = displayItems, itemsCount = itemCount, scope = scope })
    if profile then
        profile.addCategoryCalls = profile.addCategoryCalls + 1
        profile.addCategoryMs = profile.addCategoryMs + (profileNowMs() - startedAt)
        profile.itemsTotal = profile.itemsTotal + itemCount
    end
end

function AddonNS.Categories:GetLastCategoryInColumn(columnNo, scope)
    local normalizedScope = getLayoutScope(scope)
    ensureRuntimeColumns(normalizedScope)
    local categoryAssignments = categoryAssignmentsByScope[normalizedScope]
    local column = categoryAssignments and categoryAssignments[columnNo]
    if not column or #column == 0 then
        return AddonNS.CategoryStore:GetUnassigned()
    end
    return column[#column].category
end

local function appendToLayout(columnIndex, categoryIdValue, scope)
    local normalizedScope = getLayoutScope(scope)
    ensureRuntimeColumns(normalizedScope)
    local id = categoryId(categoryIdValue)
    if not id then
        return
    end
    local runtimeColumns = runtimeColumnsByScope[normalizedScope]
    local column = runtimeColumns[columnIndex]
    for _, existing in ipairs(column) do
        if existing == id then
            return
        end
    end
    table.insert(column, id)
end

local function isLayoutEmpty(scope)
    local normalizedScope = getLayoutScope(scope)
    ensureRuntimeColumns(normalizedScope)
    local runtimeColumns = runtimeColumnsByScope[normalizedScope]
    local numColumns = getNumColumns(normalizedScope)
    for columnIndex = 1, numColumns do
        if #(runtimeColumns[columnIndex] or {}) > 0 then
            return false
        end
    end
    return true
end

function AddonNS.Categories:ArrangeCategoriesIntoColumns(arrangedItems, scope)
    local normalizedScope = getLayoutScope(scope)
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

    ensureRuntimeColumns(normalizedScope)
    local runtimeColumns = runtimeColumnsByScope[normalizedScope]
    local constantsStartedAt = profile and profileNowMs() or nil
    local constantCategories = AddonNS.Categories:GetConstantCategories(normalizedScope)
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

    local numColumns = getNumColumns(normalizedScope)
    local categoryAssignments = {}
    for index = 1, numColumns do
        categoryAssignments[index] = {}
    end
    local known = {}

    local layoutMatchStartedAt = profile and profileNowMs() or nil
    for columnIndex = 1, numColumns do
        local assignmentsForColumn = categoryAssignments[columnIndex]
        local ids = runtimeColumns[columnIndex]
        for _, id in ipairs(ids) do
            local category = AddonNS.CategoryStore:Get(id)
            if category and arrangedItems[category] then
                addCategoryToColumn(assignmentsForColumn, category, arrangedItems[category], profile, normalizedScope)
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
        addCategoryToColumn(categoryAssignments[targetColumn], category, arrangedItems[category] or {}, profile, normalizedScope)
        appendToLayout(targetColumn, category:GetId(), normalizedScope)
        targetColumn = targetColumn % numColumns + 1
    end
    if profile then
        profile.unmatchedInsertMs = profileNowMs() - unmatchedInsertStartedAt
        local totalMs = profileNowMs() - profile.startedAt
        AddonNS.printDebug(
            "PROFILE ArrangeCategoriesIntoColumns",
            "scope=" .. normalizedScope,
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

    categoryAssignmentsByScope[normalizedScope] = categoryAssignments
    return categoryAssignments
end

local function findCategoryPosition(categoryIdValue, scope)
    local normalizedScope = getLayoutScope(scope)
    ensureRuntimeColumns(normalizedScope)
    local runtimeColumns = runtimeColumnsByScope[normalizedScope]
    local id = categoryId(categoryIdValue)
    if not id then
        return nil
    end
    local numColumns = getNumColumns(normalizedScope)
    for columnIndex = 1, numColumns do
        local column = runtimeColumns[columnIndex]
        for rowIndex = 1, #column do
            if column[rowIndex] == id then
                return columnIndex, rowIndex, column
            end
        end
    end
    return nil
end

local function categoryMoved(eventName, pickedCategory, targetCategory, moveTail, scope)
    AddonNS.printDebug(eventName)
    local normalizedScope = getLayoutScope(scope)
    local pickedCategoryId = categoryId(pickedCategory)
    local targetCategoryId = categoryId(targetCategory)
    if not pickedCategoryId or not targetCategoryId or pickedCategoryId == targetCategoryId then
        return
    end
    local pickedColumn, pickedRow, pickedColumnRef = findCategoryPosition(pickedCategoryId, normalizedScope)
    local targetColumn, targetRow = findCategoryPosition(targetCategoryId, normalizedScope)
    if not targetColumn then
        return
    end

    if moveTail and pickedColumn and (pickedColumn == targetColumn) and (targetRow >= pickedRow) then
        return
    end

    local movedCategoryIds = {}
    if pickedColumn then
        if moveTail then
            for rowIndex = pickedRow, #pickedColumnRef do
                table.insert(movedCategoryIds, pickedColumnRef[rowIndex])
            end
            for rowIndex = #pickedColumnRef, pickedRow, -1 do
                table.remove(pickedColumnRef, rowIndex)
            end
        else
            table.remove(pickedColumnRef, pickedRow)
            table.insert(movedCategoryIds, pickedCategoryId)
        end
    else
        table.insert(movedCategoryIds, pickedCategoryId)
    end

    local targetColumnRef = runtimeColumnsByScope[normalizedScope][targetColumn]
    for offset, id in ipairs(movedCategoryIds) do
        table.insert(targetColumnRef, targetRow + offset - 1, id)
    end
end

local function categoryMovedToColumn(eventName, pickedCategory, columnIndex, moveTail, scope)
    AddonNS.printDebug(eventName)
    local normalizedScope = getLayoutScope(scope)
    local pickedCategoryId = categoryId(pickedCategory)
    if not pickedCategoryId or not columnIndex then
        return
    end
    ensureRuntimeColumns(normalizedScope)
    local runtimeColumns = runtimeColumnsByScope[normalizedScope]
    local pickedColumn, pickedRow, pickedColumnRef = findCategoryPosition(pickedCategoryId, normalizedScope)
    local movedCategoryIds = {}
    if pickedColumn and pickedColumnRef then
        if moveTail then
            for rowIndex = pickedRow, #pickedColumnRef do
                table.insert(movedCategoryIds, pickedColumnRef[rowIndex])
            end
            for rowIndex = #pickedColumnRef, pickedRow, -1 do
                table.remove(pickedColumnRef, rowIndex)
            end
        else
            table.remove(pickedColumnRef, pickedRow)
            table.insert(movedCategoryIds, pickedCategoryId)
        end
    else
        table.insert(movedCategoryIds, pickedCategoryId)
    end
    for _, id in ipairs(movedCategoryIds) do
        table.insert(runtimeColumns[columnIndex], id)
    end
end

local function categoryDeleted(eventName, category, scope)
    AddonNS.printDebug(eventName)
    local normalizedScope = getLayoutScope(scope)
    local categoryIdValue = categoryId(category)
    if not categoryIdValue then
        return
    end
    local columnIndex, rowIndex, column = findCategoryPosition(categoryIdValue, normalizedScope)
    if columnIndex and column then
        table.remove(column, rowIndex)
    end
end

local function customCategoryCreated(eventName, category, scope)
    AddonNS.printDebug(eventName)
    local normalizedScope = getLayoutScope(scope)
    if isLayoutEmpty(normalizedScope) then
        return
    end
    local lastColumnIndex = getNumColumns(normalizedScope)
    appendToLayout(lastColumnIndex, category, normalizedScope)
end

function AddonNS.Categories:SetColumnCount(columnCount, scope)
    local normalizedScope = getLayoutScope(scope)
    ensureRuntimeColumns(normalizedScope)
    local runtimeColumns = runtimeColumnsByScope[normalizedScope]
    local previousCount = getNumColumns(normalizedScope)
    AddonNS.CategoryStore:SetColumnCount(columnCount, normalizedScope)
    local currentCount = getNumColumns(normalizedScope)
    if currentCount == previousCount then
        return
    end
    if currentCount > previousCount then
        for columnIndex = previousCount + 1, currentCount do
            runtimeColumns[columnIndex] = {}
        end
    else
        local lastVisible = runtimeColumns[currentCount]
        for columnIndex = currentCount + 1, previousCount do
            for _, id in ipairs(runtimeColumns[columnIndex] or {}) do
                table.insert(lastVisible, id)
            end
            runtimeColumns[columnIndex] = nil
        end
    end
    persistRuntimeColumns(normalizedScope)
end

AddonNS.Events:OnInitialize(function()
    ensureRuntimeColumns("bag")
end)

AddonNS.Events:RegisterEvent("PLAYER_LOGOUT", function()
    for scope in pairs(runtimeColumnsLoadedByScope) do
        persistRuntimeColumns(scope)
    end
end)

AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CUSTOM_CATEGORY_DELETED, categoryDeleted)
AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CUSTOM_CATEGORY_CREATED, customCategoryCreated)
AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CATEGORY_MOVED, categoryMoved)
AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN, categoryMovedToColumn)
