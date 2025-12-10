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

local assigned = 0
local unassigned = 0
local targetSeen = nil
local unassignedTarget = nil
local catA = addonEnv.CategoryStore:RecordDynamicCategory({
  id = "hook:a",
  name = "A",
  OnItemUnassigned = function(selfCategory, itemId, targetCategory, context)
    unassigned = unassigned + 1
    unassignedTarget = targetCategory
  end,
})
local catB = addonEnv.CategoryStore:RecordDynamicCategory({
  id = "hook:b",
  name = "B",
  OnItemAssigned = function(selfCategory)
    assigned = assigned + 10
    targetSeen = selfCategory
  end,
})

addonEnv.Categories:HandleItemReassignment("EVT", 777, nil, catA, catB, { GetBagID = function() return 0 end, GetID = function() return 1 end })
assert(assigned == 10, "assignment hook fires for the target category")
assert(unassigned == 1, "unassign hook fires for source category")
assert(targetSeen == catB and unassignedTarget == catB, "source and target categories are passed through")

local protectedTrigger = addonEnv.CategoryStore:RecordDynamicCategory({
  id = "hook:protected",
  name = "P",
  protected = true,
  OnItemAssigned = function()
    error("protected categories should not receive assignment callbacks")
  end,
})

addonEnv.Categories:HandleItemReassignment("EVT", 888, nil, catA, protectedTrigger)
assert(assigned == 10, "protected target blocks further callbacks")
