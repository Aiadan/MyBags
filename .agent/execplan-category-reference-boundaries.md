# Reduce category id/name lookups and standardize category object boundaries

This ExecPlan is a living document. Maintain it in accordance with `.agent/PLANS.md`.

## Purpose / Big Picture

The addon still passes category identifiers and sometimes category names through internal flows, then resolves them later. This makes behavior harder to reason about and keeps ambiguity (especially name-based lookups) alive. After this change, core flows should pass category wrapper objects directly, and id/name conversions should happen only at narrow I/O edges. User-visible behavior must stay unchanged.

Observable result: drag/drop reassignment, category reordering, column moves, and GUI interactions still behave the same, while internal event handlers consume category objects instead of mixed id/name/table input shapes.

## Progress

- [x] (2026-02-14 17:40Z) Audited current hotspots for id/name lookups and mixed-shape category parameters.
- [x] (2026-02-14 18:52Z) Refactored category move events to carry category wrapper objects end-to-end in drag/drop and assignment handlers.
- [x] (2026-02-14 18:52Z) Removed name-based category resolution from drag/drop and column assignment internals.
- [x] (2026-02-14 18:52Z) Kept `Categories:GetCategoryByName` as compatibility API only; eliminated internal runtime call sites in targeted modules.
- [x] (2026-02-14 18:53Z) Added integration coverage for object-based category move payloads and delete/removal behavior.
- [x] (2026-02-14 18:54Z) Ran full Lua test suite and updated `TODOs.md` status details.

## Surprises & Discoveries

- `categoriesColumnAssignment.lua` still accepts mixed input (`string`, object with `id`, object with `name`) via `resolveCategoryId`, which keeps name/id lookups in internal event handling.
  Evidence: `categoriesColumnAssignment.lua` function `resolveCategoryId`.
- `dragndrop.lua` still emits `CATEGORY_MOVED` and `CATEGORY_MOVED_TO_COLUMN` with ids, and custom GUI drop still uses `GetCategoryByName` fallback.
  Evidence: `dragndrop.lua` calls in `itemOnReceiveDrag`, `categoryOnReceiveDrag`, `backgroundOnReceiveDrag`, `customCategoryGUIOnReceiveDrag`.
- `categories.lua` still exposes `GetCategoryByName` using `CategoryStore:GetByName`, which is inherently ambiguous when names collide.
  Evidence: `categories.lua` `GetCategoryByName`; `categoryStore.lua` `GetByName` comment about ambiguity.
- Regression discovered during implementation: existing reorder insertion logic in `categoriesColumnAssignment.lua` could produce an out-of-bounds `table.insert` position when moving upward within the same column.
  Evidence: failing integration test `category move events use category references for reorder and column move` with `bad argument #2 to 'insert' (position out of bounds)`.
  Resolution: adjusted target-row shifting after removal and inserted at `targetRow + 1`.

## Decision Log

- Decision: Event payloads for category move semantics (`CATEGORY_MOVED`, `CATEGORY_MOVED_TO_COLUMN`) will use category wrapper objects, not ids/names.
  Rationale: This is the highest-leverage internal boundary; once standardized, layout logic no longer needs mixed-shape resolvers.
  Date/Author: 2026-02-14 / Codex
- Decision: Keep layout persistence as category ids (`layout.columns`), but convert wrapper->id at persistence write points only.
  Rationale: DB shape remains stable while runtime logic becomes object-based.
  Date/Author: 2026-02-14 / Codex
- Decision update: for `categoriesColumnAssignment.lua`, keep move/layout event payloads id-based as the primary contract to avoid wrapper/load-order coupling in this persistence-oriented module.
  Rationale: IDs are the canonical persisted shape and are safer for module isolation; name-based lookup remains removed.
  Date/Author: 2026-02-14 / Codex
- Decision: Keep `Categories:GetCategoryByName` as compatibility API temporarily, but no internal core flow should depend on it after this refactor.
  Rationale: Limits blast radius while avoiding abrupt external breakage.
  Date/Author: 2026-02-14 / Codex

