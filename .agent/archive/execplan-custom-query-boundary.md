# Move query orchestration behind custom categorizer and remove query knowledge from CategoryStore

This ExecPlan is a living document. Maintain it in accordance with `.agent/PLANS.md` so a novice can complete the work with only this file.

## Purpose / Big Picture

Players should still be able to set category queries in the UI and have items categorized by those queries, but the query system should become an internal implementation detail of the custom categorizer. After this change, `CategoryStore` will no longer be queried directly by `Categorizers/custom/query.lua`, and external callers (including GUI code) will interact with query state through `CustomCategories` APIs. This reduces coupling and makes future storage refactors safer.

The behavior to preserve is simple and observable: creating a custom category, saving a query, reopening/reloading, and categorizing items must continue to work exactly as before.

## Progress

- [x] (2026-02-14 12:21Z) Drafted this ExecPlan with current architecture, sequencing, and acceptance criteria.
- [x] (2026-02-14 12:27Z) Added `CustomCategories` query-facing APIs (`SetQuery` id resolution + cache sync, `GetQuery`, `GetQueryCategoryRawIds`).
- [x] (2026-02-14 12:27Z) Refactored `Categorizers/custom/query.lua` to remove `CategoryStore` dependency and initialize/query through `CustomCategories`.
- [x] (2026-02-14 12:27Z) Updated `categoriesGUI.lua` to read/write queries via `CustomCategories` boundary.
- [x] (2026-02-14 12:27Z) Updated `tests/Categorizers/query_test.lua` stubs and ran the full Lua suite successfully.

## Surprises & Discoveries

- Observation: `Categorizers/custom/query.lua` still calls `AddonNS.CategoryStore:GetCategorizerDb("cus")` directly in `GetCategories` and initialization, so query code still knows storage location.
  Evidence: `Categorizers/custom/query.lua` functions `GetCategories` and `OnInitialize`.
- Observation: `categoriesGUI.lua` writes/reads queries through `AddonNS.QueryCategories:*`, which means query details are still externally visible outside custom categorizer.
  Evidence: `categoriesGUI.lua` query save and selection handlers.
- Observation: query unit tests currently stub `CategoryStore` even though parser tests do not need storage.
  Evidence: `tests/Categorizers/query_test.lua` mock environment includes `CategoryStore` table.
- Observation: parser-only tests remained green after replacing the `CategoryStore` stub with `CustomCategories` stubs, confirming the parser/evaluator is storage-agnostic.
  Evidence: `lua tests/Categorizers/query_test.lua` exited 0 after the stub swap.

## Decision Log

- Decision: Keep query persistence field (`entry.query`) in current custom category SavedVariables for this plan; only move module boundaries now.
  Rationale: This plan targets encapsulation and dependency direction, not storage-schema migration. Mixing both increases risk and makes debugging harder.
  Date/Author: 2026-02-14 / Codex
- Decision: Add query-oriented read APIs to `CustomCategories` (for query module and GUI), and treat `QueryCategories` as compatibility facade during migration.
  Rationale: Allows incremental refactor with minimal breakage while preserving current user-visible behavior.
  Date/Author: 2026-02-14 / Codex

## Outcomes & Retrospective

Implemented as planned. `query.lua` no longer reads `CategoryStore`; it now uses `CustomCategories` APIs for query discovery and bootstrap. GUI query save/load now calls `CustomCategories` directly, so query persistence concerns are hidden behind the custom categorizer boundary. Compatibility facade methods on `AddonNS.QueryCategories` still work, but they delegate through `CustomCategories`.

Validation outcomes:
- `rg -n "GetCategorizerDb\\(|CategoryStore" Categorizers/custom/query.lua` produced no matches.
- `lua tests/categories_test.lua` exited 0.
- `lua tests/Categorizers/query_test.lua` exited 0.
- `lua tests/integration/persistence/savedvariable_test.lua` passed all scenarios.

## Context and Orientation

`categoryStore.lua` is the shared wrapper and layout persistence layer. It currently exposes categorizer-specific DB access through `GetCategorizerDb(categorizerId)`. `Categorizers/custom.lua` owns custom category creation, rename/delete, assignments, always-visible flags, and currently stores query strings under each custom category entry. `Categorizers/custom/query.lua` owns query parsing, compilation, and event wiring, but still directly reads custom DB through `CategoryStore`.

`categoriesGUI.lua` is the UI for custom categories. It currently uses `AddonNS.QueryCategories:SetQuery` and `AddonNS.QueryCategories:GetQuery` directly when editing query text. For this plan, we define “query concern leakage” as any non-custom module needing to know where/how custom query data is stored.

Key files:
- `Categorizers/custom.lua`
- `Categorizers/custom/query.lua`
- `categoriesGUI.lua`
- `tests/Categorizers/query_test.lua`
- `tests/integration/persistence/savedvariable_test.lua`

## Plan of Work

Milestone 1 establishes explicit query data access methods in `Categorizers/custom.lua`. Add methods that expose what the query module needs without exposing storage internals. Keep existing behavior and event triggers unchanged. Required APIs at end of milestone:
- `CustomCategories:GetQuery(rawId)` already exists and should remain.
- Add `CustomCategories:GetQueryCategoryRawIds()` returning an array of raw category ids with non-empty query.
- Add `CustomCategories:ForEachCategory(callback)` or equivalent read helper to iterate current custom category records without `CategoryStore` calls outside custom.

