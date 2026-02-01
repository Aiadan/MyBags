local addonName, AddonNS = ...

-- CategoryStore manages wrapper categories and shared layout state.
-- Raw categories are owned by categorizers; this store wraps them with
-- namespaced IDs and keeps layout/collapsed/itemOrder in a common place.

local CategoryStore = {}
CategoryStore.__index = CategoryStore

local UNASSIGNED_ID = "unassigned"
local SINGLETON_SUFFIX = "singleton"

local function compute_wrapper_ids(categorizerId, rawId)
    if categorizerId == UNASSIGNED_ID then
        return UNASSIGNED_ID, UNASSIGNED_ID .. "::" .. (rawId or "")
    end
    local normalizedRaw = rawId
    if normalizedRaw == "" then
        normalizedRaw = SINGLETON_SUFFIX
    end
    local wrapperId = categorizerId .. "-" .. normalizedRaw
    local rawKey = categorizerId .. "::" .. normalizedRaw
    return wrapperId, rawKey
end

local function default_raw_methods(raw)
    -- Provide safe defaults for optional raw methods.
    raw.IsProtected = raw.IsProtected or function() return false end
    return raw
end

local function wrap_category(store, categorizerId, rawCategory)
    if not rawCategory or not rawCategory.GetId then
        return nil
    end
    default_raw_methods(rawCategory)
    local rawId = rawCategory:GetId() or ""
    local wrapperId, rawKey = compute_wrapper_ids(categorizerId, rawId)
    local existing = store._wrappersByRaw[rawKey]
    if existing then
        -- Update mutable fields in place to reuse the same wrapper object.
        existing._raw = rawCategory
        existing.name = rawCategory:GetName()
        return existing
    end
    local wrapper = {
        _raw = rawCategory,
        _categorizerId = categorizerId,
        _rawKey = rawKey,
        id = wrapperId,
        name = rawCategory:GetName(),
    }
    function wrapper:GetId()
        return self.id
    end
    function wrapper:GetName()
        return self._raw:GetName()
    end
    function wrapper:IsProtected()
        return self._raw:IsProtected()
    end
    function wrapper:OnRightClick(...)
        if self._raw.OnRightClick then
            return self._raw:OnRightClick(...)
        end
    end
    function wrapper:OnItemAssigned(itemId, context)
        if self._raw.OnItemAssigned then
            self._raw:OnItemAssigned(itemId, context)
        end
    end
    function wrapper:OnItemUnassigned(itemId, context)
        if self._raw.OnItemUnassigned then
            self._raw:OnItemUnassigned(itemId, context)
        end
    end
    store._wrappersByRaw[rawKey] = wrapper
    if wrapperId == UNASSIGNED_ID then
        store._unassigned = wrapper
    end
    return wrapper
end

function CategoryStore:new()
    local instance = setmetatable({
        db = nil,
        _wrappersById = {},
        _wrappersByName = {},
        _wrappersByRaw = {},
        _wrappersByCategorizer = {},
        _unassigned = nil,
    }, CategoryStore)
    return instance
end

local function ensure_db(self)
    if not self.db then
        self:LoadOrBootstrap({})
    end
end

function CategoryStore:LoadOrBootstrap(db, legacyDb)
    self.db = db or {}
    self.db.categorizers = self.db.categorizers or {}
    self.db.itemOrder = self.db.itemOrder or {}
    self.db.layout = self.db.layout or {}
    self.db.layout.columns = self.db.layout.columns or { {}, {}, {} }
    self.db.layout.collapsed = self.db.layout.collapsed or {}
    self:_migrateFromLegacy(legacyDb)
    self:_migrateFromOldDb()
    self:_normalizeUnassignedLayout()
    return self
end

local function normalize_legacy_array(source)
    local out = {}
    for _, v in ipairs(source or {}) do
        table.insert(out, v)
    end
    return out
end

