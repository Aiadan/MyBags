# Development Guide

This addon ships a lightweight Lua test suite that exercises both unit-level categorizer logic and SavedVariable persistence across simulated sessions. The tests run with the system `lua` interpreter; no additional dependencies are required.

## Test Commands

Run the commands from the addon's root directory (`Interface/AddOns/!dev_MyBags`).

- Categorizer query evaluation: `lua tests/Categorizers/query_test.lua`
- Base category registration helpers: `lua tests/categories_test.lua`
- SavedVariable integration scenarios (boot/load/logout flows): `lua tests/integration/persistence/savedvariable_test.lua`

The integration harness deliberately stubs UI libraries (`MyLibrary_GUI`, `WowList-1.5`) and `C_Container` calls so the tests focus on data persistence without loading Blizzard frames. If you add new persistence paths, extend `tests/integration/persistence/savedvariable_test.lua` and update the harness when additional APIs need stubbing.

## Runtime Profiling

The addon includes opt-in profiling for bag refresh hotspots:

- refresh total and phase split (`categorize`, `arrange`, `place`)
- custom categorizer timing (`info` and `query` parts)
- category arrangement timing split
- items-order sorting timing split (`rebuild`, `map`, `sort`, `comparator`, `append`, `uncounted`)

Enable profiling in-game:

- `/run GLOBAL_MyBagsEnableProfiling()`

Disable profiling in-game:

- `/run GLOBAL_MyBagsDisableProfiling()`

Use it only during diagnostics. Keep profiling disabled during normal play.

## Custom Query Priority Notes

- Query-based matching inside custom categories is ordered by explicit per-category priority (higher score first).
- If no explicit priority is stored for a custom category, runtime default priority is the numeric raw category id.
- Priority ties are resolved by alphabetical category name, then internal deterministic fallback.

## Import/Export Notes

- Import/export payloads are plain Lua table literals (no leading `return`).
- Import is create-only: each payload category creates a new custom category.
- Export includes rule + manual assignment data (`name`, `query`, `priority`, `alwaysVisible`, `items`).
- `externalId` matching was intentionally removed to avoid hidden duplicate-id/user-control pitfalls that could block imports.
- Layout data is intentionally excluded from import/export to keep the flow simple and avoid order/collapse mismatch pitfalls.

## Generated Query Help Docs

- Canonical source for query help content is `QUERY_ATTRIBUTES.md`.
- Runtime file consumed by UI is `generated/queryHelpDocs.lua`.
- Regenerate locally after query-doc changes: `lua tools/generate_query_help.lua`.
- Release workflow always regenerates and verifies this file is up to date before packaging.
