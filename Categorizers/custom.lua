local addonName, AddonNS = ...

local CustomCategorizer = {}
local CustomCategories = {}
AddonNS.CustomCategories = CustomCategories
AddonNS.UserCategorizer = CustomCategorizer

local CATEGORIZER_ID = "cus"
local STORAGE_KEY = "userCategories"
local STORAGE_SCHEMA_VERSION = 1

local assignments = {}
local showAllCustomCategoriesInCategoriesGui = false
local categorizeProfile = {
    calls = 0,
    totalMs = 0,
    infoMs = 0,
    queryMs = 0,
    maxMs = 0,
}

local function profilingEnabled()
    return AddonNS.Profiling and AddonNS.Profiling.enabled
end

local function profileNowMs()
    return debugprofilestop()
end

local function normalize_array(source)
    local out = {}
    for _, value in ipairs(source or {}) do
        table.insert(out, value)
    end
    return out
end

local function strip_raw_id_prefix(rawOrWrappedId)
    if not rawOrWrappedId then
        return nil
    end
    local raw = tostring(rawOrWrappedId)
    raw = raw:gsub("^cat%-", "")
    raw = raw:gsub("^" .. CATEGORIZER_ID .. "%-", "")
    return raw
end

local function make_empty_storage()
    return {
        schemaVersion = STORAGE_SCHEMA_VERSION,
        id = CATEGORIZER_ID,
        name = "Custom",
        nextId = 0,
        categories = {},
    }
end

local function normalize_storage(storage)
    storage = storage or {}
    storage.schemaVersion = STORAGE_SCHEMA_VERSION
    storage.id = storage.id or CATEGORIZER_ID
    storage.name = storage.name or "Custom"
    storage.categories = storage.categories or {}

    local normalizedCategories = {}
    local maxNumericId = 0
    for rawId, data in pairs(storage.categories) do
        local normalizedRawId = tostring(rawId)
        local entry = type(data) == "table" and data or {}
        normalizedCategories[normalizedRawId] = {
            name = entry.name or "",
            protected = entry.protected == true or nil,
            alwaysVisible = entry.alwaysVisible == true or nil,
            query = (entry.query and entry.query ~= "") and entry.query or nil,
            items = normalize_array(entry.items),
        }
        local numeric = tonumber(normalizedRawId)
        if numeric and numeric > maxNumericId then
            maxNumericId = numeric
        end
    end
    storage.categories = normalizedCategories
    local nextId = tonumber(storage.nextId) or 0
    storage.nextId = (nextId > maxNumericId) and nextId or maxNumericId
    return storage
end

local function index_names(storage)
    local byName = {}
    for rawId, data in pairs(storage.categories or {}) do
        if data.name then
            byName[data.name] = rawId
        end
    end
    return byName
end

local function reserve_raw_id(storage, preferredName, nameIndex)
    storage.nextId = (tonumber(storage.nextId) or 0) + 1
    local rawId = tostring(storage.nextId)
    storage.categories[rawId] = storage.categories[rawId] or {
        name = preferredName or "",
        items = {},
    }
    if preferredName and preferredName ~= "" then
        nameIndex[preferredName] = rawId
    end
    return rawId
end

local function migrate_from_current_category_store_shape(db, storage)
    local source = db.categorizers and db.categorizers[CATEGORIZER_ID]
    if type(source) ~= "table" then
        return false
    end
    storage.id = source.id or storage.id
    storage.name = source.name or storage.name
    storage.nextId = tonumber(source.nextId) or 0
    storage.categories = {}
    for rawId, data in pairs(source.categories or {}) do
        storage.categories[tostring(rawId)] = {
            name = data.name or "",
            protected = data.protected == true or nil,
            alwaysVisible = data.alwaysVisible == true or nil,
            query = (data.query and data.query ~= "") and data.query or nil,
            items = normalize_array(data.items),
        }
    end
    return true
end

local function migrate_from_old_db_shape(db, storage)
    local source = db.categories
    if type(source) ~= "table" or next(source) == nil then
        return false
    end
    storage.categories = {}
    for id, record in pairs(source) do
        local sourceRecord = type(record) == "table" and record or {}
        local rawId = strip_raw_id_prefix(sourceRecord.id or id)
        if rawId then
            storage.categories[rawId] = {
                name = sourceRecord.name or "",
                protected = sourceRecord.protected == true or nil,
                alwaysVisible = sourceRecord.alwaysVisible == true or nil,
                query = (sourceRecord.query and sourceRecord.query ~= "") and sourceRecord.query or nil,
                items = normalize_array(sourceRecord.items),
            }
        end
    end
    return true
