local addonName, AddonNS = ...

--@debug@
GLOBAL_MyBags = AddonNS;
--@end-debug@

-- events
AddonNS.Events = {};
LibStub("MyLibrary_Events").embed(AddonNS.Events);
AddonNS.Const ={
    ITEMS_PER_ROW = 4, -- Maximum items per row
    NUM_COLUMNS = 3, -- Number of columns
    ORIGINAL_SPACING = 5,
    COLUMN_SPACING = 2,
    CATEGORY_HEIGHT = 20,
    MAX_ROWS = 118,
    UNASSIGNE_CATEGORY_DB_STORAGE_NAME = "UNASSIGNED_CATEGORY_DB_STORAGE_NAME"
}
AddonNS.Const.NUM_ITEM_COLUMNS = AddonNS.Const.ITEMS_PER_ROW * AddonNS.Const.NUM_COLUMNS
AddonNS.Const.ITEM_SPACING= AddonNS.Const.ORIGINAL_SPACING
AddonNS.Const.Events = {}
AddonNS.Const.Events.ITEM_MOVED= "MYBAGS_ITEM_MOVED";
AddonNS.Const.Events.ITEM_CATEGORY_CHANGED = "MYBAGS_ITEM_CATEGORY_CHANGED";
AddonNS.Const.Events.CATEGORY_MOVED = "MYBAGS_CATEGORY_MOVED"
AddonNS.Const.Events.CATEGORY_MOVED_TO_COLUMN = "MYBAGS_CATEGORY_MOVED_TO_COLUMN"
AddonNS.Const.Events.CUSTOM_CATEGORY_RENAMED = "MYBAGS_CUSTOM_CATEGORY_RENAMED";
AddonNS.Const.Events.CUSTOM_CATEGORY_DELETED = "MYBAGS_CUSTOM_CATEGORY_DELETED";
AddonNS.Const.Events.CATEGORIZER_CATEGORIES_UPDATED = "MYBAGS_CATEGORIZER_CATEGORIES_UPDATED";
AddonNS.Const.Events.COLLAPSED_CHANGED = "MYBAGS_COLLAPSED_CHANGED"
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
