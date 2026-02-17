# Add MyBags Categories To Bank Views (Character Bank First, Account Bank Kept Separate)

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This plan must be maintained in accordance with `.agent/PLANS.md`.

## Purpose / Big Picture

After this change, MyBags category rendering and manual assignment behavior will work in bank item views, not only in combined bags. The player will be able to open the bank and see item buttons arranged into MyBags categories, with category headers and drag/drop assignment behavior matching bag behavior where appropriate.

User-visible target behavior is intentionally scoped:

- Character bank tabs gain MyBags categorization support.
- Account bank (the warband/account bank panel) remains a separate top-level bank tab and is not merged into character-bank content.
- Bag-only affordances that are not needed for bank (for example the bags edit-mode cog/button behavior) remain bag-only unless a bank-specific equivalent is explicitly required.

If a merged character-bank view (multiple bank tabs shown as one categorized panel) is low-risk, implement it. If not low-risk, ship per-selected-tab categorization first and keep the merge attempt out of the critical path.

## Progress

- [x] (2026-02-17 00:30Z) Researched current MyBags bag-only architecture and Blizzard bank/container implementations; drafted this ExecPlan with file-level implementation steps.
- [x] (2026-02-17 01:35Z) Implemented scoped layout/collapsed storage (`bag`, `bank-character`, `bank-account`) with migration from legacy root layout fields and bag-root compatibility mirroring.
- [x] (2026-02-17 01:35Z) Implemented bank category rendering and item placement for active bank tab via new `bankView.lua`, with character/account bank scope separation and no bag edit-mode controls in bank.
- [x] (2026-02-17 01:35Z) Threaded layout scope through category movement/collapse flows so drag/drop + collapsed state updates apply to the active bag/bank scope.
- [x] (2026-02-17 01:36Z) Validation complete: `lua tests/categories_test.lua`, `lua tests/Categorizers/query_test.lua`, and `lua tests/integration/persistence/savedvariable_test.lua` all pass.
- [x] (2026-02-17 01:36Z) Updated `TODOs.md` to mark bank support as completed.
- [ ] Manual in-game verification pending (bank NPC interaction flows and visual polish).

## Surprises & Discoveries

- Observation: Retail bank UI is not backed by `ContainerFrameCombinedBagsMixin`; it uses `BankPanelMixin` with its own item-button pool and a selected bank tab model.
  Evidence: `/root/BlizzardInterfaceCode/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/BankFrame.lua` (`BankPanelMixin:GenerateItemSlotsForSelectedTab`, `BankPanelMixin:EnumerateValidItems`, `BankPanelMixin:OnEvent`).

- Observation: Combined bags and bank are separate interaction systems; combined bags support `EnumerateValidItems`, `UpdateItemLayout`, and `OnTokenWatchChanged`, while bank refreshes via `MarkDirty/Clean` and bank events.
  Evidence: `/root/BlizzardInterfaceCode/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua` and `/root/BlizzardInterfaceCode/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/BankFrame.lua`.

- Observation: MyBags currently hard-binds core flow to `ContainerFrameCombinedBags` (`main.lua` sets `AddonNS.container = ContainerFrameCombinedBags`), so bank support requires a surface split, not a small one-line hook.
  Evidence: `main.lua` and `categoriesGUI.lua` references to `AddonNS.container` and bag-only controls.

## Decision Log

- Decision: Deliver bank support in two layers: required layer (character-bank selected-tab categorization) and optional layer (merged character-bank tab view).
  Rationale: This satisfies the request to support bank now while keeping merged-tab complexity optional and non-blocking.
  Date/Author: 2026-02-17 / Codex.

- Decision: Keep account/warband bank separate from character bank in UI behavior and persistence scope.
  Rationale: User explicitly prefers vault bank as separate tab; Blizzard bank already separates bank types at `BankFrame` tab level.
  Date/Author: 2026-02-17 / Codex.

- Decision: Do not port bag edit-mode button/cog UI into bank unless a specific bank workflow requires it.
  Rationale: User requested simplification; current bag edit controls are tightly tied to `BagItemAutoSortButton` and combined-bag framing.
  Date/Author: 2026-02-17 / Codex.

## Outcomes & Retrospective

Implemented outcome:

- Bank tabs now get MyBags category grouping/rendering and item placement in active tab view.
- Account/warband bank remains separate from character bank through explicit scope separation.
- Bag and bank now persist layout/collapsed independently while preserving backward compatibility for existing bag data.
- Bag edit-mode controls remain bag-only.

Gap remaining:

- Optional merged character-bank tab view was intentionally not implemented in this pass.
- In-game manual verification is still required to confirm final UX and taint behavior under real bank interactions.

## Context and Orientation

This repository currently implements categorization against a single global container reference:

