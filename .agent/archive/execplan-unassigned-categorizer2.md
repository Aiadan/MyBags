# Unassigned catch-all categorizer

This ExecPlan is a living document. Maintain it in accordance with .agent/PLANS.md so a novice can finish the work without prior context.

## Purpose / Big Picture

Unassigned items should behave like a normal category so players always have a stable place to drop items that do not belong elsewhere. By turning Unassigned into its own categorizer and making it the last, catch-all category, items that match nothing else will still show up under a predictable bucket that can be collapsed, moved, and used as a drop target even when empty. Success means Unassigned is always available, respects OnItemAssigned/OnItemUnassigned hooks, and ordering of other categorizers stays unchanged.

## Progress

- [x] (2025-12-11 20:58Z) Drafted initial ExecPlan for converting Unassigned into a dedicated catch-all categorizer.
- [x] (2025-12-11 21:40Z) Added Unassigned categorizer module, store wiring (real wrapper, normalization), and load order updates.
- [x] (2025-12-11 21:46Z) Updated categorization flow/persistence hooks to use the real Unassigned wrapper and normalize stored layout ids.
- [x] (2025-12-11 21:46Z) Added unassigned categorizer coverage to tests and ran full Lua test suite.

## Surprises & Discoveries

- None encountered; test suite passed after wiring unassigned categorizer.

## Decision Log

- Decision: Use categorizer id "unassigned" with wrapper id forced to legacy "unassigned" and error if the categorizer is missing, avoiding any fallback stubs.
  Rationale: Preserves layout compatibility while surfacing misconfiguration instead of masking it.
  Date/Author: 2025-12-11 / Codex
- Decision: Normalize any stored layout/collapsed ids ending in "-unassigned" back to the canonical "unassigned" during LoadOrBootstrap.
  Rationale: Keeps persistence compatible with prior stub id and avoids duplicate entries after migration.
  Date/Author: 2025-12-11 / Codex

## Outcomes & Retrospective

- Unassigned is now a real categorizer loaded last, with layout persistence normalized to the canonical id and CategoryStore returning the real wrapper. Tests updated to expect Unassigned as the last matched category, and the full Lua suite passes. No surprises observed.

## Context and Orientation

Key files today:
- categories.lua registers categorizers via an OrderedMap and returns the first match from Categorize(), otherwise it returns a stub from CategoryStore:GetUnassigned(). It also calls category hooks (OnItemAssigned/OnItemUnassigned) when handling item moves.
- categoryStore.lua wraps raw categories with namespaced IDs, stores layout/collapsed/itemOrder, and currently defines a hard-coded _unassigned wrapper with id "unassigned". RefreshCategorizer/GetWrapperForRaw build wrapper IDs from categorizerId-rawId pairs. GetUnassigned simply returns the stub, not a real categorizer-backed wrapper.
- categoriesColumnAssignment.lua arranges categories into columns, appends unmatched categories to layout columns, and falls back to CategoryStore:GetUnassigned() when a column is empty.
- dragndrop.lua invokes Categories:HandleItemReassignment, which prevents moves into protected categories and fires hook callbacks; it relies on category objects being real drop targets.
- Categorizers/new.lua and Categorizers/EquipmentSet.lua register built-in categorizers, followed by Categorizers/custom.lua for user categories. There is no dedicated unassigned categorizer in the load order from !dev_MyBags.toc.

We need Unassigned to be a first-class categorizer so it participates in wrapper refresh, layout state, always-visible categories, and hook handling instead of being a special-case stub.

## Plan of Work

Define a dedicated Unassigned categorizer module under Categorizers/ (e.g., Categorizers/unassigned.lua) that exposes ListCategories (returns a single raw category), GetAlwaysVisibleCategories (returns that raw category so the drop target exists even when empty), and Categorize (always returns the raw category so it is the last match). Give the raw category a stable id that aligns with the existing UNASSIGNED constant and IsProtected() returns false; provide no-op OnItemAssigned/OnItemUnassigned hooks for interface completeness. Register it via Categories:RegisterCategorizer after all other categorizers, and update !dev_MyBags.toc to load it last so ordering stays intact.

