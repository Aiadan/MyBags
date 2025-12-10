local addonName, AddonNS = ...

local CategoryStore = {}
CategoryStore.__index = CategoryStore

local CATEGORY_ID_PREFIX = "cat-"
local CATEGORY_VERSION = 2

local SYSTEM_IDS = {
    UNASSIGNED = "sys:unassigned",
    NEW_ITEMS = "sys:new",
}

local CategoryMethods = {}
local CategoryMeta = {}

local function copy_array(source)
    if not source then
        return {}
    end
    local result = {}
    for index = 1, #source do
        result[index] = source[index]
    end
    return result
end

local function wrap_category(store, record, metadata)
    local object = {
        id = record and record.id or metadata.id,
        _record = record,
        _metadata = metadata or record,
        _store = store,
    }
    return setmetatable(object, CategoryMeta)
end

function CategoryMethods:GetName()
    local record = rawget(self, "_record")
    if record then
        return record.name
    end
    local metadata = rawget(self, "_metadata")
    return metadata and metadata.name or nil
end

function CategoryMethods:IsProtected()
    local record = rawget(self, "_record")
    if record and record.protected ~= nil then
        return record.protected
    end
    local metadata = rawget(self, "_metadata")
    if metadata and metadata.protected ~= nil then
        return metadata.protected
    end
    return false
end

function CategoryMethods:SetName(newName)
    return rawget(self, "_store"):Rename(self.id, newName)
end

function CategoryMethods:SetQuery(query)
    return rawget(self, "_store"):SetQuery(self.id, query)
end

function CategoryMethods:SetAlwaysVisible(flag)
    return rawget(self, "_store"):SetAlwaysVisible(self.id, flag)
end

function CategoryMethods:GetItems()
    local record = rawget(self, "_record")
    if record then
        record.items = record.items or {}
        return record.items
    end
    return {}
end

function CategoryMethods:IsDynamic()
    return rawget(self, "_record") == nil
end

function CategoryMethods:SetOnItemAssigned(handler)
    local store = rawget(self, "_store")
    if not store then
        return
    end
    store:_setHook(self.id, "OnItemAssigned", handler)
end

function CategoryMethods:SetOnItemUnassigned(handler)
    local store = rawget(self, "_store")
    if not store then
        return
    end
    store:_setHook(self.id, "OnItemUnassigned", handler)
end

CategoryMeta.__index = function(self, key)
    local store = rawget(self, "_store")
    if store then
        local hook = store:_getHook(rawget(self, "id"), key)
        if hook then
            return hook
        end
    end
    local method = CategoryMethods[key]
    if method then
        return method
    end
    local record = rawget(self, "_record")
    if record and record[key] ~= nil then
        return record[key]
    end
    local metadata = rawget(self, "_metadata")
    if metadata and metadata[key] ~= nil then
        return metadata[key]
    end
    return rawget(self, key)
end

function CategoryStore:new()
    local instance = setmetatable({
        db = nil,
        legacy = nil,
        _categoriesById = {},
        _categoriesByName = {},
        _assignments = {},
        _dynamicCategories = {},
        _systemCategories = {},
        _hooks = {},
    }, CategoryStore)
    return instance
end

function CategoryStore:_setHook(categoryId, name, handler)
    if not categoryId or not name then
        return
    end
    self._hooks = self._hooks or {}
    self._hooks[categoryId] = self._hooks[categoryId] or {}
    self._hooks[categoryId][name] = handler
end

function CategoryStore:_getHook(categoryId, name)
    local hooks = self._hooks and self._hooks[categoryId]
    if hooks then
        return hooks[name]
    end
    return nil
end

function CategoryStore:_clearHooks(categoryId)
    if not categoryId or not self._hooks then
        return
    end
    self._hooks[categoryId] = nil
end

