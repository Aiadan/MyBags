local addonEnv = {
    Const = {
        Events = {
            BAG_VIEW_MODE_CHANGED = "BAG_VIEW_MODE_CHANGED",
        },
    },
    Events = {
        TriggerCustomEvent = function() end,
    },
}

local bagViewStateChunk = assert(loadfile("bagViewState.lua"))
bagViewStateChunk("MyBags", addonEnv)

local function assertTrue(condition, message)
    if not condition then
        error(message or "assertion failed", 2)
    end
end

assertTrue(not addonEnv.BagViewState:ShouldShowScopeDisabledInConfigMode(), "runtime scope-disabled flag defaults to false")
addonEnv.BagViewState:SetShowScopeDisabledInConfigMode(true)
assertTrue(addonEnv.BagViewState:ShouldShowScopeDisabledInConfigMode(), "runtime scope-disabled flag can be enabled")
addonEnv.BagViewState:SetMode("categories_config")
assertTrue(addonEnv.BagViewState:ShouldShowScopeDisabledInConfigMode(), "mode changes do not reset runtime scope-disabled flag")
addonEnv.BagViewState:SetMode("normal")
assertTrue(addonEnv.BagViewState:ShouldShowScopeDisabledInConfigMode(), "returning to normal mode does not reset runtime scope-disabled flag")
addonEnv.BagViewState:SetShowScopeDisabledInConfigMode(false)
assertTrue(not addonEnv.BagViewState:ShouldShowScopeDisabledInConfigMode(), "runtime scope-disabled flag can be disabled")
print("✓ bag view state scope-disabled runtime flag")
