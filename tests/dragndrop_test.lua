local collapsedCalls = 0
local selectedCategoryId = nil
local categoriesConfigMode = false
local configModeClickCalls = 0

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

local function category(id, opts)
    local value = {
        GetId = function()
            return id
        end,
        OnLeftClickConfigMode = function()
            if opts and opts.configModeHandler then
                configModeClickCalls = configModeClickCalls + 1
                selectedCategoryId = id
            end
        end,
    }
    return value
end

run("config mode custom category click selects and does not collapse", function()
    collapsedCalls = 0
    selectedCategoryId = nil
    configModeClickCalls = 0
    categoriesConfigMode = true

    addonEnv.DragAndDrop.categoryOnMouseUp({ ItemCategory = category("cus-11", { configModeHandler = true }) }, "LeftButton")

    assertTrue(collapsedCalls == 0, "collapse should not be triggered in config mode")
    assertTrue(configModeClickCalls == 1, "config mode hook should be called")
    assertTrue(selectedCategoryId == "cus-11", "custom category should be selected in config mode")
end)

run("config mode non-custom category click is a no-op", function()
    collapsedCalls = 0
    selectedCategoryId = nil
    configModeClickCalls = 0
    categoriesConfigMode = true

    addonEnv.DragAndDrop.categoryOnMouseUp({ ItemCategory = category("unassigned") }, "LeftButton")

    assertTrue(collapsedCalls == 0, "non-custom category should not collapse in config mode")
    assertTrue(configModeClickCalls == 0, "category without config mode hook should do nothing")
    assertTrue(selectedCategoryId == nil, "non-custom category should not be selected in config mode")
end)

run("normal mode category click still toggles collapse", function()
    collapsedCalls = 0
    selectedCategoryId = nil
    configModeClickCalls = 0
    categoriesConfigMode = false

    addonEnv.DragAndDrop.categoryOnMouseUp({ ItemCategory = category("cus-11", { configModeHandler = true }) }, "LeftButton")

    assertTrue(collapsedCalls == 1, "collapse should be triggered in normal mode")
    assertTrue(configModeClickCalls == 0, "normal mode should not call config mode hook")
    assertTrue(selectedCategoryId == nil, "normal mode click should not select in config GUI")
end)