- `main.lua`: assigns `AddonNS.container = ContainerFrameCombinedBags` and wires event-driven layout refresh around that object.
- `ContainerFrameMyBagsMixin.lua`: mixes MyBags behavior directly into `ContainerFrameCombinedBags`.
- `gui.lua` and `categoriesGUI.lua`: render category overlays and config controls anchored to `AddonNS.container` and bag-only UI anchors.
- `categoriesColumnAssignment.lua` and `categoryStore.lua`: maintain layout/column/collapsed persistence in one shared bag-oriented shape (`db.layout`).

Blizzard bank architecture (Retail source) is different:

- `BankFrame.lua` defines `BankFrameMixin` with top-level bank-type tabs (`Character` and `Account`).
- Bank items are rendered by `BankPanelMixin` per selected bank tab (`selectedTabID`) using `GenerateItemSlotsForSelectedTab` and `itemButtonPool`.
- Bank refresh path is `MarkDirty`/`Clean` on `BAG_UPDATE` for the selected tab and `INVENTORY_SEARCH_UPDATE` for search overlay updates.

Relevant Blizzard source evidence:

- `/root/BlizzardInterfaceCode/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/BankFrame.lua`
- `/root/BlizzardInterfaceCode/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua`

Important inferred constraint for implementation in this repo: logic currently assuming `ContainerFrameCombinedBagsMixin` methods (`UpdateItemLayout`, `OnTokenWatchChanged`, `GetColumns`, `GetInitialItemAnchor`) must be abstracted before bank support can be added cleanly.

## Plan of Work

### Milestone 1: Introduce a container surface abstraction (bags + bank) (Partially Replaced)

Create a narrow runtime interface (a “surface”) representing a render target for categorization. This avoids spreading `if bag then ... else bank ...` checks everywhere.

Add a new module (for example `containerSurface.lua`) that defines surface contracts in plain Lua tables for:

- Enumerating visible item buttons.
- Reading item-button identity (`bagID`, `slotID`, item ID).
- Applying post-categorization item placement updates.
- Category-header rendering anchors and geometry.
- Triggering refresh for that surface.

Then:

- Update `main.lua` to keep bag behavior via a bag surface implementation rather than direct global `AddonNS.container` assumptions.
- Preserve existing bag behavior exactly (no functional changes in this milestone).

Acceptance for milestone 1: bag functionality remains unchanged and all tests continue to pass.

### Milestone 2: Add bank surface (character bank selected tab)

Implement a bank surface backed by `BankPanel` active item buttons:

- Enumerate from `BankPanel:EnumerateValidItems()`.
- Use each bank button’s container identity from `GetBankTabID()` and `GetContainerSlotID()` (or equivalent existing accessors on bank buttons).
- Plug this surface into shared categorization assignment flow used by bags.

Integrate with bank events by hooking `BankPanelMixin`/`BankFrame` lifecycle points used by Blizzard for refresh:

- On selected bank tab changes, re-run categorization placement for current bank surface.
- On `BAG_UPDATE` for selected bank tab and `INVENTORY_SEARCH_UPDATE`, re-run the bank surface layout update path.

Do not introduce bag-only config UI in bank.

Acceptance for milestone 2: opening bank character tab and switching between purchased bank tabs always shows MyBags categories for visible bank tab items.

### Milestone 3: Split persistence scope (bag vs bank)

Current persistence (`db.layout`) is shared and bag-centric. Add separate layout/collapsed scopes to avoid cross-contamination between bag and bank display states.

Target shape example (exact field names may vary, keep minimal):

    db.layout = {
      bag = { columnCount = ..., columns = ..., collapsed = ... },
      bank = {
        character = { columnCount = ..., columns = ..., collapsed = ... },
        account = { columnCount = ..., columns = ..., collapsed = ... },
      },
    }

Implementation notes:

- Provide migration from existing single `db.layout` to `db.layout.bag` on load.
- Initialize bank scopes lazily when first needed.
- Keep backward compatibility: no user data loss from existing bag setup.

Acceptance for milestone 3: bag layout/collapse data remains intact after migration; bank has isolated layout/collapse persistence.

### Milestone 4: Optional merged character-bank view spike (Deferred)

Run a bounded feasibility spike for merged character-bank tabs into one categorized panel:

- Build a temporary code path that iterates all eligible character-bank tab IDs and simulates a merged item list for category layout.
- Verify drag/drop reassignment remains deterministic and does not break Blizzard banking interactions.
- Verify no taint-sensitive regressions during open/close and item movement.

Decision gate:

- If complexity or regression/taint risk is non-trivial, do not ship merged mode in this cycle.
- If low-risk and behavior is stable, ship merged mode behind a clear internal flag defaulting to enabled only when validated.

Account/warband bank remains separate regardless.

### Milestone 5: Bank-specific UI composition and cleanup

Adjust `gui.lua` rendering so category headers/backgrounds can render on bank surface without assuming combined-bag money frame anchors.