function CategoryStore:LoadOrBootstrap(db, legacyDb)
    self.db = db or {}
    self.legacy = legacyDb
    if self.db.version ~= CATEGORY_VERSION then
        self:_migrateFromLegacy(legacyDb)
    end
    self:_ensureSchema()
    self:_hydrate()
    return self
end

function CategoryStore:_ensureSchema()
    local db = self.db
    db.version = db.version or CATEGORY_VERSION
    db.sequences = db.sequences or {}
    db.sequences.category = db.sequences.category or 0
    db.categories = db.categories or {}
    db.itemOrder = db.itemOrder or {}
    db.layout = db.layout or {}
    local columnCount = (AddonNS.Const and AddonNS.Const.NUM_COLUMNS) or 3
    db.layout.columns = db.layout.columns or {}
    for index = 1, columnCount do
        db.layout.columns[index] = db.layout.columns[index] or {}
    end
    db.layout.collapsed = db.layout.collapsed or {}
end

function CategoryStore:_migrateFromLegacy(legacyDb)
    local db = self.db
    for key in pairs(db) do
        db[key] = nil
    end

    db.version = CATEGORY_VERSION
    db.sequences = { category = 0 }
    db.categories = {}
    db.itemOrder = {}
    db.layout = {
        columns = { {}, {}, {} },
        collapsed = {},
    }

    if not legacyDb then
        return
    end

    local nameToId = {}
    local function reserveId(name)
        if not name or name == "" then
            return nil, nil
        end
        if nameToId[name] then
            return nameToId[name], db.categories[nameToId[name]]
        end
        db.sequences.category = db.sequences.category + 1
        local id = CATEGORY_ID_PREFIX .. db.sequences.category
        local record = {
            id = id,
            name = name,
            categorizer = "user",
            protected = false,
            items = {},
        }
        db.categories[id] = record
        nameToId[name] = id
        return id, record
    end

    local legacyCustom = legacyDb.customCategories or {}
    for name, items in pairs(legacyCustom) do
        local id, record = reserveId(name)
        if record then
            record.items = copy_array(items)
        end
    end

    local legacyQueries = legacyDb.queryCategories or {}
    for name, query in pairs(legacyQueries) do
        local id, record = reserveId(name)
        if record then
            record.query = query
        end
    end

    local legacyAlways = legacyDb.categoriesToAlwaysShow or {}
    for name, flag in pairs(legacyAlways) do
        local _, record = reserveId(name)
        if record then
            record.alwaysVisible = (flag and true) or nil
        end
    end

    local legacyCollapsed = legacyDb.collapsedCategories or {}
    for name, flag in pairs(legacyCollapsed) do
        if flag then
            local id = nameToId[name]
            if id then
                db.layout.collapsed[id] = true
            end
        end
    end

    local legacyColumns = legacyDb.categoriesColumnAssignments or {}
    for columnIndex = 1, AddonNS.Const.NUM_COLUMNS do
        db.layout.columns[columnIndex] = {}
        local sourceColumn = legacyColumns[columnIndex] or {}
        for _, name in ipairs(sourceColumn) do
            local id = nameToId[name]
            if id then
                table.insert(db.layout.columns[columnIndex], id)
            end
        end
    end

    db.itemOrder = copy_array(legacyDb.itemOrder or {})
end

function CategoryStore:_hydrate()
    self._categoriesById = {}
    self._categoriesByName = {}
    self._assignments = {}
    self._dynamicCategories = self._dynamicCategories or {}
    self._hooks = self._hooks or {}
    for id, record in pairs(self.db.categories) do
        local category = wrap_category(self, record, nil)
        self._categoriesById[id] = category
        if record.name then
            self._categoriesByName[record.name] = category
        end
        record.items = record.items or {}
        for _, itemID in ipairs(record.items) do
            self._assignments[itemID] = id
        end
    end

    self:_ensureSystemCategories()
end

