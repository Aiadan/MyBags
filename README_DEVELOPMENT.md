# Development Guide

This addon ships a lightweight Lua test suite that exercises both unit-level categorizer logic and SavedVariable persistence across simulated sessions. The tests run with the system `lua` interpreter; no additional dependencies are required.

## Test Commands

Run the commands from the addon's root directory (`Interface/AddOns/!dev_MyBags`).

- Categorizer query evaluation: `lua tests/Categorizers/query_test.lua`
- Base category registration helpers: `lua tests/categories_test.lua`
- SavedVariable integration scenarios (boot/load/logout flows): `lua tests/integration/persistence/savedvariable_test.lua`

The integration harness deliberately stubs UI libraries (`MyLibrary_GUI`, `WowList-1.5`) and `C_Container` calls so the tests focus on data persistence without loading Blizzard frames. If you add new persistence paths, extend `tests/integration/persistence/savedvariable_test.lua` and update the harness when additional APIs need stubbing.
