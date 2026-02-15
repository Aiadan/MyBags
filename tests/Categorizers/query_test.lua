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
  CustomCategories = {
    GetQuery = function() return "" end,
    SetQuery = function() end,
    GetQueryCategoryRawIds = function() return {} end,
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
local testItem3 = { itemName = "Epic Sword of Trials", itemType = 3 }
local testItem4 = { itemName = "Epic Shield" }

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
  {
    name = "accepts case-insensitive attribute names",
    query = "ITEMTYPE = 3 and ItemName = \"Epic Sword\"",
    item = testItem3,
    expected = true,
  },
  {
    name = "keeps unquoted itemName pattern behavior",
    query = "itemName = Epic.*",
    item = testItem3,
    expected = true,
  },
  {
    name = "supports quoted multi-word itemName",
    query = "itemName = \"Epic Sword\"",
    item = testItem3,
    expected = true,
  },
  {
    name = "treats quoted value as pattern",
    query = "itemName = \"Epic.*\"",
    item = testItem3,
    expected = true,
  },
  {
    name = "supports operators inside quoted itemName text",
    query = "itemName = \"Epic OR Sword\" OR itemName = \"Epic Shield\"",
    item = testItem4,
    expected = true,
  },
}

for _, case in ipairs(testCases) do
  local compiledQuery, quotedValues = Query.prepare(case.query)
  local evaluateItem = Query.evaluate(compiledQuery, quotedValues)
  assert(evaluateItem(case.item) == case.expected, case.name)
end
