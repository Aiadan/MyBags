# Per-Categorizer Wrappers and Namespaced Storage

This ExecPlan is a living document and must be maintained in accordance with .agent/PLANS.md. Update every section as work proceeds so another contributor can finish the task using only this file.

## Purpose / Big Picture

Move category ownership and persistence into each categorizer while the store provides namespaced wrappers used by layout/collapse/order. Categorizers return raw categories (with their own IDs and metadata); the store wraps them with stable IDs like `<categorizerId>-<rawId>` and exposes a unified interface. Layout/collapsed may keep stale IDs; runtime tolerates them. No version/sequences; a future SavedVariable name will handle migration if needed.

## Progress

- [x] (2025-12-11 00:00Z) Drafted plan for per-categorizer raw categories, store wrappers, and namespaced storage.
- [ ] Implement store wrapper layer and new storage schema.
- [ ] Refactor categorizers to supply raw lists and always-visible sets; update layout/collapse resolution and tests.

## Surprises & Discoveries

- None yet; log with evidence as work progresses.

## Decision Log

- Decision: Allow layout/collapse to retain stale category IDs; runtime skips missing categories and cleanup will be a separate ticket.
  Rationale: Simplifies rollout and avoids destructive pruning; stale entries are harmless.
  Date/Author: 2025-12-11 / Codex
- Decision: Query and stored assignment lists remain private to their owning categorizer; the wrapper contract excludes them to avoid cross-categorizer leakage.
  Rationale: Keeps categorizer isolation and prevents custom logic from affecting others.
  Date/Author: 2025-12-11 / Codex
- Decision: No central version/sequences for this schema; if migration is needed later, use a new SavedVariables name.
  Rationale: Avoids premature versioning and keeps rollback simple.
  Date/Author: 2025-12-11 / Codex

## Outcomes & Retrospective

Pending; fill in after milestones.

## Context and Orientation

Current: `CategoryStore` loads all categories from `db.categories` with a single schema, assigns IDs, and `CategoryStore:All()` returns every category. Categorizers (custom, equipment set, new, show always, query) rely on this central store for data like `alwaysVisible`, queries, and assignments. Layout/collapsed use store IDs and expect categories to exist.

Target: Each categorizer owns its data under `db.categorizers[<id>]` (e.g., `custom`), with raw categories containing `id`, `name`, `protected`, `query`, `items`, etc. The store wraps raw categories with namespaced IDs `<categorizerId>-<rawId>` (empty raw id => per-categorizer singleton) and exposes wrapper objects with defaults (e.g., `alwaysVisible` defaults false). The store queries each categorizer for its raw categories and always-visible set; categorizers do not register explicitly. Layout/collapsed/order keep using wrapper IDs; missing wrappers are skipped at runtime but persisted.

Target storage shape (example):

    dev_MyBagsDB = {
        categorizers = {
            custom = {
                name = "Custom",
                id = "cus",
                categories = {
                    ["13"] = { items = {224041, 224043}, protected = false, name = "Use - PvP world", query = "itemType  = 15 and itemSubType = 4" },
                    ["14"] = { items = {224041, 224043}, protected = true, name = "Pve" },
                },
            },
            -- other categorizers (e.g., equipment set "eq", new "new") store their own categories here
        },
        itemOrder = {232843, 249162},
        layout = {
            columns = {
                {"cus-13", "cus-14"},
                {"eq-1"},
                {"eq-5", "eq-2", "unassigned"},
            },
            collapsed = { ["cus-13"] = true, ["eq-5"] = true },
        },
    }

## Plan of Work

