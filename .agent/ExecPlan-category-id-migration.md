# Category ID Migration and Category Object Refactor
 
This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.
 
Reference: `.agent/PLANS.md`. Maintain this document exactly as required there; update every section when new information appears.
 
## Purpose / Big Picture
 
Players currently lose manual item groupings or accumulate broken data whenever they rename or delete a custom category because SavedVariables use the user-facing name as the identifier. This plan refactors MyBags so every category—dynamic or user-created—has a stable, installation-specific ID. SavedVariables will migrate to a new schema, a `Category` object will encapsulate metadata, and the unified categorizer will resolve both manual assignments and queries by ID. After implementation the addon will survive renames, prevent orphaned storage, and keep drag-and-drop, layouts, and toggles working without regressions. Migration happens automatically on first load and persists to a new SavedVariable while keeping a read fallback to the legacy format.
 
## Progress
 
- [x] (2025-10-29 16:44Z) Draft ExecPlan capturing current architecture, migration goals, and work breakdown.
- [ ] Implementation phase (category store, migrations, refactors) pending.
- [ ] Validation phase (full Lua test suite, manual smoke in-game) pending.
 
## Surprises & Discoveries
 
- Observation: None recorded yet.
  Evidence: Implementation has not started; update once coding begins.
 
## Decision Log
 
- Decision: New SavedVariable roots will be `dev_MyBagsDB` in development builds and `MyBagsDB` in production, replacing the `*DBGlobal` names while keeping them available for fallback reads.
  Rationale: Distinguishes the migrated schema, avoids fighting existing `*_DBGlobal` files, and lets us detect whether migration has already completed.
  Date/Author: 2025-10-29 / Codex (assistant).
- Decision: Category IDs will use the prefix `cat-` followed by a monotonically increasing integer stored in `db.sequences.category`, while dynamic sources use reserved IDs such as `sys:new` or `equip:<setID>` that are deterministic without persisting duplicate data.
  Rationale: Ensures uniqueness per installation, simplifies migration bookkeeping, and keeps dynamic categories stable without writing redundant state.
  Date/Author: 2025-10-29 / Codex.
- Decision: A new module `categoryStore.lua` will own Category objects, persistence, migrations, and item assignments; legacy modules (`custom.lua`, `query.lua`, `categories.lua`) will delegate to it.
  Rationale: Centralizes ID-aware logic, satisfies the Separation of Concerns policy, and gives all consumers a consistent API.
  Date/Author: 2025-10-29 / Codex.
 
## Outcomes & Retrospective
 
Pending implementation. Populate with lessons learned once the refactor ships.
 
## Context and Orientation
 
The addon initialises in `init.lua`, which decides the SavedVariable name (`dev_MyBagsDBGlobal` or `MyBagsDBGlobal`) and exposes a shared `AddonNS` namespace. SavedVariables currently store several name-keyed tables: `customCategories` (manual assignments), `queryCategories` (string filters), `categoriesColumnAssignments` (column ordering by display name), `collapsedCategories`, `categoriesToAlwaysShow`, and `itemOrder`. These tables are hydrated in modules such as `Categorizers/custom.lua`, `Categorizers/query.lua`, `categoriesColumnAssignment.lua`, `collapsed.lua`, and `itemsOrder.lua`.
 
`categories.lua` registers categorizers and returns category tables with the `name` and `protected` flags. Drag-and-drop behaviours in `dragndrop.lua` rely on category names to reassign items or move categories between columns. UI tooling in `categoriesGUI.lua` lists categories by name, handles renames via `AddonNS.CustomCategories:RenameCategory`, and persists toggles through `CategorShowAlways`.
 
Tests use `tests/categories_test.lua` for category registration, `tests/Categorizers/query_test.lua` for query parsing, and `tests/integration/persistence/savedvariable_test.lua` with `tests/integration/persistence/harness.lua` to assert SavedVariable lifecycle. The harness currently loads modules that depend on the legacy schema and expects the global variable `dev_MyBagsDBGlobal`. Any migration must update these fixtures.
 
Terminology to use consistently:
 
Category ID: A stable identifier string stored in SavedVariables, independent of the user-facing name.
Category object: A Lua table returned by the category store with fields `id`, `name`, `categorizer`, `protected`, optional `query`, `alwaysVisible`, optional `itemId` (for equipment sets), and helper methods for mutation.
Legacy database: The schema written to `*DBGlobal` using category names as keys.
 
## Plan of Work
 
Start by introducing a Category store and migration scaffolding, then refactor consumers in order of dependency, and finally adjust the UI and tests.
 