function CategoryStore:_migrateFromLegacy(legacyDb)
    if not legacyDb then
        return
    end
    -- Only migrate if we do not already have categorizers.
    if self.db.categorizers and next(self.db.categorizers) then
        return
    end

    self.db.categorizers = self.db.categorizers or {}
    local custom = {
        id = "cus",
        name = "Custom",
        categories = {},
        nextId = 0,
    }
    local nameToId = {}

    local function reserveId(name)
        custom.nextId = custom.nextId + 1
        local rawId = tostring(custom.nextId)
        nameToId[name] = rawId
        custom.categories[rawId] = {
            name = name,
            protected = false,
            items = {},
        }
        return rawId
    end

    local legacyCustom = legacyDb.customCategories or {}
    for name, items in pairs(legacyCustom) do
        local rawId = reserveId(name)
        custom.categories[rawId].items = normalize_legacy_array(items)
    end

    local legacyQueries = legacyDb.queryCategories or {}
    for name, query in pairs(legacyQueries) do
        local rawId = nameToId[name] or reserveId(name)
        custom.categories[rawId].query = query
    end

    local legacyAlways = legacyDb.categoriesToAlwaysShow or {}
    for name, flag in pairs(legacyAlways) do
        if flag then
            local rawId = nameToId[name] or reserveId(name)
            custom.categories[rawId].alwaysVisible = true
        end
    end

    self.db.categorizers.cus = custom

    -- Layout: map legacy column names to namespaced ids; keep stale if missing.
    local legacyColumns = legacyDb.categoriesColumnAssignments or {}
    self.db.layout.columns = self.db.layout.columns or { {}, {}, {} }
    for columnIndex = 1, 3 do
        self.db.layout.columns[columnIndex] = {}
        local sourceColumn = legacyColumns[columnIndex] or {}
        for _, name in ipairs(sourceColumn) do
            local rawId = nameToId[name]
            if rawId then
                table.insert(self.db.layout.columns[columnIndex], custom.id .. "-" .. rawId)
            else
                table.insert(self.db.layout.columns[columnIndex], name)
            end
        end
    end

    -- Collapsed: accept legacy flags, map to namespaced ids when known.
    local legacyCollapsed = legacyDb.collapsedCategories or {}
    self.db.layout.collapsed = self.db.layout.collapsed or {}
    for name, flag in pairs(legacyCollapsed) do
        if flag then
            local rawId = nameToId[name]
            if rawId then
                self.db.layout.collapsed[custom.id .. "-" .. rawId] = true
            end
        end
    end

    -- Item order is copied across directly.
    self.db.itemOrder = normalize_legacy_array(legacyDb.itemOrder or {})
end

local function strip_cat_prefix(id)
    if not id then
        return nil
    end
    local raw = tostring(id)
    raw = raw:gsub("^cat%-", "")
    return raw
end

function CategoryStore:_migrateFromOldDb()
    if self.db.categorizers and next(self.db.categorizers) then
        return
    end
    if not self.db.categories then
        return
    end

    self.db.categorizers = self.db.categorizers or {}
    local custom = {
        id = "cus",
        name = "Custom",
        categories = {},
        nextId = 0,
    }

    local function reserve(rawId, name)
        local numeric = tonumber(rawId)
        if numeric and numeric > custom.nextId then
            custom.nextId = numeric
        end
        custom.categories[rawId] = custom.categories[rawId] or {
            name = name,
            protected = false,
            items = {},
        }
    end

    for id, record in pairs(self.db.categories) do
        local rawId = strip_cat_prefix(record.id or id)
        reserve(rawId, record.name)
        local entry = custom.categories[rawId]
        entry.protected = record.protected or false
        entry.items = normalize_legacy_array(record.items)
        entry.query = record.query
        entry.alwaysVisible = record.alwaysVisible
    end

    -- Layout conversion.
    local legacyColumns = self.db.layout and self.db.layout.columns or { {}, {}, {} }
    self.db.layout.columns = { {}, {}, {} }
    for columnIndex = 1, 3 do
        for _, legacyId in ipairs(legacyColumns[columnIndex] or {}) do
            local rawId = strip_cat_prefix(legacyId)
            if rawId then
                table.insert(self.db.layout.columns[columnIndex], custom.id .. "-" .. rawId)
            else
                table.insert(self.db.layout.columns[columnIndex], legacyId)
            end
        end
    end

    -- Collapsed conversion.
    local legacyCollapsed = self.db.layout and self.db.layout.collapsed or {}
    self.db.layout.collapsed = self.db.layout.collapsed or {}
    for legacyId, flag in pairs(legacyCollapsed) do
        if flag then
            local rawId = strip_cat_prefix(legacyId)
            if rawId then
                self.db.layout.collapsed[custom.id .. "-" .. rawId] = true
            end
        end
    end

    -- Item order preserved as-is.
    self.db.itemOrder = normalize_legacy_array(self.db.itemOrder or {})

    self.db.categorizers.cus = custom
end

local function normalize_unassigned_id(id)
    if not id then
        return nil
    end
    if id == UNASSIGNED_ID then
        return UNASSIGNED_ID
    end
    if id:match("^[^%-]+%-unassigned$") then
        return UNASSIGNED_ID
    end
    return id
end

function CategoryStore:_normalizeUnassignedLayout()
    self.db.layout = self.db.layout or {}
    self.db.layout.columns = self.db.layout.columns or { {}, {}, {} }
    for columnIndex = 1, #self.db.layout.columns do
        local column = self.db.layout.columns[columnIndex]
        local seen = {}
        for idx = #column, 1, -1 do
            local normalized = normalize_unassigned_id(column[idx])
            column[idx] = normalized
            if normalized == UNASSIGNED_ID then
                if seen[UNASSIGNED_ID] then
                    table.remove(column, idx)
                else
                    seen[UNASSIGNED_ID] = true
                end
            end
        end
    end
    local collapsed = self.db.layout.collapsed or {}
    local normalizedCollapsed = {}
    for id, flag in pairs(collapsed) do
        if flag then
            local normalized = normalize_unassigned_id(id)
            if normalized then
                normalizedCollapsed[normalized] = true
            end
        end
    end
    self.db.layout.collapsed = normalizedCollapsed
