local addonEnv = {}

local baselineChunk = assert(loadfile("utils/searchCategoryBaseline.lua"))
baselineChunk("MyBags", addonEnv)

local function assertTrue(value, message)
    if not value then
        error(message or "assertion failed", 2)
    end
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
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

run("active search seeds category even for excluded item", function()
    local arrangedItems = {}
    local category = { id = "cat-a" }
    local item = { id = "item-a" }

    local inserted = addonEnv.SearchCategoryBaseline:Add(arrangedItems, category, item, false, true)
    assertTrue(inserted == false, "excluded item should not be inserted")
    assertTrue(arrangedItems[category] ~= nil, "category should be seeded under active search")
    assertEqual(#arrangedItems[category], 0, "seeded category should have filtered count 0")
end)

run("active search inserts matching item", function()
    local arrangedItems = {}
    local category = { id = "cat-a" }
    local item = { id = "item-a" }

    local inserted = addonEnv.SearchCategoryBaseline:Add(arrangedItems, category, item, true, true)
    assertTrue(inserted == true, "matching item should be inserted")
    assertEqual(#arrangedItems[category], 1, "category should contain matching item")
end)

run("non-search mode does not seed category for excluded item", function()
    local arrangedItems = {}
    local category = { id = "cat-a" }
    local item = { id = "item-a" }

    local inserted = addonEnv.SearchCategoryBaseline:Add(arrangedItems, category, item, false, false)
    assertTrue(inserted == false, "excluded item should not be inserted")
    assertTrue(arrangedItems[category] == nil, "category should not be seeded when search is inactive")
end)
