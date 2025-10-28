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

run("fresh install seeds defaults", function()
    local ctx = harness.new()
    local events = ctx:events()
    events:fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    assert_equal({}, snapshot.customCategories, "customCategories initialised")
    assert_equal({}, snapshot.collapsedCategories, "collapsedCategories initialised")
    assert_equal({}, snapshot.itemOrder, "itemOrder initialised")
    assert_equal({ {}, {}, {} }, snapshot.categoriesColumnAssignments, "column assignments seeded")
    assert_equal({}, snapshot.categoriesToAlwaysShow, "always show toggles initialised")
    assert_equal({}, snapshot.queryCategories, "query categories initialised")
end)

run("rename migrates all SavedVariable consumers", function()
    local ctx = harness.new({
        saved = {
            collapsedCategories = {},
            itemOrder = { 101, 102 },
            categoriesColumnAssignments = { { "old" }, {}, {} },
            customCategories = { old = { 101, 102 }, other = { 201 } },
            categoriesToAlwaysShow = { old = true },
            queryCategories = { old = "ilvl >= 450" },
        },
    })

    ctx.AddonNS.CustomCategories:RenameCategory("old", "new")
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    assert_equal({ { "new" }, {}, {} }, snapshot.categoriesColumnAssignments, "column rename propagated")
    assert_equal({ new = { 101, 102 }, other = { 201 } }, snapshot.customCategories, "custom categories renamed")
    assert_equal({ new = true }, snapshot.categoriesToAlwaysShow, "always show migrated")
    assert_equal({ new = "ilvl >= 450" }, snapshot.queryCategories, "queries migrated")
    assert_equal({ 101, 102 }, snapshot.itemOrder, "item order preserved")
end)

run("partial fixtures hydrate missing keys", function()
    local ctx = harness.new({ saved = { customCategories = { keep = { 9001 } } } })
    local snapshot = ctx:snapshot()

    assert_equal({ keep = { 9001 } }, snapshot.customCategories)
    assert_true(type(snapshot.collapsedCategories) == "table", "collapsedCategories table initialised")
    assert_true(type(snapshot.itemOrder) == "table", "itemOrder table initialised")
    assert_true(type(snapshot.categoriesColumnAssignments) == "table", "column assignments initialised")
    assert_true(type(snapshot.categoriesToAlwaysShow) == "table", "always show table initialised")
    assert_true(type(snapshot.queryCategories) == "table", "query categories table initialised")
end)

run("item move updates assignments and toggles", function()
    local ctx = harness.new({
        saved = {
            customCategories = { A = { 101 }, B = { 102 } },
            itemOrder = { 101, 102 },
            categoriesColumnAssignments = { {}, {}, {} },
            collapsedCategories = {},
            categoriesToAlwaysShow = {},
            queryCategories = {},
        },
    })

    local events = ctx:events()
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow("A", true)
    events:fire_custom(ctx.AddonNS.Const.Events.ITEM_MOVED, 101, 102, { name = "A" }, { name = "B" }, item_button(0, 1), item_button(0, 2))
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow("B", true)
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow("A", false)

    events:fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot_subset({ "customCategories", "itemOrder", "categoriesToAlwaysShow" })
    assert_equal({ A = {}, B = { 102, 101 } }, snapshot.customCategories, "category reassignment persisted")
    assert_equal({ 102, 101 }, snapshot.itemOrder, "item order updated")
    assert_equal({ B = true }, snapshot.categoriesToAlwaysShow, "toggle state persisted")
end)

run("invalid inputs clear stored data", function()
    local ctx = harness.new({
        saved = {
            customCategories = { Solo = { 555 } },
            queryCategories = { Solo = "isQuestItem = true" },
            categoriesToAlwaysShow = { Solo = true },
        },
    })

    ctx.AddonNS.CustomCategories:AssignToCategoryByName(nil, 555)
    ctx.AddonNS.QueryCategories:SetQuery("Solo", "")
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow("Solo", false)
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    assert_true(next(snapshot.customCategories.Solo or {}) == nil, "category cleared")
    assert_true(snapshot.queryCategories.Solo == nil, "query removed")
    assert_true(snapshot.categoriesToAlwaysShow.Solo == nil, "toggle removed")
end)

run("duplicate events stay idempotent", function()
    local ctx = harness.new({
        saved = {
            customCategories = { Alpha = {} },
            categoriesColumnAssignments = { { "Alpha" }, {}, {} },
            itemOrder = { 700, 800 },
        },
    })

    local alpha = { name = "Alpha" }
    local events = ctx:events()
    events:fire_custom(ctx.AddonNS.Const.Events.CATEGORY_MOVED, alpha, alpha)
    events:fire_custom(ctx.AddonNS.Const.Events.CATEGORY_MOVED, alpha, alpha)
    ctx.AddonNS.CustomCategories:AssignToCategoryByName("Alpha", 700)
    ctx.AddonNS.CustomCategories:AssignToCategoryByName("Alpha", 700)
    events:fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    assert_equal({ { "Alpha" }, {}, {} }, snapshot.categoriesColumnAssignments, "category layout unchanged")
    assert_equal({ Alpha = { 700 } }, snapshot.customCategories, "single item stored")
end)

run("protected and missing categories ignore mutations", function()
    local ctx = harness.new({ saved = { customCategories = {} } })

    ctx.AddonNS.CustomCategories:AssignToCategory({ name = "System", protected = true }, 42)
    ctx.AddonNS.CustomCategories:RenameCategory("ghost", "still-ghost")

    local snapshot = ctx:snapshot()
    assert_true(snapshot.customCategories.System == nil, "protected category ignored")
    assert_true(snapshot.customCategories["still-ghost"] == nil, "missing rename ignored")
end)

print("All integration scenarios completed.")