end

function CategoryStore:GetCategorizerDb(categorizerId)
    ensure_db(self)
    self.db.categorizers[categorizerId] = self.db.categorizers[categorizerId] or { id = categorizerId, categories = {} }
    local entry = self.db.categorizers[categorizerId]
    entry.id = entry.id or categorizerId
    entry.categories = entry.categories or {}
    return entry
end

function CategoryStore:ResetWrappers()
    self._wrappersById = {}
    self._wrappersByName = {}
    self._wrappersByRaw = {}
    self._wrappersByCategorizer = {}
    self._unassigned = nil
end

function CategoryStore:RefreshCategorizer(categorizerId, rawCategories)
    -- Drop existing wrappers for this categorizer.
    local existing = self._wrappersByCategorizer[categorizerId]
    if existing then
        for _, wrapper in ipairs(existing) do
            self._wrappersById[wrapper.id] = nil
            local name = wrapper:GetName()
            if name and self._wrappersByName[name] then
                self._wrappersByName[name][wrapper.id] = nil
            end
            local rawKey = wrapper._rawKey
            if not rawKey then
                local rawId = wrapper:GetId():match("^[^%-]+%-(.+)$")
                if rawId then
                    rawKey = wrapper._categorizerId .. "::" .. rawId
                end
            end
            if rawKey then
                self._wrappersByRaw[rawKey] = nil
            end
        end
    end
    if categorizerId == UNASSIGNED_ID then
        self._unassigned = nil
    end
    local list = {}
    rawCategories = rawCategories or {}
    for index = 1, #rawCategories do
        local wrapper = wrap_category(self, categorizerId, rawCategories[index])
        if wrapper then
            table.insert(list, wrapper)
            self._wrappersById[wrapper.id] = wrapper
            local name = wrapper:GetName()
            if name then
                self._wrappersByName[name] = self._wrappersByName[name] or {}
                self._wrappersByName[name][wrapper.id] = wrapper
            end
        end
    end
    self._wrappersByCategorizer[categorizerId] = list
    return list
end

function CategoryStore:GetWrapperForRaw(categorizerId, rawCategory)
    local rawId = rawCategory and rawCategory.GetId and rawCategory:GetId()
    if not rawId then
        return nil
    end
    local wrapperId, rawKey = compute_wrapper_ids(categorizerId, rawId)
    local existing = self._wrappersById[wrapperId]
    if existing then
        return existing
    end
    local wrapper = wrap_category(self, categorizerId, rawCategory)
    if not wrapper then
        return nil
    end
    self._wrappersById[wrapper.id] = wrapper
    local name = wrapper:GetName()
    if name then
        self._wrappersByName[name] = self._wrappersByName[name] or {}
        self._wrappersByName[name][wrapper.id] = wrapper
    end
    self._wrappersByCategorizer[categorizerId] = self._wrappersByCategorizer[categorizerId] or {}
    table.insert(self._wrappersByCategorizer[categorizerId], wrapper)
    return wrapper
end

function CategoryStore:Get(id)
    if not id then
        return nil
    end
    if id == UNASSIGNED_ID then
        return self._unassigned
    end
    return self._wrappersById[id]
end

function CategoryStore:GetByName(name)
    -- Names are not globally unique in this model; return nil to avoid ambiguity.
    if not name then
        return nil
    end
    local map = self._wrappersByName[name]
    if not map then
        return nil
    end
    for _, wrapper in pairs(map) do
        return wrapper
    end
    return nil
end

function CategoryStore:GetByCategorizer(categorizerId)
    return self._wrappersByCategorizer[categorizerId] or {}
end

function CategoryStore:GetLayoutColumns()
    ensure_db(self)
    return self.db.layout.columns
end

function CategoryStore:SetLayoutColumns(columns)
    ensure_db(self)
    self.db.layout.columns = columns
end

function CategoryStore:SetCollapsed(id, collapsed)
    ensure_db(self)
    if not id then
        return
    end
    if collapsed then
        self.db.layout.collapsed[id] = true
    else
        self.db.layout.collapsed[id] = nil
    end
end

function CategoryStore:IsCollapsed(id)
    ensure_db(self)
    return self.db.layout.collapsed[id] or false
end

function CategoryStore:GetUnassigned()
    if not self._unassigned then
        error("Unassigned categorizer not registered")
    end
    return self._unassigned
end

AddonNS.CategoryStore = CategoryStore:new()
