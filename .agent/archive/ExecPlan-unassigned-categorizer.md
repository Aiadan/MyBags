# Unassigned Categorizer Runs Last
 
This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.
 
Reference: `.agent/PLANS.md`. Maintain this document exactly as required there; update every section when new information appears.
 
## Purpose / Big Picture
 
Players should experience Unassigned as a first-class category that is produced by its own categorizer rather than by an implicit fallback. Making Unassigned an explicit categorizer that always initializes after all other categorizers keeps ordering deterministic, lets later logic (such as collapsing or column placement) reason about it like any other source, and reduces hidden behaviour in `Categories:Categorize`. After implementation, every item without a match will be tagged by the Unassigned categorizer, while items that already matched another categorizer remain untouched, and the categorizer registration order will guarantee Unassigned runs last.
 
## Progress
 
- [x] (2025-12-10 22:16Z) Draft ExecPlan covering goal, current architecture, and planned work.
- [ ] Implement ordered categorizer pipeline changes and add Unassigned categorizer module.
- [ ] Validate via automated Lua suite and in-game smoke covering Unassigned ordering.
 
## Surprises & Discoveries
 
- Observation: None yet.
  Evidence: Plan drafted before implementation.
 
## Decision Log
 
- Decision: Model Unassigned as a dedicated categorizer module that registers itself after all existing categorizers and only emits the Unassigned category when no earlier categorizer produced a match.
  Rationale: Keeps separation of concerns (categorization logic lives with categorizers), makes ordering explicit, and avoids duplicating fallback logic across consumers.
  Date/Author: 2025-12-10 / Codex.
- Decision: Extend `Categories:Categorize` to pass the current matches table to each categorizer (backward compatible because Lua ignores extra args) and retain the final `CategoryStore:GetUnassigned()` fallback as a safety net if the module fails to load.
  Rationale: The matches table lets the Unassigned categorizer detect prior matches without global state, while the fallback prevents nil categories if the pipeline misfires.
  Date/Author: 2025-12-10 / Codex.
 
## Outcomes & Retrospective
 
Pending implementation. Populate with outcomes and lessons once the Unassigned categorizer lands and is verified.
 
## Context and Orientation
 
The addon initializes in `init.lua`, sets up the `AddonNS` namespace and constants, and hydrates SavedVariables before delegating category management to `categoryStore.lua`. `CategoryStore` owns persisted categories, item assignments, layout columns, and two system categories: `sys:new` for New Items and `sys:unassigned` for items without a match. `_ensureSystemCategories` always builds in-memory objects for these system categories; Unassigned currently has `name = nil` and `categorizer = "system:unassigned"` and is returned via `CategoryStore:GetUnassigned()`.
 
`categories.lua` maintains an ordered map of categorizers (backed by `utils/orderedMap.lua`) and iterates them in registration order inside `Categories:Categorize`. The current flow collects categories from each categorizer, sets `itemButton.ItemCategories`, returns the first match, and falls back to `CategoryStore:GetUnassigned()` when no matches exist. Categorizers live under `Categorizers/` and are loaded in TOC order (`Categorizers/new.lua`, `Categorizers/EquipmentSet.lua`, `Categorizers/custom.lua`, `Categorizers/query.lua`, `Categorizers/showAlways.lua`). Unassigned is not a registered categorizer today; it only appears via the fallback.
 
Layout and UI rely on the categories produced by `Categories:Categorize`. `main.lua` collects categories into `arrangedItems`, and `categoriesColumnAssignment.lua` places them into columns (creating column entries for unmatched categories). GUI labels fall back to "Unassigned" when the category name is nil (`gui.lua` and `categoriesGUI.lua`). Tests exist for the categorizer pipeline (`tests/categories_test.lua`) and query logic (`tests/Categorizers/query_test.lua`); integration tests cover persistence (`tests/integration/persistence/savedvariable_test.lua`).
 
Terminology: a "categorizer" is a module exposing `Categorize(itemID, itemButton, matches?)` that returns a category (string ID or category object) or a list thereof. "Unassigned categorizer" refers to the new module that emits the `sys:unassigned` category when nothing else matched.
 
## Plan of Work
 
