local addonName, AddonNS = ...

local MODE_DEFAULT = "default"
local MODE_SHIFT_ONLY = "shift_only"
local MODE_DISABLED = "disabled"

local function normalizeMode(value)
    if value == MODE_DEFAULT or value == MODE_SHIFT_ONLY or value == MODE_DISABLED then
        return value
    end
    return MODE_DEFAULT
end

local function getSettingsRoot()
    local db = AddonNS.db
    if type(db) ~= "table" then
        error("TooltipSettings missing db")
    end
    if type(db.settings) ~= "table" then
        return nil
    end
    return db.settings
end

local function getPersistedMode()
    local settings = getSettingsRoot()
    if not settings then
        return MODE_DEFAULT
    end
    return normalizeMode(settings.tooltipMode)
end

local function pruneEmptySettingsRoot()
    local db = AddonNS.db
    if type(db) ~= "table" then
        error("TooltipSettings missing db")
    end
    if type(db.settings) ~= "table" then
        return
    end
    if next(db.settings) == nil then
        db.settings = nil
    end
end

AddonNS.TooltipSettings = {
    MODE_DEFAULT = MODE_DEFAULT,
    MODE_SHIFT_ONLY = MODE_SHIFT_ONLY,
    MODE_DISABLED = MODE_DISABLED,
}

function AddonNS.TooltipSettings:GetMode()
    return getPersistedMode()
end

function AddonNS.TooltipSettings:SetMode(mode)
    local normalized = normalizeMode(mode)
    if normalized == MODE_DEFAULT then
        local settings = getSettingsRoot()
        if settings then
            settings.tooltipMode = nil
        end
        pruneEmptySettingsRoot()
        return MODE_DEFAULT
    end
    AddonNS.db.settings = AddonNS.db.settings or {}
    AddonNS.db.settings.tooltipMode = normalized
    return normalized
end

function AddonNS.TooltipSettings:IsTooltipDisabled()
    return self:GetMode() == MODE_DISABLED
end

function AddonNS.TooltipSettings:ShouldShowShiftHintWhenNotHeld()
    return self:GetMode() == MODE_DEFAULT
end