end

local function migrate_from_legacy_global_shape(legacyDb, storage)
    if type(legacyDb) ~= "table" then
        return false
    end
    local legacyCustom = legacyDb.customCategories
    local legacyQueries = legacyDb.queryCategories
    local legacyAlways = legacyDb.categoriesToAlwaysShow
    if type(legacyCustom) ~= "table" and type(legacyQueries) ~= "table" and type(legacyAlways) ~= "table" then
        return false
    end

    storage.categories = {}
    local nameIndex = index_names(storage)

    local function get_or_create(name)
        local rawId = nameIndex[name]
        if rawId and storage.categories[rawId] then
            return rawId
        end
        return reserve_raw_id(storage, name, nameIndex)
    end

    for name, items in pairs(legacyCustom or {}) do
        local rawId = get_or_create(name)
        storage.categories[rawId].items = normalize_array(items)
    end
    for name, query in pairs(legacyQueries or {}) do
        local rawId = get_or_create(name)
        storage.categories[rawId].query = (query and query ~= "") and query or nil
    end
    for name, flag in pairs(legacyAlways or {}) do
        if flag then
            local rawId = get_or_create(name)
            storage.categories[rawId].alwaysVisible = true
        end
    end
    return true
end

local function normalize_layout_custom_ids(db, storage)
    local layout = db.layout
    if type(layout) ~= "table" then
        return
    end
    layout.columns = layout.columns or { {}, {}, {} }
    layout.collapsed = layout.collapsed or {}
    local nameIndex = index_names(storage)

    local function resolve_layout_id(id)
        if type(id) ~= "string" then
            return id
        end
        if id:match("^" .. CATEGORIZER_ID .. "%-") then
            return id
        end
        if id:match("^cat%-") then
            return CATEGORIZER_ID .. "-" .. id:gsub("^cat%-", "")
        end
        local rawId = nameIndex[id]
        if rawId then
            return CATEGORIZER_ID .. "-" .. rawId
        end
        return id
    end

    for columnIndex = 1, #layout.columns do
        local seen = {}
        local normalizedColumn = {}
        for _, id in ipairs(layout.columns[columnIndex] or {}) do
            local normalized = resolve_layout_id(id)
            local key = type(normalized) == "string" and normalized or tostring(normalized)
            if not seen[key] then
                table.insert(normalizedColumn, normalized)
                seen[key] = true
            end
        end
        layout.columns[columnIndex] = normalizedColumn
    end

    local normalizedCollapsed = {}
    for id, flag in pairs(layout.collapsed or {}) do
        if flag then
            local normalized = resolve_layout_id(id)
            normalizedCollapsed[normalized] = true
        end
    end
    layout.collapsed = normalizedCollapsed
end

local function prune_old_custom_shapes(db)
    if db.categorizers then
        db.categorizers[CATEGORIZER_ID] = nil
    end
    db.categories = nil
end

function CustomCategories:LoadOrBootstrap(db, legacyDb)
    if not db then
        error("CustomCategories LoadOrBootstrap missing db")
    end
    local storage = db[STORAGE_KEY]
    if type(storage) ~= "table" then
        storage = make_empty_storage()
        if not migrate_from_current_category_store_shape(db, storage) then
            if not migrate_from_old_db_shape(db, storage) then
                migrate_from_legacy_global_shape(legacyDb, storage)
            end
        end
    end
    storage = normalize_storage(storage)
    db[STORAGE_KEY] = storage
    normalize_layout_custom_ids(db, storage)
    prune_old_custom_shapes(db)
end

function CustomCategories:GetStorage()
    if not AddonNS.db then
        error("CustomCategories storage requested before DB init")
    end
    local storage = AddonNS.db[STORAGE_KEY]
    if type(storage) ~= "table" then
        error("CustomCategories storage missing; call LoadOrBootstrap first")
    end
    return storage
end

local function get_db()
    return CustomCategories:GetStorage()
