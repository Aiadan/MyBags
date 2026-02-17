local fetchedBankType = nil

_G.Enum = {
    BankType = {
        Character = 1,
        Account = 2,
    },
}

_G.C_Bank = {
    FetchPurchasedBankTabData = function(bankType)
        fetchedBankType = bankType
        return {
            { ID = 41, name = "Fetched A" },
            { ID = 42, name = "Fetched B" },
        }
    end,
}

_G.C_Container = {
    GetContainerNumSlots = function(tabID)
        if tabID == 10 then
            return 2
        end
        if tabID == 20 then
            return 1
        end
        return 0
    end,
}

_G.CreateFrame = function()
    return {}
end

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
    printDebug = function() end,
}

local bankViewChunk = assert(loadfile("bankView.lua"))
bankViewChunk("MyBags", addonEnv)
local hooks = assert(addonEnv.BankViewTestHooks, "BankViewTestHooks should be exposed")

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTrue(condition, message)
    if not condition then
        error(message or "assertion failed", 2)
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

run("getPurchasedTabIdsForActiveType prefers panel cached data", function()
    fetchedBankType = nil
    local panel = {
        purchasedBankTabData = {
            { ID = 11, name = "First" },
            { ID = 12, name = "Second" },
        },
        GetActiveBankType = function()
            return Enum.BankType.Character
        end,
    }

    local tabIds, tabData = hooks.GetPurchasedTabIdsForActiveType(panel)
    assertEqual(#tabIds, 2, "two tab IDs should be returned")
    assertEqual(tabIds[1], 11, "first tab ID")
    assertEqual(tabIds[2], 12, "second tab ID")
    assertEqual(#tabData, 2, "tab data should mirror panel cache")
    assertEqual(fetchedBankType, nil, "FetchPurchasedBankTabData should not be used when panel cache is present")
end)

run("getPurchasedTabIdsForActiveType fetches data when panel cache is missing", function()
    local panel = {
        purchasedBankTabData = nil,
        GetActiveBankType = function()
            return Enum.BankType.Account
        end,
    }

    local tabIds = hooks.GetPurchasedTabIdsForActiveType(panel)
    assertEqual(#tabIds, 2, "fetched tab IDs should be returned")
    assertEqual(tabIds[1], 41, "first fetched tab ID")
    assertEqual(tabIds[2], 42, "second fetched tab ID")
    assertEqual(fetchedBankType, Enum.BankType.Account, "FetchPurchasedBankTabData should use panel active type")
end)

run("BuildVisibleTabIds returns a fast lookup set", function()
    local visible = hooks.BuildVisibleTabIds({ 3, 7, 11 })
    assertTrue(visible[3] == true, "tab 3 should be visible")
    assertTrue(visible[7] == true, "tab 7 should be visible")
    assertTrue(visible[11] == true, "tab 11 should be visible")
    assertTrue(visible[1] == nil, "other tabs should not be marked visible")
end)

run("ShouldRefreshForBagUpdate refreshes for nil and visible tab IDs only", function()
    local visible = hooks.BuildVisibleTabIds({ 6, 9 })
    assertTrue(hooks.ShouldRefreshForBagUpdate(visible, nil), "nil bagID should refresh")
    assertTrue(hooks.ShouldRefreshForBagUpdate(visible, 6), "visible tab should refresh")
    assertTrue(not hooks.ShouldRefreshForBagUpdate(visible, 5), "non-visible tab should not refresh")
end)

run("GenerateAllTabItemButtons creates buttons for all slots from all tabs", function()
    local inits = {}
    local acquireCount = 0
    local releaseCount = 0
    local panel = {
        itemButtonPool = {
            ReleaseAll = function()
                releaseCount = releaseCount + 1
            end,
            Acquire = function()
                acquireCount = acquireCount + 1
                return {
                    Init = function(_, bankType, tabID, slotID)
                        table.insert(inits, { bankType = bankType, tabID = tabID, slotID = slotID })
                    end,
                    Show = function() end,
                }
            end,
        },
    }

    hooks.GenerateAllTabItemButtons(panel, Enum.BankType.Character, { 10, 20 })
    assertEqual(releaseCount, 1, "pool should be reset once")
    assertEqual(acquireCount, 3, "should acquire one button per slot across all tabs")
    assertEqual(inits[1].tabID, 10, "first init tabID")
    assertEqual(inits[1].slotID, 1, "first init slot")
    assertEqual(inits[2].slotID, 2, "second init slot in first tab")
    assertEqual(inits[3].tabID, 20, "third init tabID")
    assertEqual(inits[3].slotID, 1, "first slot in second tab")
    assertEqual(inits[3].bankType, Enum.BankType.Character, "active bank type should be forwarded")
end)

run("BuildItemButtonsSignature includes bank type and per-tab slot counts", function()
    local signature = hooks.BuildItemButtonsSignature(Enum.BankType.Character, { 10, 20 })
    assertEqual(signature, "1|10:2|20:1", "signature should include active type and tab:slot pairs")
end)

run("HasAnyActiveItemButtons reports whether enumeration has entries", function()
    local emptyPanel = {
        EnumerateValidItems = function()
            return function()
                return nil
            end
        end,
    }
    local populatedPanel = {
        EnumerateValidItems = function()
            local done = false
            return function()
                if done then
                    return nil
                end
                done = true
                return {}
            end
        end,
    }
    assertTrue(not hooks.HasAnyActiveItemButtons(emptyPanel), "empty enumeration should report false")
    assertTrue(hooks.HasAnyActiveItemButtons(populatedPanel), "non-empty enumeration should report true")
end)

run("CountActiveItemButtons counts all enumerated buttons", function()
    local panel = {
        EnumerateValidItems = function()
            local index = 0
            return function()
                index = index + 1
                if index <= 3 then
                    return {}
                end
                return nil
            end
        end,
    }
    assertEqual(hooks.CountActiveItemButtons(panel), 3, "active button count should match enumeration size")
end)

run("CountExpectedButtonsForTabs sums slots across all tabs", function()
    assertEqual(hooks.CountExpectedButtonsForTabs({ 10, 20 }), 3, "expected buttons should sum all visible tab slots")
end)
