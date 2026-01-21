local addonName, AddonNS = ...

local UnassignedCategorizer = {}
local CATEGORIZER_ID = "unassigned"
local RAW_ID = "unassigned"

local rawUnassigned = {
    GetId = function() return RAW_ID end,
    GetName = function() return "Unassigned" end,
    IsProtected = function() return false end,
    OnItemAssigned = function() end,
    OnItemUnassigned = function() end,
}

function UnassignedCategorizer:ListCategories()
    return { rawUnassigned }
end

function UnassignedCategorizer:GetAlwaysVisibleCategories()
    return { rawUnassigned }
end

function UnassignedCategorizer:Categorize()
    return rawUnassigned
end

AddonNS.Categories:RegisterCategorizer("Unassigned", UnassignedCategorizer, CATEGORIZER_ID)
