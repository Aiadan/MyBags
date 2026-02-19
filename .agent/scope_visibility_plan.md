# Scope Visibility Implementation Plan (Completed)

## Goal
Add per-custom-category visibility across `bag`, `bank-character`, and `bank-account` scopes, with UI controls in category config and edit-mode header toggles.

## Decisions
- Disabled scope excludes category from categorization and render in that scope.
- Shift tooltip diagnostics still include scope-disabled matches.
- Current-scope tooltip line marks disabled entries with `(disabled in this scope)`.
- Persist only false overrides in `userCategories.categories[rawId].scopes`.
- Keep defaults enabled when `scopes` is absent.

## Implemented Areas
- Wrapper contract extension for `IsVisibleInScope(scope)`.
- Scope-aware filtering in `Categorize`, `GetMatches`, and constant-category retrieval.
- Custom category scope visibility APIs and persistence normalization.
- Category config panel checkboxes: Bags / Bank / Warbank.
- Bag and bank edit-mode current-scope visibility icon toggle.
- Shift tooltip diagnostics include disabled categories with scope-disabled marker.
- Unit + integration tests for scope visibility behavior/persistence.

## Validation
- `lua tests/categories_test.lua`
- `lua tests/Categorizers/query_test.lua`
- `lua tests/integration/persistence/savedvariable_test.lua`
- `lua tests/bank_view_all_tabs_test.lua`
