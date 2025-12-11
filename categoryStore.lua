local addonName, AddonNS = ...

-- CategoryStore manages wrapper categories and shared layout state.
-- Raw categories are owned by categorizers; this store wraps them with
-- namespaced IDs and keeps layout/collapsed/itemOrder in a common place.

local CategoryStore = {}
CategoryStore.__index = CategoryStore

local UNASSIGNED_ID = "unassigned"
local SINGLETON_SUFFIX = "singleton"

local function default_raw_methods(raw)
    -- Provide safe defaults for optional raw methods.
    raw.IsProtected = raw.IsProtected or function() return false end
    raw.IsAlwaysVisible = raw.IsAlwaysVisible or function() return false end
    return raw
end

local function wrap_category(store, categorizerId, rawCategory)
    if not rawCategory or not rawCategory.GetId then
        return nil
    end
    default_raw_methods(rawCategory)
    local rawId = rawCategory:GetId() or ""
    if rawId == "" then
        rawId = SINGLETON_SUFFIX
    end
    local wrapperId = categorizerId .. "-" .. rawId
    local wrapper = {
        _raw = rawCategory,
        _categorizerId = categorizerId,
        id = wrapperId,
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
    function wrapper:IsAlwaysVisible()
        return self._raw:IsAlwaysVisible()
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
    return wrapper
end

function CategoryStore:new()
    local instance = setmetatable({
        db = nil,
        _wrappersById = {},
        _wrappersByName = {},
        _wrappersByCategorizer = {},
        _unassigned = {
            id = UNASSIGNED_ID,
            GetId = function(self) return self.id end,
            GetName = function() return nil end,
            IsProtected = function() return false end,
            IsAlwaysVisible = function() return false end,
            OnItemAssigned = function() end,
            OnItemUnassigned = function() end,
        },
    }, CategoryStore)
    return instance
end

local function ensure_db(self)
    if not self.db then
        self:LoadOrBootstrap({})
    end
end

function CategoryStore:LoadOrBootstrap(db)
    self.db = db or {}
    self.db.categorizers = self.db.categorizers or {}
    self.db.itemOrder = self.db.itemOrder or {}
    self.db.layout = self.db.layout or {}
    self.db.layout.columns = self.db.layout.columns or { {}, {}, {} }
    self.db.layout.collapsed = self.db.layout.collapsed or {}
    return self
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
    self._wrappersByCategorizer = {}
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
        end
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
    if rawId == "" then
        rawId = SINGLETON_SUFFIX
    end
    if not rawId then
        return nil
    end
    local wrapperId = categorizerId .. "-" .. rawId
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
    return self._unassigned
end

AddonNS.CategoryStore = CategoryStore:new()