function CategoryStore:_ensureSystemCategories()
    self._systemCategories = self._systemCategories or {}
    if not self._systemCategories.unassigned then
        self._systemCategories.unassigned = wrap_category(self, nil, {
            id = SYSTEM_IDS.UNASSIGNED,
            name = nil,
            categorizer = "system:unassigned",
            protected = false,
        })
    end
    self:_setHook(self._systemCategories.unassigned.id, "OnItemAssigned", function(_, itemId)
        self:AssignItem(itemId, nil)
    end)
    if not self._systemCategories.newItems then
        self._systemCategories.newItems = wrap_category(self, nil, {
            id = SYSTEM_IDS.NEW_ITEMS,
            name = "New",
            categorizer = "system:new",
            protected = true,
        })
    end
end

function CategoryStore:Get(id)
    if not id then
        return nil
    end
    return self._categoriesById[id] or self._dynamicCategories[id] or self:_systemById(id)
end

function CategoryStore:_systemById(id)
    if id == SYSTEM_IDS.UNASSIGNED then
        return self._systemCategories.unassigned
    end
    if id == SYSTEM_IDS.NEW_ITEMS then
        return self._systemCategories.newItems
    end
    return nil
end

function CategoryStore:GetByName(name)
    if not name then
        return nil
    end
    return self._categoriesByName[name]
end

function CategoryStore:All(opts)
    opts = opts or {}
    local includeDynamic = opts.includeDynamic or false
    local list = {}
    for _, category in pairs(self._categoriesById) do
        table.insert(list, category)
    end
    if includeDynamic then
        for _, category in pairs(self._dynamicCategories) do
            table.insert(list, category)
        end
        table.insert(list, self._systemCategories.unassigned)
        table.insert(list, self._systemCategories.newItems)
    end
    table.sort(list, function(left, right)
        local leftName = left:GetName() or ""
        local rightName = right:GetName() or ""
        if leftName == rightName then
            return left.id < right.id
        end
        return leftName < rightName
    end)
    local index = 0
    local count = #list
    return function()
        index = index + 1
        if index <= count then
            return list[index]
        end
    end
end

function CategoryStore:_assertNameAvailable(name, ignoreId)
    if not name or name == "" then
        error("Category name is required.")
    end
    local existing = self._categoriesByName[name]
    if existing and existing.id ~= ignoreId then
        error("Category name already exists.")
    end
end

function CategoryStore:_nextId()
    self.db.sequences.category = (self.db.sequences.category or 0) + 1
    return CATEGORY_ID_PREFIX .. self.db.sequences.category
end

function CategoryStore:CreateCustom(name, opts)
    opts = opts or {}
    self:_assertNameAvailable(name)
    local id = self:_nextId()
    local record = {
        id = id,
        name = name,
        categorizer = opts.categorizer or "user",
        protected = opts.protected or false,
        alwaysVisible = opts.alwaysVisible or nil,
        items = {},
    }
    self.db.categories[id] = record
    local category = wrap_category(self, record, nil)
    self._categoriesById[id] = category
    self._categoriesByName[name] = category
    return category
end

function CategoryStore:Rename(id, newName)
    local category = self:Get(id)
    if not category then
        return nil
    end
    local record = rawget(category, "_record")
    if not record then
        return category
    end
    self:_assertNameAvailable(newName, id)
    local previousName = record.name
    record.name = newName
    if previousName then
        self._categoriesByName[previousName] = nil
    end
    if newName then
        self._categoriesByName[newName] = category
    end
    return category
end

function CategoryStore:SetQuery(id, query)
    local category = self:Get(id)
    if not category then
        return
    end
    local record = rawget(category, "_record")
    if record then
        if query and query ~= "" then
            record.query = query
        else
            record.query = nil
        end
    end
end

function CategoryStore:SetAlwaysVisible(id, flag)
    local category = self:Get(id)
    if not category then
        return
    end
    local record = rawget(category, "_record")
    if record then
        if flag then
            record.alwaysVisible = true
        else
            record.alwaysVisible = nil
        end
    end
end

