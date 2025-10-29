local addonEnv = {
  Const = {
    Events = {
      CUSTOM_CATEGORY_DELETED = "CUSTOM_CATEGORY_DELETED",
      CUSTOM_CATEGORY_RENAMED = "CUSTOM_CATEGORY_RENAMED",
    },
    NUM_COLUMNS = 3,
    UNASSIGNE_CATEGORY_DB_STORAGE_NAME = "UNASSIGNED",
  },
  Events = {
    RegisterCustomEvent = function() end,
  },
  CategorShowAlways = {
    GetAlwaysShownCategories = function() return {} end,
  },
  printDebug = function() end,
}
dofile("utils/orderedMap.lua")
local storeChunk = assert(loadfile("categoryStore.lua"))
storeChunk("MyBags", addonEnv)
addonEnv.CategoryStore:LoadOrBootstrap({}, nil)

local categoriesChunk = assert(loadfile("categories.lua"))
categoriesChunk("MyBags", addonEnv)

local function makeCategorizer(id, name)
  return {
    Categorize = function(self, itemID)
      if itemID == 1 then
        return addonEnv.CategoryStore:RecordDynamicCategory({
          id = id,
          name = name,
          protected = false,
        })
      end
    end,
  }
end

addonEnv.Categories:RegisterCategorizer("cat1", makeCategorizer("cat1", "cat1"))
addonEnv.Categories:RegisterCategorizer("cat2", makeCategorizer("cat2", "cat2"))

local itemButton = {}
local category = addonEnv.Categories:Categorize(1, itemButton)

assert(category.name == "cat1", "returns first matching category")
assert(#itemButton.ItemCategories == 2, "stores all matching categories")
assert(itemButton.ItemCategories[1].name == "cat1", "first category is first in list")
assert(itemButton.ItemCategories[2].name == "cat2", "second category is second in list")
