package.path = package.path .. ";./?.lua;./?/init.lua"

local harness = require("tests.integration.persistence.harness")

local function deep_equal(a, b, seen)
    if a == b then
        return true
    end
    local typeA, typeB = type(a), type(b)
    if typeA ~= typeB then
        return false, string.format("Type mismatch: %s vs %s", typeA, typeB)
    end
    if typeA ~= "table" then
        return false, string.format("Value mismatch: %s vs %s", tostring(a), tostring(b))
    end
    seen = seen or {}
    if seen[a] and seen[a][b] then
        return true
    end
    seen[a] = seen[a] or {}
    seen[a][b] = true
    local visited = {}
    for k, v in pairs(a) do
        local ok, err = deep_equal(v, b[k], seen)
        if not ok then
            return false, string.format("Key %s: %s", tostring(k), err or "mismatch")
        end
        visited[k] = true
    end
    for k in pairs(b) do
        if not visited[k] then
            return false, string.format("Unexpected key in second table: %s", tostring(k))
        end
    end
    return true
end

local function assert_equal(expected, actual, message)
    local ok, err = deep_equal(expected, actual)
    if not ok then
        error((message or "tables differ") .. ": " .. err, 2)
    end
end

local function assert_true(condition, message)
    if not condition then
        error(message or "assertion failed", 2)
    end
end

