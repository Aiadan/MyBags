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

local function custom_snapshot(snapshot)
    return snapshot.userCategories or {}
end

local function raw_by_name(snapshot, name)
    local custom = custom_snapshot(snapshot)
    for rawId, data in pairs(custom.categories or {}) do
        if data.name == name then
            return rawId, data
        end
    end
    return nil
end

local function layout_columns(snapshot)
    local columns = {}
    local layout = snapshot.layout or {}
    for index, column in ipairs(layout.columns or {}) do
        columns[index] = {}
        for _, id in ipairs(column) do
            table.insert(columns[index], id)
        end
    end
    return columns
end

run("fresh install seeds defaults", function()
    local ctx = harness.new()
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    assert_true(custom.id == "cus", "custom bucket seeded")
    assert_true(custom.schemaVersion == 1, "custom schema version seeded")
    assert_equal({}, custom.categories, "no user categories persisted")
    assert_equal({ {}, {}, {} }, snapshot.layout.columns, "layout columns seeded")
    assert_equal({}, snapshot.layout.collapsed, "collapsed state empty")
    assert_equal({}, snapshot.itemOrder, "item order initialised")
    assert_true(snapshot.categorizers == nil or snapshot.categorizers.cus == nil, "legacy custom bucket removed")
    assert_true(snapshot.categories == nil, "old custom categories bucket removed")
end)

run("custom categories persist with namespaced layout", function()
    local ctx = harness.new()
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")
    ctx.AddonNS.CustomCategories:AssignToCategory(catA, 101)
    ctx.AddonNS.CustomCategories:AssignToCategory(catB, 102)
    ctx.AddonNS.QueryCategories:SetQuery(catA, "ilvl >= 400")
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow(catB, true)
    table.insert(ctx.AddonNS.CategoryStore:GetLayoutColumns()[1], catA:GetId())
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    assert_true(custom.id == "cus", "custom categorizer id stored")
    local aId, aData = raw_by_name(snapshot, "A")
    local bId, bData = raw_by_name(snapshot, "B")
    assert_true(aId ~= nil and bId ~= nil, "categories persisted")
    assert_equal({ 101 }, aData.items, "A stores assignment")
    assert_equal({ 102 }, bData.items, "B stores assignment")
    assert_true(aData.query == "ilvl >= 400", "query persisted for A")
    assert_true(bData.alwaysVisible == true, "always visible persisted for B")
    assert_equal({ { catA:GetId() }, {}, {} }, layout_columns(snapshot), "layout uses namespaced ids")
    assert_true(snapshot.categorizers == nil or snapshot.categorizers.cus == nil, "old custom bucket not persisted")
    assert_true(snapshot.categories == nil, "legacy categories not persisted")
end)

run("item move reassigns through hooks and respects protected target", function()
    local ctx = harness.new()
    local catA = ctx.AddonNS.CustomCategories:NewCategory("A")
    local catB = ctx.AddonNS.CustomCategories:NewCategory("B")
    ctx.AddonNS.CustomCategories:AssignToCategory(catA, 101)
    ctx.AddonNS.CustomCategories:AssignToCategory(catB, 102)
    ctx.AddonNS.db.itemOrder[1] = 101
    ctx.AddonNS.db.itemOrder[2] = 102

    ctx:events():fire_custom(ctx.AddonNS.Const.Events.ITEM_MOVED, 101, 102, catA, catB, item_button(0, 1), item_button(0, 2))
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    local aData = custom.categories[catA:GetId():match("^[^%-]+%-(.+)$")]
    local bData = custom.categories[catB:GetId():match("^[^%-]+%-(.+)$")]
    assert_equal({}, aData.items, "source cleared after move")
    assert_equal({ 102, 101 }, bData.items, "target has both items after move")

    -- Protected target should block move.
    local ctx2 = harness.new()
    local prot = ctx2.AddonNS.CustomCategories:NewCategory("Prot", { protected = true })
    local src = ctx2.AddonNS.CustomCategories:NewCategory("Src")
    ctx2.AddonNS.CustomCategories:AssignToCategory(src, 201)
    ctx2.AddonNS.db.itemOrder[1] = 201
    ctx2:events():fire_custom(ctx2.AddonNS.Const.Events.ITEM_MOVED, 201, nil, src, prot, item_button(0, 1), nil)
    ctx2:events():fire_game("PLAYER_LOGOUT")
    local snap2 = ctx2:snapshot()
    local custom2 = custom_snapshot(snap2)
    local srcData = custom2.categories[src:GetId():match("^[^%-]+%-(.+)$")]
    local protData = custom2.categories[prot:GetId():match("^[^%-]+%-(.+)$")]
    assert_equal({ 201 }, srcData.items, "protected target prevents reassignment")
    assert_equal({}, protData.items, "protected target stays empty")
end)