local function remove_value(list, value)
    local index = 1
    while index <= #list do
        if list[index] == value then
            table.remove(list, index)
        else
            index = index + 1
        end
    end
end

function CategoryStore:_removeItemFromCategory(categoryId, itemId)
    local category = self:Get(categoryId)
    if not category then
        return
    end
    local record = rawget(category, "_record")
    if record then
        record.items = record.items or {}
        remove_value(record.items, itemId)
    end
end

function CategoryStore:_addItemToCategory(category, itemId)
    local record = rawget(category, "_record")
    if not record then
        return
    end
    record.items = record.items or {}
    for _, existing in ipairs(record.items) do
        if existing == itemId then
            return
        end
    end
    table.insert(record.items, itemId)
end

function CategoryStore:AssignItem(itemId, categoryId)
    if not itemId then
        return
    end
    local previous = self._assignments[itemId]
    if previous and previous == categoryId then
        return
    end
    if previous then
        self:_removeItemFromCategory(previous, itemId)
    end
    if categoryId then
        local category = self:Get(categoryId)
        if category then
            self:_addItemToCategory(category, itemId)
            self._assignments[itemId] = categoryId
        else
            self._assignments[itemId] = nil
        end
    else
        self._assignments[itemId] = nil
    end
end

function CategoryStore:UnassignItem(itemId)
    local current = self._assignments[itemId]
    if current then
        self:_removeItemFromCategory(current, itemId)
        self._assignments[itemId] = nil
    end
end

function CategoryStore:GetAssignment(itemId)
    return self._assignments[itemId]
end

function CategoryStore:Delete(id)
    local category = self:Get(id)
    if not category then
        return
    end
    if category:IsProtected() then
        return
    end
    local record = rawget(category, "_record")
    if not record then
        return
    end
    if record.items then
        for _, itemId in ipairs(copy_array(record.items)) do
            self._assignments[itemId] = nil
        end
    end
    for columnIndex = 1, AddonNS.Const.NUM_COLUMNS do
        remove_value(self.db.layout.columns[columnIndex], id)
    end
    self.db.layout.collapsed[id] = nil
    if record.name then
        self._categoriesByName[record.name] = nil
    end
    self._categoriesById[id] = nil
    self.db.categories[id] = nil
    self:_clearHooks(id)
end

function CategoryStore:SetCollapsed(id, collapsed)
    if collapsed then
        self.db.layout.collapsed[id] = true
    else
        self.db.layout.collapsed[id] = nil
    end
end

function CategoryStore:IsCollapsed(id)
    return self.db.layout.collapsed[id] or false
end

function CategoryStore:GetLayoutColumns()
    if not self.db then
        self.db = {}
        self:_ensureSchema()
    end
    return self.db.layout.columns
end

function CategoryStore:SetLayoutColumns(columns)
    self.db.layout.columns = columns
end

function CategoryStore:RecordDynamicCategory(payload)
    local id = payload.id
    if not id then
        error("Dynamic category requires an id.")
    end
    local existing = self._dynamicCategories[id]
    if existing then
        local metadata = rawget(existing, "_metadata")
        for key, value in pairs(payload) do
            metadata[key] = value
        end
        if payload.OnItemAssigned then
            self:_setHook(id, "OnItemAssigned", payload.OnItemAssigned)
        end
        if payload.OnItemUnassigned then
            self:_setHook(id, "OnItemUnassigned", payload.OnItemUnassigned)
        end
        return existing
    end
    local category = wrap_category(self, nil, payload)
    if payload.OnItemAssigned then
        self:_setHook(id, "OnItemAssigned", payload.OnItemAssigned)
    end
    if payload.OnItemUnassigned then
        self:_setHook(id, "OnItemUnassigned", payload.OnItemUnassigned)
    end
    self._dynamicCategories[id] = category
    return category
end

function CategoryStore:GetUnassigned()
    return self._systemCategories.unassigned
end

AddonNS.CategoryStore = CategoryStore:new()
