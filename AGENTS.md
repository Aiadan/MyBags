# Repository Agent Guide

This guide is for AI agents (e.g., Codex CLI) contributing to MyBags. It consolidates policies, coding standards, and test commands so changes are safe, minimal, and consistent.

## Project overview

MyBags is a World of Warcraft bag addon focused on manual organisation. It extends Blizzard's combined bags rather than replacing them, letting players create bespoke categories while keeping default behaviours. Bank and reagent bags remain out of scope currently.

- Manual grouping: users drag items or categories to reorganise quickly; flows such as vendor purchases or bank transfers respect assignments.
- Built-in categorizers: always-present Equipment Set (with icons) and New Items (right-click to clear). Everything else starts in the Unassigned bucket until placed.
- Design philosophy: simplicity over configuration; minimal persistence; compatibility with default bag features and helpers like BlizzMove.

Runtime interaction:

- Drag-and-drop emits events like `ITEM_MOVED`; dragging onto custom categories reassigns items unless the destination is protected.
- Protected categories remain read-only for user moves.
- Collapsing categories works for all categories, including the Unassigned category.

Categories comprise:

- Dynamic categorizers (e.g., Equipment Set, New)
- Custom categorizers (user-managed) with per-item assignments and optional query-based logic.
- “Unassigned” sentinel tracked via `UNASSIGNED_CATEGORY_DB_STORAGE_NAME`.

## Build and test commands

MyBags is pure Lua and requires no build step. Run tests with the system `lua` interpreter from the addon's root (`Interface/AddOns/!dev_MyBags`).

- Unit: `lua tests/categories_test.lua`
- Unit: `lua tests/Categorizers/query_test.lua`
- Integration (persistence: migration, layout, assignment, sentinel): `lua tests/integration/persistence/savedvariable_test.lua`

 

## Code style guidelines

- Pure Lua; stick to ASCII unless a file already uses special glyphs (e.g., colour codes).
- Prefer simple, explicit helpers; do not wrap primitives like `foo = foo or default` unless it clearly improves clarity.
- Guard new data structures against nil; lazily initialize tables.
- Use the `AddonNS` namespace consistently; expose functionality via `AddonNS` tables.
- Favour descriptive local function names; keep closures near their use.
- Call `AddonNS.QueueContainerUpdateItemLayout()` sparingly and only when state changes.

## Testing instructions

- Location: place automated tests under `tests/`, mirroring the source tree (e.g., `Categorizers/query.lua` → `tests/Categorizers/query_test.lua`).
- Quality: avoid tests that only verify a method was called; prefer behaviour and state assertions.
- Scope: include unit tests for categorizer/query logic and integration tests for SavedVariables lifecycle. Update integration when persistence paths change.
- Run: execute the full suite before shipping substantial changes.

## SavedVariables and storage

- Store only what is necessary. Avoid persisting empty values/strings/tables to reduce load time and memory overhead.
- Sanitize all input read from SavedVariables; strip empty tables/strings and normalise shapes.
- Prohibit duplication. Examples of what NOT to do:
  - Do not persist an ID mapped to a value that redundantly maps back to the same ID (derive dynamically on load if needed):

    ```lua
    ["items"] = {
      [191229] = { ["itemid"] = 191229 },
    }
    ```

  - Do not store the same information under multiple entities (e.g., storing per-category column and separately listing categories per column is prohibited):

    ```lua
    ["categoryState"] = { ["equipment-set:5"] = { ["column"] = 1 } },
    ["categoryLayout"] = { ["columns"] = { {"equipment-set:5"} } }
    ```

## Backward compatibility

- When changing storage formats, ensure users do not lose setup. Provide a reader/migration that translates old formats to new.
- Simple additive extensions typically do not require backward-compat shims.
- For major storage changes, consider using a new SavedVariables variable to allow safe rollback until stable. Plan a later cleanup to remove deprecated variables. On load, try the new SavedVariable. If missing, fall back to the old one. On logout, always save in the new format to complete migration.

## Planning and documentation

- Store plans/decisions you create under `.agents/` as Markdown files.
- Modify `TODOs.md` only when resolving an existing item; prefix completed items with a checkmark icon as appropriate.
- Modify `README.md` only when explicitly asked, or when resolving a `TODOs.md` item that requires it.

## Repository rules

- Keep changes minimal and focused. Do not fix unrelated issues.

## ExecPlans

When writing complex features or significant refactors, use an ExecPlan (as described in .agent/PLANS.md) from design to implementation.