local function run(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if ok then
        print("✓ " .. name)
    else
        print("✗ " .. name)
        error(err)
    end
end

local function item_button(bag, slot)
    return {
        GetBagID = function() return bag end,
        GetID = function() return slot end,
    }
end

local function category_by_name(snapshot, name)
    for id, data in pairs(snapshot.categories or {}) do
        if data.name == name then
            return id, data
        end
    end
    return nil
end

local function column_names(snapshot)
    local columns = {}
    local layout = snapshot.layout or {}
    for index, column in ipairs(layout.columns or {}) do
        local names = {}
        for _, categoryId in ipairs(column) do
            local category = snapshot.categories and snapshot.categories[categoryId]
            table.insert(names, category and category.name or categoryId)
        end
        columns[index] = names
    end
    return columns
end

run("fresh install seeds defaults", function()
    local ctx = harness.new()
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    assert_true(snapshot.version == 2, "schema version set to 2")
    assert_true(snapshot.sequences.category == 0, "category sequence initialised")
    assert_equal({}, snapshot.categories, "no user categories persisted")
    assert_equal({ {}, {}, {} }, snapshot.layout.columns, "layout columns seeded")
    assert_equal({}, snapshot.layout.collapsed, "collapsed state empty")
    assert_equal({}, snapshot.itemOrder, "item order initialised")
end)

run("legacy data migrates into ID schema", function()
    local ctx = harness.new({
        legacy = {
            customCategories = { old = { 101, 102 }, other = { 201 } },
            categoriesColumnAssignments = { { "old" }, {}, {} },
            categoriesToAlwaysShow = { old = true },
            queryCategories = { old = "ilvl >= 450" },
            itemOrder = { 101, 102 },
        },
    })
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    local oldId, oldCategory = category_by_name(snapshot, "old")
    local otherId, otherCategory = category_by_name(snapshot, "other")
    assert_true(oldId ~= nil, "legacy category 'old' migrated")
    assert_true(otherId ~= nil, "legacy category 'other' migrated")
    assert_equal({ 101, 102 }, oldCategory.items, "items preserved for old")
    assert_equal({ 201 }, otherCategory.items, "items preserved for other")
    assert_true(oldCategory.alwaysVisible == true, "alwaysVisible migrated")
    assert_true(oldCategory.query == "ilvl >= 450", "query migrated")
    assert_equal({ { "old" }, {}, {} }, column_names(snapshot), "layout references migrated category")
    assert_equal({ 101, 102 }, snapshot.itemOrder, "item order preserved")
    assert_true(snapshot.sequences.category >= 2, "category sequence advanced")
end)

run("rename updates persisted layout and metadata", function()
    local ctx = harness.new({
        legacy = {
            customCategories = { old = { 1 } },
            categoriesColumnAssignments = { { "old" }, {}, {} },
        },
    })
    local category = ctx.AddonNS.CategoryStore:GetByName("old")
    ctx.AddonNS.CustomCategories:RenameCategory(category, "new")
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    local newId, newCategory = category_by_name(snapshot, "new")
    assert_true(newId ~= nil, "category renamed")
    assert_equal({ { "new" }, {}, {} }, column_names(snapshot), "layout uses updated name")
    assert_equal({ 1 }, newCategory.items, "items preserved after rename")
end)

run("item move updates assignments and always show state", function()
    local ctx = harness.new()
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")
    ctx.AddonNS.CustomCategories:AssignToCategory(catA, 101)
    ctx.AddonNS.CustomCategories:AssignToCategory(catB, 102)
    ctx.AddonNS.db.itemOrder[1] = 101
    ctx.AddonNS.db.itemOrder[2] = 102

    local events = ctx:events()
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow(catA, true)
    events:fire_custom(ctx.AddonNS.Const.Events.ITEM_MOVED, 101, 102, catA.id, catB.id, item_button(0, 1), item_button(0, 2))
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow(catB, true)
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow(catA, false)
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    assert_equal({}, snapshot.categories[catA.id].items, "source category cleared")
    assert_equal({ 102, 101 }, snapshot.categories[catB.id].items, "target category stores both items")
    assert_true(snapshot.categories[catB.id].alwaysVisible == true, "always visible toggled on for B")
    assert_true(snapshot.categories[catA.id].alwaysVisible == nil, "always visible cleared for A")
    assert_equal({ 102, 101 }, snapshot.itemOrder, "item order updated after move")
end)

run("clearing inputs removes stored data", function()
    local ctx = harness.new()
    local category = ctx.AddonNS.CustomCategories:NewCategory("Solo")
    ctx.AddonNS.CustomCategories:AssignToCategory(category, 555)
    ctx.AddonNS.QueryCategories:SetQuery(category.id, "isQuestItem = true")
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow(category.id, true)

    ctx.AddonNS.CustomCategories:AssignToCategory(nil, 555)
    ctx.AddonNS.QueryCategories:SetQuery(category.id, "")
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow(category.id, false)
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    assert_true(#(snapshot.categories[category.id].items) == 0, "manual assignments cleared")
    assert_true(snapshot.categories[category.id].query == nil, "query cleared")
    assert_true(snapshot.categories[category.id].alwaysVisible == nil, "always visible flag cleared")
end)

run("duplicate layout events stay idempotent", function()
    local ctx = harness.new()
    local alpha = ctx.AddonNS.CustomCategories:NewCategory("Alpha")
    table.insert(ctx.AddonNS.CategoryStore:GetLayoutColumns()[1], alpha.id)
    ctx.AddonNS.db.itemOrder = { 700, 800 }

    local events = ctx:events()
    events:fire_custom(ctx.AddonNS.Const.Events.CATEGORY_MOVED, alpha.id, alpha.id)
    events:fire_custom(ctx.AddonNS.Const.Events.CATEGORY_MOVED, alpha.id, alpha.id)
    ctx.AddonNS.CustomCategories:AssignToCategory(alpha.id, 700)
    ctx.AddonNS.CustomCategories:AssignToCategory(alpha.id, 700)
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    assert_equal({ { "Alpha" }, {}, {} }, column_names(snapshot), "category layout unchanged")
    assert_equal({ 700 }, snapshot.categories[alpha.id].items, "single item stored")
end)

run("protected and missing categories ignore mutations", function()
    local ctx = harness.new()
    local protectedCategory = ctx.AddonNS.CategoryStore:RecordDynamicCategory({
        id = "sys:protected",
        name = "System",
        protected = true,
    })

    ctx.AddonNS.CustomCategories:AssignToCategory(protectedCategory, 42)
    ctx.AddonNS.CustomCategories:RenameCategory("ghost", "still-ghost")
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    for _, data in pairs(snapshot.categories) do
        assert_true(not data.items or not table.concat(data.items, ","):find("42", 1, true), "protected assignment ignored")
    end
    assert_true(category_by_name(snapshot, "still-ghost") == nil, "missing rename ignored")
end)

print("All integration scenarios completed.")