end

local function rebuild_assignments()
    assignments = {}
    local db = get_db()
    for rawId, data in pairs(db.categories) do
        if data.items then
            for _, itemId in ipairs(data.items) do
                assignments[itemId] = rawId
            end
        end
    end
end

local function new_raw(id, data)
    local raw = {}
    function raw:GetId()
        return id
    end
    function raw:GetName()
        return data.name or ""
    end
    function raw:IsProtected()
        return data.protected == true
    end
    function raw:OnItemAssigned(itemId, context)
        if not itemId then
            return
        end
        if data.protected then
            return
        end
        local db = get_db()
        db.categories[id].items = db.categories[id].items or {}
        local previous = assignments[itemId]
        if previous and db.categories[previous] and db.categories[previous].items then
            local items = db.categories[previous].items
            for idx = #items, 1, -1 do
                if items[idx] == itemId then
                    table.remove(items, idx)
                end
            end
        end
        assignments[itemId] = id
        for _, existing in ipairs(db.categories[id].items) do
            if existing == itemId then
                return
            end
        end
        table.insert(db.categories[id].items, itemId)
    end
    function raw:OnItemUnassigned(itemId, context)
        if not itemId then
            return
        end
        if data.protected then
            return
        end
        local db = get_db()
        local entry = db.categories[id]
        if not entry or not entry.items then
            return
        end
        for idx = #entry.items, 1, -1 do
            if entry.items[idx] == itemId then
                table.remove(entry.items, idx)
            end
        end
        if assignments[itemId] == id then
            assignments[itemId] = nil
        end
    end
    return raw
end

local function all_raw()
    local db = get_db()
    local list = {}
    for rawId, data in pairs(db.categories) do
        table.insert(list, new_raw(rawId, data))
    end
    return list
end

local function find_by_id(rawId)
    local db = get_db()
    local data = db.categories[rawId]
    if not data then
        return nil
    end
    return new_raw(rawId, data)
end

local function find_by_name(name)
    local db = get_db()
    for rawId, data in pairs(db.categories) do
        if data.name == name then
            return new_raw(rawId, data)
        end
    end
    return nil
end

local function resolve_raw_id(categoryOrId)
    if not categoryOrId then
        return nil
    end
    if type(categoryOrId) == "table" and categoryOrId.GetId then
        local id = categoryOrId:GetId()
        local raw = id:match("^[^%-]+%-(.+)$")
        return raw or id
    end
    if type(categoryOrId) == "table" and categoryOrId.name then
        local found = find_by_name(categoryOrId.name)
        return found and found:GetId() or nil
    end
    return strip_raw_id_prefix(tostring(categoryOrId))
end

local function collectItemInfo(itemID, itemButton)
    if not itemButton then
        return nil, nil
    end
    local bagID = itemButton:GetBagID()
    local slotID = itemButton:GetID()
    local containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)
    if not containerInfo then
        return nil, nil
    end
    local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expansionID, setID, isCraftingReagent =
        C_Item.GetItemInfo(containerInfo.hyperlink)
    if not itemName then
        return nil, containerInfo
    end
    local questInfo = C_Container.GetContainerItemQuestInfo(bagID, slotID) or {}
    local inventoryType = C_Item.GetItemInventoryTypeByID(itemID)
    local payload = {
        stackCount = containerInfo.stackCount,
        quality = containerInfo.quality,
        isReadable = containerInfo.isReadable,
        hasLoot = containerInfo.hasLoot,
        hasNoValue = containerInfo.hasNoValue,
        itemID = containerInfo.itemID,
        isBound = containerInfo.isBound,
        itemName = containerInfo.itemName,
        ilvl = itemLevel,
        itemMinLevel = itemMinLevel,
        itemType = classID,
        itemSubType = subclassID,
        inventoryType = inventoryType,
        sellPrice = sellPrice,
        isCraftingReagent = isCraftingReagent,
        isQuestItem = questInfo.isQuestItem,
        questID = questInfo.questID,
        isQuestItemActive = questInfo.isActive,
        bindType = bindType,
        expansionID = expansionID,
    }
    return payload, containerInfo
end

function CustomCategorizer:ListCategories()
    return all_raw()
end