1. Create `categoryStore.lua`. This module will expose `AddonNS.CategoryStore` with responsibilities:
   initialise from SavedVariables, run migrations, generate new IDs, return Category objects, and manage item assignments. Define helper methods such as `:Get(id)`, `:All()` (iterable ordered map), `:CreateCustom(name, opts)`, `:Rename(id, newName)`, `:Delete(id)`, `:AssignItem(itemID, categoryId)`, `:UnassignItem(itemID)`, `:SetQuery(id, query)`, `:SetAlwaysVisible(id, flag)`, and `:RecordDynamicCategory(props)` for system categorizers. Implement the Category object as a table with metatable giving read/write helpers that update both in-memory state and persistence.
 
2. Update `init.lua` to:
   - Define new SavedVariable names `dev_MyBagsDB` / `MyBagsDB`.
   - Populate `AddonNS.LegacyDB` when the old variable exists.
   - Initialise `AddonNS.db` via `CategoryStore:LoadOrBootstrap`, which returns the migrated schema and ensures `db.version == 2`.
   - Retain the ability to read legacy data if the new database is missing while ensuring the addon always saves back to the new variable.
 
3. Implement migration logic inside `categoryStore.lua` with access to both `AddonNS.LegacyDB` and the new target store:
   - Build a map of legacy names to generated IDs using `db.sequences`.
   - Copy manual assignment lists (`customCategories`) into `categories[id].items`.
   - Translate query strings into `categories[id].query`.
   - Carry `categoriesToAlwaysShow` into `categories[id].alwaysVisible`.
   - Move layout tables so `db.layout.columns[columnIndex]` and `db.layout.collapsed` use IDs.
   - Preserve `itemOrder`.
   - Create reserved dynamic IDs: `sys:unassigned`, `sys:new`, and `equip:<equipmentSetID>`. Mark them `protected = true` as appropriate.
   Provide idempotency (running migration twice leaves the same result) and log decisions for later debugging via `AddonNS.printDebug`.
 
4. Refactor `categories.lua` to delegate to `CategoryStore`:
   - `RegisterCategorizer` should receive a categorizer record that can call `AddonNS.CategoryStore:RecordDynamicCategory` and fetch category objects by ID.
   - `Categorize` must return Category objects and attach `itemButton.ItemCategories` with objects instead of name tables.
   - Remove `GetCategoryByName`, replacing it with `GetCategoryById` and `FindByName` (for UI search) that query the store.
   - Ensure the unassigned sentinel uses the `sys:unassigned` Category object.
 
5. Replace `Categorizers/custom.lua` and `Categorizers/query.lua` with a unified categorizer module:
   - Either merge them into a new `Categorizers/user.lua` or refactor one file to own both behaviours under a single `AddonNS.UserCategories` namespace.
   - Maintain separation of concerns by keeping persistence and querying inside the store while the categorizer focuses on returning category IDs based on itemID or query evaluation.
   - Update query compilation to store compiled functions inside the Category store keyed by ID.
   - Update rename/delete flows to operate by ID and emit events carrying Category objects.
 
6. Revise `categoriesColumnAssignment.lua`, `collapsed.lua`, and `CategorShowAlways` to use IDs:
   - Column layouts should read and write `db.layout.columns`, storing category IDs and refreshing references through the store.
   - Collapsed state should reference `db.layout.collapsed[categoryId]`.
   - Always-show toggles should call `CategoryStore:SetAlwaysVisible`.
 
7. Refactor drag-and-drop in `dragndrop.lua`:
   - Replace name-based data with `category.id`.
   - Update event payloads (`ITEM_MOVED`, `CATEGORY_MOVED`, `CATEGORY_MOVED_TO_COLUMN`, `CUSTOM_CATEGORY_RENAMED`, `CUSTOM_CATEGORY_DELETED`) to pass Category objects or IDs consistently. All emitters and listeners must follow the new signature.
   - Ensure `AssignToCategory` functions resolve categories via the store, respect `protected`, and update assignments using `CategoryStore`.
 
8. Update UI management in `categoriesGUI.lua`:
   - Populate the WowList from `CategoryStore:All()` filtered to user-managed categories.
   - Track the selected category ID rather than the name.
   - Wire the rename, delete, always-show, and query save handlers to call store methods.
   - Display category names via `category:GetName()`, and keep the query edit box in sync with `category.query`.
 
9. Adjust ancillary modules (`itemsOrder.lua`, `main.lua`, `categoriesColumnAssignment.lua`) to work with Category IDs wherever they interact with layout or assignments. Ensure tooltips and sorted categories fetch display names from Category objects.
 
