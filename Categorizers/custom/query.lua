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

local function toboolean(text)
    return text == "true" and true or false
end

local Comparators = {
    [ValueType.STRING] = {
        ["="] = {
            createNew = function(retriver, value)
                return function(itemInfo)
                    local candidate = retriver(itemInfo)
                    if type(candidate) ~= "string" then
                        return false
                    end
                    return candidate:match(value) ~= nil
                end
            end,
        },
        ["!="] = {
            createNew = function(retriver, value)
                return function(itemInfo)
                    local candidate = retriver(itemInfo)
                    if type(candidate) ~= "string" then
                        return true
                    end
                    return candidate:match(value) == nil
                end
            end,
        },
    },
    [ValueType.NUMBER] = {
        ["="] = {
            createNew = function(retriver, value)
                local numberValue = tonumber(value)
                return function(itemInfo)
                    return retriver(itemInfo) == numberValue
                end
            end,
        },
        ["!="] = {
            createNew = function(retriver, value)
                local numberValue = tonumber(value)
                return function(itemInfo)
                    return retriver(itemInfo) ~= numberValue
                end
            end,
        },
        [">"] = {
            createNew = function(retriver, value)
                local numberValue = tonumber(value)
                return function(itemInfo)
                    return retriver(itemInfo) > numberValue
                end
            end,
        },
        [">="] = {
            createNew = function(retriver, value)
                local numberValue = tonumber(value)
                return function(itemInfo)
                    return retriver(itemInfo) >= numberValue
                end
            end,
        },
        ["<"] = {
            createNew = function(retriver, value)
                local numberValue = tonumber(value)
                return function(itemInfo)
                    return retriver(itemInfo) < numberValue
                end
            end,
        },
        ["<="] = {
            createNew = function(retriver, value)
                local numberValue = tonumber(value)
                return function(itemInfo)
                    return retriver(itemInfo) <= numberValue
                end
            end,
        },
    },
    [ValueType.BOOL] = {
        ["="] = {
            createNew = function(retriver, value)
                local boolValue = toboolean(value)
                return function(itemInfo)
                    return boolValue == retriver(itemInfo)
                end
            end,
        },
        ["!="] = {
            createNew = function(retriver, value)
                local boolValue = toboolean(value)
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
}

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
        return function()
            return false
        end
    end
    local comparatorFactory = Comparators[descriptor.type] and Comparators[descriptor.type][comparison]
    if not comparatorFactory then
        return function()
            return false
        end
    end
    return comparatorFactory.createNew(descriptor.func, value)
end

local alwaysFalse = function()
    return false
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
        return alwaysFalse
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
            local func = evaluate(subQuery, quotedValues)
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
            return alwaysFalse
        end
        query = trim(query:sub(#tokenString + 1))
        tokenString = nil
    end

    return orFunction
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

local function storeCompiledQuery(rawId, queryString)
    if not rawId or not queryString or #trim(queryString) == 0 then
        if rawId then
            compiledQueries[rawId] = nil
        end
        return
    end
    compiledQueries[rawId] = evaluate(prepare(queryString))
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
}
