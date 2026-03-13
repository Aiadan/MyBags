# MyBags Query Reference

This guide explains how to write queries for custom categories.

## Default Starter Groups

MyBags seeds a default set of starter custom groups on a fresh setup.

If you delete all custom groups and reload the game, MyBags recreates that default starter set. This is the quickest way to reset your custom-group setup back to the addon defaults.

Current starter groups:

| Group | What it is for | Default query / source |
|---|---|---|
| `Junk` | Poor-quality items. | `quality = 0` |
| `Quest` | Quest-linked items and quest-item class items. | `isQuestItem = true OR itemType = 12` |
| `Warbound` | Account-bound-until-equipped items that are not yet fully bound. | `isWarbound = true AND isBound = false` |
| `BoE` | Bind-on-equip items that are not yet bound. | `bindType = 2 AND isBound = false` |
| `Reagents - Soulbound` | Crafting reagents that are already soulbound. | `isCraftingReagent = true AND isBound = true` |
| `Reagents` | Crafting reagents that are still tradable. | `isCraftingReagent = true AND isBound = false` |
| `Recipes` | Recipe items. | `itemType = 9` |
| `Gems` | Gem items. | `itemType = 3` |
| `Potions/Flasks/Food` | Common consumables such as potions, flasks/phials, and food/drink. | `itemType = 0 AND (itemSubType = 1 OR itemSubType = 3 OR itemSubType = 5)` |
| `Armor & Weapons` | Weapons and armor grouped together. | `itemType = 2 OR itemType = 4` |
| `Uncollected Transmog` | Items with an uncollected transmog appearance. | `isTransmogCollected = false` |
| `Teleport` | Manual hearthstone / teleport utility items from the built-in item list. | Manual item list, no query |
| `Mounts & Pets` | Miscellaneous items such as mounts and pets. | `itemType = 15 AND (itemSubType = 2 OR itemSubType > 4)` |
| `Curios` | Utility and combat curios. | `itemType = 0 AND (itemSubType = 10 OR itemSubType = 11)` |
| `Decor` | Housing decor items. | `itemType = 20` |
| `Caches / One-time Use` | Loot containers and selected one-time-use utility items. | `hasLoot = true OR onUseDescription = "Knowledge by"` |

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
- String matching is case-insensitive (`itemName`, `description`, and `onUseDescription`).
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
- String matching is case-insensitive (for example, `itemName = "epic sword"` matches `Epic Sword`).
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
| `isAnimaItem` | boolean |
| `isArtifactPowerItem` | boolean |
| `isCorruptedItem` | boolean |
| `isWarbound` | boolean |
| `description` | string |
| `onUseDescription` | string |
| `isTransmogCollected` | boolean |

Notes:
- `isCurioItem` is intentionally not a separate field; use `itemType = 0 AND (itemSubType = 10 OR itemSubType = 11)`.
- `isHeirloomItem` is intentionally not a separate field; use `quality = 7`.
- `onUseDescription` is populated from the localized tooltip text after the item's `Use:` prefix, and is only inspected for items where `C_Item.GetItemSpell(itemID)` reports an on-use spell.

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
| Item Enhancement | 8 |
| Recipe | 9 |
| Currency Token | 10 |
| Quiver | 11 |
| Quest item | 12 |
| Key | 13 |
| Permanent | 14 |
| Miscellaneous | 15 |
| Glyph | 16 |
| Battlepet | 17 |
| WoW Token | 18 |
| Profession | 19 |
| Housing | 20 |

### `inventoryType`

| Name | Value |
|---|---:|
| Non Equip | 0 |
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
| Two Hand Weapon | 17 |
| Bag | 18 |
| Tabard | 19 |
| Robe | 20 |
| Main Hand Weapon | 21 |
| Off Hand Weapon | 22 |
| Holdable | 23 |
| Ammo | 24 |
| Thrown | 25 |
| Ranged Right | 26 |
| Quiver | 27 |
| Relic | 28 |
| Profession Tool | 29 |
| Profession Gear | 30 |
| Equipable Spell Offensive | 31 |
| Equipable Spell Utility | 32 |
| Equipable Spell Defensive | 33 |
| Equipable Spell Weapon | 34 |

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

### `isAnimaItem`

Returns whether an item is recognized as an anima item.

| Value | Meaning |
|---|---|
| `true` | Item is anima |
| `false` | Item is not anima |

### `isArtifactPowerItem`

Returns whether an item is recognized as an artifact power item.

| Value | Meaning |
|---|---|
| `true` | Item is artifact power |
| `false` | Item is not artifact power |

### `isCorruptedItem`

Returns whether an item is recognized as a corrupted item.

| Value | Meaning |
|---|---|
| `true` | Item is corrupted |
| `false` | Item is not corrupted |

### `isWarbound`

Returns whether an item is warbound (bound to account until equipped).

| Value | Meaning |
|---|---|
| `true` | Item is warbound |
| `false` | Item is not warbound |

### `description`

Item description text.

Notes:
- Uses the same string matching behavior as `itemName` (Lua pattern matching, case-insensitive).

### `isTransmogCollected`

Whether the item's transmog source is collected.

| Value | Meaning |
|---|---|
| `true` | Transmog source is collected |
| `false` | Transmog source is not collected |
| `nil` | Item has no transmog source info |

