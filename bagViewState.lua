local addonName, AddonNS = ...

AddonNS.BagViewState = {}

local MODE_NORMAL = "normal"
local MODE_CATEGORIES_CONFIG = "categories_config"
local mode = MODE_NORMAL

function AddonNS.BagViewState:SetMode(nextMode)
    if nextMode ~= MODE_NORMAL and nextMode ~= MODE_CATEGORIES_CONFIG then
        error("Unknown bag view mode: " .. tostring(nextMode))
    end
    if mode == nextMode then
        return
    end
    mode = nextMode
    AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.BAG_VIEW_MODE_CHANGED, mode)
end

function AddonNS.BagViewState:GetMode()
    return mode
end

function AddonNS.BagViewState:IsCategoriesConfigMode()
    return mode == MODE_CATEGORIES_CONFIG
end