## Outcomes & Retrospective

Implemented for targeted runtime paths (with id-based layout contract in `categoriesColumnAssignment.lua`):

- `dragndrop.lua` no longer uses category-name fallback in custom GUI drag/drop.
- `categoriesColumnAssignment.lua` keeps runtime/persisted layout as category ids (with explicit rationale comment) and no longer depends on name resolution.
- `categoriesGUI.lua` passes id payloads for custom category drag/drop list interactions.
- `Categorizers/custom.lua` emits `CUSTOM_CATEGORY_DELETED` with category id payload for column layout handling.

Remaining scope for the broader TODO remains around additional id-heavy boundary cleanup where ids are still valid for persistence/UI identity.

## Context and Orientation

Current relevant files and roles:

- `categories.lua`: categorizer registry, categorization, and reassignment hooks. Also exposes `GetCategoryById`/`GetCategoryByName`.
- `dragndrop.lua`: emits item/category move events and currently serializes categories as ids in several paths.
- `categoriesColumnAssignment.lua`: owns column arrangement/reordering and currently normalizes mixed category shapes via `resolveCategoryId`.
- `categoriesGUI.lua`: GUI list rows carry ids; drag/drop from list to bag uses `customCategoryGUIOnReceiveDrag` currently taking id-or-name.
- `categoryStore.lua`: authoritative wrapper lookup by id and optional by name.

Known mixed-shape patterns to eliminate from internals:

- `resolveCategoryId(input)` handling `string`, `{id}`, `{name}`.
- Drag/drop handlers passing ids into custom events and resolving later.
- Name fallback lookup in custom GUI drag-drop (`GetCategoryByName(...) or Get(id)`).

## Plan of Work

Milestone 1: normalize category move event payloads to wrapper objects.

In `dragndrop.lua`, emit `CATEGORY_MOVED` with `(pickedCategoryWrapper, targetCategoryWrapper)` and `CATEGORY_MOVED_TO_COLUMN` with `(pickedCategoryWrapper, columnNo)`. These wrappers are already present as `ItemCategory` on frames in most paths. Remove id extraction helper usage in these event emissions.

In `categoriesColumnAssignment.lua`, replace `resolveCategoryId` with object-oriented helpers:

- `categoryKey(category)` returns `category:GetId()`.
- event handlers require category objects; if non-table payload appears, fail fast by returning early.

Keep layout column storage as id strings, but conversion to ids should occur in one place right before manipulating `layoutColumns`.

Milestone 2: remove name lookup dependency from custom GUI drag-drop.

In `dragndrop.lua`, change `customCategoryGUIOnMouseUp` / `customCategoryGUIOnReceiveDrag` signatures to accept category wrappers (from row data) instead of id/name strings. Update `categoriesGUI.lua` row payload to include the wrapper object directly for callbacks while still preserving `id` for list identity/sorting.

This eliminates `GetCategoryByName` fallback from drag-drop path and removes ambiguity.

Milestone 3: tighten compatibility APIs and call sites.

- Keep `Categories:GetCategoryByName` and `CategoryStore:GetByName` for compatibility, but remove all core internal call sites introduced by this plan.
- Audit call sites with `rg` and ensure internal runtime paths use category wrappers or ids at persistence boundaries only.

Milestone 4: tests and regression safety.

Update/add tests:

- `tests/categories_test.lua` or a new unit under `tests/` for category move event semantics using wrapper payloads.
- Integration persistence tests should still pass unchanged behavior for reorder/move operations.
- Add guard test proving duplicate category names do not affect move behavior (because internal flow no longer resolves by name).

## Concrete Steps

Work in addon root:

    /mnt/c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/!dev_MyBags

1. Edit `dragndrop.lua`:
   - Emit category move custom events with wrapper objects.
   - Remove/stop using `getCategoryId` in event emission paths.
   - Update custom GUI drag/drop functions to consume category wrappers.

