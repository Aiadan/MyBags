local dummy = function() end

local itemPlaceholder = {}
local category = { name = "Test" }

local addonEnv = {
  Const = { NUM_COLUMNS = 1, UNASSIGNE_CATEGORY_DB_STORAGE_NAME = "Unassigned", Events = {} },
  Collapsed = { isCollapsed = function() return true end },
  Categories = {},
  ItemsOrder = { Sort = dummy },
  itemButtonPlaceholder = itemPlaceholder,
  db = {},
  Events = {
    OnInitialize = function(_, f) f() end,
    RegisterCustomEvent = dummy,
    RegisterEvent = dummy,
  },
}
addonEnv.Categories.GetConstantCategories = function() return {} end
addonEnv.Categories.GetCategoryByName = function() return category end

local chunk = assert(loadfile("categoriesColumnAssignment.lua"))
chunk("MyBags", addonEnv)

local arrangedItems = { [category] = {1,2,3} }
local assignments = addonEnv.Categories:ArrangeCategoriesIntoColumns(arrangedItems)
local info = assignments[1][1]
assert(info.itemsCount == 3, "expected itemsCount to reflect original number of items")
assert(#info.items == 1 and info.items[1] == itemPlaceholder, "collapsed category should contain placeholder item")
