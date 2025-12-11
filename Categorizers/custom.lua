local addonName, AddonNS = ...

local UserCategorizer = {}
local UserCategories = {}
AddonNS.CustomCategories = UserCategories

local seen = {}
local initialized = false

local function shouldProcess(id)
    local now = debugprofilestop()
    local last = seen[id]
    if last and (now - last) < 1000 then
        return false
    end
    seen[id] = now
    return true
end

local function resolveCategoryIdentifier(categoryOrId)
    if not categoryOrId then
        return nil
    end
    if type(categoryOrId) == "table" then
        return categoryOrId
    end
    return AddonNS.CategoryStore:Get(categoryOrId) or AddonNS.Categories:GetCategoryByName(categoryOrId)
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

function UserCategorizer:Categorize(itemID, itemButton)
    local matches = {}
    local seenCategories = {}

    local assignedId = AddonNS.CategoryStore:GetAssignment(itemID)
    if assignedId then
        local assignedCategory = AddonNS.CategoryStore:Get(assignedId)
        if assignedCategory then
            matches[1] = assignedCategory
            seenCategories[assignedId] = true
        end
    end

    local itemInfo, containerInfo = collectItemInfo(itemID, itemButton)
    if not itemInfo then
        if containerInfo and shouldProcess(itemID) then
            local item = Item:CreateFromItemID(itemID)
            item:ContinueOnItemLoad(function()
                AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CATEGORIZER_CATEGORIES_UPDATED, UserCategorizer)
            end)
        end
        if matches[1] then
            return matches
        end
        return nil
    end

    for category in AddonNS.CategoryStore:All() do
        if category.query then
            local evaluator = AddonNS.QueryCategories:GetCompiled(category)
            if evaluator and evaluator(itemInfo) and not seenCategories[category.id] then
                table.insert(matches, category)
                seenCategories[category.id] = true
            end
        end
    end

    if #matches > 0 then
        return matches
    end
    return nil
end

AddonNS.Categories:RegisterCategorizer("UserCategories", UserCategorizer)
AddonNS.UserCategorizer = UserCategorizer

local function fireUpdate()
    AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CATEGORIZER_CATEGORIES_UPDATED, UserCategorizer)
end

local function attachHooks(category)
    if not category or category.categorizer ~= "user" then
        return
    end
    category:SetOnItemAssigned(function(selfCategory, itemId)
        AddonNS.CategoryStore:AssignItem(itemId, selfCategory.id)
        fireUpdate()
    end)
    category:SetOnItemUnassigned(function(_, itemId)
        AddonNS.CategoryStore:UnassignItem(itemId)
        fireUpdate()
    end)
end

local function ensureHooks()
    if initialized then
        return
    end
    initialized = true
    local userCategories = AddonNS.CategoryStore:GetByCategorizer("user")
    for index = 1, #userCategories do
        attachHooks(userCategories[index])
    end
end

function UserCategories:GetCategories()
    local categories = {}
    local userCategories = AddonNS.CategoryStore:GetByCategorizer("user")
    for index = 1, #userCategories do
        local category = userCategories[index]
        categories[category.id] = category
    end
    return categories
end

function UserCategories:NewCategory(name, opts)
    local category = AddonNS.CategoryStore:CreateCustom(name, opts or {})
    attachHooks(category)
    fireUpdate()
    return category
end

function UserCategories:RenameCategory(categoryOrId, newName)
    local category = resolveCategoryIdentifier(categoryOrId)
    if not category then
        return
    end
    local previousName = category:GetName()
    AddonNS.CategoryStore:Rename(category.id, newName)
    fireUpdate()
    AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CUSTOM_CATEGORY_RENAMED, category.id, newName, previousName)
end

function UserCategories:DeleteCategory(categoryOrId)
    local category = resolveCategoryIdentifier(categoryOrId)
    if not category then
        return
    end
    AddonNS.CategoryStore:Delete(category.id)
    fireUpdate()
    AddonNS.Events:TriggerCustomEvent(AddonNS.Const.Events.CUSTOM_CATEGORY_DELETED, category.id)
end

function UserCategories:AssignToCategory(categoryOrId, itemID)
    if not itemID then
        return
    end
    local category = resolveCategoryIdentifier(categoryOrId)
    if category and category:IsProtected() then
        return
    end
    if category then
        AddonNS.CategoryStore:AssignItem(itemID, category.id)
    else
        AddonNS.CategoryStore:UnassignItem(itemID)
    end
    fireUpdate()
end

function UserCategories:AssignToCategoryByName(name, itemID)
    local category = AddonNS.Categories:GetCategoryByName(name)
    if category and category.id == AddonNS.CategoryStore:GetUnassigned().id then
        category = nil
    end
    self:AssignToCategory(category, itemID)
end

ensureHooks()