function CustomCategorizer:GetAlwaysVisibleCategories()
    local list = {}
    local db = get_db()
    for rawId, data in pairs(db.categories) do
        if showAllCustomCategoriesInCategoriesGui or data.alwaysVisible then
            table.insert(list, new_raw(rawId, data))
        end
    end
    return list
end

function CustomCategorizer:Categorize(itemID, itemButton)
    local startedAt = profilingEnabled() and profileNowMs() or nil
    local assignedId = assignments[itemID]
    if assignedId then
        if startedAt then
            local elapsed = profileNowMs() - startedAt
            categorizeProfile.calls = categorizeProfile.calls + 1
            categorizeProfile.totalMs = categorizeProfile.totalMs + elapsed
        end
        return find_by_id(assignedId)
    end

    -- Query-based matching remains internal to custom categorizer.
    local infoStartedAt = startedAt and profileNowMs() or nil
    local itemInfo, containerInfo = collectItemInfo(itemID, itemButton)
    if infoStartedAt then
        categorizeProfile.infoMs = categorizeProfile.infoMs + (profileNowMs() - infoStartedAt)
    end
    if not itemInfo then
        if startedAt then
            local elapsed = profileNowMs() - startedAt
            categorizeProfile.calls = categorizeProfile.calls + 1
            categorizeProfile.totalMs = categorizeProfile.totalMs + elapsed
        end
        return nil
    end

    local matches = {}
    local queryStartedAt = startedAt and profileNowMs() or nil
    for rawId, data in pairs(get_db().categories) do
        if data.query then
            local evaluator = AddonNS.QueryCategories:GetCompiled(rawId)
            if evaluator and evaluator(itemInfo) then
                table.insert(matches, new_raw(rawId, data))
            end
        end
    end
    if queryStartedAt then
        categorizeProfile.queryMs = categorizeProfile.queryMs + (profileNowMs() - queryStartedAt)
    end
    if startedAt then
        local elapsed = profileNowMs() - startedAt
        categorizeProfile.calls = categorizeProfile.calls + 1
        categorizeProfile.totalMs = categorizeProfile.totalMs + elapsed
        if elapsed > categorizeProfile.maxMs then
            categorizeProfile.maxMs = elapsed
        end
        if categorizeProfile.calls >= 100 then
            AddonNS.printDebug(
                "PROFILE CustomCategorizer:Categorize",
                "calls=" .. categorizeProfile.calls,
                string.format("avg=%.3fms", categorizeProfile.totalMs / categorizeProfile.calls),
                string.format("infoAvg=%.3fms", categorizeProfile.infoMs / categorizeProfile.calls),
                string.format("queryAvg=%.3fms", categorizeProfile.queryMs / categorizeProfile.calls),
                string.format("max=%.3fms", categorizeProfile.maxMs)
            )
            categorizeProfile.calls = 0
            categorizeProfile.totalMs = 0
            categorizeProfile.infoMs = 0
            categorizeProfile.queryMs = 0
            categorizeProfile.maxMs = 0
        end
    end
    if #matches > 0 then
        return matches
    end
    return nil
end

AddonNS.Categories:RegisterCategorizer("UserCategories", CustomCategorizer, CATEGORIZER_ID)

local function fireUpdate()
    AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CATEGORIZER_CATEGORIES_UPDATED, CustomCategorizer)
end

AddonNS.CategorShowAlways = {}

function AddonNS.CategorShowAlways:ShouldAlwaysShow(categoryOrId)
    local rawId = resolve_raw_id(categoryOrId)
    if not rawId then
        return false
    end
    local db = get_db()
    local entry = db.categories[rawId]
    return entry and entry.alwaysVisible or false
end

function AddonNS.CategorShowAlways:SetAlwaysShow(categoryOrId, show)
    local rawId = resolve_raw_id(categoryOrId)
    if not rawId then
        return
    end
    CustomCategories:SetAlwaysVisible(rawId, show)
end

function AddonNS.CategorShowAlways:SetShowAllCustomInCategoriesGui(show)
    if showAllCustomCategoriesInCategoriesGui ~= show then
        showAllCustomCategoriesInCategoriesGui = show
        fireUpdate()
    end
end

