local removedBag = nil
local removedSlot = nil

C_NewItems = {
  RemoveNewItem = function(bagID, slotIndex)
    removedBag = bagID
    removedSlot = slotIndex
  end,
  IsNewItem = function()
    return false
  end,
  ClearAll = function() end,
}

local registeredCategorizer = nil
local addonEnv = {
  Categories = {
    RegisterCategorizer = function(_, _, categorizer)
      registeredCategorizer = categorizer
    end,
  },
  Events = {
    RegisterEvent = function() end,
  },
  printDebug = function() end,
}

local chunk = assert(loadfile("Categorizers/new.lua"))
chunk("MyBags", addonEnv)

local list = registeredCategorizer:ListCategories()
assert(#list == 1, "new categorizer exposes one category")
local newCategory = list[1]
assert(newCategory ~= nil, "new category exists")

local fakeButton = {
  GetBagID = function() return 2 end,
  GetID = function() return 11 end,
}

newCategory:OnItemUnassigned(19019, {
  pickedItemButton = fakeButton,
})

assert(removedBag == 2, "OnItemUnassigned uses context button bag id")
assert(removedSlot == 11, "OnItemUnassigned uses context button slot index")