1) Define raw/wrapper interface: raw implements `GetId()` (raw id, empty allowed for singleton), `GetName()` (non-nil string), `IsProtected()` (bool), `IsAlwaysVisible()` (bool, default false), optional hooks `OnItemAssigned/Unassigned`. No query or stored assignment lists leave the categorizer. Wrapper exposes namespaced `GetId()` (`<categorizerId>-<rawId>` or `<categorizerId>-singleton`), delegates name/protected/alwaysVisible and hooks with safe defaults; no `GetItems`/assignments/query.
2) Store changes (categoryStore.lua): replace `db.categories`/sequences with `db.categorizers`; add wrapper cache keyed by `<categorizerId>-<rawId>`; lazily wrap raw categories supplied by categorizers; tolerate missing wrappers in layout/collapsed/order (skip at runtime, leave persisted). Keep layout/collapse/itemOrder at root; accept stale IDs. No version field; future migrations use a new SavedVariable name if needed.
3) Categorizers: add `ListCategories()` and `GetAlwaysVisibleCategories()` (default empty) and keep query/assignments private. Custom stores its data under `db.categorizers.custom`; equipment set/new and others use their own slots. Remove cross-categorizer scans.
4) Categories module: replace `CategoryStore:All()` reliance by aggregating categorizer `GetAlwaysVisibleCategories()` and wrapping them; keep categorizer isolation.
5) Migration/seeding: load from `db.categorizers` when present; for legacy globals, seed into the new per-categorizer buckets (e.g., custom ⇒ `custom`, equipment sets ⇒ `eq`, new ⇒ `new`), without needing to preserve old version/sequences.
6) Tests: update expectations for the new storage shape and wrapper IDs; add coverage for namespaced IDs, singleton raw ids, missing-wrapper tolerance in layout, and always-visible aggregation. Run the full Lua suite.

## Concrete Steps

1. Update storage schema in `categoryStore.lua` to use `db.categorizers` and wrapper cache; implement wrapper creation using `<categorizerId>-<rawId>`, skipping missing raw categories gracefully.
2. Add categorizer interfaces: each categorizer implements `ListCategories()` and `GetAlwaysVisibleCategories()`; adjust custom/equipment set/new/showAlways/query to source from `db.categorizers[theirId]` and return raw categories.
3. Replace `CategoryStore:All()` usages in custom/query/showAlways with categorizer-scoped lists. Update `Categories:GetConstantCategories` to aggregate via categorizer `GetAlwaysVisibleCategories`.
4. Handle layout/collapse resolution to ignore missing wrappers but keep persisted IDs. Support singleton categories (empty raw id) per categorizer.
5. Update tests: adjust paths and expectations for new storage shape; add new tests for wrapper IDs and stale layout tolerance. Run:
   - `lua tests/categories_test.lua`
   - `lua tests/Categorizers/query_test.lua`
   - `lua tests/integration/persistence/savedvariable_test.lua`

## Validation and Acceptance

Accepted when: the SavedVariable schema matches the provided example (`db.categorizers` with namespaced IDs in layout/collapsed), categorizers provide their own raw categories and always-visible sets, wrappers are created lazily with `<categorizerId>-<rawId>`, layout/collapsed tolerate stale IDs, and the full test suite above passes. Disabling a categorizer removes its runtime categories; stale layout IDs remain harmless.

## Idempotence and Recovery

Wrapper creation is idempotent; re-listing categories reuses or refreshes wrappers. Missing raw categories in layout/collapse are skipped without mutation. If a step fails, re-run load/test; stale entries remain harmless until an explicit cleanup task.

## Artifacts and Notes

Capture test runs and any wrapper/log evidence here as you proceed.

## Interfaces and Dependencies

Planned APIs (adjust as needed during implementation):

    Categorizer:ListCategories() -> { rawCategory... }
    Categorizer:GetAlwaysVisibleCategories() -> { rawCategory... } (default empty)
    CategoryStore:GetWrapper(categorizerId, rawCategory) -> wrapperCategory
    CategoryStore:WrapAllFromCategorizer(categorizerId) -> {wrapper...}

Wrapper ID format: `<categorizerId>-<rawId>`; if `rawId` is empty, use `<categorizerId>-singleton`. Hooks and flags are forwarded with defaults (`alwaysVisible` false). Stale layout IDs are tolerated. 

Method contracts for clarity:

Raw category (owned by categorizer):
    GetId() -> string (raw id; empty allowed for singleton)
    GetName() -> string (non-nil)
    IsProtected() -> bool
    IsAlwaysVisible() -> bool (default false)
    OnItemAssigned(itemId, context) [optional; no-op if missing]
    OnItemUnassigned(itemId, context) [optional; no-op if missing]
    (Any other fields/methods, like query or stored assignments, remain private to the categorizer.)

Wrapper category (store-provided):
    GetId() -> string (namespaced id `<categorizerId>-<rawId>` or `<categorizerId>-singleton`)
    GetName(), IsProtected(), IsAlwaysVisible() -> delegated to raw with defaults
    OnItemAssigned(itemId, context) -> forwards to raw hook if present
    OnItemUnassigned(itemId, context) -> forwards to raw hook if present