Adjust categoryStore.lua to drop the hard-coded _unassigned stub in favor of a real wrapper. Special-case wrapper creation so the Unassigned wrapper keeps the legacy id ("unassigned") for layout/collapsed compatibility even though it is namespaced internally; expose an accessor that returns this real wrapper (no fallback stubs—assume the categorizer is registered). If later all callers are updated to pull directly from the categorizer, this accessor can be removed. Add a small migration in LoadOrBootstrap to normalize any stored layout/collapsed entries that reference either the legacy id or a namespaced form back to the canonical unassigned id.

Update categories.lua to rely on the registered Unassigned categorizer instead of manually injecting a stub. Keep ItemCategories ordering deterministic: other categorizers return first matches, and Unassigned should show up last. Ensure GetCategoryByName still resolves the stored constant to the canonical Unassigned wrapper.

Review downstream callers (categoriesColumnAssignment.lua, dragndrop.lua, gui components) and adjust any assumptions that Unassigned lacks names or hooks. Ensure the always-visible list includes Unassigned via the new categorizer so users can drop items onto it even when empty.

Refresh documentation/comments if needed to describe the new flow, but avoid touching README unless required by TODOs. Keep persistence minimal and avoid storing redundant fields per AGENTS.md.

## Concrete Steps

Work from the addon root (/mnt/c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/!dev_MyBags).
1) Create Categorizers/unassigned.lua with the described categorizer, register it, and add it to !dev_MyBags.toc after other categorizers.
2) Update categoryStore.lua with Unassigned wrapper handling and migration for stored layout ids.
3) Adjust categories.lua and any dependent modules to use the new categorizer and canonical Unassigned wrapper.
4) Add or update tests under tests/ to cover the catch-all behavior and layout compatibility; mirror existing test patterns in tests/categories_test.lua and integration persistence tests.
5) Run tests:
    lua tests/categories_test.lua
    lua tests/Categorizers/query_test.lua
    lua tests/integration/persistence/savedvariable_test.lua
Record any failures/output in Surprises & Discoveries and update the plan accordingly.

## Validation and Acceptance

After implementation, items with no other matches must always be categorized into Unassigned, and items with matches keep their existing ordering while still listing Unassigned as the last category in ItemCategories. The Unassigned category should render even when empty (via GetAlwaysVisibleCategories) and accept drops that clear assignments. All automated tests above should pass. Existing layouts and collapsed state should retain their placement of Unassigned after migration.

## Idempotence and Recovery

The new categorizer registration and migrations should be safe to run multiple times; layout normalization must handle already-normalized ids without duplication. If tests fail midway, re-run them after fixes; LoadOrBootstrap should remain additive and avoid deleting user data.

## Artifacts and Notes

No code changes yet; this file is the initial plan for implementing the Unassigned categorizer.

## Interfaces and Dependencies

Expected Unassigned categorizer interface in Categorizers/unassigned.lua:
    ListCategories() -> { rawCategory }
    GetAlwaysVisibleCategories() -> { rawCategory }
    Categorize(itemID, itemButton) -> rawCategory (catch-all)
    OnRightClick optional (likely none)
Raw category shape:
    GetId() -> "unassigned" (canonical)
    GetName() -> "Unassigned" (or nil if UI continues to supply a default label)
    IsProtected() -> false
    OnItemAssigned(itemId, context) / OnItemUnassigned(itemId, context) -> no-op

Note any future deviations in the Decision Log and update Progress as milestones are completed.

Revision note (2025-12-11 21:15Z): Removed suggestion of a defensive fallback for the Unassigned wrapper; implementation must assume the categorizer is registered and avoid fallbacks.
Revision note (2025-12-11 21:14Z): Clarified that any GetUnassigned accessor must return the real Unassigned wrapper (no stubs), and can be removed entirely if all callers consume the registered categorizer directly.
