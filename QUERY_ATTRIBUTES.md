# MyBags Query Reference

This guide explains how to write queries for custom categories.

## Priority And Match Order

When multiple query categories match the same item:
1. Higher category priority wins first.
2. If priorities tie, category name alphabetical order is used.
3. If that still ties, internal tie-break logic is applied.

Avoid giving matching categories the same name and priority if you need predictable ordering.

Manual assignment always wins over query matching.

## Query Syntax

Supported logical operators:
- `AND`
- `OR`
- `NOT`
- Parentheses: `(` and `)`

Supported comparisons by value type:
- Number: `=`, `!=`, `>`, `>=`, `<`, `<=`
- Boolean: `=`, `!=`
- String: `=`, `!=` (pattern matching)

Examples:
```lua
itemType = 4 AND ilvl >= 580
NOT isQuestItem = true
(itemType = 2 AND inventoryType = 13) OR (itemType = 4 AND inventoryType = 5)
```

## Case Sensitivity

Query field names are not case-sensitive:
- Field names are case-insensitive: `itemType`, `ItemType`, and `ITEMTYPE` are equivalent.
- Boolean values should be lowercase: `true` / `false`.
- `itemName` matching is case-sensitive by default.
- Use uppercase logical operators (`AND`, `OR`, `NOT`) for predictable results.

## String Matching

`itemName` supports two value styles:
- Unquoted values use Lua pattern matching.
- Quoted values are also pattern matching, but allow multi-word values (spaces).

Examples:
```lua
itemName = Epic.*
itemName = "Epic Sword"
itemName != .*Potion.*
```

Notes:
- `itemName = Epic` matches names containing `Epic`.
- `itemName = "Epic Sword"` matches names containing `Epic Sword`.
- Both unquoted and quoted values can use Lua patterns like `.*`, character classes, and anchors.
- Use quotes when the pattern includes spaces or query operators as plain text.

## Supported Attributes

| Attribute | Type |
|---|---|
| `stackCount` | number |
| `expansionID` | number |
| `quality` | number |
| `isReadable` | boolean |
| `hasLoot` | boolean |
| `hasNoValue` | boolean |
| `itemID` | number |
| `isBound` | boolean |
| `itemName` | string |
| `ilvl` | number |
| `itemMinLevel` | number |
| `itemType` | number |
| `itemSubType` | number |
| `inventoryType` | number |
| `sellPrice` | number |
| `isCraftingReagent` | boolean |
| `isQuestItem` | boolean |
| `questID` | number |
| `isQuestItemActive` | boolean |
| `bindType` | number |

## Core Value Tables

### `expansionID`

| Name | Value |
|---|---:|
| Classic | 0 |
| The Burning Crusade | 1 |
| Wrath of the Lich King | 2 |
| Cataclysm | 3 |
| Mists of Pandaria | 4 |
| Warlords of Draenor | 5 |
| Legion | 6 |
| Battle for Azeroth | 7 |
| Shadowlands | 8 |
| Dragonflight | 9 |
| The War Within | 10 |
| Midnight | 11 |
| The Last Titan | 12 |

### `quality`

| Name | Value |
|---|---:|
| Poor | 0 |
| Common | 1 |
| Uncommon | 2 |
| Rare | 3 |
| Epic | 4 |
| Legendary | 5 |
| Artifact | 6 |
| Heirloom | 7 |
| WoWToken | 8 |

### `itemType`

| Name | Value |
|---|---:|
| Consumable | 0 |
| Container | 1 |
| Weapon | 2 |
| Gem | 3 |
| Armor | 4 |
| Reagent | 5 |
| Projectile | 6 |
| Tradegoods | 7 |
| ItemEnhancement | 8 |
| Recipe | 9 |
| CurrencyTokenObsolete | 10 |
| Quiver | 11 |
| Questitem | 12 |
| Key | 13 |
| PermanentObsolete | 14 |
| Miscellaneous | 15 |
| Glyph | 16 |
| Battlepet | 17 |
| WoWToken | 18 |
| Profession | 19 |
| Housing | 20 |

### `inventoryType`

| Name | Value |
|---|---:|
| NonEquip | 0 |
| Head | 1 |
| Neck | 2 |
| Shoulder | 3 |
| Body | 4 |
| Chest | 5 |
| Waist | 6 |
| Legs | 7 |
| Feet | 8 |
| Wrist | 9 |
| Hand | 10 |
| Finger | 11 |
| Trinket | 12 |
| Weapon | 13 |
| Shield | 14 |
| Ranged | 15 |
| Cloak | 16 |
| TwoHandWeapon | 17 |
| Bag | 18 |
| Tabard | 19 |
| Robe | 20 |
| MainHandWeapon | 21 |
| OffHandWeapon | 22 |
| Holdable | 23 |
| Ammo | 24 |
| Thrown | 25 |
| RangedRight | 26 |
| Quiver | 27 |
| Relic | 28 |
| ProfessionTool | 29 |
| ProfessionGear | 30 |
| EquipableSpellOffensive | 31 |
| EquipableSpellUtility | 32 |
| EquipableSpellDefensive | 33 |
| EquipableSpellWeapon | 34 |

### `bindType`