Milestone 1 — make the categorizer pipeline aware of earlier matches and safe for a final categorizer. Update `categories.lua` so `Categories:Categorize` passes the mutable `matches` table to every categorizer call, continues to deduplicate via `resolveCategory`, and keeps the fallback to `CategoryStore:GetUnassigned()` only as a last-resort guard. Confirm all existing categorizers tolerate the extra argument and that unit tests still reflect the iteration order.
 
Milestone 2 — introduce the Unassigned categorizer as a first-class module loaded last. Add `Categorizers/unassigned.lua` (or equivalent) that registers with `AddonNS.Categories:RegisterCategorizer` and in `Categorize` returns `nil` when `#matches > 0` and `AddonNS.CategoryStore:GetUnassigned()` otherwise. Ensure the TOC lists this file after all other categorizer files so it is initialized last. Avoid persistence changes; rely on `CategoryStore:GetUnassigned()` for the category instance.
 
Milestone 3 — align tests and validation. Extend `tests/categories_test.lua` (or a new `tests/Categorizers/unassigned_test.lua`) to assert that the Unassigned categorizer runs after earlier categorizers, only tags unmatched items, and still yields the first matched category for items with assignments or query matches. Add a regression check that `itemButton.ItemCategories` remains ordered (first real match first, Unassigned absent when not needed). Keep integration tests green to confirm SavedVariables are unaffected.
 
Milestone 4 — manual verification and clean-up. Validate in-game that items already assigned to custom categories stay out of Unassigned, while unassigned items still render under the Unassigned header. Confirm collapsing and column movement still work with the new categorizer present. Document any surprises in this plan and update `Concrete Steps` and `Validation and Acceptance` as execution proceeds.
 
## Concrete Steps
 
Run all commands from the addon root `Interface/AddOns/!dev_MyBags`.
 
    lua tests/categories_test.lua
    lua tests/Categorizers/query_test.lua
    lua tests/integration/persistence/savedvariable_test.lua
 
After adding Unassigned tests, include their invocation here (for example, `lua tests/Categorizers/unassigned_test.lua`). Rerun the suite after each milestone to capture regressions quickly.
 
## Validation and Acceptance
 
Automated acceptance: all Lua tests above (plus the new Unassigned-focused test) must pass. A targeted unit test should fail before the Unassigned categorizer exists and pass after the new module runs last and only for unmatched items. Manual acceptance: load the addon, create a custom category, drag an item into it, and verify that item no longer appears under Unassigned while an unassigned item still does. Collapse Unassigned and move it between columns to confirm layout code treats it like other categories.
 
## Idempotence and Recovery
 
Registration should be idempotent: reloading the UI should not register the Unassigned categorizer twice, and the fallback to `CategoryStore:GetUnassigned()` ensures items never end up without a category even if the module fails. Changes are additive and confined to categorizers and TOC ordering, so reverting to prior behaviour only requires removing the new module and optional arguments while keeping SavedVariables intact.
 
## Artifacts and Notes
 
Expected categorization outcome after the change:
 
    Categorize(item matched by custom) => ItemCategories {customCat, ...}; return customCat
    Categorize(item with no matches)  => ItemCategories {sys:unassigned}; return sys:unassigned
 
Keep this section updated with short transcripts (e.g., unit test outputs) during implementation.
 
## Interfaces and Dependencies
 
`categories.lua`:
 
    function AddonNS.Categories:Categorize(itemID, itemButton)
        -- should call categorizer:Categorize(itemID, itemButton, matches)
        -- maintain resolveCategory deduplication and final fallback to CategoryStore:GetUnassigned()
    end
 
`Categorizers/unassigned.lua`:
 
    local UnassignedCategorizer = {}
    function UnassignedCategorizer:Categorize(itemID, itemButton, matches)
        if matches and #matches > 0 then return nil end
        return AddonNS.CategoryStore:GetUnassigned()
    end
    AddonNS.Categories:RegisterCategorizer("Unassigned", UnassignedCategorizer)
 
TOC ordering: ensure `Categorizers/unassigned.lua` is listed after all other `Categorizers/*.lua` entries so `OrderedMap:iterate()` visits it last.
 
---
Initial version drafted on 2025-12-10 by Codex to plan the Unassigned categorizer sequencing change.
