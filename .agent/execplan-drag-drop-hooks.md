# Drag-and-drop category reassignment hooks

This ExecPlan is a living document and must be maintained in accordance with .agent/PLANS.md. Update every section as work proceeds so another contributor can finish the task using only this file.

## Purpose / Big Picture

Enable item drag-and-drop to notify real category objects with explicit OnItemAssigned and OnItemUnassigned hooks while respecting protected categories. The goal is to stop categorizers from individually listening for assignment events and instead route reassignment through a central handler that calls per-category callbacks. After implementation, dropping an item between non-protected categories will invoke those hooks, allow dynamic categorizers to persist or react however they need, and skip dispatch entirely when a protected category is involved.

## Progress

- [x] (2025-12-10 22:29Z) Drafted initial ExecPlan covering category assignment hook redesign.
- [x] (2025-12-10 23:02Z) Added hook storage on Category objects, central reassignment dispatcher, and refactored drag-and-drop to emit category references.
- [x] (2025-12-10 23:02Z) Migrated categorizers and ordering to hook-based reassignment; pending test updates.
- [x] (2025-12-10 23:03Z) Added hook coverage in unit tests and ran full Lua test suite (all passing).

## Surprises & Discoveries

- Allowing protected categories as sources (but not targets) was necessary to keep “New” items movable; clearing the new-item flag now happens through the category hook context rather than legacy ITEM_CATEGORY_CHANGED listeners.

## Decision Log

- Decision: Only block reassignment dispatch when the target category is protected (allow protected sources to participate).
  Rationale: Items must be movable out of protected dynamic categories like “New” so they can be assigned elsewhere and clear their new-item state; blocking on protected sources would freeze those flows.
  Date/Author: 2025-12-10 23:02Z / Codex

## Outcomes & Retrospective

Hook-based reassignment is wired end-to-end: drag-and-drop emits category objects, Categories dispatches to per-category hooks, custom and dynamic categories react appropriately, and tests remain green. Protected targets block moves while protected sources can be exited. Further manual verification in-game is recommended to validate UI flows.

## Context and Orientation

Current drag-and-drop flow lives in dragndrop.lua; it fires ITEM_MOVED and ITEM_CATEGORY_CHANGED events and directly calls CustomCategories to assign items. Categorizers like Categorizers/custom.lua and Categorizers/new.lua subscribe to ITEM_MOVED (and ITEM_CATEGORY_CHANGED) to update assignments or clear the “New” flag. ItemsOrder (itemsOrder.lua) also listens to ITEM_MOVED to maintain the persisted item order. Categories are resolved via CategoryStore (categoryStore.lua), which exposes Category objects with helpers like IsProtected and GetName, and Categories (categories.lua) registers categorizers and picks matches. Event constants are defined in init.lua. Protected categories (e.g., system “New”) are meant to ignore manual reassignment.

## Plan of Work

Describe and enforce a category-level hook contract. Extend Category objects so they can carry non-persisted OnItemAssigned and OnItemUnassigned callbacks supplied by whatever creates the category. Custom/user categories can attach proxies that update CategoryStore assignments; dynamic categories recorded via CategoryStore:RecordDynamicCategory can accept callbacks in their metadata.

Introduce a single dispatcher inside categories.lua that listens for item reassignment events. It should map incoming category identifiers to real Category objects, refuse to act if either category is protected, and then call source:OnItemUnassigned(...) and target:OnItemAssigned(...) (if present) with enough context (itemId, source/target categories, drag source/target buttons) for categorizers to manage their own storage. Keep the dispatcher as the only listener for assignment events; other modules should subscribe to richer signals exposed by this handler if needed.

Update dragndrop.lua to send category reassignment through the dispatcher using real Category references (fetched from buttons or CategoryStore) instead of raw ids/names. Prevent firing the assignment event when either the origin or destination category is protected. Ensure drag-and-drop still queues layout updates only once per move.

Refit categorizers to the new contract. Remove their direct ITEM_MOVED/ITEM_CATEGORY_CHANGED listeners and instead define OnItemAssigned/OnItemUnassigned for the categories they expose. For custom categories, those hooks should proxy to CategoryStore:AssignItem/UnassignItem and trigger any necessary category list refresh. For the “New” dynamic category, use hooks to clear the new-item state when an item is assigned elsewhere, while leaving its protected status intact. Adjust ItemsOrder to react either via the dispatcher or a dedicated signal that replaces the old ITEM_MOVED payloads.

Design and add tests that prove the new flow. Cover: assignment calls category hooks; protected categories block dispatch; custom category proxies persist assignments; “New” hook clears the flag; ItemsOrder continues to update ordering. Update integration tests in tests/integration/persistence/savedvariable_test.lua and add focused unit coverage near the new dispatcher.

## Concrete Steps

Work in /mnt/c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/!dev_MyBags.

1. Extend category representations and add the dispatcher in categories.lua and/or categoryStore.lua, ensuring OnItemAssigned/OnItemUnassigned are available on Category objects without persisting functions to SavedVariables.
2. Route drag-and-drop reassignment through the dispatcher with real Category references and protected-category guards. Remove direct assignment calls that bypass the dispatcher.
3. Update categorizers (Categorizers/custom.lua, Categorizers/new.lua, and any others exposing categories) to register hook proxies instead of event listeners; adjust ItemsOrder to consume the new event/dispatcher output.
4. Add or update tests alongside existing suites. Run the repository’s Lua tests and iterate until green:

    lua tests/categories_test.lua
    lua tests/Categorizers/query_test.lua
    lua tests/integration/persistence/savedvariable_test.lua

## Validation and Acceptance

Acceptance requires being able to drop an item from one non-protected category to another and observe the target category’s OnItemAssigned firing and the source category’s OnItemUnassigned firing exactly once, with the assignment persisted or reacted to according to each categorizer’s hook. Dropping an item when either category is protected must skip dispatch and leave assignments unchanged. ItemsOrder must still reorder items after a move. All Lua test suites above must pass. For manual proof, move an item between two custom categories in-game and verify persistence after reload; confirm that “New” flags clear when items are reassigned via hooks rather than event listeners.

## Idempotence and Recovery

Ensure dispatcher guards prevent duplicate hook invocations when the same category is passed for both source and target or when events repeat; exiting early must leave data unchanged. Hook registration should be safe to call multiple times per load. If a step fails mid-change, restoring CategoryStore’s in-memory maps and re-running tests should bring the environment back to a clean state without touching SavedVariables manually.

## Artifacts and Notes

Capture brief evidence snippets (test output or log lines showing hook invocation and protected-category skips) here as work proceeds. Keep examples short and directly tied to acceptance criteria.

## Interfaces and Dependencies

Expose or document the following interfaces after refactor:

    Category:OnItemAssigned(itemId, sourceCategory, context)
    Category:OnItemUnassigned(itemId, targetCategory, context)

context should include drag source/target buttons when available for consumers like the “New” categorizer that need bag/slot data.

    AddonNS.Categories:HandleItemReassignment(itemId, sourceCategoryIdOrObj, targetCategoryIdOrObj, sourceButton, targetButton)

The dispatcher should be the sole subscriber to ITEM_MOVED (or a renamed event if introduced) and should emit any downstream signals ItemsOrder or UI refresh code need, keeping callers unaware of CategoryStore internals.
