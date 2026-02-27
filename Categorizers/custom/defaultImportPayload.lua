local addonName, AddonNS = ...

AddonNS.CustomDefaultImportPayload = {
    version = 1,
    categories = {
        -- quality = 0 means Poor quality items.
        { name = "Junk", query = "quality = 0", priority = 900, alwaysVisible = true, items = {} },
        -- isQuestItem marks quest-linked items; itemType = 12 is Questitem class.
        { name = "Quest", query = "isQuestItem = true OR itemType = 12", priority = 850, items = {} },
        -- isWarbound marks account-bound-until-equipped items, limited to not yet bound.
        { name = "Warbound", query = "isWarbound = true AND isBound = false", priority = 820, items = {} },
        -- bindType = 2 is Bind on Equip, limited to not yet bound/tradable.
        { name = "BoE", query = "bindType = 2 AND isBound = false", priority = 810, items = {} },
        -- isCraftingReagent marks reagent items; isBound=true keeps only already-bound ones.
        { name = "Reagents - Soulbound", query = "isCraftingReagent = true AND isBound = true", priority = 780, items = {} },
        -- isCraftingReagent marks reagent items; isBound=false keeps tradable ones.
        { name = "Reagents", query = "isCraftingReagent = true AND isBound = false", priority = 770, items = {} },
        -- itemType = 9 is Recipe class.
        { name = "Recipes", query = "itemType = 9", priority = 760, items = {} },
        -- itemType = 3 is Gem class.
        { name = "Gems", query = "itemType = 3", priority = 730, items = {} },
        -- itemType = 0 is Consumable; subtype 1=Potion, 3=Flasksphials, 5=Fooddrink.
        { name = "Potions/Flasks/Food", query = "itemType = 0 AND (itemSubType = 1 OR itemSubType = 3 OR itemSubType = 5)", priority = 725, items = {} },
        -- itemType 2 is Weapon, itemType 4 is Armor.
        { name = "Armor & Weapons", query = "itemType = 2 OR itemType = 4", priority = 715, items = {} },
        -- Weapon/Armor that can be transmogged and are not yet collected; excludes neck/ring/trinket slots.
        { name = "Uncollected Transmog", query = " isTransmogCollected = false", priority = 1716, items = {} },
        -- Manual teleport/hearthstone utility item IDs copied from user profile.
        { name = "Teleport", priority = 712, items = { 147869, 37863, 63207, 63353, 208066, 217956, 18149, 217930, 41255, 44655, 200613, 110560, 6948, 140192, 173373, 65274, 46874, 21711, 180817, 234389, 116413, 249699, 250411, 238727 } },
        -- itemType = 15 is Miscellaneous; subtype 2=CompanionPet and 5=Mount.
        { name = "Mounts & Pets", query = "itemType = 15 AND (itemSubType = 2 OR itemSubType > 4)", priority = 720, items = {} },
        -- itemType = 0 is Consumable; subtype 10=UtilityCurio and 11=CombatCurio.
        { name = "Curios", query = "itemType = 0 AND (itemSubType = 10 OR itemSubType = 11)", priority = 710, items = {} },
        -- itemType = 20 is Housing class.
        { name = "Decor", query = "itemType = 20", priority = 700, items = {} },
        -- hasLoot catches loot-containing items; plus consumable subtype 8 (Other) and armor subtype 5 (Cosmetic).
        { name = "Caches / One-time Use", query = "hasLoot = true OR (itemType = 0 AND itemSubType = 8) OR (itemType = 4 AND itemSubType = 5)", priority = 690, items = {} },
    },
}

AddonNS.CustomDefaultLayoutColumns = {
    { "new-singleton", "Caches / One-time Use","Decor", "Mounts & Pets", "Quest", "Gems", "Recipes" },
    { "Potions/Flasks/Food", "Teleport", "Curios", "BoE", "Uncollected Transmog", "Armor & Weapons", "Warbound" },
    { "Reagents", "Reagents - Soulbound", "unassigned", "Junk" },
}
