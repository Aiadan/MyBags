# Query-Expanded Search Decision

Date: 2026-02-15

## Decision

- Hook search-text updates via `BagSearch_OnTextChanged` only.
- Build an ad-hoc query evaluator from current search text.
- Expand visible item set using union semantics:
  - `default Blizzard search match OR ad-hoc query match`.
- Ignore invalid ad-hoc query text silently.
- Force `itemButton:SetMatchesSearch(true)` for query-only matches so they are not dimmed.

## Implementation Notes

- Added `AddonNS.QueryCategories:CompileAdHoc(queryText)` for valid-or-nil ad-hoc compilation.
- Added `AddonNS.CustomCategories:GetItemQueryPayload(itemID, itemButton)` so search-query evaluation reuses the same item payload shape as custom query categories.
- Main iterator now evaluates query expansion only for items Blizzard filtered out.
