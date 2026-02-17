local addonEnv = {
    Const = {
        ITEM_SPACING = 4,
        CATEGORY_HEIGHT = 20,
        ITEMS_PER_ROW = 4,
        COLUMN_SPACING = 12,
        Events = {
            COLLAPSED_CHANGED = "COLLAPSED_CHANGED",
            CATEGORIZER_CATEGORIES_UPDATED = "CATEGORIZER_CATEGORIES_UPDATED",
        },
    },
    Events = {
        OnInitialize = function() end,
    },
    CustomCategories = {
        GetItemQueryPayload = function(_, itemID)
            return { itemID = itemID, itemType = itemID }
        end,
    },
    QueryCategories = {
        EvaluateSearchUnion = function(_, defaultMatch, evaluator, payload)
            if defaultMatch then
                return true, false
            end
            local queryMatch = evaluator(payload)
            return queryMatch, queryMatch
        end,
        CompileAdHoc = function(_, queryText)
            if queryText == "itemType = 42" then
                return function(payload)
                    return payload.itemType == 42
                end
            end
            return nil
        end,
    },
    printDebug = function() end,
}

_G.C_Container = {
    GetContainerItemInfo = function(bagID, slotID)
        if bagID == 1 and slotID == 1 then
            return { itemID = 42, isFiltered = true }
        end
        if bagID == 1 and slotID == 2 then
            return { itemID = 9, isFiltered = true }
        end
        return nil
    end,
}

local bankViewChunk = assert(loadfile("bankView.lua"))
bankViewChunk("MyBags", addonEnv)
local hooks = assert(addonEnv.BankViewTestHooks, "BankViewTestHooks should be exposed")

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function run(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if ok then
        print("✓ " .. name)
    else
        print("✗ " .. name)
        error(err)
    end
end

run("evaluateSearchVisibility keeps default matches without query flag", function()
    local includeInSearch, queryMatch = hooks.EvaluateSearchVisibility(true, function() return true end, { itemID = 7 }, {})
    assertEqual(includeInSearch, true, "default match should be included")
    assertEqual(queryMatch, false, "default match should not mark query match")
end)

run("evaluateSearchVisibility includes query-only matches", function()
    local includeInSearch, queryMatch = hooks.EvaluateSearchVisibility(false, function(payload)
        return payload.itemType == 42
    end, { itemID = 42 }, {})
    assertEqual(includeInSearch, true, "query-only match should be included")
    assertEqual(queryMatch, true, "query-only match should mark query match")
end)

run("evaluateSearchVisibility excludes when default and query both fail", function()
    local includeInSearch, queryMatch = hooks.EvaluateSearchVisibility(false, function() return false end, { itemID = 9 }, {})
    assertEqual(includeInSearch, false, "item should be excluded when no branch matches")
    assertEqual(queryMatch, false, "query match should be false when evaluator fails")
end)

run("applySearchUnionMatchState updates visible bank buttons with query-union matches", function()
    local firstButtonMatchState = nil
    local secondButtonMatchState = nil
    local panel = {
        EnumerateValidItems = function()
            local items = {
                {
                    GetBagID = function() return 1 end,
                    GetID = function() return 1 end,
                    SetMatchesSearch = function(_, value) firstButtonMatchState = value end,
                },
                {
                    GetBagID = function() return 1 end,
                    GetID = function() return 2 end,
                    SetMatchesSearch = function(_, value) secondButtonMatchState = value end,
                },
            }
            local index = 0
            return function()
                index = index + 1
                return items[index]
            end
        end,
    }

    hooks.ApplySearchUnionMatchState(panel, addonEnv.QueryCategories:CompileAdHoc("itemType = 42"))
    assertEqual(firstButtonMatchState, true, "query-only match should be undimmed")
    assertEqual(secondButtonMatchState, true, "non-matching item is also undimmed by design")
end)
