local addonEnv = {
  Const = {
    Events = {
      CUSTOM_CATEGORY_DELETED = "CUSTOM_CATEGORY_DELETED",
      CUSTOM_CATEGORY_RENAMED = "CUSTOM_CATEGORY_RENAMED",
      ITEM_MOVED = "ITEM_MOVED",
    },
    DEFAULT_NUM_COLUMNS = 3,
    MIN_NUM_COLUMNS = 3,
    MAX_NUM_COLUMNS = 8,
    UNASSIGNE_CATEGORY_DB_STORAGE_NAME = "UNASSIGNED",
  },
  Events = {
    RegisterCustomEvent = function() end,
    OnInitialize = function(_, fn) fn() end,
  },
  printDebug = function() end,
}
dofile("utils/orderedMap.lua")
local storeChunk = assert(loadfile("categoryStore.lua"))
storeChunk("MyBags", addonEnv)
addonEnv.CategoryStore:LoadOrBootstrap({})

local categoriesChunk = assert(loadfile("categories.lua"))
categoriesChunk("MyBags", addonEnv)

local function makeRaw(id, name)
  local raw = {}
  function raw:GetId() return id end
  function raw:GetName() return name end
  function raw:IsProtected() return false end
  return raw
end

local cat1Raw = makeRaw("cat1", "cat1")
local cat2Raw = makeRaw("cat2", "cat2")
local diagRaw = makeRaw("diag", "diag")
local diagCalls = { categorize = 0, getMatches = 0 }

local function makeCategorizer(raw)
  return {
    ListCategories = function() return { raw } end,
    GetAlwaysVisibleCategories = function() return {} end,
    Categorize = function(self, itemID)
      if itemID == 1 then
        return raw
      end
      return nil
    end,
  }
end

addonEnv.Categories:RegisterCategorizer("cat1", makeCategorizer(cat1Raw), "cat1")
addonEnv.Categories:RegisterCategorizer("cat2", makeCategorizer(cat2Raw), "cat2")
addonEnv.Categories:RegisterCategorizer("diag", {
  ListCategories = function() return { diagRaw } end,
  GetAlwaysVisibleCategories = function() return {} end,
  Categorize = function()
    diagCalls.categorize = diagCalls.categorize + 1
    return nil
  end,
  GetMatches = function(_, itemID)
    diagCalls.getMatches = diagCalls.getMatches + 1
    if itemID == 2 then
      return diagRaw
    end
    return nil
  end,
}, "diag")
local unassignedChunk = assert(loadfile("Categorizers/unassigned.lua"))
unassignedChunk("MyBags", addonEnv)

local itemButton = {}
function itemButton:GetBagID() return 0 end
function itemButton:GetID() return 1 end

local category = addonEnv.Categories:Categorize(1, itemButton)
local matches = addonEnv.Categories:GetMatches(1, itemButton)

assert(category:GetName() == "cat1", "returns first matching category")
assert(category:GetDisplayName(0) == "cat1", "display name defaults to name for categories without custom formatter")
assert(category:IsVisibleInScope("bag") == true, "visibility defaults to true when raw method is missing")
assert(itemButton.ItemCategories == nil, "categorize no longer stores all matches on item buttons")
assert(#matches == 3, "GetMatches returns all matching categories including unassigned")
assert(matches[1]:GetName() == "cat1", "first category is first in list")
assert(matches[2]:GetName() == "cat2", "second category is second in list")
assert(matches[3]:GetName() == "Unassigned", "unassigned is last catch-all")

local category2 = addonEnv.Categories:Categorize(2, itemButton)
local matches2 = addonEnv.Categories:GetMatches(2, itemButton)
assert(category2:GetName() == "Unassigned", "categorize uses categorizer Categorize() contract only")
assert(matches2[1]:GetName() == "diag", "GetMatches uses categorizer GetMatches() when available")
assert(matches2[2]:GetName() == "Unassigned", "unassigned remains catch-all in GetMatches")
assert(diagCalls.categorize >= 1, "diagnostic categorizer Categorize path is exercised")
assert(diagCalls.getMatches >= 1, "diagnostic categorizer GetMatches path is exercised")

local assigned = 0
local unassigned = 0
local targetSeen = nil
local rightClicks = 0
local catA = {
  GetId = function() return "hook:a" end,
  GetName = function() return "A" end,
  GetDisplayName = function(_, itemsCount) return "A[" .. tostring(itemsCount) .. "]" end,
  IsProtected = function() return false end,
  OnItemUnassigned = function(_, itemId, context)
    unassigned = unassigned + 1
  end,
  OnRightClick = function()
    rightClicks = rightClicks + 1
    return true
  end,
}
local catB = {
  GetId = function() return "hook:b" end,
  GetName = function() return "B" end,
  IsProtected = function() return false end,
  OnItemAssigned = function(selfCategory)
    assigned = assigned + 10
    targetSeen = selfCategory
  end,
}
addonEnv.CategoryStore:GetWrapperForRaw("hook", catA)
addonEnv.CategoryStore:GetWrapperForRaw("hook", catB)
local wrappedA = addonEnv.CategoryStore:GetWrapperForRaw("hook", catA)

addonEnv.Categories:HandleItemReassignment("EVT", 777, nil, catA, catB, { GetBagID = function() return 0 end, GetID = function() return 1 end })
assert(assigned == 10, "assignment hook fires for the target category")
assert(unassigned == 1, "unassign hook fires for source category")
assert(targetSeen == catB, "target category is passed through")
assert(wrappedA:OnRightClick() == true and rightClicks == 1, "right-click passes through to raw category")
assert(wrappedA:GetDisplayName(3) == "A[3]", "display-name formatter passes through to raw category")
assert(wrappedA:IsVisibleInScope("bag") == true, "visibility defaults to true for wrapped categories without explicit visibility method")

local scopedVisibilityRaw = {
  GetId = function() return "hook:scope" end,
  GetName = function() return "Scope" end,
  IsProtected = function() return false end,
  IsVisibleInScope = function(_, scope) return scope ~= "bank-character" end,
}
local wrappedScope = addonEnv.CategoryStore:GetWrapperForRaw("hook", scopedVisibilityRaw)
assert(wrappedScope:IsVisibleInScope("bag") == true, "wrapped category forwards scope visibility for bag")
assert(wrappedScope:IsVisibleInScope("bank-character") == false, "wrapped category forwards scope visibility for bank-character")

local protectedTrigger = {
  GetId = function() return "hook:protected" end,
  GetName = function() return "P" end,
  IsProtected = function() return true end,
}
addonEnv.CategoryStore:GetWrapperForRaw("hook", protectedTrigger)

addonEnv.Categories:HandleItemReassignment("EVT", 888, nil, catA, protectedTrigger)
assert(assigned == 10, "protected target blocks further callbacks")