| Name | Value |
|---|---:|
| None | 0 |
| OnAcquire (Bind on Pickup) | 1 |
| OnEquip (Bind on Equip) | 2 |
| OnUse (Bind on Use) | 3 |
| Quest | 4 |
| Unused1 | 5 |
| Unused2 | 6 |
| ToWoWAccount | 7 |
| ToBnetAccount | 8 |
| ToBnetAccountUntilEquipped | 9 |

## Detailed `itemSubType` Tables (by `itemType`)

`itemSubType` values depend on `itemType`.

### `itemType = 0` (Consumable)

| Name | itemSubType |
|---|---:|
| Generic | 0 |
| Potion | 1 |
| Elixir | 2 |
| Flasksphials | 3 |
| Scroll | 4 |
| Fooddrink | 5 |
| Itemenhancement | 6 |
| Bandage | 7 |
| Other | 8 |
| VantusRune | 9 |
| UtilityCurio | 10 |
| CombatCurio | 11 |
| Relic | 12 |

### `itemType = 2` (Weapon)

| Name | itemSubType |
|---|---:|
| Axe1H | 0 |
| Axe2H | 1 |
| Bows | 2 |
| Guns | 3 |
| Mace1H | 4 |
| Mace2H | 5 |
| Polearm | 6 |
| Sword1H | 7 |
| Sword2H | 8 |
| Warglaive | 9 |
| Staff | 10 |
| Bearclaw | 11 |
| Catclaw | 12 |
| Unarmed | 13 |
| Generic | 14 |
| Dagger | 15 |
| Thrown | 16 |
| Obsolete3 | 17 |
| Crossbow | 18 |
| Wand | 19 |
| Fishingpole | 20 |

### `itemType = 3` (Gem)

| Name | itemSubType |
|---|---:|
| Intellect | 0 |
| Agility | 1 |
| Strength | 2 |
| Stamina | 3 |
| Spirit | 4 |
| Criticalstrike | 5 |
| Mastery | 6 |
| Haste | 7 |
| Versatility | 8 |
| Other | 9 |
| Multiplestats | 10 |
| Artifactrelic | 11 |

### `itemType = 4` (Armor)

| Name | itemSubType |
|---|---:|
| Generic | 0 |
| Cloth | 1 |
| Leather | 2 |
| Mail | 3 |
| Plate | 4 |
| Cosmetic | 5 |
| Shield | 6 |
| Libram | 7 |
| Idol | 8 |
| Totem | 9 |
| Sigil | 10 |
| Relic | 11 |

### `itemType = 5` (Reagent)

| Name | itemSubType |
|---|---:|
| Reagent | 0 |
| Keystone | 1 |
| ContextToken | 2 |

### `itemType = 9` (Recipe)

| Name | itemSubType |
|---|---:|
| Book | 0 |
| Leatherworking | 1 |
| Tailoring | 2 |
| Engineering | 3 |
| Blacksmithing | 4 |
| Cooking | 5 |
| Alchemy | 6 |
| FirstAid | 7 |
| Enchanting | 8 |
| Fishing | 9 |
| Jewelcrafting | 10 |
| Inscription | 11 |

### `itemType = 15` (Miscellaneous)

| Name | itemSubType |
|---|---:|
| Junk | 0 |
| Reagent | 1 |
| CompanionPet | 2 |
| Holiday | 3 |
| Other | 4 |
| Mount | 5 |
| MountEquipment | 6 |

### `itemType = 19` (Profession)

| Name | itemSubType |
|---|---:|
| Blacksmithing | 0 |
| Leatherworking | 1 |
| Alchemy | 2 |
| Herbalism | 3 |
| Cooking | 4 |
| Mining | 5 |
| Tailoring | 6 |
| Engineering | 7 |
| Enchanting | 8 |
| Fishing | 9 |
| Skinning | 10 |
| Jewelcrafting | 11 |
| Inscription | 12 |
| Archaeology | 13 |

### `itemType = 20` (Housing)

| Name | itemSubType |
|---|---:|
| Decor | 0 |
| Dye | 1 |
| Room | 2 |
| RoomCustomization | 3 |
| ExteriorCustomization | 4 |
| ServiceItem | 5 |

### Other `itemType` values

For some classes (for example `Container`, `Tradegoods`, `ItemEnhancement`, `Questitem`, `Glyph`, `Battlepet`, `WoWToken`), subtype values may vary more by game data.

## Known Limitations

- Quoted multi-word literals are not supported.
  - `itemName = Epic Sword` does not work as a single value.
  - Workaround: `itemName = Epic.Sword` matches `Epic Sword`.
- Unknown fields or invalid operators do not match.
- Use uppercase logical operators (`AND`, `OR`, `NOT`) for most predictable results.
- Use lowercase boolean values: `true` / `false`.

## Practical Examples

```lua
-- High item level plate
itemType = 4 AND itemSubType = 4 AND ilvl >= 610

-- Bind on equip gear
bindType = 2 AND inventoryType >= 1 AND inventoryType <= 22

-- Crafting reagents from newer expansions
isCraftingReagent = true AND expansionID >= 10

-- Name pattern
itemName = .*Potion.*
```
