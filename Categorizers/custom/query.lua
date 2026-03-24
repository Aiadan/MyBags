local addonName, AddonNS = ...

AddonNS = AddonNS or {}
AddonNS.QueryCategories = AddonNS.QueryCategories or {}

local ValueType = {
    STRING = 1,
    NUMBER = 2,
    BOOL = 3,
}

local function trim(text)
    return text:match("^%s*(.-)%s*$")
end

local OpEnum = { AND = 1, OR = 2, NOT = 3 };

local function unescapeQuotedString(text)
    return (string.gsub(text, "\\(.)", "%1"))
end

local function protectQuotedValues(query)
    local placeholders = {}
    local out = {}
    local index = 1
    local length = #query
    local placeholderIndex = 0

    while index <= length do
        local character = query:sub(index, index)
        if character ~= "\"" then
            table.insert(out, character)
            index = index + 1
        else
            local endIndex = index + 1
            local isEscaped = false
            while endIndex <= length do
                local current = query:sub(endIndex, endIndex)
                if current == "\\" and not isEscaped then
                    isEscaped = true
                elseif current == "\"" and not isEscaped then
                    break
                else
                    isEscaped = false
                end
                endIndex = endIndex + 1
            end

            if endIndex > length then
                table.insert(out, character)
                index = index + 1
            else
                local value = unescapeQuotedString(query:sub(index + 1, endIndex - 1))
                placeholderIndex = placeholderIndex + 1
                local token = "__MYBAGS_QUOTED_" .. placeholderIndex .. "__"
                placeholders[token] = value
                table.insert(out, token)
                index = endIndex + 1
            end
        end
    end

    return table.concat(out), placeholders
end

local function prepare(query)
    local quotedValues
    query, quotedValues = protectQuotedValues(query)
    query = string.gsub(query, "%(", " ( ")
    query = string.gsub(query, "%)", " ) ")
    query = string.gsub(query, "([%=%!%~%<%>]+)", " %1 ")
    query = string.gsub(query, " ~= ", " != ")
    query = string.gsub(query, " <> ", " != ")
    query = string.gsub(query, " [Aa][Nn][Dd] ", " AND ")
    query = string.gsub(query, " [Aa][Nn][Dd] ", " AND ")
    query = string.gsub(query, " [Nn][Oo][Tt] ", " NOT ")
    query = string.gsub(query, " [Oo][Rr] ", " OR ")
    query = string.gsub(query, "%s%s+", " ")
    return query, quotedValues
end

local function parseBoolValue(text)
    if text == "true" then
        return true
    end
    if text == "false" then
        return false
    end
    return nil
end

local function isValidLuaPattern(value)
    local success = pcall(string.match, "", value)
    return success
end

