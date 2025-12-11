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

1) Define raw category interface and wrapper contract: raw includes `id` (may be empty for singleton), `name`, `protected`, optional `query`, `items`, optional hooks `OnItemAssigned/Unassigned`, optional `alwaysVisible`. Wrapper exposes store ID `<catId>-<rawId>`, forwards hooks, and defaults `alwaysVisible` to false.
2) Store changes (categoryStore.lua): add a wrapper registry keyed by `<categorizerId>-<rawId>`, helper to obtain/refresh wrappers from raw categories supplied by categorizers, and tolerate missing wrappers when resolving layout/collapsed/order. Remove dependence on central `db.categories`; introduce `db.categorizers` with the schema described. Keep layout/collapse/itemOrder in root and allow stale IDs.
3) Categorizers: add `ListCategories()` and `GetAlwaysVisibleCategories()` (default empty) to each categorizer (custom, equipment set, new, showAlways/query helpers). Custom stores its data under `db.categorizers.custom`; others store in their own slots. No cross-categorizer scans.
4) Categories module: adjust `GetConstantCategories`/show-always aggregation to ask each categorizer for always-visible raw categories, then wrap via the store.
5) Migration: replace old `db.categories`/version/sequences with new `db.categorizers` layout; no need to migrate released data. Seed data from legacy globals if present, mapping to categorizer IDs (e.g., custom => `custom`, equipment sets => `equipment-set`, new => `new`).
6) Tests: update/query tests to use new paths; add coverage for wrapper ID generation, missing/raw categories in layout, always-visible aggregation, and singleton categories (empty raw id). Ensure integration tests pass with the new schema.

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
