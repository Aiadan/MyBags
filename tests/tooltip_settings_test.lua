local addonEnv = {
    db = {},
}

local tooltipSettingsChunk = assert(loadfile("tooltipSettings.lua"))
tooltipSettingsChunk("MyBags", addonEnv)

local function assertTrue(condition, message)
    if not condition then
        error(message or "assertion failed", 2)
    end
end

assertTrue(addonEnv.TooltipSettings:GetMode() == addonEnv.TooltipSettings.MODE_DEFAULT, "mode defaults to default")
assertTrue(addonEnv.TooltipSettings:ShouldShowShiftHintWhenNotHeld(), "shift hint is shown in default mode")
assertTrue(not addonEnv.TooltipSettings:IsTooltipDisabled(), "tooltip modifications enabled in default mode")

addonEnv.TooltipSettings:SetMode(addonEnv.TooltipSettings.MODE_SHIFT_ONLY)
assertTrue(addonEnv.TooltipSettings:GetMode() == addonEnv.TooltipSettings.MODE_SHIFT_ONLY, "mode can be set to shift_only")
assertTrue(not addonEnv.TooltipSettings:ShouldShowShiftHintWhenNotHeld(), "shift hint hidden in shift_only mode")
assertTrue(not addonEnv.TooltipSettings:IsTooltipDisabled(), "shift_only does not disable tooltip modifications")
assertTrue(addonEnv.db.settings.tooltipMode == addonEnv.TooltipSettings.MODE_SHIFT_ONLY, "shift_only persisted")

addonEnv.TooltipSettings:SetMode(addonEnv.TooltipSettings.MODE_DISABLED)
assertTrue(addonEnv.TooltipSettings:IsTooltipDisabled(), "disabled mode disables tooltip modifications")
assertTrue(addonEnv.db.settings.tooltipMode == addonEnv.TooltipSettings.MODE_DISABLED, "disabled persisted")

addonEnv.TooltipSettings:SetMode("unexpected")
assertTrue(addonEnv.TooltipSettings:GetMode() == addonEnv.TooltipSettings.MODE_DEFAULT, "invalid input normalizes to default")
assertTrue(addonEnv.db.settings == nil, "default mode prunes persisted settings root")

addonEnv.db.settings = { tooltipMode = "broken_value" }
assertTrue(addonEnv.TooltipSettings:GetMode() == addonEnv.TooltipSettings.MODE_DEFAULT, "invalid persisted value normalizes to default")

print("✓ tooltip settings modes and persistence")
