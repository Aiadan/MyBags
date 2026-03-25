local addonName, AddonNS = ...

local SETTINGS_VARIABLE = "MYBAGS_TOOLTIP_MODE"
local registered = false

local function registerAddonSettings()
    if registered then
        return
    end
    if not Settings then
        return
    end
    if not AddonNS.TooltipSettings then
        error("TooltipSettings missing")
    end

    local category = Settings.RegisterVerticalLayoutCategory("MyBags")
    category:SetShouldSortAlphabetically(true)

    local function getValue()
        return AddonNS.TooltipSettings:GetMode()
    end

    local function setValue(value)
        AddonNS.TooltipSettings:SetMode(value)
    end

    local setting = Settings.RegisterProxySetting(
        category,
        SETTINGS_VARIABLE,
        Settings.VarType.String,
        "Item Tooltip Mode",
        AddonNS.TooltipSettings.MODE_DEFAULT,
        getValue,
        setValue
    )

    local function getOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add(AddonNS.TooltipSettings.MODE_DEFAULT, "Default (show hint; details on Shift)")
        container:Add(AddonNS.TooltipSettings.MODE_SHIFT_ONLY, "Hide hint; details only on Shift")
        container:Add(AddonNS.TooltipSettings.MODE_EDIT_ONLY, "Only show in edit mode (Shift for details)")
        container:Add(AddonNS.TooltipSettings.MODE_DISABLED, "Disable MyBags tooltip additions")
        return container:GetData()
    end

    Settings.CreateDropdown(category, setting, getOptions, "Control MyBags item tooltip additions.")
    Settings.RegisterAddOnCategory(category)
    registered = true
end

function AddonNS.Events:ADDON_LOADED(eventName, loadedAddonName)
    if loadedAddonName == "Blizzard_Settings" then
        registerAddonSettings()
    end
end

AddonNS.Events:RegisterEvent("ADDON_LOADED")

if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_Settings") then
    registerAddonSettings()
end