local Comparators = {
    [ValueType.STRING] = {
        ["="] = {
            createNew = function(retriver, value)
                local loweredValue = string.lower(value)
                if not isValidLuaPattern(loweredValue) then
                    return nil
                end
                return function(itemInfo)
                    local candidate = retriver(itemInfo)
                    if type(candidate) ~= "string" then
                        return false
                    end
                    return string.lower(candidate):match(loweredValue) ~= nil
                end
            end,
        },
        ["!="] = {
            createNew = function(retriver, value)
                local loweredValue = string.lower(value)
                if not isValidLuaPattern(loweredValue) then
                    return nil
                end
                return function(itemInfo)
                    local candidate = retriver(itemInfo)
                    if type(candidate) ~= "string" then
                        return true
                    end
                    return string.lower(candidate):match(loweredValue) == nil
                end
            end,
        },
    },
    [ValueType.NUMBER] = {
        ["="] = {
            createNew = function(retriver, value)
                local numberValue = tonumber(value)
                if not numberValue then
                    return nil
                end
                return function(itemInfo)
                    return retriver(itemInfo) == numberValue
                end
            end,
        },
        ["!="] = {
            createNew = function(retriver, value)
                local numberValue = tonumber(value)
                if not numberValue then
                    return nil
                end
                return function(itemInfo)
                    return retriver(itemInfo) ~= numberValue
                end
            end,
        },
        [">"] = {
            createNew = function(retriver, value)
                local numberValue = tonumber(value)
                if not numberValue then
                    return nil
                end
                return function(itemInfo)
                    local candidate = retriver(itemInfo)
                    if type(candidate) ~= "number" then
                        return false
                    end
                    return candidate > numberValue
                end
            end,
        },
        [">="] = {
            createNew = function(retriver, value)
                local numberValue = tonumber(value)
                if not numberValue then
                    return nil
                end
                return function(itemInfo)
                    local candidate = retriver(itemInfo)
                    if type(candidate) ~= "number" then
                        return false
                    end
                    return candidate >= numberValue
                end
            end,
        },
        ["<"] = {
            createNew = function(retriver, value)
                local numberValue = tonumber(value)
                if not numberValue then
                    return nil
                end
                return function(itemInfo)
                    local candidate = retriver(itemInfo)
                    if type(candidate) ~= "number" then
                        return false
                    end
                    return candidate < numberValue
                end
            end,
        },
        ["<="] = {
            createNew = function(retriver, value)
                local numberValue = tonumber(value)
                if not numberValue then
                    return nil
                end
                return function(itemInfo)
                    local candidate = retriver(itemInfo)
                    if type(candidate) ~= "number" then
                        return false
                    end
                    return candidate <= numberValue
                end
            end,
        },
    },
    [ValueType.BOOL] = {
        ["="] = {
            createNew = function(retriver, value)
                local boolValue = parseBoolValue(value)
                if boolValue == nil then
                    return nil
                end
                return function(itemInfo)
                    return boolValue == retriver(itemInfo)
                end
            end,
        },
        ["!="] = {
            createNew = function(retriver, value)
                local boolValue = parseBoolValue(value)
                if boolValue == nil then
                    return nil
                end
                return function(itemInfo)
                    return boolValue ~= retriver(itemInfo)
                end
            end,
        },
    },
}

local Retrievers = {
    stackCount = { type = ValueType.NUMBER },
    expansionID = { type = ValueType.NUMBER },
    quality = { type = ValueType.NUMBER },
    isReadable = { type = ValueType.BOOL },
    hasLoot = { type = ValueType.BOOL },
    hasNoValue = { type = ValueType.BOOL },
    itemID = { type = ValueType.NUMBER },
    isBound = { type = ValueType.BOOL },
    itemName = { type = ValueType.STRING },
    ilvl = { type = ValueType.NUMBER },
    itemMinLevel = { type = ValueType.NUMBER },
    itemType = { type = ValueType.NUMBER },
    itemSubType = { type = ValueType.NUMBER },
    inventoryType = { type = ValueType.NUMBER },
    sellPrice = { type = ValueType.NUMBER },
    isCraftingReagent = { type = ValueType.BOOL },
    isQuestItem = { type = ValueType.BOOL },
    questID = { type = ValueType.NUMBER },
    isQuestItemActive = { type = ValueType.BOOL },
    bindType = { type = ValueType.NUMBER },
    isAnimaItem = { type = ValueType.BOOL },
    isArtifactPowerItem = { type = ValueType.BOOL },
    isCorruptedItem = { type = ValueType.BOOL },
    isWarbound = { type = ValueType.BOOL },
    description = { type = ValueType.STRING },
    isTransmogCollected = { type = ValueType.BOOL },
    upgradeTrack = { type = ValueType.STRING },
    upgradeTrackID = { type = ValueType.NUMBER },
    upgradeLevel = { type = ValueType.NUMBER },
    upgradeMaxLevel = { type = ValueType.NUMBER },
    isWrongArmorType = { type = ValueType.BOOL },
    isWrongPrimaryStat = { type = ValueType.BOOL },
}