run("clearing inputs removes stored data", function()
    local ctx = harness.new()
    local category = ctx.AddonNS.CustomCategories:NewCategory("Solo")
    ctx.AddonNS.CustomCategories:AssignToCategory(category, 555)
    ctx.AddonNS.QueryCategories:SetQuery(category, "isQuestItem = true")
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow(category, true)

    ctx.AddonNS.CustomCategories:AssignToCategory(nil, 555)
    ctx.AddonNS.QueryCategories:SetQuery(category, "")
    ctx.AddonNS.CategorShowAlways:SetAlwaysShow(category, false)
    ctx:events():fire_game("PLAYER_LOGOUT")

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    local rawId = category:GetId():match("^[^%-]+%-(.+)$")
    local entry = custom.categories[rawId]
    assert_true(#(entry.items or {}) == 0, "manual assignments cleared")
    assert_true(entry.query == nil, "query cleared")
    assert_true(entry.alwaysVisible == nil, "always visible flag cleared")
end)

run("custom category query updates compiled cache via direct API", function()
    local ctx = harness.new()
    local category = ctx.AddonNS.CustomCategories:NewCategory("Compiled")

    ctx.AddonNS.CustomCategories:SetQuery(category, "ilvl >= 400")
    local compiled = ctx.AddonNS.QueryCategories:GetCompiled(category)
    assert_true(type(compiled) == "function", "compiled query exists after direct set")
    assert_true(compiled({ ilvl = 420 }) == true, "compiled query matches satisfying payload")
    assert_true(compiled({ ilvl = 399 }) == false, "compiled query rejects non-satisfying payload")

    ctx.AddonNS.CustomCategories:SetQuery(category, "")
    assert_true(ctx.AddonNS.QueryCategories:GetCompiled(category) == nil, "compiled query removed after clearing")
end)

run("migrates from db.categorizers.cus to userCategories", function()
    local ctx = harness.new({
        saved = {
            categorizers = {
                cus = {
                    id = "cus",
                    name = "Custom",
                    nextId = 7,
                    categories = {
                        ["5"] = {
                            name = "MigratedA",
                            items = { 111 },
                            query = "ilvl >= 400",
                            alwaysVisible = true,
                        },
                    },
                },
            },
            layout = {
                columns = { { "cus-5" }, {}, {} },
                collapsed = { ["cus-5"] = true },
            },
            itemOrder = { 111 },
        },
    })

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    assert_true(custom.nextId == 7, "nextId migrated from categorizers.cus")
    assert_true(custom.categories["5"].name == "MigratedA", "category migrated from categorizers.cus")
    assert_equal({ 111 }, custom.categories["5"].items, "items migrated from categorizers.cus")
    assert_true(snapshot.categorizers == nil or snapshot.categorizers.cus == nil, "source custom bucket removed")
end)

run("migrates from old db.categories and converts cat layout ids", function()
    local ctx = harness.new({
        saved = {
            categories = {
                ["cat-9"] = {
                    id = "cat-9",
                    name = "LegacyCat",
                    items = { 909 },
                    query = "itemType = 3",
                    alwaysVisible = true,
                },
            },
            layout = {
                columns = { { "cat-9" }, {}, {} },
                collapsed = { ["cat-9"] = true },
            },
        },
    })

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    assert_true(custom.categories["9"].name == "LegacyCat", "old db.categories migrated")
    assert_equal({ 909 }, custom.categories["9"].items, "old db.items migrated")
    assert_equal({ { "cus-9" }, {}, {} }, layout_columns(snapshot), "cat- layout ids converted to cus-")
    assert_true(snapshot.layout.collapsed["cus-9"] == true, "collapsed cat- id converted to cus-")
    assert_true(snapshot.categories == nil, "old categories source removed")
end)

run("migrates from legacy global and maps layout names", function()
    local ctx = harness.new({
        legacy = {
            customCategories = {
                LegacyOne = { 1001, 1002 },
            },
            queryCategories = {
                LegacyOne = "ilvl >= 200",
            },
            categoriesToAlwaysShow = {
                LegacyOne = true,
            },
            categoriesColumnAssignments = {
                { "LegacyOne" },
                {},
                {},
            },
            collapsedCategories = {
                LegacyOne = true,
            },
            itemOrder = { 1001, 1002 },
        },
    })

    local snapshot = ctx:snapshot()
    local custom = custom_snapshot(snapshot)
    local rawId, data = raw_by_name(snapshot, "LegacyOne")
    assert_true(rawId ~= nil, "legacy global category migrated")
    assert_equal({ 1001, 1002 }, data.items, "legacy global items migrated")
    assert_true(data.query == "ilvl >= 200", "legacy global query migrated")
    assert_true(data.alwaysVisible == true, "legacy global always visible migrated")
    assert_equal({ { "cus-" .. rawId }, {}, {} }, layout_columns(snapshot), "legacy layout names converted to cus ids")
    assert_true(snapshot.layout.collapsed["cus-" .. rawId] == true, "legacy collapsed names converted to cus ids")
    assert_equal({ 1001, 1002 }, snapshot.itemOrder, "legacy item order migrated")
end)

print("All integration scenarios completed.")
