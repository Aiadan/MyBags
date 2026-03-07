# Repository Agent Guide

This guide is for AI agents (e.g., Codex CLI) contributing to MyBags. It consolidates policies, coding standards, and test commands so changes are safe, minimal, and consistent.

## Project overview

MyBags is a World of Warcraft bag addon focused on manual organisation. It extends Blizzard's combined bags rather than replacing them, letting players create bespoke categories while keeping default behaviours. Bank and reagent bags remain out of scope currently.

- Manual grouping: users drag items or categories to reorganise quickly; flows such as vendor purchases or bank transfers respect assignments.
- Built-in categorizers: always-present Equipment Set (with icons) and New Items (right-click to clear). Everything else starts in the Unassigned bucket until placed.
- Design philosophy: simplicity over configuration; minimal persistence; compatibility with default bag features and helpers like BlizzMove.
- Dependency ownership: `MyLibrary_GUI` and `MyLibrary_Common` are under our control. If a bug originates there, fix it in those libraries directly rather than adding addon-local workarounds.

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

## Fallbacks

Avoid implementing fallback logic. Always assume the code operates as intended. Including fallback mechanisms can mask underlying issues, making future debugging more difficult. Do not add defensive code paths for missing registrations or unset globals—treat absence of expected setup as a bug to surface, not something to paper over.

## Code style guidelines

- Pure Lua; stick to ASCII unless a file already uses special glyphs (e.g., colour codes).
- Naming:
  - standalone/local functions must use lower camel case (example: `doSomething`).
  - functions defined on tables via `:` must use UpperCamelCase method names (example: `SomeTable:DoSomething()`).
  - objects/tables are UpperCamelCase; constant values are UPPER_SNAKE_CASE.
- Prefer simple, explicit helpers; do not wrap primitives like `foo = foo or default` unless it clearly improves clarity.
- Guard new data structures against nil; lazily initialize tables.
- Use the `AddonNS` namespace consistently; expose functionality via `AddonNS` tables.
- Favour descriptive local function names; keep closures near their use.
- Call `AddonNS.QueueContainerUpdateItemLayout()` sparingly and only when state changes.
- When a concept is modeled as an object (e.g., categories), pass and store that object consistently rather than accepting mixed types such as ids-or-objects. Avoid helper patterns like `resolveXIdentifier` that take multiple shapes; enforce a single shape at boundaries and coerce inputs before they reach shared modules.
- Avoid defensive early-return guards that silently swallow invalid state (for example `if not x then return end` in internal domain paths). This is a known anti-pattern because it hides real bugs and makes behavior non-deterministic at scale.
- Prefer fail-fast behavior in internal code paths (clear errors or strict precondition handling) so invalid state is surfaced during development/testing instead of being masked.
- For internal boolean parameters, do not coerce values (for example `flag == true`) and do not add defensive type-check gates; pass and store booleans directly, and treat non-boolean inputs as upstream bugs to fix at the call site.

## Internal contracts (strict)

- Wrapper/domain interfaces are mandatory contracts. If a wrapper exposes a method (for example category click hooks), internal callers must call it directly and must not guard with `if obj and obj.Method then ...`.
- Optional behavior must be implemented via no-op methods at construction/wrapping time, not by adding call-site guards.
- Defensive checks are allowed only at external boundaries (Blizzard API payloads, SavedVariables input, user-entered text). Internal module-to-module/event-to-handler paths must be strict and fail-fast.
- Do not add silent fallback paths in internal flows. Invalid internal state should be surfaced immediately (error or strict precondition), not swallowed.
- When introducing or changing an internal interface contract, add/update tests that validate the contract directly (for example: wrapper forwards method and call path works without guards).

### Internal contract review checklist

- No `if x and x.Method then` patterns for internal wrapper/domain calls.
- No silent `if not x then return end` guards in internal domain flow unless this is an explicit external-boundary sanitization point.
- Interface changes include test updates that verify strict contract behavior.

## AI Agent Code Organization Policy

