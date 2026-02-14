# Move custom persistence ownership from CategoryStore to CustomCategories

This ExecPlan is a living document and is maintained in accordance with `.agent/PLANS.md`.

## Purpose / Big Picture

Custom category persistence (manual item assignments, queries, always-visible flags, IDs) should be fully owned by `CustomCategories` so `CategoryStore` stays focused on shared wrapper/layout concerns. After this change, users keep existing setups, new data persists in `db.userCategories`, and legacy shapes are migrated safely using dual-read single-write.

## Progress

- [x] (2026-02-14 13:07Z) Implemented custom-owned bootstrap/migration in `Categorizers/custom.lua` using `db.userCategories`.
- [x] (2026-02-14 13:07Z) Wired `AddonNS.CustomCategories:LoadOrBootstrap(AddonNS.db, AddonNS.LegacyDB)` in `init.lua` after `CategoryStore` bootstrap.
- [x] (2026-02-14 13:07Z) Removed custom-specific migration ownership from `categoryStore.lua`; left shared layout/item-order migration only.
- [x] (2026-02-14 13:08Z) Updated integration tests for new storage shape plus migration scenarios from `db.categorizers.cus`, `db.categories`, and legacy global DB.
- [x] (2026-02-14 13:09Z) Ran full Lua suite and verified boundary cleanup with search checks.
- [x] (2026-02-14 13:10Z) Updated `TODOs.md` statuses/notes for completed persistence boundary work.

## Surprises & Discoveries

- Observation: Shared layout migration from legacy global data still needed to happen before custom migration could map category names to IDs.
  Evidence: `CategoryStore:_migrateFromLegacy` now preserves raw legacy layout values; `CustomCategories` converts those names/old IDs into `cus-*` IDs once category mapping exists.

## Decision Log

- Decision: Store custom category persistence under top-level `db.userCategories`.
  Rationale: Hard ownership boundary and cleaner future refactors.
  Date/Author: 2026-02-14 / Codex
- Decision: Keep `CategoryStore:GetCategorizerDb` API but remove custom-category consumers.
  Rationale: Minimize blast radius while achieving boundary goal.
  Date/Author: 2026-02-14 / Codex
- Decision: Use dual-read single-write migration with pruning of stale old custom buckets.
  Rationale: Preserve user data while converging to single persisted truth.
  Date/Author: 2026-02-14 / Codex

## Outcomes & Retrospective

Completed as planned:
- Custom persistence lifecycle and migration now live in `Categorizers/custom.lua`.
- `CategoryStore` no longer builds/stores custom fields (`items/query/alwaysVisible`) during migration.
- Runtime behavior and query cache behavior remain intact.
- Integration suite now verifies migration from all three old sources to `db.userCategories`.

## Context and Orientation

Files changed:
- `Categorizers/custom.lua`
- `categoryStore.lua`
- `init.lua`
- `tests/integration/persistence/savedvariable_test.lua`
- `TODOs.md`

Key interfaces now present:
- `AddonNS.CustomCategories:LoadOrBootstrap(db, legacyDb)`
- `AddonNS.CustomCategories:GetStorage()`

Storage shape now persisted:
- `db.userCategories` with fields: `schemaVersion`, `id`, `name`, `nextId`, `categories`.

## Concrete Steps

Working directory:

    /mnt/c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/!dev_MyBags

Validation commands run:

    lua tests/categories_test.lua
    lua tests/Categorizers/query_test.lua
    lua tests/integration/persistence/savedvariable_test.lua
    rg -n "GetCategorizerDb\(\"cus\"\)|categorizers\.cus|db\.categories" Categorizers/custom.lua Categorizers/custom/query.lua categoriesGUI.lua categoryStore.lua tests/integration/persistence/savedvariable_test.lua

## Validation and Acceptance

All acceptance criteria are met:
- Custom data is persisted under `db.userCategories`.
- Migration from `db.categorizers.cus`, `db.categories`, and legacy global DB works.
- `CategoryStore` no longer owns custom field migration.
- Test suite passes.

## Idempotence and Recovery

Migration logic is idempotent:
- Repeated load/bootstrap reuses normalized `db.userCategories`.
- Old custom buckets are pruned to avoid duplicate persisted truth.
- Layout ID normalization is repeatable and stable.

## Artifacts and Notes

Integration test summary:

    ✓ fresh install seeds defaults
    ✓ custom categories persist with namespaced layout
    ✓ item move reassigns through hooks and respects protected target
    ✓ clearing inputs removes stored data
    ✓ custom category query updates compiled cache via direct API
    ✓ migrates from db.categorizers.cus to userCategories
    ✓ migrates from old db.categories and converts cat layout ids
    ✓ migrates from legacy global and maps layout names
    All integration scenarios completed.

Boundary check summary:

    rg -n "GetCategorizerDb\(\"cus\"\)" Categorizers/custom.lua Categorizers/custom/query.lua categoriesGUI.lua
    (no matches)

Revision note (2026-02-14 13:10Z): Initial completed implementation record added with test/migration evidence and TODO status updates.
