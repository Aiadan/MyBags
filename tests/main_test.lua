local dummy = function() end

-- stub functions and objects required by main.lua
ContainerFrameCombinedBags = {
  MyBags = {
    arrangedItems = {},
    positionsInBags = {},
    categoryPositions = {},
  },
  Items = { { GetHeight = function() return 32 end } },
  EnumerateValidItems = function()
    return function() return nil end
  end,
}

local addonEnv = {
  Const = {
    ITEM_SPACING = 0,
    ITEMS_PER_ROW = 1,
    CATEGORY_HEIGHT = 10,
    COLUMN_SPACING = 0,
    NUM_ITEM_COLUMNS = 1,
    Events = {},
  },
  Collapsed = { isCollapsed = function() return true end },
  Categories = {
    ArrangeCategoriesIntoColumns = function()
      return {
        { { category = { name = "Test" }, items = {1,2,3} } }
      }
    end,
  },
  Events = {
    RegisterCustomEvent = dummy,
    RegisterEvent = dummy,
  },
  printDebug = dummy,
  DragAndDrop = {},
}

local chunk = assert(loadfile("main.lua"))
chunk("MyBags", addonEnv)

local iter = addonEnv.newEnumerateValidItems(ContainerFrameCombinedBags)
-- trigger the else branch immediately
iter(ContainerFrameCombinedBags, 0)

local pos = ContainerFrameCombinedBags.MyBags.categoryPositions[1]
assert(pos and pos.itemsCount == 3, "itemsCount missing from category position")
