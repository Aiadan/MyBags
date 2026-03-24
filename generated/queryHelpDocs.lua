local addonName, AddonNS = ...
AddonNS.QueryHelpDocs = AddonNS.QueryHelpDocs or {}
AddonNS.QueryHelpDocs.text = [[
|cffedd39aMyBags Query Reference|r

This guide explains how to write queries for custom categories.

|cffe6d0a2Default Starter Groups|r

MyBags seeds a default set of starter custom groups on a fresh setup.

If you delete all custom groups and reload the game, MyBags recreates that default starter set. This is the quickest way to reset your custom-group setup back to the addon defaults.

Current starter groups:

|cffe0d8c4Group | What it is for | Default query / source|r
• |cff8ebfe9Junk|r | Poor-quality items. | |cff8ebfe9quality = 0|r
• |cff8ebfe9Quest|r | Quest-linked items and quest-item class items. | |cff8ebfe9isQuestItem = true OR itemType = 12|r
• |cff8ebfe9Warbound|r | Account-bound-until-equipped items that are not yet fully bound. | |cff8ebfe9isWarbound = true AND isBound = false|r
• |cff8ebfe9BoE|r | Bind-on-equip items that are not yet bound. | |cff8ebfe9bindType = 2 AND isBound = false|r
• |cff8ebfe9Reagents - Soulbound|r | Crafting reagents that are already soulbound. | |cff8ebfe9isCraftingReagent = true AND isBound = true|r
• |cff8ebfe9Reagents|r | Crafting reagents that are still tradable. | |cff8ebfe9isCraftingReagent = true AND isBound = false|r
• |cff8ebfe9Recipes|r | Recipe items. | |cff8ebfe9itemType = 9|r
• |cff8ebfe9Gems|r | Gem items. | |cff8ebfe9itemType = 3|r
• |cff8ebfe9Potions/Flasks/Food|r | Common consumables such as potions, flasks/phials, and food/drink. | |cff8ebfe9itemType = 0 AND (itemSubType = 1 OR itemSubType = 3 OR itemSubType = 5)|r
• |cff8ebfe9Armor & Weapons|r | Weapons and armor grouped together. | |cff8ebfe9itemType = 2 OR itemType = 4|r
• |cff8ebfe9Uncollected Transmog|r | Items with an uncollected transmog appearance. | |cff8ebfe9isTransmogCollected = false|r
• |cff8ebfe9Teleport|r | Manual hearthstone / teleport utility items from the built-in item list. | Manual item list, no query
• |cff8ebfe9Mounts & Pets|r | Miscellaneous items such as mounts and pets. | |cff8ebfe9itemType = 15 AND (itemSubType = 2 OR itemSubType > 4)|r
• |cff8ebfe9Curios|r | Utility and combat curios. | |cff8ebfe9itemType = 0 AND (itemSubType = 10 OR itemSubType = 11)|r
• |cff8ebfe9Decor|r | Housing decor items. | |cff8ebfe9itemType = 20|r
• |cff8ebfe9Caches / One-time Use|r | Loot containers and selected one-time-use utility items. | |cff8ebfe9hasLoot = true OR onUseDescription = "Knowledge by"|r


|cffe6d0a2Priority And Match Order|r

When multiple query categories match the same item:
1. Higher category priority wins first.
2. If priorities tie, category name alphabetical order is used.
3. If that still ties, internal tie-break logic is applied.

Avoid giving matching categories the same name and priority if you need predictable ordering.

Manual assignment always wins over query matching.

|cffe6d0a2Query Syntax|r

Supported logical operators:
• |cff8ebfe9AND|r
• |cff8ebfe9OR|r
• |cff8ebfe9NOT|r
• Parentheses: |cff8ebfe9(|r and |cff8ebfe9)|r

Supported comparisons by value type:
• Number: |cff8ebfe9=|r, |cff8ebfe9!=|r, |cff8ebfe9>|r, |cff8ebfe9>=|r, |cff8ebfe9<|r, |cff8ebfe9<=|r
• Boolean: |cff8ebfe9=|r, |cff8ebfe9!=|r
• String: |cff8ebfe9=|r, |cff8ebfe9!=|r (pattern matching)

Examples:
|cffb6c6d8Code|r
|cff9bb6cfitemType = 4 AND ilvl >= 580|r
|cff9bb6cfNOT isQuestItem = true|r
|cff9bb6cf(itemType = 2 AND inventoryType = 13) OR (itemType = 4 AND inventoryType = 5)|r


|cffe6d0a2Case Sensitivity|r

Query field names are not case-sensitive:
• Field names are case-insensitive: |cff8ebfe9itemType|r, |cff8ebfe9ItemType|r, and |cff8ebfe9ITEMTYPE|r are equivalent.
• Boolean values should be lowercase: |cff8ebfe9true|r / |cff8ebfe9false|r.
• String matching is case-insensitive (|cff8ebfe9itemName|r, |cff8ebfe9description|r, and |cff8ebfe9onUseDescription|r).
• Use uppercase logical operators (|cff8ebfe9AND|r, |cff8ebfe9OR|r, |cff8ebfe9NOT|r) for predictable results.

|cffe6d0a2String Matching|r

|cff8ebfe9itemName|r supports two value styles:
• Unquoted values use Lua pattern matching.
• Quoted values are also pattern matching, but allow multi-word values (spaces).

Examples:
|cffb6c6d8Code|r
|cff9bb6cfitemName = Epic.*|r
|cff9bb6cfitemName = "Epic Sword"|r
|cff9bb6cfitemName != .*Potion.*|r


Notes:
• |cff8ebfe9itemName = Epic|r matches names containing |cff8ebfe9Epic|r.
• |cff8ebfe9itemName = "Epic Sword"|r matches names containing |cff8ebfe9Epic Sword|r.
• String matching is case-insensitive (for example, |cff8ebfe9itemName = "epic sword"|r matches |cff8ebfe9Epic Sword|r).
• Both unquoted and quoted values can use Lua patterns like |cff8ebfe9.*|r, character classes, and anchors.
• Use quotes when the pattern includes spaces or query operators as plain text.

|cffe6d0a2Supported Attributes|r

|cffe0d8c4Attribute / Type|r
• |cff8ebfe9stackCount|r: |cff9bb6cfnumber|r
• |cff8ebfe9expansionID|r: |cff9bb6cfnumber|r
• |cff8ebfe9quality|r: |cff9bb6cfnumber|r
• |cff8ebfe9isReadable|r: |cff9bb6cfboolean|r
• |cff8ebfe9hasLoot|r: |cff9bb6cfboolean|r
• |cff8ebfe9hasNoValue|r: |cff9bb6cfboolean|r
• |cff8ebfe9itemID|r: |cff9bb6cfnumber|r
• |cff8ebfe9isBound|r: |cff9bb6cfboolean|r
• |cff8ebfe9itemName|r: |cff9bb6cfstring|r
• |cff8ebfe9ilvl|r: |cff9bb6cfnumber|r
• |cff8ebfe9itemMinLevel|r: |cff9bb6cfnumber|r
• |cff8ebfe9itemType|r: |cff9bb6cfnumber|r
• |cff8ebfe9itemSubType|r: |cff9bb6cfnumber|r
• |cff8ebfe9inventoryType|r: |cff9bb6cfnumber|r
• |cff8ebfe9sellPrice|r: |cff9bb6cfnumber|r
• |cff8ebfe9isCraftingReagent|r: |cff9bb6cfboolean|r
• |cff8ebfe9isQuestItem|r: |cff9bb6cfboolean|r
• |cff8ebfe9questID|r: |cff9bb6cfnumber|r
• |cff8ebfe9isQuestItemActive|r: |cff9bb6cfboolean|r
• |cff8ebfe9bindType|r: |cff9bb6cfnumber|r
• |cff8ebfe9isAnimaItem|r: |cff9bb6cfboolean|r
• |cff8ebfe9isArtifactPowerItem|r: |cff9bb6cfboolean|r
• |cff8ebfe9isCorruptedItem|r: |cff9bb6cfboolean|r
• |cff8ebfe9isWarbound|r: |cff9bb6cfboolean|r
• |cff8ebfe9description|r: |cff9bb6cfstring|r
• |cff8ebfe9onUseDescription|r: |cff9bb6cfstring|r
• |cff8ebfe9isTransmogCollected|r: |cff9bb6cfboolean|r
• |cff8ebfe9isWrongArmorType|r: |cff9bb6cfboolean|r
• |cff8ebfe9isWrongPrimaryStat|r: |cff9bb6cfboolean|r
• |cff8ebfe9upgradeTrack|r: |cff9bb6cfstring|r
• |cff8ebfe9upgradeTrackID|r: |cff9bb6cfnumber|r
• |cff8ebfe9upgradeLevel|r: |cff9bb6cfnumber|r
• |cff8ebfe9upgradeMaxLevel|r: |cff9bb6cfnumber|r


Notes:
• |cff8ebfe9isCurioItem|r is intentionally not a separate field; use |cff8ebfe9itemType = 0 AND (itemSubType = 10 OR itemSubType = 11)|r.
• |cff8ebfe9isHeirloomItem|r is intentionally not a separate field; use |cff8ebfe9quality = 7|r.
• |cff8ebfe9onUseDescription|r is populated from the localized tooltip text after the item's |cff8ebfe9Use:|r prefix, and is only inspected for items where |cff8ebfe9C_Item.GetItemSpell(itemID)|r reports an on-use spell.

|cffe6d0a2Core Value Tables|r

|cffd8d8b0|cff8ebfe9expansionID|r|r

|cffe0d8c4Name / Value|r
• Classic: |cff9bb6cf0|r
• The Burning Crusade: |cff9bb6cf1|r
• Wrath of the Lich King: |cff9bb6cf2|r
• Cataclysm: |cff9bb6cf3|r
• Mists of Pandaria: |cff9bb6cf4|r
• Warlords of Draenor: |cff9bb6cf5|r
• Legion: |cff9bb6cf6|r
• Battle for Azeroth: |cff9bb6cf7|r
• Shadowlands: |cff9bb6cf8|r
• Dragonflight: |cff9bb6cf9|r
• The War Within: |cff9bb6cf10|r
• Midnight: |cff9bb6cf11|r
• The Last Titan: |cff9bb6cf12|r


|cffd8d8b0|cff8ebfe9quality|r|r

|cffe0d8c4Name / Value|r
• Poor: |cff9bb6cf0|r
• Common: |cff9bb6cf1|r
• Uncommon: |cff9bb6cf2|r
• Rare: |cff9bb6cf3|r
• Epic: |cff9bb6cf4|r
• Legendary: |cff9bb6cf5|r
• Artifact: |cff9bb6cf6|r
• Heirloom: |cff9bb6cf7|r
• WoWToken: |cff9bb6cf8|r


|cffd8d8b0|cff8ebfe9itemType|r|r

|cffe0d8c4Name / Value|r
• Consumable: |cff9bb6cf0|r
• Container: |cff9bb6cf1|r
• Weapon: |cff9bb6cf2|r
• Gem: |cff9bb6cf3|r
• Armor: |cff9bb6cf4|r
• Reagent: |cff9bb6cf5|r
• Projectile: |cff9bb6cf6|r
• Tradegoods: |cff9bb6cf7|r
• Item Enhancement: |cff9bb6cf8|r
• Recipe: |cff9bb6cf9|r
• Currency Token: |cff9bb6cf10|r
• Quiver: |cff9bb6cf11|r
• Quest item: |cff9bb6cf12|r
• Key: |cff9bb6cf13|r
• Permanent: |cff9bb6cf14|r
• Miscellaneous: |cff9bb6cf15|r
• Glyph: |cff9bb6cf16|r
• Battlepet: |cff9bb6cf17|r
• WoW Token: |cff9bb6cf18|r
• Profession: |cff9bb6cf19|r
• Housing: |cff9bb6cf20|r


|cffd8d8b0|cff8ebfe9inventoryType|r|r

|cffe0d8c4Name / Value|r
• Non Equip: |cff9bb6cf0|r
• Head: |cff9bb6cf1|r
• Neck: |cff9bb6cf2|r
• Shoulder: |cff9bb6cf3|r
• Body: |cff9bb6cf4|r
• Chest: |cff9bb6cf5|r
• Waist: |cff9bb6cf6|r
• Legs: |cff9bb6cf7|r
• Feet: |cff9bb6cf8|r
• Wrist: |cff9bb6cf9|r
• Hand: |cff9bb6cf10|r
• Finger: |cff9bb6cf11|r
• Trinket: |cff9bb6cf12|r
• Weapon: |cff9bb6cf13|r
• Shield: |cff9bb6cf14|r
• Ranged: |cff9bb6cf15|r
• Cloak: |cff9bb6cf16|r
• Two Hand Weapon: |cff9bb6cf17|r
• Bag: |cff9bb6cf18|r
• Tabard: |cff9bb6cf19|r
• Robe: |cff9bb6cf20|r
• Main Hand Weapon: |cff9bb6cf21|r
• Off Hand Weapon: |cff9bb6cf22|r
• Holdable: |cff9bb6cf23|r
• Ammo: |cff9bb6cf24|r
• Thrown: |cff9bb6cf25|r
• Ranged Right: |cff9bb6cf26|r
• Quiver: |cff9bb6cf27|r
• Relic: |cff9bb6cf28|r
• Profession Tool: |cff9bb6cf29|r
• Profession Gear: |cff9bb6cf30|r
• Equipable Spell Offensive: |cff9bb6cf31|r
• Equipable Spell Utility: |cff9bb6cf32|r
• Equipable Spell Defensive: |cff9bb6cf33|r
• Equipable Spell Weapon: |cff9bb6cf34|r


|cffd8d8b0|cff8ebfe9bindType|r|r

|cffe0d8c4Name / Value|r
• None: |cff9bb6cf0|r
• OnAcquire (Bind on Pickup): |cff9bb6cf1|r
• OnEquip (Bind on Equip): |cff9bb6cf2|r
• OnUse (Bind on Use): |cff9bb6cf3|r
• Quest: |cff9bb6cf4|r
• Unused1: |cff9bb6cf5|r
• Unused2: |cff9bb6cf6|r
• ToWoWAccount: |cff9bb6cf7|r
• ToBnetAccount: |cff9bb6cf8|r
• ToBnetAccountUntilEquipped: |cff9bb6cf9|r


|cffd8d8b0|cff8ebfe9isAnimaItem|r|r

Returns whether an item is recognized as an anima item.

|cffe0d8c4Value / Meaning|r
• |cff8ebfe9true|r: |cff9bb6cfItem is anima|r
• |cff8ebfe9false|r: |cff9bb6cfItem is not anima|r


|cffd8d8b0|cff8ebfe9isArtifactPowerItem|r|r

Returns whether an item is recognized as an artifact power item.

|cffe0d8c4Value / Meaning|r
• |cff8ebfe9true|r: |cff9bb6cfItem is artifact power|r
• |cff8ebfe9false|r: |cff9bb6cfItem is not artifact power|r


|cffd8d8b0|cff8ebfe9isCorruptedItem|r|r

Returns whether an item is recognized as a corrupted item.

|cffe0d8c4Value / Meaning|r
• |cff8ebfe9true|r: |cff9bb6cfItem is corrupted|r
• |cff8ebfe9false|r: |cff9bb6cfItem is not corrupted|r


|cffd8d8b0|cff8ebfe9isWarbound|r|r

Returns whether an item is warbound (bound to account until equipped).

|cffe0d8c4Value / Meaning|r
• |cff8ebfe9true|r: |cff9bb6cfItem is warbound|r
• |cff8ebfe9false|r: |cff9bb6cfItem is not warbound|r


|cffd8d8b0|cff8ebfe9description|r|r

Item description text.

Notes:
• Uses the same string matching behavior as |cff8ebfe9itemName|r (Lua pattern matching, case-insensitive).

|cffd8d8b0|cff8ebfe9isTransmogCollected|r|r

Whether the item's transmog source is collected.

|cffe0d8c4Value / Meaning|r
• |cff8ebfe9true|r: |cff9bb6cfTransmog source is collected|r
• |cff8ebfe9false|r: |cff9bb6cfTransmog source is not collected|r
• |cff8ebfe9nil|r: |cff9bb6cfItem has no transmog source info|r

|cffd8d8b0|cff8ebfe9isWrongArmorType|r|r

Whether the item is an armor type the player's class does not primarily wear.

|cffe0d8c4Value / Meaning|r
• |cff8ebfe9true|r: |cff9bb6cfItem is a different armor type than the player's class|r
• |cff8ebfe9false|r: |cff9bb6cfItem matches the player's armor type|r
• |cff8ebfe9nil|r: |cff9bb6cfItem is not a standard armor piece (Cloth/Leather/Mail/Plate)|r

|cffd8d8b0|cff8ebfe9isWrongPrimaryStat|r|r

Whether the item has a primary stat that none of the player's class specs use.

|cffe0d8c4Value / Meaning|r
• |cff8ebfe9true|r: |cff9bb6cfItem has a primary stat, but none match any of the player's specs|r
• |cff8ebfe9false|r: |cff9bb6cfItem has a primary stat matching at least one of the player's specs|r
• |cff8ebfe9nil|r: |cff9bb6cfItem has no primary stat (rings, amulets, some trinkets)|r

|cffd8d8b0|cff8ebfe9upgradeTrack|r|r

The item's upgrade track name.

|cffe0d8c4Value / Meaning|r
• |cff8ebfe9"Adventurer"|r: |cff9bb6cfAdventurer track|r
• |cff8ebfe9"Veteran"|r: |cff9bb6cfVeteran track|r
• |cff8ebfe9"Champion"|r: |cff9bb6cfChampion track|r
• |cff8ebfe9"Hero"|r: |cff9bb6cfHero track|r
• |cff8ebfe9"Myth"|r: |cff9bb6cfMyth track|r
• |cff8ebfe9nil|r: |cff9bb6cfItem has no upgrade track|r

|cffd8d8b0|cff8ebfe9upgradeTrackID|r|r

Numeric ID for the upgrade track. Useful for sorting by track potency.

|cffe0d8c4Value / Meaning|r
• |cff8ebfe9971|r: |cff9bb6cfAdventurer|r
• |cff8ebfe9972|r: |cff9bb6cfVeteran|r
• |cff8ebfe9973|r: |cff9bb6cfChampion|r
• |cff8ebfe9974|r: |cff9bb6cfHero|r
• |cff8ebfe9975|r: |cff9bb6cfMyth|r

|cffd8d8b0|cff8ebfe9upgradeLevel|r|r

Current upgrade level within the track (e.g., 4 of 8).

|cffd8d8b0|cff8ebfe9upgradeMaxLevel|r|r

Maximum upgrade level for the track (e.g., 8).


|cffe6d0a2Detailed |cff8ebfe9itemSubType|r Tables (by |cff8ebfe9itemType|r)|r

|cff8ebfe9itemSubType|r values depend on |cff8ebfe9itemType|r.

|cffd8d8b0|cff8ebfe9itemType = 0|r (Consumable)|r

|cffe0d8c4Name / itemSubType|r
• Generic: |cff9bb6cf0|r
• Potion: |cff9bb6cf1|r
• Elixir: |cff9bb6cf2|r
• Flasks / phials: |cff9bb6cf3|r
• Scroll: |cff9bb6cf4|r
• Food / drink: |cff9bb6cf5|r
• Item enhancement: |cff9bb6cf6|r
• Bandage: |cff9bb6cf7|r
• Other: |cff9bb6cf8|r
• Vantus Rune: |cff9bb6cf9|r
• Utility Curio: |cff9bb6cf10|r
• Combat Curio: |cff9bb6cf11|r
• Relic: |cff9bb6cf12|r


|cffd8d8b0|cff8ebfe9itemType = 1|r (Container)|r

|cffe0d8c4Name / itemSubType|r
• Bag: |cff9bb6cf0|r
• Soul Bag: |cff9bb6cf1|r
• Herb Bag: |cff9bb6cf2|r
• Enchanting Bag: |cff9bb6cf3|r
• Engineering Bag: |cff9bb6cf4|r
• Gem Bag: |cff9bb6cf5|r
• Mining Bag: |cff9bb6cf6|r
• Leatherworking Bag: |cff9bb6cf7|r
• Inscription Bag: |cff9bb6cf8|r
• Tackle Box: |cff9bb6cf9|r
• Cooking Bag: |cff9bb6cf10|r


|cffd8d8b0|cff8ebfe9itemType = 2|r (Weapon)|r

|cffe0d8c4Name / itemSubType|r
• Axe 1H: |cff9bb6cf0|r
• Axe 2H: |cff9bb6cf1|r
• Bows: |cff9bb6cf2|r
• Guns: |cff9bb6cf3|r
• Mace 1H: |cff9bb6cf4|r
• Mace 2H: |cff9bb6cf5|r
• Polearm: |cff9bb6cf6|r
• Sword 1H: |cff9bb6cf7|r
• Sword 2H: |cff9bb6cf8|r
• Warglaive: |cff9bb6cf9|r
• Staff: |cff9bb6cf10|r
• Bearclaw: |cff9bb6cf11|r
• Catclaw: |cff9bb6cf12|r
• Unarmed: |cff9bb6cf13|r
• Generic: |cff9bb6cf14|r
• Dagger: |cff9bb6cf15|r
• Thrown: |cff9bb6cf16|r
• Obsolete: |cff9bb6cf17|r
• Crossbow: |cff9bb6cf18|r
• Wand: |cff9bb6cf19|r
• Fishingpole: |cff9bb6cf20|r


|cffd8d8b0|cff8ebfe9itemType = 3|r (Gem)|r

|cffe0d8c4Name / itemSubType|r
• Intellect: |cff9bb6cf0|r
• Agility: |cff9bb6cf1|r
• Strength: |cff9bb6cf2|r
• Stamina: |cff9bb6cf3|r
• Spirit: |cff9bb6cf4|r
• Critical Strike: |cff9bb6cf5|r
• Mastery: |cff9bb6cf6|r
• Haste: |cff9bb6cf7|r
• Versatility: |cff9bb6cf8|r
• Other: |cff9bb6cf9|r
• Multiple stats: |cff9bb6cf10|r
• Artifact / relic: |cff9bb6cf11|r


|cffd8d8b0|cff8ebfe9itemType = 4|r (Armor)|r

|cffe0d8c4Name / itemSubType|r
• Generic: |cff9bb6cf0|r
• Cloth: |cff9bb6cf1|r
• Leather: |cff9bb6cf2|r
• Mail: |cff9bb6cf3|r
• Plate: |cff9bb6cf4|r
• Cosmetic: |cff9bb6cf5|r
• Shield: |cff9bb6cf6|r
• Libram: |cff9bb6cf7|r
• Idol: |cff9bb6cf8|r
• Totem: |cff9bb6cf9|r
• Sigil: |cff9bb6cf10|r
• Relic: |cff9bb6cf11|r


|cffd8d8b0|cff8ebfe9itemType = 5|r (Reagent)|r

|cffe0d8c4Name / itemSubType|r
• Reagent: |cff9bb6cf0|r
• Keystone: |cff9bb6cf1|r
• Context Token: |cff9bb6cf2|r


|cffd8d8b0|cff8ebfe9itemType = 6|r (Projectile)|r

|cffe0d8c4Name / itemSubType|r
• Wand: |cff9bb6cf0|r
• Bolt: |cff9bb6cf1|r
• Arrow: |cff9bb6cf2|r
• Bullet: |cff9bb6cf3|r
• Thrown: |cff9bb6cf4|r


|cffd8d8b0|cff8ebfe9itemType = 7|r (Tradegoods)|r

|cffe0d8c4Name / itemSubType|r
• Trade Goods (Obsolete): |cff9bb6cf0|r
• Parts: |cff9bb6cf1|r
• Explosives (Obsolete): |cff9bb6cf2|r
• Devices (Obsolete): |cff9bb6cf3|r
• Jewelcrafting: |cff9bb6cf4|r
• Cloth: |cff9bb6cf5|r
• Leather: |cff9bb6cf6|r
• Metal Stone: |cff9bb6cf7|r
• Cooking: |cff9bb6cf8|r
• Herb: |cff9bb6cf9|r
• Elemental: |cff9bb6cf10|r
• Other: |cff9bb6cf11|r
• Enchanting: |cff9bb6cf12|r
• Materials (Obsolete): |cff9bb6cf13|r
• Item Enchantment (Obsolete): |cff9bb6cf14|r
• Weapon Enchantment (Obsolete): |cff9bb6cf15|r
• Inscription: |cff9bb6cf16|r
• Explosives & Devices (Obsolete): |cff9bb6cf17|r
• Optional Reagents: |cff9bb6cf18|r
• Finishing Reagents: |cff9bb6cf19|r


|cffd8d8b0|cff8ebfe9itemType = 8|r (ItemEnhancement)|r

|cffe0d8c4Name / itemSubType|r
• Head: |cff9bb6cf0|r
• Neck: |cff9bb6cf1|r
• Shoulder: |cff9bb6cf2|r
• Cloak: |cff9bb6cf3|r
• Chest: |cff9bb6cf4|r
• Wrist: |cff9bb6cf5|r
• Hands: |cff9bb6cf6|r
• Waist: |cff9bb6cf7|r
• Legs: |cff9bb6cf8|r
• Feet: |cff9bb6cf9|r
• Finger: |cff9bb6cf10|r
• Weapon: |cff9bb6cf11|r
• Two Handed Weapon: |cff9bb6cf12|r
• Shield Offhand: |cff9bb6cf13|r
• Misc: |cff9bb6cf14|r
• Kit: |cff9bb6cf15|r
• Artifact Relic: |cff9bb6cf16|r


|cffd8d8b0|cff8ebfe9itemType = 9|r (Recipe)|r

|cffe0d8c4Name / itemSubType|r
• Book: |cff9bb6cf0|r
• Leatherworking: |cff9bb6cf1|r
• Tailoring: |cff9bb6cf2|r
• Engineering: |cff9bb6cf3|r
• Blacksmithing: |cff9bb6cf4|r
• Cooking: |cff9bb6cf5|r
• Alchemy: |cff9bb6cf6|r
• FirstAid: |cff9bb6cf7|r
• Enchanting: |cff9bb6cf8|r
• Fishing: |cff9bb6cf9|r
• Jewelcrafting: |cff9bb6cf10|r
• Inscription: |cff9bb6cf11|r


|cffd8d8b0|cff8ebfe9itemType = 10|r (CurrencyTokenObsolete)|r

|cffe0d8c4Name / itemSubType|r
• Money: |cff9bb6cf0|r


|cffd8d8b0|cff8ebfe9itemType = 11|r (Quiver)|r

|cffe0d8c4Name / itemSubType|r
• Quiver: |cff9bb6cf0|r
• Ammo Pouch: |cff9bb6cf1|r


|cffd8d8b0|cff8ebfe9itemType = 12|r (Questitem)|r

|cffe0d8c4Name / itemSubType|r
• Quest: |cff9bb6cf0|r


|cffd8d8b0|cff8ebfe9itemType = 13|r (Key)|r

|cffe0d8c4Name / itemSubType|r
• Key: |cff9bb6cf0|r


|cffd8d8b0|cff8ebfe9itemType = 14|r (PermanentObsolete)|r

|cffe0d8c4Name / itemSubType|r
• Permanent: |cff9bb6cf0|r


|cffd8d8b0|cff8ebfe9itemType = 15|r (Miscellaneous)|r

|cffe0d8c4Name / itemSubType|r
• Junk: |cff9bb6cf0|r
• Reagent: |cff9bb6cf1|r
• Companion Pet: |cff9bb6cf2|r
• Holiday: |cff9bb6cf3|r
• Other: |cff9bb6cf4|r
• Mount: |cff9bb6cf5|r
• MountEquipment: |cff9bb6cf6|r


|cffd8d8b0|cff8ebfe9itemType = 16|r (Glyph)|r

|cffe0d8c4Name / itemSubType|r
• Warrior: |cff9bb6cf1|r
• Paladin: |cff9bb6cf2|r
• Hunter: |cff9bb6cf3|r
• Rogue: |cff9bb6cf4|r
• Priest: |cff9bb6cf5|r
• Death Knight: |cff9bb6cf6|r
• Shaman: |cff9bb6cf7|r
• Mage: |cff9bb6cf8|r
• Warlock: |cff9bb6cf9|r
• Monk: |cff9bb6cf10|r
• Druid: |cff9bb6cf11|r


|cffd8d8b0|cff8ebfe9itemType = 17|r (Battlepet)|r

|cffe0d8c4Name / itemSubType|r
• Humanoid: |cff9bb6cf0|r
• Dragonkin: |cff9bb6cf1|r
• Flying: |cff9bb6cf2|r
• Undead: |cff9bb6cf3|r
• Critter: |cff9bb6cf4|r
• Magic: |cff9bb6cf5|r
• Elemental: |cff9bb6cf6|r
• Beast: |cff9bb6cf7|r
• Aquatic: |cff9bb6cf8|r
• Mechanical: |cff9bb6cf9|r


|cffd8d8b0|cff8ebfe9itemType = 18|r (WoWToken)|r

|cffe0d8c4Name / itemSubType|r
• WoWToken: |cff9bb6cf0|r


|cffd8d8b0|cff8ebfe9itemType = 19|r (Profession)|r

|cffe0d8c4Name / itemSubType|r
• Blacksmithing: |cff9bb6cf0|r
• Leatherworking: |cff9bb6cf1|r
• Alchemy: |cff9bb6cf2|r
• Herbalism: |cff9bb6cf3|r
• Cooking: |cff9bb6cf4|r
• Mining: |cff9bb6cf5|r
• Tailoring: |cff9bb6cf6|r
• Engineering: |cff9bb6cf7|r
• Enchanting: |cff9bb6cf8|r
• Fishing: |cff9bb6cf9|r
• Skinning: |cff9bb6cf10|r
• Jewelcrafting: |cff9bb6cf11|r
• Inscription: |cff9bb6cf12|r
• Archaeology: |cff9bb6cf13|r


|cffd8d8b0|cff8ebfe9itemType = 20|r (Housing)|r

|cffe0d8c4Name / itemSubType|r
• Decor: |cff9bb6cf0|r
• Dye: |cff9bb6cf1|r
• Room: |cff9bb6cf2|r
• Room Customization: |cff9bb6cf3|r
• Exterior Customization: |cff9bb6cf4|r
• Service Item: |cff9bb6cf5|r


|cffe6d0a2Known Limitations|r

• Quoted multi-word literals are not supported.
• |cff8ebfe9itemName = Epic Sword|r does not work as a single value.
• Workaround: |cff8ebfe9itemName = Epic.Sword|r matches |cff8ebfe9Epic Sword|r.
• Unknown fields or invalid operators do not match.
• Use uppercase logical operators (|cff8ebfe9AND|r, |cff8ebfe9OR|r, |cff8ebfe9NOT|r) for most predictable results.
• Use lowercase boolean values: |cff8ebfe9true|r / |cff8ebfe9false|r.

|cffe6d0a2Practical Examples|r

|cffb6c6d8Code|r
|cff9bb6cf-- High item level plate|r
|cff9bb6cfitemType = 4 AND itemSubType = 4 AND ilvl >= 610|r
|cff9bb6cf|r
|cff9bb6cf-- Bind on equip gear|r
|cff9bb6cfbindType = 2 AND inventoryType >= 1 AND inventoryType <= 22|r
|cff9bb6cf|r
|cff9bb6cf-- Crafting reagents from newer expansions|r
|cff9bb6cfisCraftingReagent = true AND expansionID >= 10|r
|cff9bb6cf|r
|cff9bb6cf-- Name pattern|r
|cff9bb6cfitemName = .*Potion.*|r


]]