local QueryTooltipDefinitions = {
    order = {
        
        "itemType",
        "itemSubType",
        "inventoryType",
        "expansionID",
        "isCraftingReagent",
        "isWarbound",
        "isBound",
        "isQuestItem",
        "isAnimaItem",
        "isArtifactPowerItem",
        "isCorruptedItem",
        "isTransmogCollected",
        "isWrongArmorType",
        "isWrongPrimaryStat",
        "upgradeTrack",
        "upgradeLevel",
        "upgradeMaxLevel",
        "upgradeTrackID",
        "isReadable",
        "isQuestItemActive",
        "quality",
        "hasLoot",
        "bindType",
        "hasNoValue",
        "sellPrice",
        "stackCount",
        "itemName",
        "description",
        "ilvl",
        "itemMinLevel",
        "questID",
        "itemID",
        
    },
    descriptions = {
        -- stackCount = "Item stack size",
        -- expansionID = "Item expansion id",
        -- quality = "Item quality",
        -- isReadable = "Item can be read",
        -- hasLoot = "Item contains loot",
        -- hasNoValue = "True if item cannot be sold",
        -- itemID = "Item id",
        -- isBound = "Item is bound",
        -- itemName = "Item name",
        -- ilvl = "Item level",
        -- itemMinLevel = "Character required level",
        -- itemType = "Item class",
        -- itemSubType = "Item subclass",
        -- inventoryType = "Equip slot type",
        -- sellPrice = "Vendor sell price",
        -- isCraftingReagent = "Crafting reagent flag",
        -- isQuestItem = "Quest item flag",
        -- questID = "Quest id",
        -- isQuestItemActive = "Quest active flag",
        -- isAnimaItem = "True when the item is an anima item",
        -- isArtifactPowerItem = "True when the item is an artifact power item",
        -- isCorruptedItem = "True when the item is a corrupted item",
        -- isWarbound = "True when the item is warbound (bound to account until equipped)",
        -- isTransmogCollected = "True when the item's transmog source is collected",
        -- bindType = "Bind type",
        -- description = "Item description text",
    },
    valueLabels = {

        hasNoValue = {
            [true] ="Item cannot be sold",
            [false] = "Item can be sold"
        },
        expansionID = {
            [0] = "Classic",
            [1] = "The Burning Crusade",
            [2] = "Wrath of the Lich King",
            [3] = "Cataclysm",
            [4] = "Mists of Pandaria",
            [5] = "Warlords of Draenor",
            [6] = "Legion",
            [7] = "Battle for Azeroth",
            [8] = "Shadowlands",
            [9] = "Dragonflight",
            [10] = "The War Within",
            [11] = "Midnight",
            [12] = "The Last Titan",
        },
        quality = {
            [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic", [5] = "Legendary",
            [6] = "Artifact", [7] = "Heirloom", [8] = "WoWToken",
        },
        itemType = {
            [0] = "Consumable", [1] = "Container", [2] = "Weapon", [3] = "Gem", [4] = "Armor", [5] = "Reagent",
            [6] = "Projectile", [7] = "Tradegoods", [8] = "Item Enhancement", [9] = "Recipe", [10] = "Currency Token",
            [11] = "Quiver", [12] = "Quest item", [13] = "Key", [14] = "Permanent", [15] = "Miscellaneous",
            [16] = "Glyph", [17] = "Battlepet", [18] = "WoW Token", [19] = "Profession", [20] = "Housing",
        },
        inventoryType = {
            [0] = "Non Equip", [1] = "Head", [2] = "Neck", [3] = "Shoulder", [4] = "Body", [5] = "Chest", [6] = "Waist",
            [7] = "Legs", [8] = "Feet", [9] = "Wrist", [10] = "Hand", [11] = "Finger", [12] = "Trinket", [13] = "Weapon",
            [14] = "Shield", [15] = "Ranged", [16] = "Cloak", [17] = "Two Hand Weapon", [18] = "Bag", [19] = "Tabard",
            [20] = "Robe", [21] = "Main Hand Weapon", [22] = "Off Hand Weapon", [23] = "Holdable", [24] = "Ammo",
            [25] = "Thrown", [26] = "Ranged Right", [27] = "Quiver", [28] = "Relic", [29] = "Profession Tool",
            [30] = "Profession Gear", [31] = "Equipable Spell Offensive", [32] = "Equipable Spell Utility",
            [33] = "Equipable Spell Defensive", [34] = "Equipable Spell Weapon",
        },
        bindType = {
            [0] = "None", [1] = "Bind on Pickup", [2] = "Bind on Equip",
            [3] = "Bind on Use", [4] = "Quest", [5] = "Unused1", [6] = "Unused2",
            [7] = "ToWoWAccount", [8] = "ToBnetAccount", [9] = "ToBnetAccountUntilEquipped",
        },
    },
    itemSubTypeLabelsByItemType = {
        [0] = {
            [0] = "Generic", [1] = "Potion", [2] = "Elixir", [3] = "Flasks / phials", [4] = "Scroll", [5] = "Food / drink",
            [6] = "Item enhancement", [7] = "Bandage", [8] = "Other", [9] = "Vantus Rune", [10] = "Utility Curio",
            [11] = "Combat Curio", [12] = "Relic",
        },
        [1] = {
            [0] = "Bag", [1] = "Soul Bag", [2] = "Herb Bag", [3] = "Enchanting Bag", [4] = "Engineering Bag",
            [5] = "Gem Bag", [6] = "Mining Bag", [7] = "Leatherworking Bag", [8] = "Inscription Bag", [9] = "Tackle Box",
            [10] = "Cooking Bag",
        },
        [2] = {
            [0] = "Axe 1H", [1] = "Axe 2H", [2] = "Bows", [3] = "Guns", [4] = "Mace 1H", [5] = "Mace 2H",
            [6] = "Polearm", [7] = "Sword 1H", [8] = "Sword 2H", [9] = "Warglaive", [10] = "Staff", [11] = "Bearclaw",
            [12] = "Catclaw", [13] = "Unarmed", [14] = "Generic", [15] = "Dagger", [16] = "Thrown", [17] = "Obsolete",
            [18] = "Crossbow", [19] = "Wand", [20] = "Fishingpole",
        },
        [3] = {
            [0] = "Intellect", [1] = "Agility", [2] = "Strength", [3] = "Stamina", [4] = "Spirit", [5] = "Critical Strike",
            [6] = "Mastery", [7] = "Haste", [8] = "Versatility", [9] = "Other", [10] = "Multiple stats", [11] = "Artifact / relic",
        },
        [4] = {
            [0] = "Generic", [1] = "Cloth", [2] = "Leather", [3] = "Mail", [4] = "Plate", [5] = "Cosmetic",
            [6] = "Shield", [7] = "Libram", [8] = "Idol", [9] = "Totem", [10] = "Sigil", [11] = "Relic",
        },
        [5] = {
            [0] = "Reagent", [1] = "Keystone", [2] = "Context Token",
        },
        [6] = {
            [0] = "Wand", [1] = "Bolt", [2] = "Arrow", [3] = "Bullet", [4] = "Thrown",
        },
        [7] = {
            [0] = "Trade Goods", [1] = "Parts", [2] = "Explosives", [3] = "Devices",
            [4] = "Jewelcrafting", [5] = "Cloth", [6] = "Leather", [7] = "Metal Stone", [8] = "Cooking",
            [9] = "Herb", [10] = "Elemental", [11] = "Other", [12] = "Enchanting", [13] = "Materials",
            [14] = "Item Enchantment", [15] = "Weapon Enchantment", [16] = "Inscription",
            [17] = "Explosives & Devices", [18] = "Optional Reagents", [19] = "Finishing Reagents",
        },
        [8] = {
            [0] = "Head", [1] = "Neck", [2] = "Shoulder", [3] = "Cloak", [4] = "Chest", [5] = "Wrist",
            [6] = "Hands", [7] = "Waist", [8] = "Legs", [9] = "Feet", [10] = "Finger", [11] = "Weapon",
            [12] = "Two Handed Weapon", [13] = "Shield Offhand", [14] = "Misc", [15] = "Kit", [16] = "Artifact Relic",
        },
        [9] = {
            [0] = "Book", [1] = "Leatherworking", [2] = "Tailoring", [3] = "Engineering", [4] = "Blacksmithing",
            [5] = "Cooking", [6] = "Alchemy", [7] = "FirstAid", [8] = "Enchanting", [9] = "Fishing", [10] = "Jewelcrafting",
            [11] = "Inscription",
        },
        [10] = {
            [0] = "Money",
        },
        [11] = {
            [0] = "Quiver", [1] = "Ammo Pouch",
        },
        [12] = {
            [0] = "Quest",
        },
        [13] = {
            [0] = "Key",
        },
        [14] = {
            [0] = "Permanent",
        },
        [15] = {
            [0] = "Junk", [1] = "Reagent", [2] = "Companion Pet", [3] = "Holiday", [4] = "Other", [5] = "Mount",
            [6] = "MountEquipment",
        },
        [16] = {
            [1] = "Warrior", [2] = "Paladin", [3] = "Hunter", [4] = "Rogue", [5] = "Priest", [6] = "Death Knight",
            [7] = "Shaman", [8] = "Mage", [9] = "Warlock", [10] = "Monk", [11] = "Druid",
        },
        [17] = {
            [0] = "Humanoid", [1] = "Dragonkin", [2] = "Flying", [3] = "Undead", [4] = "Critter", [5] = "Magic",
            [6] = "Elemental", [7] = "Beast", [8] = "Aquatic", [9] = "Mechanical",
        },
        [18] = {
            [0] = "WoWToken",
        },
        [19] = {
            [0] = "Blacksmithing", [1] = "Leatherworking", [2] = "Alchemy", [3] = "Herbalism", [4] = "Cooking",
            [5] = "Mining", [6] = "Tailoring", [7] = "Engineering", [8] = "Enchanting", [9] = "Fishing", [10] = "Skinning",
            [11] = "Jewelcrafting", [12] = "Inscription", [13] = "Archaeology",
        },
        [20] = {
            [0] = "Decor", [1] = "Dye", [2] = "Room", [3] = "Room Customization", [4] = "Exterior Customization",
            [5] = "Service Item",
        },
    },
}

local function getTooltipValueMeaning(attributeName, value, payload)
    if attributeName == "itemSubType" and type(value) == "number" then
        local itemType = payload and payload.itemType or nil
        local byType = QueryTooltipDefinitions.itemSubTypeLabelsByItemType[itemType]
        if byType then
            return byType[value]
        end
    end
    local labels = QueryTooltipDefinitions.valueLabels[attributeName]
    if labels and labels[value] then
        return labels[value]
    end
    return QueryTooltipDefinitions.descriptions[attributeName]
end

local RetrieversByLowerName = {}

local function genericRetrieverFunction(name)
    return function(itemInfo)
        return itemInfo[name]
    end
end

for key, descriptor in pairs(Retrievers) do
    if not descriptor.func then
        descriptor.func = genericRetrieverFunction(key)
    end
    RetrieversByLowerName[string.lower(key)] = descriptor
end

local function GetRetriever(name, comparison, value)
    local descriptor = RetrieversByLowerName[string.lower(name)]
    if not descriptor then
        return nil
    end
    local comparatorFactory = Comparators[descriptor.type] and Comparators[descriptor.type][comparison]
    if not comparatorFactory then
        return nil
    end
    return comparatorFactory.createNew(descriptor.func, value)
end

local space = ""

local function parseLeafValue(value, quotedValues)
    local quotedPlaceholderValue = quotedValues and quotedValues[value]
    if quotedPlaceholderValue ~= nil then
        return quotedPlaceholderValue
    end

    local directQuotedValue = value:match("^\"(.*)\"$")
    if directQuotedValue ~= nil then
        return unescapeQuotedString(directQuotedValue)
    end

    return value
end

local function evaluateLeaf(leafQuery, quotedValues)
    leafQuery = trim(leafQuery)
    local name, comparison, value = leafQuery:match("^(%S+)%s+(%S+)%s+(.+)$")
    if not name then
        return nil
    end
    value = parseLeafValue(trim(value), quotedValues)
    return GetRetriever(name, comparison, value)
end

local function pumpUp()
    space = space .. "_ "
end

local function pumpDown()
    space = space:sub(3)
end

local function evaluate(query, quotedValues)
    query = trim(query)
    local andFunctions
    local orFunctions = {}
    local orFunction = function(itemInfo)
        if (#orFunctions == 0) then
            return false
        end
        for _, func in ipairs(orFunctions) do
            pumpUp()
            local result = func(itemInfo)
            pumpDown()
            if result then
                return true
            end
        end
        return false
    end
    local function newAndFunction()
        local localAndFunctions = {}
        andFunctions = localAndFunctions
        local andFunction = function(itemInfo)
            for _, func in ipairs(localAndFunctions) do
                pumpUp()
                local result = func(itemInfo)
                pumpDown()
                if not result then
                    return false
                end
            end
            return #localAndFunctions > 0
        end
        table.insert(orFunctions, andFunction)
    end
    newAndFunction()

    local tokenString
    local nextOp = OpEnum.AND

    while (#query > 0) do
        query = trim(query)
        tokenString = query:match("^%b()")
        if tokenString then
            local subQuery = tokenString:sub(2, -2)
            local func, isValid = evaluate(subQuery, quotedValues)
            if not isValid then
                return nil, false
            end
            local notFunc
            if nextOp then
                if nextOp == OpEnum.NOT then
                    notFunc = function(itemInfo)
                        return not func(itemInfo)
                    end
                end
                table.insert(andFunctions, notFunc or func)
            end
            nextOp = nil
        end
        if not tokenString then
            tokenString = query:match("^AND ")
            if tokenString then
                if not nextOp then
                    nextOp = OpEnum.AND
                end
            end
        end
        if not tokenString then
            tokenString = query:match("^OR ")
            if tokenString then
                if not nextOp then
                    nextOp = OpEnum.AND
                    newAndFunction()
                end
            end
        end
        if not tokenString then
            tokenString = query:match("^NOT ")
            if tokenString then
                if nextOp == OpEnum.AND then
                    nextOp = OpEnum.NOT
                end
            end
        end

        if not tokenString then
            local andTokenString = query:match("(.-) AND ")
            local orTokenString = query:match("(.-) OR ")
            local notTokenString = query:match("(.-) NOT ")
            local vanillaTokenString = query:match("(.*)")
            tokenString = andTokenString
            tokenString = tokenString and orTokenString and #orTokenString < #tokenString and orTokenString or
                (not tokenString and orTokenString or tokenString)
            tokenString = tokenString and notTokenString and #notTokenString < #tokenString and notTokenString or
                (not tokenString and notTokenString or tokenString)
            tokenString = tokenString and vanillaTokenString and #vanillaTokenString < #tokenString and vanillaTokenString or
                (not tokenString and vanillaTokenString or tokenString)
            if tokenString then
                local func = evaluateLeaf(tokenString, quotedValues)
                if not func then
                    return nil, false
                end
                local notFunc
                if nextOp then
                    if nextOp == OpEnum.NOT then
                        notFunc = function(itemInfo)
                            return not func(itemInfo)
                        end
                    end
                    table.insert(andFunctions, notFunc or func)
                end
                nextOp = nil
            end
        end
        if not tokenString then
            return nil, false
        end
        query = trim(query:sub(#tokenString + 1))
        tokenString = nil
    end

    if #orFunctions == 0 then
        return nil, false
    end
    return orFunction, true
end

local compiledQueries = {}

local function resolveRawId(categoryOrId)
    if not categoryOrId then
        return nil
    end
    if type(categoryOrId) == "table" and categoryOrId.GetId then
        local id = categoryOrId:GetId()
        local raw = id:match("^[^%-]+%-(.+)$")
        return raw or id
    end
    return categoryOrId
end

local function compileQuery(queryString)
    if not queryString or #trim(queryString) == 0 then
        return nil, false
    end
    local preparedQuery, quotedValues = prepare(queryString)
    local evaluator, isValid = evaluate(preparedQuery, quotedValues)
    if not isValid or not evaluator then
        return nil, false
    end
    return evaluator, true
end

local function storeCompiledQuery(rawId, queryString)
    if not rawId or not queryString or #trim(queryString) == 0 then
        if rawId then
            compiledQueries[rawId] = nil
        end
        return
    end
    local evaluator = compileQuery(queryString)
    compiledQueries[rawId] = evaluator
end

function AddonNS.QueryCategories:SyncCompiledQuery(categoryOrId, queryString)
    local rawId = resolveRawId(categoryOrId)
    if not rawId then
        return
    end
    storeCompiledQuery(rawId, queryString)
end

function AddonNS.QueryCategories:GetQuery(categoryOrId)
    local rawId = resolveRawId(categoryOrId)
    if not rawId then
        return ""
    end
    return AddonNS.CustomCategories:GetQuery(rawId)
end

function AddonNS.QueryCategories:SetQuery(categoryOrId, query)
    local rawId = resolveRawId(categoryOrId)
    if not rawId then
        return
    end
    AddonNS.CustomCategories:SetQuery(rawId, query)
end

function AddonNS.QueryCategories:DeleteQuery(categoryOrId)
    local rawId = resolveRawId(categoryOrId)
    if not rawId then
        return
    end
    AddonNS.CustomCategories:SetQuery(rawId, nil)
end

function AddonNS.QueryCategories:GetCategories()
    local categories = {}
    for _, rawId in ipairs(AddonNS.CustomCategories:GetQueryCategoryRawIds()) do
        categories[rawId] = true
    end
    return categories
end

function AddonNS.QueryCategories:GetCompiled(categoryOrId)
    local rawId = resolveRawId(categoryOrId)
    if not rawId then
        return nil
    end
    return compiledQueries[rawId]
end

function AddonNS.QueryCategories:CompileAdHoc(queryText)
    local evaluator = compileQuery(queryText)
    return evaluator
end

function AddonNS.QueryCategories:EvaluateSearchUnion(defaultMatch, evaluator, itemInfo)
    local queryMatch = false
    if evaluator and itemInfo then
        queryMatch = evaluator(itemInfo) == true
    end
    return defaultMatch or queryMatch, queryMatch
end

AddonNS.QueryCategories.TooltipAttributeDefinitions = QueryTooltipDefinitions
AddonNS.QueryCategories.RetrieversByLowerName = RetrieversByLowerName

function AddonNS.QueryCategories:GetTooltipAttributeRows(payload)
    local rows = {}
    if type(payload) ~= "table" then
        return rows
    end
    local order = QueryTooltipDefinitions.order
    for index = 1, #order do
        local attributeName = order[index]
        local value = payload[attributeName]
        if value ~= nil then
            rows[#rows + 1] = {
                name = attributeName,
                value = value,
                meaning = getTooltipValueMeaning(attributeName, value, payload),
            }
        end
    end
    return rows
end

AddonNS.Events:OnInitialize(function()
    for _, rawId in ipairs(AddonNS.CustomCategories:GetQueryCategoryRawIds()) do
        local query = AddonNS.CustomCategories:GetQuery(rawId)
        if query ~= "" then
            storeCompiledQuery(rawId, query)
        end
    end
end)

local function categoryDeleted(eventName, category)
    local rawId = resolveRawId(category)
    if rawId then
        compiledQueries[rawId] = nil
    end
end

AddonNS.Events:RegisterCustomEvent(AddonNS.Const.Events.CUSTOM_CATEGORY_DELETED, categoryDeleted)

AddonNS._Test = AddonNS._Test or {}
AddonNS._Test.Query = {
    prepare = prepare,
    evaluate = evaluate,
    compileQuery = compileQuery,
}
