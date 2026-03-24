local addonName, AddonNS = ...

AddonNS.SortOrder = {}
local SortOrder = AddonNS.SortOrder

local compiledSortOrders = {}

local function trim(text)
    return text:match("^%s*(.-)%s*$")
end

-- Parse a sort expression into a list of { func, isAscending } clauses.
-- Returns: clauses list (may be empty), or nil + errorMsg on failure.
function SortOrder:ParseSortExpression(text)
    if not text or trim(text) == "" then
        return {}, nil
    end

    local retrievers = AddonNS.QueryCategories and AddonNS.QueryCategories.RetrieversByLowerName
    if not retrievers then
        return nil, "Query retrievers not available"
    end

    local clauses = {}
    for clauseText in (text .. ";"):gmatch("([^;]*);") do
        clauseText = trim(clauseText)
        if clauseText ~= "" then
            local attrName, direction = clauseText:match("^(%S+)%s+(%S+)$")
            if not attrName then
                return nil, "Invalid clause: \"" .. clauseText .. "\". Expected: attributeName ASC|DESC"
            end
            local dirUpper = string.upper(direction)
            if dirUpper ~= "ASC" and dirUpper ~= "DESC" then
                return nil, "Invalid direction \"" .. direction .. "\" in clause \"" .. clauseText .. "\". Expected ASC or DESC"
            end
            local descriptor = retrievers[string.lower(attrName)]
            if not descriptor then
                return nil, "Unknown attribute \"" .. attrName .. "\""
            end
            table.insert(clauses, {
                func = descriptor.func,
                isAscending = (dirUpper == "ASC"),
            })
        end
    end

    return clauses, nil
end

-- Compile a sort comparator from expression text.
-- Returns: comparatorFn or nil, errorMsg (both nil when text is empty).
function SortOrder:CompileSortComparator(text)
    if not text or trim(text) == "" then
        return nil, nil
    end

    local clauses, err = self:ParseSortExpression(text)
    if err then
        return nil, err
    end
    if #clauses == 0 then
        return nil, nil
    end

    local function comparator(payloadA, payloadB)
        for _, clause in ipairs(clauses) do
            local valA = clause.func(payloadA)
            local valB = clause.func(payloadB)

            -- nil sorts last regardless of direction
            if valA == nil and valB == nil then
                -- equal on this clause, continue
            elseif valA == nil then
                return false  -- A is nil → A goes after B
            elseif valB == nil then
                return true   -- B is nil → B goes after A
            else
                local less
                local typeA = type(valA)
                if typeA == "boolean" then
                    if valA ~= valB then
                        less = (not valA)  -- false < true
                    end
                elseif typeA == "number" then
                    if valA ~= valB then
                        less = valA < valB
                    end
                else
                    local lowerA = string.lower(tostring(valA))
                    local lowerB = string.lower(tostring(valB))
                    if lowerA ~= lowerB then
                        less = lowerA < lowerB
                    end
                end

                if less ~= nil then
                    if clause.isAscending then
                        return not less
                    else
                        return less
                    end
                end
                -- equal on this clause, continue to next
            end
        end
        return false  -- all clauses equal; stable
    end

    return comparator, nil
end

-- Validate expression text. Returns nil if valid, error string if invalid.
-- Empty string is valid (means no sort).
function SortOrder:ValidateExpression(text)
    if not text or trim(text) == "" then
        return nil
    end
    local _, err = self:ParseSortExpression(text)
    return err
end

-- Update or clear the cached comparator for a rawId.
function SortOrder:SyncCompiledSortOrder(rawId, text)
    if not rawId then
        return
    end
    if not text or trim(text) == "" then
        compiledSortOrders[rawId] = nil
        return
    end
    local fn = self:CompileSortComparator(text)
    compiledSortOrders[rawId] = fn or nil
end

-- Return the cached comparator for a rawId, or nil.
function SortOrder:GetCompiledSortComparator(rawId)
    if not rawId then
        return nil
    end
    return compiledSortOrders[rawId]
end

-- Set and cache the default sort expression.
function SortOrder:SetDefaultSortExpression(text)
    if not text or trim(text) == "" then
        compiledSortOrders["__default__"] = nil
        return
    end
    local fn = self:CompileSortComparator(text)
    compiledSortOrders["__default__"] = fn or nil
end

-- Return the cached default sort comparator, or nil.
function SortOrder:GetDefaultCompiledSortComparator()
    return compiledSortOrders["__default__"]
end

-- Sort an item button list in-place using the given comparator.
function SortOrder:SortItemButtons(itemButtonsList, comparator)
    if not itemButtonsList or #itemButtonsList <= 1 then
        return
    end
    if itemButtonsList[1] == AddonNS.itemButtonPlaceholder then
        return
    end

    -- Build payload map up front to avoid repeated calls inside comparator.
    local payloadMap = {}
    for _, itemButton in ipairs(itemButtonsList) do
        local itemId = itemButton._myBagsItemId
        if itemId then
            payloadMap[itemButton] = AddonNS.CustomCategories:GetItemQueryPayload(itemId, itemButton)
        end
    end

    table.sort(itemButtonsList, function(itemButtonA, itemButtonB)
        local payloadA = payloadMap[itemButtonA]
        local payloadB = payloadMap[itemButtonB]
        if payloadA and payloadB then
            return comparator(payloadA, payloadB)
        end
        -- Fallback: sort by item ID
        local idA = itemButtonA._myBagsItemId
        local idB = itemButtonB._myBagsItemId
        if idA and idB then
            return idA < idB
        end
        return false
    end)
end

AddonNS._Test = AddonNS._Test or {}
AddonNS._Test.SortOrder = {
    ParseSortExpression = function(text) return SortOrder:ParseSortExpression(text) end,
    CompileSortComparator = function(text) return SortOrder:CompileSortComparator(text) end,
}
