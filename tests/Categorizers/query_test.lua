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
  {
    name = "numeric comparisons treat missing value as non-match instead of error",
    query = "questid > 0",
    item = testItem2,
    expected = false,
  },
}

for _, case in ipairs(testCases) do
  local compiledQuery, quotedValues = Query.prepare(case.query)
  local evaluateItem = Query.evaluate(compiledQuery, quotedValues)
  assert(evaluateItem(case.item) == case.expected, case.name)
end

local adHocEvaluator = addonEnv.QueryCategories:CompileAdHoc("itemType = 3")
assert(type(adHocEvaluator) == "function", "CompileAdHoc returns evaluator for valid query")
assert(adHocEvaluator(testItem1) == true, "CompileAdHoc evaluator matches valid item")
assert(adHocEvaluator(testItem2) == false, "CompileAdHoc evaluator rejects invalid item")

local invalidAttribute = addonEnv.QueryCategories:CompileAdHoc("unknownAttr = 3")
assert(invalidAttribute == nil, "CompileAdHoc returns nil for unknown attribute")

local invalidComparator = addonEnv.QueryCategories:CompileAdHoc("itemType == 3")
assert(invalidComparator == nil, "CompileAdHoc returns nil for invalid comparator")

local invalidSyntax = addonEnv.QueryCategories:CompileAdHoc("itemType = 3 OR")
assert(invalidSyntax == nil, "CompileAdHoc returns nil for malformed syntax")

local tooltipRows = addonEnv.QueryCategories:GetTooltipAttributeRows({
  stackCount = 0,
  expansionID = 10,
  itemType = 2,
  itemSubType = 15,
  bindType = 2,
  isQuestItem = true,
  hasLoot = false,
  itemName = "",
})
assert(#tooltipRows >= 6, "GetTooltipAttributeRows returns all non-nil attributes")
local rowByName = {}
for _, row in ipairs(tooltipRows) do
  rowByName[row.name] = row
end
assert(rowByName.expansionID and rowByName.expansionID.meaning == "The War Within", "expansionID meaning is resolved")
assert(rowByName.itemType and rowByName.itemType.meaning == "Weapon", "itemType meaning is resolved")
assert(rowByName.itemSubType and rowByName.itemSubType.meaning == "Dagger", "itemSubType meaning is resolved by itemType")
assert(rowByName.stackCount and rowByName.stackCount.value == 0, "numeric zero values are included")
assert(rowByName.hasLoot and rowByName.hasLoot.value == false, "boolean false values are included")
assert(rowByName.itemName and rowByName.itemName.value == "", "empty string values are included")

local classicRows = addonEnv.QueryCategories:GetTooltipAttributeRows({
  expansionID = 0,
})
local classicExpansionRow = nil
for _, row in ipairs(classicRows) do
  if row.name == "expansionID" then
    classicExpansionRow = row
    break
  end
end
assert(classicExpansionRow ~= nil, "GetTooltipAttributeRows keeps expansionID when value is 0")
assert(classicExpansionRow.meaning == "Classic", "expansionID value 0 meaning is resolved")

local tradegoodsRows = addonEnv.QueryCategories:GetTooltipAttributeRows({
  itemType = 7,
  itemSubType = 17,
})
local tradegoodsSubclassRow = nil
for _, row in ipairs(tradegoodsRows) do
  if row.name == "itemSubType" then
    tradegoodsSubclassRow = row
    break
  end
end
assert(tradegoodsSubclassRow ~= nil, "GetTooltipAttributeRows keeps itemSubType for tradegoods")
assert(tradegoodsSubclassRow.meaning == "OptionalReagents", "tradegoods itemSubType meaning is resolved by itemType")

local order = addonEnv.QueryCategories.TooltipAttributeDefinitions.order
local orderPosByName = {}
for index, name in ipairs(order) do
  orderPosByName[name] = index
end
local previousOrderPos = 0
for _, row in ipairs(tooltipRows) do
  local currentPos = orderPosByName[row.name]
  assert(currentPos ~= nil, "row name exists in tooltip order")
  assert(currentPos > previousOrderPos, "rows follow configured tooltip order")
  previousOrderPos = currentPos
end
