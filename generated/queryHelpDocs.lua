local addonName, AddonNS = ...
AddonNS.QueryHelpDocs = AddonNS.QueryHelpDocs or {}
AddonNS.QueryHelpDocs.text = [[
|cffedd39aMyBags Query Reference|r

This guide explains how to write queries for custom categories.

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
• |cff8ebfe9itemName|r matching is case-sensitive by default.
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


|cffe6d0a2Core Value Tables|r

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
• ItemEnhancement: |cff9bb6cf8|r
• Recipe: |cff9bb6cf9|r
• CurrencyTokenObsolete: |cff9bb6cf10|r
• Quiver: |cff9bb6cf11|r
• Questitem: |cff9bb6cf12|r
• Key: |cff9bb6cf13|r
• PermanentObsolete: |cff9bb6cf14|r
• Miscellaneous: |cff9bb6cf15|r
• Glyph: |cff9bb6cf16|r
• Battlepet: |cff9bb6cf17|r
• WoWToken: |cff9bb6cf18|r
• Profession: |cff9bb6cf19|r
• Housing: |cff9bb6cf20|r


|cffd8d8b0|cff8ebfe9inventoryType|r|r

|cffe0d8c4Name / Value|r
• NonEquip: |cff9bb6cf0|r
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
• TwoHandWeapon: |cff9bb6cf17|r
• Bag: |cff9bb6cf18|r
• Tabard: |cff9bb6cf19|r
• Robe: |cff9bb6cf20|r
• MainHandWeapon: |cff9bb6cf21|r
• OffHandWeapon: |cff9bb6cf22|r
• Holdable: |cff9bb6cf23|r
• Ammo: |cff9bb6cf24|r
• Thrown: |cff9bb6cf25|r
• RangedRight: |cff9bb6cf26|r
• Quiver: |cff9bb6cf27|r
• Relic: |cff9bb6cf28|r
• ProfessionTool: |cff9bb6cf29|r
• ProfessionGear: |cff9bb6cf30|r
• EquipableSpellOffensive: |cff9bb6cf31|r
• EquipableSpellUtility: |cff9bb6cf32|r
• EquipableSpellDefensive: |cff9bb6cf33|r
• EquipableSpellWeapon: |cff9bb6cf34|r


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


|cffe6d0a2Detailed |cff8ebfe9itemSubType|r Tables (by |cff8ebfe9itemType|r)|r

|cff8ebfe9itemSubType|r values depend on |cff8ebfe9itemType|r.

|cffd8d8b0|cff8ebfe9itemType = 0|r (Consumable)|r

|cffe0d8c4Name / itemSubType|r
• Generic: |cff9bb6cf0|r
• Potion: |cff9bb6cf1|r
• Elixir: |cff9bb6cf2|r
• Flasksphials: |cff9bb6cf3|r
• Scroll: |cff9bb6cf4|r
• Fooddrink: |cff9bb6cf5|r
• Itemenhancement: |cff9bb6cf6|r
• Bandage: |cff9bb6cf7|r
• Other: |cff9bb6cf8|r
• VantusRune: |cff9bb6cf9|r
• UtilityCurio: |cff9bb6cf10|r
• CombatCurio: |cff9bb6cf11|r
• Relic: |cff9bb6cf12|r


|cffd8d8b0|cff8ebfe9itemType = 2|r (Weapon)|r

|cffe0d8c4Name / itemSubType|r
• Axe1H: |cff9bb6cf0|r
• Axe2H: |cff9bb6cf1|r
• Bows: |cff9bb6cf2|r
• Guns: |cff9bb6cf3|r
• Mace1H: |cff9bb6cf4|r
• Mace2H: |cff9bb6cf5|r
• Polearm: |cff9bb6cf6|r
• Sword1H: |cff9bb6cf7|r
• Sword2H: |cff9bb6cf8|r
• Warglaive: |cff9bb6cf9|r
• Staff: |cff9bb6cf10|r
• Bearclaw: |cff9bb6cf11|r
• Catclaw: |cff9bb6cf12|r
• Unarmed: |cff9bb6cf13|r
• Generic: |cff9bb6cf14|r
• Dagger: |cff9bb6cf15|r
• Thrown: |cff9bb6cf16|r
• Obsolete3: |cff9bb6cf17|r
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
• Criticalstrike: |cff9bb6cf5|r
• Mastery: |cff9bb6cf6|r
• Haste: |cff9bb6cf7|r
• Versatility: |cff9bb6cf8|r
• Other: |cff9bb6cf9|r
• Multiplestats: |cff9bb6cf10|r
• Artifactrelic: |cff9bb6cf11|r


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
• ContextToken: |cff9bb6cf2|r


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


|cffd8d8b0|cff8ebfe9itemType = 15|r (Miscellaneous)|r

|cffe0d8c4Name / itemSubType|r
• Junk: |cff9bb6cf0|r
• Reagent: |cff9bb6cf1|r
• CompanionPet: |cff9bb6cf2|r
• Holiday: |cff9bb6cf3|r
• Other: |cff9bb6cf4|r
• Mount: |cff9bb6cf5|r
• MountEquipment: |cff9bb6cf6|r


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
• RoomCustomization: |cff9bb6cf3|r
• ExteriorCustomization: |cff9bb6cf4|r
• ServiceItem: |cff9bb6cf5|r


|cffd8d8b0Other |cff8ebfe9itemType|r values|r

For some classes (for example |cff8ebfe9Container|r, |cff8ebfe9Tradegoods|r, |cff8ebfe9ItemEnhancement|r, |cff8ebfe9Questitem|r, |cff8ebfe9Glyph|r, |cff8ebfe9Battlepet|r, |cff8ebfe9WoWToken|r), subtype values may vary more by game data.

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
