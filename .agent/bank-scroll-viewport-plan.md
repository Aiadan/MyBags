# Bank Scroll Viewport Plan (Implemented)

## Goal
Add bank-frame vertical scrolling for MyBags-rendered categories/items with clipped overflow, mouse-wheel support, and a darker visible scroll region.

## Decisions
- Use Blizzard native `MinimalScrollFrameTemplate` (no ScrollBox refactor).
- Render MyBags bank headers and item buttons inside a scroll child frame.
- Preserve scroll offset across all refresh triggers and clamp only when content shrinks.
- Forward mouse wheel from interactive children (item buttons and category headers) to the bank scroll frame.
- Keep existing drag/drop/category interaction paths unchanged.

## Implemented Touchpoints
- `bankView.lua`
  - Added scroll state (`scrollOffset`) and viewport constants.
  - Added scroll area creation (`ensureScrollArea`) with dark backdrop and native minimal scrollbar.
  - Added scroll metrics update (`updateScrollMetrics`) with offset clamping.
  - Reparented positioned item buttons and header rendering under the scroll content frame.
  - Added mouse-wheel forwarding on category headers and item buttons.
  - Added cleanup for hidden/invalid/empty refresh states to avoid stale visible bank content.
- `TODOs.md`
  - Added a completed item documenting bank vertical scrolling.

## Verification
- Ran unit tests:
  - `lua tests/categories_test.lua`
  - `lua tests/Categorizers/query_test.lua`
- Ran integration tests:
  - `lua tests/integration/persistence/savedvariable_test.lua`