## Detailed `itemSubType` Tables (by `itemType`)

`itemSubType` values depend on `itemType`.

### `itemType = 0` (Consumable)

| Name | itemSubType |
|---|---:|
| Generic | 0 |
| Potion | 1 |
| Elixir | 2 |
| Flasks / phials | 3 |
| Scroll | 4 |
| Food / drink | 5 |
| Item enhancement | 6 |
| Bandage | 7 |
| Other | 8 |
| Vantus Rune | 9 |
| Utility Curio | 10 |
| Combat Curio | 11 |
| Relic | 12 |

### `itemType = 1` (Container)

| Name | itemSubType |
|---|---:|
| Bag | 0 |
| Soul Bag | 1 |
| Herb Bag | 2 |
| Enchanting Bag | 3 |
| Engineering Bag | 4 |
| Gem Bag | 5 |
| Mining Bag | 6 |
| Leatherworking Bag | 7 |
| Inscription Bag | 8 |
| Tackle Box | 9 |
| Cooking Bag | 10 |

### `itemType = 2` (Weapon)

| Name | itemSubType |
|---|---:|
| Axe 1H | 0 |
| Axe 2H | 1 |
| Bows | 2 |
| Guns | 3 |
| Mace 1H | 4 |
| Mace 2H | 5 |
| Polearm | 6 |
| Sword 1H | 7 |
| Sword 2H | 8 |
| Warglaive | 9 |
| Staff | 10 |
| Bearclaw | 11 |
| Catclaw | 12 |
| Unarmed | 13 |
| Generic | 14 |
| Dagger | 15 |
| Thrown | 16 |
| Obsolete | 17 |
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
| Critical Strike | 5 |
| Mastery | 6 |
| Haste | 7 |
| Versatility | 8 |
| Other | 9 |
| Multiple stats | 10 |
| Artifact / relic | 11 |

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
| Context Token | 2 |

### `itemType = 6` (Projectile)

| Name | itemSubType |
|---|---:|
| Wand | 0 |
| Bolt | 1 |
| Arrow | 2 |
| Bullet | 3 |
| Thrown | 4 |

### `itemType = 7` (Tradegoods)

| Name | itemSubType |
|---|---:|
| Trade Goods (Obsolete) | 0 |
| Parts | 1 |
| Explosives (Obsolete) | 2 |
| Devices (Obsolete) | 3 |
| Jewelcrafting | 4 |
| Cloth | 5 |
| Leather | 6 |
| Metal Stone | 7 |
| Cooking | 8 |
| Herb | 9 |
| Elemental | 10 |
| Other | 11 |
| Enchanting | 12 |
| Materials (Obsolete) | 13 |
| Item Enchantment (Obsolete) | 14 |
| Weapon Enchantment (Obsolete) | 15 |
| Inscription | 16 |
| Explosives & Devices (Obsolete) | 17 |
| Optional Reagents | 18 |
| Finishing Reagents | 19 |

### `itemType = 8` (ItemEnhancement)

| Name | itemSubType |
|---|---:|
| Head | 0 |
| Neck | 1 |
| Shoulder | 2 |
| Cloak | 3 |
| Chest | 4 |
| Wrist | 5 |
| Hands | 6 |
| Waist | 7 |
| Legs | 8 |
| Feet | 9 |
| Finger | 10 |
| Weapon | 11 |
| Two Handed Weapon | 12 |
| Shield Offhand | 13 |
| Misc | 14 |
| Kit | 15 |
| Artifact Relic | 16 |

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

### `itemType = 10` (CurrencyTokenObsolete)

| Name | itemSubType |
|---|---:|
| Money | 0 |

### `itemType = 11` (Quiver)

| Name | itemSubType |
|---|---:|
| Quiver | 0 |
| Ammo Pouch | 1 |

### `itemType = 12` (Questitem)

| Name | itemSubType |
|---|---:|
| Quest | 0 |

### `itemType = 13` (Key)

| Name | itemSubType |
|---|---:|
| Key | 0 |

### `itemType = 14` (PermanentObsolete)

| Name | itemSubType |
|---|---:|
| Permanent | 0 |

### `itemType = 15` (Miscellaneous)

| Name | itemSubType |
|---|---:|
| Junk | 0 |
| Reagent | 1 |
| Companion Pet | 2 |
| Holiday | 3 |
| Other | 4 |
| Mount | 5 |
| MountEquipment | 6 |

### `itemType = 16` (Glyph)

| Name | itemSubType |
|---|---:|
| Warrior | 1 |
| Paladin | 2 |
| Hunter | 3 |
| Rogue | 4 |
| Priest | 5 |
| Death Knight | 6 |
| Shaman | 7 |
| Mage | 8 |
| Warlock | 9 |
| Monk | 10 |
| Druid | 11 |

### `itemType = 17` (Battlepet)

| Name | itemSubType |
|---|---:|
| Humanoid | 0 |
| Dragonkin | 1 |
| Flying | 2 |
| Undead | 3 |
| Critter | 4 |
| Magic | 5 |
| Elemental | 6 |
| Beast | 7 |
| Aquatic | 8 |
| Mechanical | 9 |

### `itemType = 18` (WoWToken)

| Name | itemSubType |
|---|---:|
| WoWToken | 0 |

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
| Room Customization | 3 |
| Exterior Customization | 4 |
| Service Item | 5 |

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