10. Update the TOC file:
    - Change `## SavedVariables` entries to the new names.
    - Add the new `categoryStore.lua` (and any other new module) to the load order before dependent files.
 
11. Revise and extend tests:
    - Upgrade `tests/integration/persistence/harness.lua` to load the new module order, seed `dev_MyBagsDB`, and expose both new and legacy globals so migration can run.
    - Update `tests/integration/persistence/savedvariable_test.lua` to expect ID-based structures, new layout schema, and Category fields.
    - Enhance unit tests for category registration to assert Category objects expose IDs, names, and queries.
    - Add migration-specific tests covering legacy rename propagation, fallback loading when only the old DB exists, and ID generation uniqueness.
 
12. Perform manual smoke checks:
    - Provide a short QA checklist for in-game validation (rename a category, drag items, collapse categories) to include under `Validation and Acceptance`.
 
## Concrete Steps
 
Execute commands from the addon root (`Interface/AddOns/!dev_MyBags`).
 
    lua tests/categories_test.lua
    lua tests/Categorizers/query_test.lua
    lua tests/integration/persistence/savedvariable_test.lua
 
Before coding, run the existing suite to capture current baselines. After implementation, rerun all commands and ensure they pass. If new tests are added (for migration, Category store, or drag-and-drop behaviour), document their invocation here.
 
## Validation and Acceptance
 
Automated acceptance requires all Lua tests above to pass with the migrated schema. Add a migration-specific test that fails against the legacy database but passes after the new code runs to prove the conversion occurs.
 
Manual acceptance in-game: load the addon on a character with existing categories, rename a custom category, log out, log back in, and confirm the category retains items and layout. Create a new category, assign items, move it between columns, collapse it, and confirm persistence. Confirm Equipment Set and New Items categories retain functionality with Category IDs.
 
## Idempotence and Recovery
 
Migration functions must check whether `db.version` is already 2 before mutating data, so reloading the UI or logging multiple times leaves SavedVariables unchanged. Keep the legacy database untouched for rollback; if a user removes the new SavedVariable file, the addon should re-run the migration from the legacy data on next launch. Provide helper functions to recompute derived maps (item assignments, compiled queries) on demand for recovery after any desync.
 
## Artifacts and Notes
 
Capture representative before/after SavedVariable snippets while implementing migration, for example:
 
    -- Legacy custom category
    customCategories = { Potions = { 171267, 171268 } }
 
    -- Migrated v2 state
    categories = {
      ["cat-1"] = {
        id = "cat-1",
        name = "Potions",
        categorizer = "custom",
        items = { 171267, 171268 },
        alwaysVisible = false,
      },
    }
    layout = {
      columns = { { "sys:new", "cat-1" }, {}, {} },
      collapsed = { ["cat-1"] = false },
    }
 
Update this section with real data captured during testing to help future maintainers debug migrations.
 
## Interfaces and Dependencies
 
Define the following interfaces:
 
    -- categoryStore.lua
    AddonNS.CategoryStore = {
      LoadOrBootstrap = function(self, legacyDb) -> db end,
      Get = function(self, id) -> Category|nil end,
      All = function(self, opts) -> iterator end,
      CreateCustom = function(self, name, opts) -> Category end,
      Rename = function(self, id, newName) -> Category end,
      Delete = function(self, id) end,
      AssignItem = function(self, itemId, categoryId) end,
      UnassignItem = function(self, itemId) end,
      SetQuery = function(self, categoryId, queryString) end,
      SetAlwaysVisible = function(self, categoryId, flag) end,
      RecordDynamicCategory = function(self, payload) -> Category end,
    }
 
Category objects must support:
 
    category.id           -- stable string
    category.name         -- mutable display name
    category.categorizer  -- "custom", "query", "system:new", "system:equipment", etc.
    category.protected    -- boolean
    category.query        -- optional string
    category.alwaysVisible-- boolean
    category.items        -- array of item IDs (custom/query categories only)
    category:SetName(newName)
    category:SetQuery(queryString)
    category:SetAlwaysVisible(flag)
 
Events will now emit Category IDs:
 
    CUSTOM_CATEGORY_RENAMED(event, categoryId, newName)
    CUSTOM_CATEGORY_DELETED(event, categoryId)
    CATEGORY_MOVED(event, draggedCategoryId, targetCategoryId)
    CATEGORY_MOVED_TO_COLUMN(event, draggedCategoryId, columnIndex)
    ITEM_MOVED(event, draggedItemId, targetItemId, draggedCategoryId, targetCategoryId, ...)
 
All listeners must be updated to resolve IDs through the store before acting.
 
---
Initial version drafted on 2025-10-29 by Codex to guide the category ID migration.