- Keep bag edit-mode controls anchored only to bag surface.
- For bank, render only required category headers/hints and item arrangement visuals.
- Ensure search-related flows do not rely exclusively on `BagItemSearchBox` lock behavior.

Acceptance for milestone 5: bank category overlays render correctly in both character/account bank tabs, with account kept separate and no unnecessary bag edit controls.

### Milestone 6: Tests and hardening

Add/extend tests with behavior assertions (not only call assertions):

- Unit tests for new surface abstraction behavior where possible.
- Persistence integration tests for new `db.layout` migration and separate bank scopes in `tests/integration/persistence/savedvariable_test.lua`.
- Add deterministic tests for layout scope selection between bag and bank.

## Concrete Steps

All commands from repo root:

    cd "/mnt/c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/!dev_MyBags"

Baseline tests before edits:

    lua tests/categories_test.lua
    lua tests/Categorizers/query_test.lua
    lua tests/integration/persistence/savedvariable_test.lua

Implementation order:

1. Add surface abstraction module and wire bag surface to it.
2. Add bank surface and bank lifecycle hooks.
3. Add persistence split + migration.
4. Add optional merged character-bank spike and gate decision.
5. Finalize bank UI rendering and remove bag-only leakage.
6. Add/adjust tests.
7. Update `TODOs.md` with completed item.

Post-change verification:

    lua tests/categories_test.lua
    lua tests/Categorizers/query_test.lua
    lua tests/integration/persistence/savedvariable_test.lua

Manual in-game verification script:

1. Open bags: verify existing behavior unchanged.
2. Open bank character tab: verify categories render and item assignment drag/drop works.
3. Switch character bank tabs: verify consistent recategorization and layout persistence.
4. Switch to account bank tab: verify separate category state and no unintended merge with character bank.
5. Confirm bag edit-mode controls still exist only in bags.

## Validation and Acceptance

The change is accepted when all below are true:

- Automated tests pass with no regressions.
- Bag behavior remains unchanged for category rendering, drag/drop, and search integration.
- Character bank shows MyBags categories and supports assignment behavior equivalent to bag flow where meaningful.
- Account/warband bank remains separate (not merged into character-bank categorized content).
- No bag-only control leakage into bank UI (for example no forced reuse of bag edit cog).
- Persistence migration keeps prior bag layout/collapsed data and stores bank state separately.

## Idempotence and Recovery

Idempotence:

- Migration must be one-way but repeat-safe: if `db.layout.bag` already exists, migration should not duplicate/mutate layout repeatedly.
- Bank layout scopes should be lazily initialized with deterministic defaults.

Recovery:

- If migration logic is incorrect, restore from pre-change SavedVariables backup and rerun with fixed migration.
- During development, keep migration small and testable; avoid destructive rewrites of unrelated DB keys.

## Artifacts and Notes

Observed Blizzard source anchors used for this plan:

- `/root/BlizzardInterfaceCode/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua`:
  - `ContainerFrameCombinedBagsMixin` behavior and bag-specific combined container flow.
- `/root/BlizzardInterfaceCode/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/BankFrame.lua`:
  - `BankFrameMixin` bank-type tabs.
  - `BankPanelMixin:GenerateItemSlotsForSelectedTab` and `BankPanelMixin:EnumerateValidItems` item model.

Current addon hotspots that must be abstracted/split:

- `main.lua` (`AddonNS.container` direct binding to `ContainerFrameCombinedBags`).
- `ContainerFrameMyBagsMixin.lua` (combined-bag mixin assumptions).
- `gui.lua` / `categoriesGUI.lua` (bag-frame anchors and bag-only controls).
- `categoryStore.lua` + `categoriesColumnAssignment.lua` (single shared layout scope).

## Interfaces and Dependencies

Required internal interfaces after implementation:

- A surface provider module exposing stable functions for both bag and bank surfaces, including:
  - `GetSurfaceId()` (example values: `bag`, `bank-character`, `bank-account`).
  - `EnumerateValidItems()`.
  - `QueueLayoutRefresh()`.
  - `ApplyCategorizedLayout(assignments)`.
  - `GetLayoutScopeKey()` for persistence routing.

- Category/layout APIs updated to accept a layout scope key instead of relying on one implicit global layout.

Dependency constraints:

- Keep using in-repo `MyLibrary_GUI` / `MyLibrary_Common` patterns; do not add fallback guards for missing internal contracts.
- Preserve strict internal contracts (no new `if obj and obj.Method then` call-site patterns).

## Plan Revision Note

- 2026-02-17 / Codex: Initial plan created from current repo state plus Blizzard source review, to define an implementation path for bank categorization support with account-bank separation and optional merged-character-bank feasibility gate.
- 2026-02-17 / Codex: Updated after implementation. Delivered scoped layout/collapsed persistence plus active-tab bank categorization rendering (`bankView.lua`) and deferred optional merged-tab spike; recorded full test-pass evidence and remaining manual in-game verification task.
