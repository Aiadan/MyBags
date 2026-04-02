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

## Debugging and Problem-Solving Rules

These rules exist because of a real, prolonged failure: ~30 iterative attempts to fix map pin icons and tooltips on WorldQuestsList's continent map, all of which failed because every attempt was a workaround rather than a proper fix. The author of the addon later shipped a clean fix by working *with* Blizzard's systems instead of around them. Every rule below addresses a specific mistake that was made repeatedly.

### Rule 1: Understand the system before patching symptoms

When something breaks at the boundary between addon code and Blizzard UI, **read the relevant Blizzard source code first**. Not just the API name — read the full mixin, the data provider, the pin template, the pool manager. Understand the lifecycle the system expects before writing a single line of fix code.

**The rule:** If you are about to create frames manually, bypass a pool, or reimplement something Blizzard already provides, stop. Go read how Blizzard does it in the interface source. The correct fix almost always works *with* the existing system rather than around it.

### Rule 2: Escalate after 3 failed approaches, not 30

If three materially different approaches to the same problem have all failed, the current mental model of the problem is wrong. Do not try a fourth variation at the same level. Instead:

1. **Stop and re-read the Blizzard source** for the entire subsystem involved (not just the function that errored).
2. **Trace the actual call chain** from where the error occurs back to the addon's entry point.
3. **State the root cause hypothesis explicitly** before writing any more code. If you can't articulate why the previous approaches failed, you don't understand the problem yet.
4. **Ask the user** whether to continue or take a different direction. Thirty silent iterations wasting time is worse than one honest "I don't understand why this is happening yet."

### Rule 3: Taint is architectural, not patchable

WoW's taint system propagates. You cannot fix taint by wrapping individual calls in `pcall` or by conditionally skipping code in combat. If addon code taints a Blizzard-owned frame or value, the taint spreads through every subsequent operation on that frame.

**The correct responses to taint are:**
- **Use addon-owned frames** for addon-driven UI rather than touching Blizzard-owned frames
- **Disable the tainting code path entirely** (`nop` out methods) rather than conditionally wrapping them
- **Stay within Blizzard's data provider / pin pool system** so frames are managed by secure code, not addon code

### Rule 4: Check what the addon already provides before building new things

Before creating a new mechanism, check whether the addon already has one that does what you need. Read the full codebase, not just the area around the bug.

### Rule 5: When modifying someone else's addon, study their patterns first

Before making changes to an addon you didn't write, identify the patterns and idioms the author uses throughout the codebase. Your fix should look like code the author would write, not like a foreign patch bolted on from outside.

### Rule 6: "It works around the problem" is not the same as "it fixes the problem"

If a fix requires `pcall`, suppressing errors, hiding frames instead of removing them, or stripping functionality to prevent crashes — it is a workaround, not a fix. Workarounds are acceptable as temporary measures only if you explicitly flag them as such and continue pursuing the real fix.

**The test:** Can you explain *why* your change fixes the problem in terms of the system's design, not just that it stops the error from appearing? If the explanation is "it catches the error" or "it prevents the code from running," that's a workaround.

### Postmortem: Category layout displacement bug (2026-03)

Categories temporarily jumped to wrong positions when selling, deleting, or using items. Three fix attempts were needed.

**Attempt 1 (wrong):** Identified `newFreeBagSlots <= freeBagSlots` in the BAG_UPDATE handler as skipping layout updates when items were consumed. Removed the condition. This was a real secondary issue but not the root cause — the layout still broke because the update was running but producing wrong results.

**Attempt 2 (wrong, made it worse):** Added debug output that revealed wrapper object identity mismatch: `CategoryStore:Get(id)` returned a different Lua table than what was stored as keys in `arrangedItems`. Attempted to work around this by building an ID-keyed index (`arrangedById`) in `ArrangeCategoriesIntoColumns`. This introduced a new bug — when duplicate entries existed for the same ID (old wrapper with items + new wrapper with empty list from `GetConstantCategories`), the index could pick the empty one. Half the categories broke instead of two.

**Attempt 3 (correct):** Root cause traced: `buildQueryPayload` in `Categorizers/custom.lua:770-774` registers `ContinueOnItemLoad` callbacks when `C_Item.GetItemInfo()` returns nil. These callbacks fire `CATEGORIZER_CATEGORIES_UPDATED` **synchronously** if item data is already cached in the WoW client. This triggers `RefreshCategorizer("cus", ...)` mid-iterator, which drops all custom wrappers from `_wrappersByRaw` and creates new Lua tables. Items categorized before the refresh have OLD tables as keys in `arrangedItems`; lookups via `Get(id)` return the NEW tables.

**Fix:** Removed the `self._wrappersByRaw[rawKey] = nil` line from `CategoryStore:RefreshCategorizer`. Now `wrap_category()` finds the old wrapper in `_wrappersByRaw` and reuses the same Lua table, preserving object identity. One line removed, zero lines added.

**Lessons:**
1. Theoretical analysis of event/callback timing is unreliable — `ContinueOnItemLoad` firing synchronously was invisible to code reading. Debug output was essential.
2. Workarounds in consumers (`arrangedById` index) are fragile and can introduce new bugs. Fix the producer (`RefreshCategorizer` preserving `_wrappersByRaw`).
3. When Lua tables are used as dictionary keys, object identity is a load-bearing invariant. Any code path that replaces table instances (even with functionally identical ones) breaks callers that stored the old instance as a key.

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
