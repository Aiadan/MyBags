local addonName, AddonNS = ...

--@debug@
GLOBAL_MyBags = AddonNS;
--@end-debug@

-- events
AddonNS.Events = {};
LibStub("MyLibrary_Events").embed(AddonNS.Events);
AddonNS.Const ={
    ITEMS_PER_ROW = 4, -- Maximum items per row
    DEFAULT_NUM_COLUMNS = 3,
    MIN_NUM_COLUMNS = 3,
    MAX_NUM_COLUMNS = 8,
    ORIGINAL_SPACING = 5,
    COLUMN_SPACING = 2,
    CATEGORY_HEIGHT = 20,
    MAX_ROWS = 118,
    UNASSIGNE_CATEGORY_DB_STORAGE_NAME = "UNASSIGNED_CATEGORY_DB_STORAGE_NAME"
}
AddonNS.Const.ITEM_SPACING= AddonNS.Const.ORIGINAL_SPACING
AddonNS.Const.Events = {}
AddonNS.Const.Events.ITEM_MOVED= "MYBAGS_ITEM_MOVED";
AddonNS.Const.Events.ITEM_CATEGORY_CHANGED = "MYBAGS_ITEM_CATEGORY_CHANGED";
AddonNS.Const.Events.CATEGORY_MOVED = "MYBAGS_CATEGORY_MOVED"
AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN = "MYBAGS_CATEGORY_MOVED_TO_COLUMN"
AddonNS.Const.Events.CUSTOM_CATEGORY_RENAMED = "MYBAGS_CUSTOM_CATEGORY_RENAMED";
AddonNS.Const.Events.CUSTOM_CATEGORY_DELETED = "MYBAGS_CUSTOM_CATEGORY_DELETED";
AddonNS.Const.Events.CUSTOM_CATEGORY_CREATED = "MYBAGS_CUSTOM_CATEGORY_CREATED";
AddonNS.Const.Events.CATEGORIZER_CATEGORIES_UPDATED = "MYBAGS_CATEGORIZER_CATEGORIES_UPDATED";
AddonNS.Const.Events.COLLAPSED_CHANGED = "MYBAGS_COLLAPSED_CHANGED"
AddonNS.Const.Events.BAG_VIEW_MODE_CHANGED = "MYBAGS_BAG_VIEW_MODE_CHANGED"
AddonNS.Const.Events.CUSTOM_QUERY_EDITOR_FOCUS_CHANGED = "MYBAGS_CUSTOM_QUERY_EDITOR_FOCUS_CHANGED"
-- DB
--@debug@
local legacyGlobalDbName = "dev_MyBagsDBGlobal"
local globalDbName = "dev_MyBagsDB"
--@end-debug@
--[===[@non-debug@
local legacyGlobalDbName = "MyBagsDBGlobal";
local globalDbName = "MyBagsDB";
--@end-non-debug@]===]

AddonNS.db = {};
AddonNS.LegacyDB = nil;
AddonNS.Profiling = AddonNS.Profiling or {
    enabled = false,
}
AddonNS.init = function()
    AddonNS.LegacyDB = _G[legacyGlobalDbName];
    _G[globalDbName] = _G[globalDbName] or {};
    AddonNS.db = _G[globalDbName];
    if not AddonNS.CategoryStore then
        error("CategoryStore missing")
    end
    AddonNS.CategoryStore:LoadOrBootstrap(AddonNS.db, AddonNS.LegacyDB);
    if not AddonNS.CustomCategories or not AddonNS.CustomCategories.LoadOrBootstrap then
        error("CustomCategories missing")
    end
    AddonNS.CustomCategories:LoadOrBootstrap(AddonNS.db, AddonNS.LegacyDB)
end

AddonNS.Events:OnDbLoaded(AddonNS.init)

local function normalizeColumnCount(value)
    local numeric = tonumber(value) or AddonNS.Const.DEFAULT_NUM_COLUMNS
    numeric = math.floor(numeric)
    if numeric < AddonNS.Const.MIN_NUM_COLUMNS then
        return AddonNS.Const.MIN_NUM_COLUMNS
    end
    if numeric > AddonNS.Const.MAX_NUM_COLUMNS then
        return AddonNS.Const.MAX_NUM_COLUMNS
    end
    return numeric
end

function AddonNS:GetNumColumns()
    return AddonNS.CategoryStore:GetColumnCount()
end

function AddonNS:SetNumColumns(count)
    local normalized = normalizeColumnCount(count)
    AddonNS.Categories:SetColumnCount(normalized)
    AddonNS.QueueContainerUpdateItemLayout()
    AddonNS.TriggerContainerOnTokenWatchChanged()
    return normalized
end

function AddonNS.printDebug(...)
--@debug@
    -- print(...)
--@end-debug@
end




--@debug@
function GLOBAL_MyBagsEnableDebug()
    AddonNS.printDebug = function(...) print(...) end
end

function GLOBAL_MyBagsEnableProfiling()
    AddonNS.Profiling.enabled = true
    AddonNS.printDebug = function(...) print(...) end
    print("MyBags profiling enabled")
end

function GLOBAL_MyBagsDisableProfiling()
    AddonNS.Profiling.enabled = false
    print("MyBags profiling disabled")
end

-- AddonNS.printDebug = function(...) print(...) end
--@end-debug@
