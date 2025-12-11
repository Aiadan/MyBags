local addonEnv = {
  Const = { Events = {
    CATEGORIZER_CATEGORIES_UPDATED = "CATEGORIZER_CATEGORIES_UPDATED",
    CUSTOM_CATEGORY_RENAMED = "CUSTOM_CATEGORY_RENAMED",
    CUSTOM_CATEGORY_DELETED = "CUSTOM_CATEGORY_DELETED",
  }},
  Events = {
    OnInitialize = function() end,
    RegisterCustomEvent = function() end,
    TriggerCustomEvent = function() end,
  },
  Categories = {
    RegisterCategorizer = function() end,
  },
  CategoryStore = {
    All = function()
      return function() end
    end,
    SetQuery = function() end,
  },
  printDebug = function() end,
}

local queryChunk = assert(loadfile("Categorizers/custom/query.lua"))
queryChunk("MyBags", addonEnv)

local Query = addonEnv._Test.Query
local testItem1 = {
  itemName = "Epic",
  isCraftingReagent = true,
  itemType = 3,
  ilvl = 120,
}

local testItem2 = { itemType = 4 }

local testCases = {
  {
    name = "matches itemType 3 with spaces",
    query = "itemType !=4 or itemType != 5 and itemType = 3",
    item = testItem1,
    expected = true,
  },
  {
    name = "rejects itemType 4",
    query = "itemType !=4 or itemType != 5 and itemType = 3",
    item = testItem2,
    expected = false,
  },
  {
    name = "parses without spaces",
    query = "itemType=3",
    item = testItem1,
    expected = true,
  },
  {
    name = "accepts uppercase operators",
    query = "itemType=3 OR itemType=4",
    item = testItem2,
    expected = true,
  },
}

for _, case in ipairs(testCases) do
  local compiledQuery = Query.prepare(case.query)
  local evaluateItem = Query.evaluate(compiledQuery)
  assert(evaluateItem(case.item) == case.expected, case.name)
end
