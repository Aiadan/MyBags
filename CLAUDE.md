# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MyBags is a World of Warcraft retail addon (version 12.0.1-3.34) that enhances the default bag interface with manual and automatic item categorization, flexible column layouts, and search via a custom query language. It supports bags, bank, and warband (account-wide bank) views.

## Development Workflow

No build process — pure Lua. To test changes:
1. Save files
2. In-game: `/reload` to reload the UI

## Architecture

MyBags hooks into WoW's native `ContainerFrameCombinedBags` rather than replacing it. The addon is structured in layers:

```
WoW Native Container Frame
  └── ContainerFrameMyBagsMixin  (integration layer; overrides item iterator & layout)
        └── Categorization Engine
              ├── categories.lua        (registry & matching coordinator)
              ├── categoryStore.lua     (wrapper store; IDs, layout, collapsed state)
              └── Categorizers/        (plug-in matching logic)
                    ├── custom.lua      (user-created, query-based)
                    ├── unassigned.lua  (fallback for unmatched items)
                    ├── new.lua         (WoW's "new item" flag; protected)
                    └── EquipmentSet.lua (dynamic per equipment set)
```

### Categorizer Interface (plug-in system)

Register a new categorizer via:
```lua
AddonNS.Categories:RegisterCategorizer(displayName, categorizerObject, categorizerID)
```

A categorizer object must implement:
- `Categorize(itemID, itemButton)` → rawCategory or nil
- `ListCategories()` → list of rawCategories
- `GetAlwaysVisibleCategories()` → list or nil
- Optionally: `GetMatches(itemID, itemButton)` → list (for multi-match support)

Raw categories expose: `GetId()`, `GetName()`, `IsProtected()`, `IsVisibleInScope(scope)`, `OnItemAssigned(itemId, ctx)`, `OnItemUnassigned(itemId, ctx)`.

CategoryStore wraps raw categories with a unified interface; access all categories through `AddonNS.CategoryStore`.

### Category ID Format

`{categorizerId}-{rawId}` — e.g., `"cus-1"` (custom), `"unassigned"`, `"new-"`.

### Scopes

Three scopes: `"bag"`, `"bank-character"`, `"bank-account"`. Categories can be hidden/shown per scope.

### Custom Events

All defined in `init.lua` with `MYBAGS_` prefix. Key events:
- `MYBAGS_ITEM_MOVED`, `MYBAGS_ITEM_CATEGORY_CHANGED`
- `MYBAGS_CATEGORY_MOVED`, `MYBAGS_CATEGORY_MOVED_TO_COLUMN`
- `MYBAGS_CUSTOM_CATEGORY_CREATED/DELETED/RENAMED`
- `MYBAGS_CATEGORIZER_CATEGORIES_UPDATED`
- `MYBAGS_COLLAPSED_CHANGED`, `MYBAGS_BAG_VIEW_MODE_CHANGED`

Event usage pattern:
```lua
AddonNS.Events:RegisterCustomEvent("EVENT_NAME", callback)
AddonNS.Events:TriggerCustomEvent("EVENT_NAME", ...)
```

### SavedVariables Structure (MyBagsDB)

```lua
{
  userCategories = {},    -- custom category definitions
  layoutColumns = {},     -- per-scope column layouts
  columnCounts = {},      -- per-scope column counts
  collapsedState = {},    -- per-scope collapse flags
  itemOrder = {},         -- user-defined item ordering
}
```

### Query Language (`Categorizers/custom/query.lua`)

Supports Lua pattern matching, comparisons (`=`, `!=`, `<`, `>`, `<=`, `>=`), and logical operators (`AND`, `OR`, `NOT`). Attributes include: `ilvl`, `quality`, `itemType`, `itemSubType`, `stackCount`, `expansionID`, `bindType`, `isQuestItem`, `isTransmogCollected`, and ~20 more. See `QUERY_ATTRIBUTES.md` for the full reference.

### Priority Resolution (multiple category matches)

1. Manual assignment (always wins)
2. Priority value (higher wins)
3. Alphabetical name (tie-breaker)

### Performance Patterns

- Item categorization results are cached with version invalidation; invalidate by bumping the cache version
- `C_Container.GetContainerItemInfo()` results cached in `utils/containerItemInfoCache.lua`
- Layout updates deferred via `RunNextFrame()` to batch changes
- `utils/orderedMap.lua` provides O(1) lookups for category lists

## Key Files Quick Reference

| File | Role |
|------|------|
| `init.lua` | Constants, events, DB names, bootstrap |
| `tooltipSettings.lua` | Tooltip display behavior settings |
| `addonSettings.lua` | Addon settings panel registration |
| `main.lua` | Item layout, search, tooltip, categorization cache |
| `categories.lua` | Categorizer registry & match engine |
| `categoryStore.lua` | Single source of truth for category metadata |
| `categoriesColumnAssignment.lua` | Column layout distribution |
| `dragndrop.lua` | Drag-and-drop with cross-scope guards |
| `gui.lua` | Category header rendering & controls |
| `categoriesGUI.lua` | Category editor UI (query input, import/export) |
| `Categorizers/custom/query.lua` | Query parser & evaluator |
| `Categorizers/custom/sortOrder.lua` | Sort order expression compiler & sorter |
| `bankView.lua` | Bank-specific UI view |
| `ContainerFrameMyBagsMixin.lua` | WoW frame integration mixin |