All AI agents must follow the Separation of Concerns principle. Each file, module, or agent must focus on a single, well-defined responsibility. Helper functions that directly support that responsibility are permitted within the same scope. Shared or unrelated logic must be implemented in separate modules and imported where needed. Agents must not duplicate or embed logic outside their defined concern but should rely on clear interfaces or service modules that expose necessary functionality.

This policy also applies to generic or reusable components such as utility functions, data maps, or classes that could serve multiple agents or modules. Such tools must be implemented in dedicated files and imported where needed, ensuring that shared logic exists only once and can be maintained or extended independently.

## Testing instructions

- Location: place automated tests under `tests/`, mirroring the source tree (e.g., `Categorizers/custom/query.lua` → `tests/Categorizers/query_test.lua`).
- Quality: avoid tests that only verify a method was called; prefer behaviour and state assertions.
- Scope: include unit tests for categorizer/query logic and integration tests for SavedVariables lifecycle. Update integration when persistence paths change.
- Run: execute the full suite before shipping substantial changes.
- Test removal policy: never remove test cases unless the underlying logic they cover is removed. Document any removals or substantial test changes with rationale in .agent/TESTS_REMOVED.md (or in execplan if that workflow is used).

## SavedVariables and storage

- Storage lifecycle in this addon:
  - SavedVariables are loaded/bootstraped during `OnDbLoaded` (see `init.lua`).
  - Persisted writes are committed by WoW at logout (`PLAYER_LOGOUT`).
  - Prefer hydrating runtime structures from DB on load and serializing them back to DB on logout rather than repeatedly reading persisted shapes during runtime.
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

- Store plans/decisions you create under `.agent/` as Markdown files.
- `TODOs.md` is a concise backlog, not a changelog.
- Update `TODOs.md` only when:
  - the work completes or materially changes an existing tracked item;
  - the work is a user-visible or backlog-worthy improvement;
  - the work is a substantial maintenance/refactor effort worth tracking; or
  - the user explicitly asks to track it there.
- Do not add `TODOs.md` entries for small technical fixes, narrow refactors, tests-only changes, naming cleanups, or implementation details unless they resolve an existing tracked item.
- Keep `TODOs.md` entries brief and outcome-focused. Describe what changed for the project, not how the code was written.
- `Done` entries in `TODOs.md` must include the completion date in `YYYY-MM-DD` format.
- For iterative work on the same feature/thread, keep one consolidated `TODOs.md` item instead of appending near-duplicate follow-ups.
- Put technical/implementation details in ExecPlans, tests, commits, code comments, or other appropriate documentation, not in `TODOs.md`.
- Modify `README.md` only when explicitly asked, or when resolving a `TODOs.md` item that requires it.
- `README.md` is user-facing documentation. Keep language user-oriented and avoid internal implementation details there.
- If a task introduces a user-facing feature, update `README.md` with a short description of that feature.
- Do not update `README.md` for minor internal behavior tweaks/refactors that do not materially change user-visible functionality.
- Put technical/implementation details (for example defaults, storage shapes, tie-break rules) in `README_DEVELOPMENT.md` instead of `README.md`.

## Repository rules

- Keep changes minimal and focused. Do not fix unrelated issues.
- Simplicity is king: prefer the smallest working change over architectural expansion.
- Avoid introducing new state/metadata/abstractions unless the existing shape cannot support the requirement.
- Default to surgical diffs: touch as few files/lines as possible and preserve existing flow/structure.
- If a simpler implementation exists with identical behavior, choose the simpler one.
- Debugging/change strategy: start at lifecycle entry points and state boundaries before adding internal lock/state machinery.
  - Example: for bank first-open filter/scale issues, prefer adjusting `BankFrame_Open` open sequence first (for example open unfiltered, then restore search) rather than introducing extra search-lock fields in `bankView.lua`.
  - Rationale: entry-point fixes are easier to reason about, more reversible, and less likely to break unrelated behavior (column count, resize handle visibility, anchor updates).

## ExecPlans

When writing complex features or significant refactors, use an ExecPlan (as described in .agent/PLANS.md) from design to implementation.

You must not read any files from .agent/archive/ directory.
