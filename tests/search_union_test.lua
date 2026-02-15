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

local evaluator = addonEnv.QueryCategories:CompileAdHoc("itemType = 3")
assert(type(evaluator) == "function", "valid query compiles")

local include1, queryMatch1 = addonEnv.QueryCategories:EvaluateSearchUnion(true, evaluator, { itemType = 4 })
assert(include1 == true, "default match is always included")
assert(queryMatch1 == false, "query match is false when evaluator does not match")

local include2, queryMatch2 = addonEnv.QueryCategories:EvaluateSearchUnion(false, evaluator, { itemType = 3 })
assert(include2 == true, "query-only match is included in union")
assert(queryMatch2 == true, "query-only include reports query match")

local include3, queryMatch3 = addonEnv.QueryCategories:EvaluateSearchUnion(false, evaluator, { itemType = 4 })
assert(include3 == false, "item excluded when default and query both fail")
assert(queryMatch3 == false, "query match false when evaluator fails")

local include4, queryMatch4 = addonEnv.QueryCategories:EvaluateSearchUnion(false, nil, { itemType = 3 })
assert(include4 == false, "invalid or missing query keeps default-only behavior")
assert(queryMatch4 == false, "no evaluator means no query match")