Milestone 2 refactors `Categorizers/custom/query.lua` to consume only `CustomCategories` APIs for query discovery and initialization. Remove direct calls to `AddonNS.CategoryStore:GetCategorizerDb("cus")`. Keep parser/compiler logic unchanged. Keep `QueryCategories` object if needed, but make it a thin adapter over `CustomCategories` and compiled-query cache.

Milestone 3 moves UI query read/write boundary to custom categorizer APIs. In `categoriesGUI.lua`, replace direct query facade usage with custom-owned query methods (for example `AddonNS.CustomCategories:SetQuery` and `AddonNS.CustomCategories:GetQuery`). If retaining `AddonNS.QueryCategories` for compatibility, keep it internal and avoid direct GUI reliance.

Milestone 4 updates tests and validates behavior. Adjust parser tests so they do not require `CategoryStore` mocks unless strictly needed. Add integration assertions that query persistence and query-based categorization still work after reload. Confirm no regressions in item reassignment and protected-category behavior.

## Concrete Steps

Work from addon root:

    cd "/mnt/c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/!dev_MyBags"

1. Edit `Categorizers/custom.lua`:
   - Add query-category listing/iteration helper APIs on `CustomCategories`.
   - Keep lazy DB access internal via existing `get_db()`.
   - Do not add fallback logic for missing globals; surface setup issues as errors.

2. Edit `Categorizers/custom/query.lua`:
   - Replace `CategoryStore:GetCategorizerDb("cus")` usage with new `CustomCategories` APIs.
   - Keep compiled query cache behavior (`compiledQueries`) unchanged.
   - Keep `CATEGORIZER_CATEGORIES_UPDATED` event trigger behavior unchanged.

3. Edit `categoriesGUI.lua`:
   - Replace query get/set calls to use `CustomCategories` query methods.
   - Preserve current UX: selecting a row loads query text; save button persists query and refreshes layout.

4. Edit tests:
   - `tests/Categorizers/query_test.lua`: remove unnecessary `CategoryStore` coupling in stubs.
   - `tests/integration/persistence/savedvariable_test.lua`: keep/extend scenario that persists query, reloads, and confirms query presence.

5. Run tests:

    lua tests/categories_test.lua
    lua tests/Categorizers/query_test.lua
    lua tests/integration/persistence/savedvariable_test.lua

Expected terminal shape:

    ✓ ...
    ✓ ...
    All integration scenarios completed.

Any failing test must be recorded in `Surprises & Discoveries` with short error excerpts and then resolved.

## Validation and Acceptance

Acceptance is behavior-based:

- Query authoring still works: create custom category in GUI, set query, close/reopen, query text is preserved.
- Query categorization still works: items matching query appear in correct category.
- No query module direct dependency on `CategoryStore`: `Categorizers/custom/query.lua` contains zero references to `GetCategorizerDb` or direct custom DB table traversal.
- Existing automated tests pass.

A quick static verification command for the dependency boundary:

    rg -n "GetCategorizerDb\(|CategoryStore" Categorizers/custom/query.lua

Expected result:

    (no matches)

## Idempotence and Recovery

This refactor is safe to repeat because it is boundary-preserving and storage-preserving. Re-running edits should not mutate saved data format. If work is interrupted, re-open this plan, continue from unchecked `Progress` items, and re-run the full test list. If a boundary change breaks behavior, temporarily keep a compatibility shim in `QueryCategories` while restoring tests, then remove remaining direct dependencies in a follow-up commit.

## Artifacts and Notes

Boundary and test evidence:

    $ rg -n "GetCategorizerDb\(|CategoryStore" Categorizers/custom/query.lua
    (no matches)

    $ lua tests/integration/persistence/savedvariable_test.lua
    ✓ fresh install seeds defaults
    ✓ custom categories persist with namespaced layout
    ✓ item move reassigns through hooks and respects protected target
    ✓ clearing inputs removes stored data
    All integration scenarios completed.

No test failures were encountered during this implementation.

## Interfaces and Dependencies

Required interfaces after this plan:

In `Categorizers/custom.lua`:

    function CustomCategories:GetQuery(rawId) -> string
    function CustomCategories:SetQuery(rawId, query) -> nil
    function CustomCategories:GetQueryCategoryRawIds() -> { rawId1, rawId2, ... }

In `Categorizers/custom/query.lua`:

    function AddonNS.QueryCategories:GetCompiled(categoryOrId) -> function|nil
    function AddonNS.QueryCategories:SetQuery(categoryOrId, query) -> nil
    function AddonNS.QueryCategories:DeleteQuery(categoryOrId) -> nil

Dependency direction after refactor:
- Allowed: `query.lua` -> `CustomCategories`.
- Not allowed: `query.lua` -> `CategoryStore`.
- GUI should call `CustomCategories` for query persistence/read, or a custom-owned facade that does not expose storage internals.

Revision note (2026-02-14 12:21Z): Initial draft created to execute TODO item “custom.lua should interact directly with query.lua and hide query concerns from CategoryStore”.
Revision note (2026-02-14 12:27Z): Marked implementation complete, recorded boundary verification and test evidence, and updated living sections to match completed refactor work.
