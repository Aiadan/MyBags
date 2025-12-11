local addonName, AddonNS = ...

local CustomCategorizer = {}
local CustomCategories = {}
AddonNS.CustomCategories = CustomCategories
AddonNS.UserCategorizer = CustomCategorizer

local CATEGORIZER_ID = "cus"

local assignments = {}

local function get_db()
    local db = AddonNS.CategoryStore:GetCategorizerDb(CATEGORIZER_ID)
    db.name = db.name or "Custom"
    db.id = db.id or CATEGORIZER_ID
    return db
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
    function raw:IsAlwaysVisible()
        return data.alwaysVisible == true
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
    return tostring(categoryOrId)
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
        if data.alwaysVisible then
            table.insert(list, new_raw(rawId, data))
        end
    end
    return list
end

function CustomCategorizer:Categorize(itemID, itemButton)
    local assignedId = assignments[itemID]
    if assignedId then
        return find_by_id(assignedId)
    end

    -- Query-based matching remains internal to custom categorizer.
    local itemInfo, containerInfo = collectItemInfo(itemID, itemButton)
    if not itemInfo then
        return nil
    end

    local matches = {}
    for rawId, data in pairs(get_db().categories) do
        if data.query then
            local evaluator = AddonNS.QueryCategories:GetCompiled(rawId)
            if evaluator and evaluator(itemInfo) then
                table.insert(matches, new_raw(rawId, data))
            end
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
    AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CUSTOM_CATEGORY_DELETED, raw:GetId())
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
    local db = get_db()
    local entry = db.categories[rawId]
    if not entry then
        return
    end
    entry.query = (query and query ~= "") and query or nil
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
    local entry = get_db().categories[rawId]
    if not entry then
        return ""
    end
    return entry.query or ""
end

AddonNS.Events:OnInitialize(function()
    rebuild_assignments()
end)