2. Edit `categoriesGUI.lua`:
   - In list row data, include `category = <wrapper>`.
   - Pass row `category` object to drag/drop handlers.

3. Edit `categoriesColumnAssignment.lua`:
   - Replace mixed resolver with object-based processing.
   - Convert category object to id only when reading/updating `layoutColumns`.

4. Optional compatibility cleanup in `categories.lua`:
   - Keep `GetCategoryByName`, but mark compatibility-only in comments.

5. Add/update tests in `tests/` for object-payload move flows and name-collision safety.

6. Run:

    lua tests/categories_test.lua
    lua tests/Categorizers/query_test.lua
    lua tests/integration/persistence/savedvariable_test.lua

7. Update `TODOs.md` status details for this partial item with completed/remaining bullets.

## Validation and Acceptance

Acceptance criteria:

- Category move events (`CATEGORY_MOVED`, `CATEGORY_MOVED_TO_COLUMN`) are handled using category wrapper objects.
- Internal column assignment code no longer accepts `{name}` / raw string category inputs in normal flow.
- Custom GUI drag/drop no longer calls `GetCategoryByName`.
- Behavior regression-free:
  - category reorder works,
  - move-to-column works,
  - item reassignment works,
  - persistence tests still pass.

Static verification commands:

    rg -n "GetCategoryByName\(|GetByName\(" dragndrop.lua categoriesColumnAssignment.lua categoriesGUI.lua
    rg -n "resolveCategoryId\(" categoriesColumnAssignment.lua

Expected after implementation:
- no `GetCategoryByName` use in these runtime files,
- `resolveCategoryId` removed or replaced by object-only helpers.

## Idempotence and Recovery

This refactor is code-structure focused and should be repeatable. If a step partially lands:

- keep event payloads and handlers aligned in the same commit to avoid mixed-payload runtime breakage,
- rerun full test suite after each milestone,
- if regression appears, restore compatibility by temporarily accepting both object and id in handlers, then remove dual path once all call sites are migrated.

## Artifacts and Notes

Capture during implementation:

- before/after `rg` output for `GetCategoryByName` call sites,
- small diff snippets for event payload changes,
- test outputs proving unchanged behavior.

Verification snippets:

    $ rg -n "GetCategoryByName\\(|GetByName\\(" dragndrop.lua categoriesColumnAssignment.lua categoriesGUI.lua categories.lua categoryStore.lua
    categories.lua:113:function AddonNS.Categories:GetCategoryByName(categoryName)
    categoryStore.lua:322:function CategoryStore:GetByName(name)

    $ lua tests/integration/persistence/savedvariable_test.lua
    ✓ fresh install seeds defaults
    ✓ custom categories persist with namespaced layout
    ✓ item move reassigns through hooks and respects protected target
    ✓ clearing inputs removes stored data
    ✓ custom category query updates compiled cache via direct API
    ✓ category move events use category references for reorder and column move
    ✓ category delete removes layout entry via category reference event
    ✓ migrates from db.categorizers.cus to userCategories
    ✓ migrates from old db.categories and converts cat layout ids
    ✓ migrates from legacy global and maps layout names
    All integration scenarios completed.

## Interfaces and Dependencies

Public/custom-event payload changes (internal contract):

- `CATEGORY_MOVED`:
  - before: `(pickedCategoryId, targetCategoryId)`
  - after: `(pickedCategoryWrapper, targetCategoryWrapper)`

- `CATEGORY_MOVED_TO_COLUMN`:
  - before: `(pickedCategoryId, columnIndex)`
  - after: `(pickedCategoryWrapper, columnIndex)`

Persistence dependency remains:

- `CategoryStore:GetLayoutColumns()` stores ids, so conversion `category:GetId()` stays at persistence boundary.

Revision note (2026-02-14 17:40Z): Initial draft created for TODO item “stop using ids or names ... use references to categories.”
Revision note (2026-02-14 18:54Z): Marked implementation complete for targeted move/drag-drop runtime paths, documented regression fix, test evidence, and TODO updates.
