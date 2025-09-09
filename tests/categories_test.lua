local addonEnv = {
  Const = {
    Events = {
      CUSTOM_CATEGORY_DELETED = "CUSTOM_CATEGORY_DELETED",
      CUSTOM_CATEGORY_RENAMED = "CUSTOM_CATEGORY_RENAMED",
    },
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
local categoriesChunk = assert(loadfile("categories.lua"))
categoriesChunk("MyBags", addonEnv)

local function makeCategorizer(catName)
  return {
    Categorize = function(self, itemID)
      if itemID == 1 then return catName end
    end,
  }
end

addonEnv.Categories:RegisterCategorizer("cat1", makeCategorizer("cat1"), false)
addonEnv.Categories:RegisterCategorizer("cat2", makeCategorizer("cat2"), false)

local itemButton = {}
local category = addonEnv.Categories:Categorize(1, itemButton)

assert(category.name == "cat1", "returns first matching category")
assert(#itemButton.ItemCategories == 2, "stores all matching categories")
assert(itemButton.ItemCategories[1].name == "cat1", "first category is first in list")
assert(itemButton.ItemCategories[2].name == "cat2", "second category is second in list")
