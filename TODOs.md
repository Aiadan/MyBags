# TODOs

This file is the live backlog for MyBags. Keep it concise and outcome-focused.

## Planned

### Improtant
- Sometimes the scale / frame position still does not work as expected. Maybe we could hook to it and if we noticed pos has changed, regardless of the locks, just fix it/readjust it before it is even visible to the user.
- 🐞 There is some kind of tainting during bank usage. It is quite hard to grasp it currently. I have marked the places which cause it with "--TODO: BANK_TAINT"

### Normal
- Add toy category. Maybe C_ToyBox.IsToyUsable(itemID) ?
- Observation: dragging an item from vendor, inventory, or another container shows category highlight even when background drop does not actually assign the item; the highlight/assignment expectation should match the real behavior.
- Observation: changing tabs between bank and warband bank while search is active freezes resize behavior.
- Observation: dragging an item from bags to bank into a different category first changes the bag category, and only the next drag moves it to the bank; this should happen in one action.
- Expectation: creating a new category should place it in the last column consistently across bags, bank, and warband bank.
- 🛠️ Observation: query help window triggers and UI logic are still mixed into `categoriesGUI.lua` and should be moved to a dedicated file.
- 🛠️ Observation: internal silent-guard patterns still exist and should be replaced with fail-fast preconditions where contracts are strict.
- 🛠️ Observation: some flows rely on direct cross-module reactions where clearer event-driven boundaries would better separate responsibilities.
- 🛠️ Expectation: naming conventions across the codebase should be normalized to match repository rules.
- 🛠️ Observation: bag-search anchor-lock behavior is still spread across existing files and should live behind a dedicated module interface.
- 🛠️ Observation: `CustomCategorizer:Categorize` still looks like the next profiling/performance hotspot.
- 🛠️ Observation: internal runtime still has places where category ids/names are used instead of passing category objects directly.

### Low priority

- 🛠️ Expectation: collapsed-state and column-assignment persistence should be stored per container scope instead of sharing one bag-oriented shape.
- 🛠️ Observation: drag/drop cursor checks still rely on `pickedItemButton`; `C_Cursor.GetCursorItem()` may be the cleaner source if behavior matches.
- 🛠️ Observation: the release workflow still publishes more than the addon zip; this should be reduced only if it does not break downstream consumers such as WoWUpHub.
- 🛠️ Observation: leftover logs, debug helpers, profiling hooks, and temporary triggers should be removed before release.

### Doubtful

- 🛠️ Observation: some state-change flows may be better expressed as container/layout events instead of direct state mutations, but this needs validation before turning into implementation work.

## In Progress

- Simplify TODO tracking: keep this file as a curated backlog, archive the historical diary, and require dated concise entries for tracked completions.
- 🛠️ Add a curated user-facing changelog workflow with one `RELEASE_NOTES.md` draft per stable cycle and `CHANGELOG.md` as the stable archive.

## Done

- 2026-03-07 - Re-scoped `TODOs.md` to a concise live backlog and moved the historical log to `.agent/todo-history.md`.

## Rejected

- Hide categories and their items entirely.
- Add an authenticator button to the custom bag layout.
- Disable categories in a way that removes them from matching while keeping their prior assignments as a separate feature.
