local collapsedCalls = 0
local selectedCategoryId = nil
local categoriesConfigMode = false

_G.C_Container = {}
_G.hooksecurefunc = function() end
_G.GetTime = function() return 1 end
_G.GetCursorInfo = function() return nil end

local addonEnv = {
    container = {},
    Collapsed = {
        toggleCollapsed = function()
            collapsedCalls = collapsedCalls + 1
        end,
    },
    BagViewState = {
        IsCategoriesConfigMode = function()
            return categoriesConfigMode
        end,
    },
    CategoriesGUI = {
        SelectCategoryById = function(_, categoryId)
            selectedCategoryId = categoryId
        end,
    },
    printDebug = function() end,
    Const = {
        Events = {
            ITEM_MOVED = "ITEM_MOVED",
            CATEGORY_MOVED = "CATEGORY_MOVED",
            CATEGORY_MOVED_TO_COLUMN = "CATEGORY_MOVED_TO_COLUMN",
        },
    },
    Events = {
        TriggerCustomEvent = function() end,
    },
    QueueContainerUpdateItemLayout = function() end,
}

local dragAndDropChunk = assert(loadfile("dragndrop.lua"))
dragAndDropChunk("MyBags", addonEnv)

local function assertTrue(condition, message)
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

local function category(id)
    return {
        GetId = function()
            return id
        end,
    }
end

run("config mode custom category click selects and does not collapse", function()
    collapsedCalls = 0
    selectedCategoryId = nil
    categoriesConfigMode = true

    addonEnv.DragAndDrop.categoryOnMouseUp({ ItemCategory = category("cus-11") }, "LeftButton")

    assertTrue(collapsedCalls == 0, "collapse should not be triggered in config mode")
    assertTrue(selectedCategoryId == "cus-11", "custom category should be selected in config mode")
end)

run("config mode non-custom category click is a no-op", function()
    collapsedCalls = 0
    selectedCategoryId = nil
    categoriesConfigMode = true

    addonEnv.DragAndDrop.categoryOnMouseUp({ ItemCategory = category("unassigned") }, "LeftButton")

    assertTrue(collapsedCalls == 0, "non-custom category should not collapse in config mode")
    assertTrue(selectedCategoryId == nil, "non-custom category should not be selected in config mode")
end)

run("normal mode category click still toggles collapse", function()
    collapsedCalls = 0
    selectedCategoryId = nil
    categoriesConfigMode = false

    addonEnv.DragAndDrop.categoryOnMouseUp({ ItemCategory = category("cus-11") }, "LeftButton")

    assertTrue(collapsedCalls == 1, "collapse should be triggered in normal mode")
    assertTrue(selectedCategoryId == nil, "normal mode click should not select in config GUI")
end)