function CustomCategories:GetCategories()
    local map = {}
    for _, raw in ipairs(all_raw()) do
        local wrapper = AddonNS.CategoryStore:GetWrapperForRaw(CATEGORIZER_ID, raw)
        if wrapper then
            map[wrapper:GetId()] = wrapper
        end
    end
    return map
end

function CustomCategories:NewCategory(name, opts)
    opts = opts or {}
    local db = get_db()
    local rawId = tostring((db.nextId or 0) + 1)
    db.nextId = tonumber(rawId)
    db.categories[rawId] = {
        name = name,
        protected = opts.protected or false,
        alwaysVisible = opts.alwaysVisible or false,
        items = {},
    }
    fireUpdate()
    return AddonNS.CategoryStore:GetWrapperForRaw(CATEGORIZER_ID, new_raw(rawId, db.categories[rawId]))
end

function CustomCategories:RenameCategory(categoryOrId, newName)
    local raw
    if type(categoryOrId) == "table" and categoryOrId.GetId then
        raw = find_by_id(categoryOrId:GetId():gsub("^" .. CATEGORIZER_ID .. "%-", ""))
    else
        raw = find_by_id(categoryOrId)
    end
    if not raw then
        return
    end
    local db = get_db()
    local previousName = raw:GetName()
    db.categories[raw:GetId()].name = newName
    fireUpdate()
    AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CUSTOM_CATEGORY_RENAMED, raw:GetId(), newName, previousName)
end

function CustomCategories:DeleteCategory(categoryOrId)
    local raw
    if type(categoryOrId) == "table" and categoryOrId.GetId then
        local stripped = categoryOrId:GetId():gsub("^" .. CATEGORIZER_ID .. "%-", "")
        raw = find_by_id(stripped)
    else
        raw = find_by_id(categoryOrId)
    end
    if not raw or raw:IsProtected() then
        return
    end
    local db = get_db()
    db.categories[raw:GetId()] = nil
    fireUpdate()
    AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CUSTOM_CATEGORY_DELETED, CATEGORIZER_ID .. "-" .. raw:GetId())
end

function CustomCategories:SetAlwaysVisible(categoryOrId, flag)
    local raw = find_by_id(categoryOrId) or find_by_name(categoryOrId)
    if not raw then
        return
    end
    local db = get_db()
    db.categories[raw:GetId()].alwaysVisible = flag and true or nil
    fireUpdate()
end

function CustomCategories:SetQuery(rawId, query)
    local resolvedRawId = resolve_raw_id(rawId)
    if not resolvedRawId then
        return
    end
    local db = get_db()
    local entry = db.categories[resolvedRawId]
    if not entry then
        return
    end
    entry.query = (query and query ~= "") and query or nil
    AddonNS.QueryCategories:SyncCompiledQuery(resolvedRawId, entry.query)
    fireUpdate()
end

function CustomCategories:AssignToCategory(categoryOrId, itemID)
    if not itemID then
        return
    end
    local rawId = resolve_raw_id(categoryOrId)
    local previous = assignments[itemID]
    if previous then
        local db = get_db()
        local entry = db.categories[previous]
        if entry and entry.items then
            for idx = #entry.items, 1, -1 do
                if entry.items[idx] == itemID then
                    table.remove(entry.items, idx)
                end
            end
        end
        assignments[itemID] = nil
    end
    if not rawId then
        fireUpdate()
        return
    end
    local raw = find_by_id(rawId)
    if not raw or raw:IsProtected() then
        fireUpdate()
        return
    end
    raw:OnItemAssigned(itemID, {})
    fireUpdate()
end

function CustomCategories:AssignToCategoryByName(name, itemID)
    local raw = find_by_name(name)
    return self:AssignToCategory(raw and raw:GetId() or nil, itemID)
end

function CustomCategories:GetQuery(rawId)
    local resolvedRawId = resolve_raw_id(rawId)
    if not resolvedRawId then
        return ""
    end
    local entry = get_db().categories[resolvedRawId]
    if not entry then
        return ""
    end
    return entry.query or ""
end

function CustomCategories:GetQueryCategoryRawIds()
    local ids = {}
    for rawId, data in pairs(get_db().categories) do
        if data.query and data.query ~= "" then
            table.insert(ids, rawId)
        end
    end
    return ids
end

AddonNS.Events:OnInitialize(function()
    rebuild_assignments()
end)
