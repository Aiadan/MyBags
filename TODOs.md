# Things to consider to change

There is a number of things that I can consdier for implementation. Some are more impacting user, some are rather technical - hence the split.

Some of the things are marked with [!] indicating their cruciallity before exposing this addon to wider audience.

## User focused

### DONE

* ✅ click on an item in the bag requires you to drop it onto a different item in anothe rcategory. You cannot click another category which is miasligned with the ability to drag onto another category. Same when draggoning on the categories in edit mode.
* ✅ when too many items are to expand the height to far, the addon should try to automatically split given categories into separate columns.
* ✅ when dropping an item on bg [outside of category] it should it be assigned to latest category in the column.
* ✅ when buying from merchant you should be able to assign to a category automatically when dropping on an item
* ✅ when buying from merchant you should be able to drop an item onto a free space to buy the item as long as there is an itembutton available
* ✅ When moving items from vendor or bank by mouse consider allowing for direct association with a category. Currently only dropping on items would work, but in the case of bank this results in items switching places. The only way is to right click which is doable, but then association with category has to be done afterwards resulting in two clicks which would be good to avoid.
* ✅ when moving an item from bank you should be able to assing to a category
* ✅ make it possible to always display certain categories, even if it is empty currently. I mean "Junk" - I want to see it all the time for cleanup purposes.
* ✅ as we have to use placedholder anyway rewrite the Junk how it is handled, and just add a category with one placeholder item to the arrange list and remove all the other code as it is not needed lol.... :|
* ✅ using placeholder items which allowed for better categories placements from the begining
* ✅ initial categories assignment is done by alphabetic order. Useful when we will allow for import of custom categories or external categorizers
* ✅ the gear categorizer could add icon of the category at the begining? :)
* ✅ BAG_UPDATE is a bit broken - it was supposed not to refresh the view when items are removed, but fixing one bug caused it to no longer work this way in all cicrumstances. To verify what can we do about it, when actually this event is sent and what info we can get from it.
* ✅ create a categorizer that is based on a query language. Categorizer would create protected categories (is this actually needed?).
* ✅ the config should be stored in account wide config so maybe at some point we could introduce profiles.
* ✅blizzMove addon breakes it seems with this addon - to check whether it breaks only with this addon, or with it disabled as well as it currently does not work properly with other things like talents window so it might just be broken blizzmove.
  * ✅ the way I solved is that it now works with BlizzMove. However I noticed that by default this addon does not remember scaling of the bags, so I might need to implement such functionality in the end. I'd rather make a merge request, unfortunately the licensing is "all rights reseved" in blizz move addon.
* ✅ add option to mark category as always visible
* ✅ always-visible empty categories now render as header-only rows (full-width like collapsed headers) without placeholder-item stacking
* ✅ codified simplicity-first contribution rule in `AGENTS.md` (prefer surgical diffs, avoid unnecessary abstractions/state)
* [solved - by preventing Blizz UI changing the scale] consider adding option to manage scale (or at least remember between each open), placement of bag as well as prevent it from auto closing.
* ✅[changed - see sub point] reenable new categorizer to work properly with merchant. Maybe mark those items bought from merchant somehow?
  * ✅ renenble new categorizer and make it so that we will store new items and mark them so for a bit long. Right clicking on the title should remove items from new group.
* ✅ make categories foldable
* ✅ folded group when have too many items should not leak onto other columns. They are folded in the end.
* ✅ crafting an item, ie. hearty simple stew, when it wasnt in the equipment before wont show it in the bags, reopenning is required.
* ✅ could make search actually filter items (done with changing the bag size, but to be tested whether that is better / sufficient)
* ✅ when creating a category clicking Enter should create a category, not close the prompt. comment: that was harder than expected...
* ✅[!] make the window be smaller than restricted 75% of the original addon
  * now scale is being overwritten and automatically calculated always and can go below 0.75
* ✅[!] persist information that a given category is currently folded
  * I have resolved it in a way that I have moved it for now into a separate file. It should still be a part of the mixin.
* ✅[!!] the query doesnt work sometimes on bag open. This is because some data is not loaded at that moment in time. We have to find a workaround ie. use async function, though I'm not sure how this would have to work. Maybe we need to separate recategorization of item buttons from displaying them. I think this would also help with other situations where we'd like to not refresh the assignments.
  * I just added update when categorizer updates. Works like a dream. (hopefully ;))
* ✅ Folding now casues update the frame size
* ~👎[!] it seems that saving a positition of group in the bag on other char can cause discrepancies between how items are saved on other leading into having items in groups which are then displayed in number of separate columns [ some are empty]. Probably caused by the fact that there is not domain split of the repsonsibilities. Hence this rework with this bug is even more critical to make sure which part of the app is repsonsible for what.~
  * i dont think that is true. This if I recall correctly was due to the fact that addon was enabled in dev and non dev mode at the same time, hence the data from both started to overlap. There could be a prevention mechanism in place if at all.
* ✅[!!] Removing of equipment set does not update the categorizer. Gear sets categorizer seem to not work properly on some characters, as well as does not seem to update categorization properly once items gear set association have been modified
* ✅ in custom categories GUI it should state "Query" above the query text input.
* ✅ tech - rename folded to collapsed
* ✅ show many items are inside collapsed group
* ✅ category should be selected after creation and list should scroll to it so it was visible
* ✅(sound of bag) add sound when picking a category - maybe use the same sound that is used picking up items for simplicity
* ✅ code now allows for proper splits of items without issues
* ✅ (this was done long ago I think) when opening bags sometimes not all info about items is available. Create a callback to readjust after data is loaded. Might cause a weird flicker so would need to verify how acceptable that is.
* ✅ removed code that caused tainting, now it should hopefully be fine
* ✅ added workaround for infinite loop caused by bug in how the game loads info about mythic keystones
* ✅ *improved greatly how you can move items around the backback*
* ✅ replaced the old text `Edit` button with a cog-style settings button and hid Blizzard `BagItemAutoSortButton` for the combined-bags MyBags container.
* ✅ fixed category drag reorder regression where dragging a lower category onto an upper one could no-op; reorder now works in both drag directions.
* ✅ custom categories are now temporarily rendered as always-visible while the categories GUI is open (runtime-only; no SavedVariables change).
* ✅ introduced explicit bag view mode (`normal` / `categories_config`): while config is open, custom category header left-click selects that category in config GUI, non-custom header left-click is a no-op, and collapse toggling is disabled.
* ✅ categories config panel can now be hidden without exiting edit mode; selecting a custom category from bag headers reopens the panel automatically and WowList single-select now stays single when selecting by predicate.
* ✅ config-mode category header left click now uses category-level hook (`OnLeftClickConfigMode`) so categories decide their own edit-mode behavior; custom category implements it to select itself in categories GUI.
* ✅ category wrappers now expose `GetDisplayName(itemsCount)` and GUI uses it as the single header label source (no `cus-*` checks or direct `.name` reads in `gui.lua`); custom category owns muted-empty display formatting.
* ✅ selected custom category in config mode now gets `>> ` prefix in bag headers via `GetDisplayName(itemsCount)`; selection change in categories GUI triggers layout refresh so highlight updates immediately.
* ✅ AGENTS.md now has strict "Internal contracts" rules (mandatory wrapper interfaces, boundary-only defensive checks, fail-fast internal flows, and a review checklist to block defensive call-site guards).
* ✅ in-bag category headers now render custom categories in grey when runtime-empty and not marked Always Visible.
* ✅ fixed custom category rename/delete API paths to resolve wrapped ids (`cus-<id>`), so Categories GUI rename/delete works reliably and rename preserves assignments.
* ✅ categories config rename/delete popups now pass category wrapper references (not ids) through UI flow, keeping internal interactions object-based.
* ✅ added explicit in-bag edit-mode indicator (`Edit mode` badge + highlighted cog icon), and closing the bag now always exits edit mode and hides the custom categories config UI/popups.
* ✅ `Edit mode` badge next to the cog now acts as part of the config toggle (clicking the badge triggers the same edit-mode on/off behavior as the cog).
* ✅ resolved search-filter + edit-mode/category-move anchor conflicts without clearing search text/focus on mode toggles (lock now survives those flows).
* ✅ holding Shift while dragging a category now moves that category and all categories below it in the source column (applies to category-drop reorder and background column-drop).
* ✅ reworked category drag tooltip for Shift-tail move guidance: improved readability/contrast, wrapped hint text, live Shift-state message updates, and final category-name/default-color formatting.
* ✅ Unassigned should be a separate categorizer initialized at the end of all the others.
* ✅ drag and drop triggering an action that an item was dropped onto a new category should be handled differently. First of all drop and down should be using reference to real categories. Each category should have function to handle OnItemAssigned and OnItemUnassigned. As example I believe that custom categorizer when exposing its categories would most likely create some kind of proxy functions for those functions. Categorizers should no longer listen to events about associating item with a category - instead there could be a separate handling function within categories.lua which will listen to those events, and then call OnItemAssigned and OnItemUnassigned accordingly. However draganddrop should not trigger that event if any of those categories is protected. This will allow us to create some additional dynamic, non protected categorizers which might want to perform some actions of their own during such reassignment and store information differently then the one in custom.
* ✅ each categorizer should store a list of categories which could be retrieved when needed from categories store
* ✅ Because of the above categoriesGUI should also by default work mostly with custom categorizer.
* ✅ custom/query boundary step completed: query orchestration now goes through `CustomCategories` APIs; `Categorizers/custom/query.lua` no longer reads `CategoryStore`; query edit UI also uses `CustomCategories` directly.
* ✅ categories store is no longer responsible for storing custom category saved-variable data (`items`, `query`, `alwaysVisible`, etc.); custom data is now owned/migrated by `CustomCategories` in `db.userCategories`.
* ✅ custom.lua now handles persistence/bootstrap for custom category query/items data and migration, so CategoryStore is no longer aware of custom query/items state.
* ✅ category move and custom-category GUI drag/drop flows now pass category references (wrappers) end-to-end; internal runtime no longer resolves categories by name in those paths.
* ✅ selected category visibility in config flow is effectively covered: while categories config is open, custom categories are shown, selected category is highlighted (`>> `), and selecting from bag headers keeps that selection visible without persisting Always Visible state.
* ✅ [DONE with differences] rewrite categorization [or rather where each piece is stored for a given category]
  * ✅ custom/query/always-visible/manual-item data ownership moved to `CustomCategories`; `CategoryStore` now keeps wrappers/shared layout only.
  * ✅ wrapped-id rename path preserves assignments (covered by integration test: `category rename accepts wrapped category id and preserves assignments`).
  * ✅ manual assignment flow now de-duplicates entries and rebuilds assignment index from persisted data on load.
  * ✅ custom/categories domain split and event/update responsibilities were reworked in the AI refactor section below.
* ✅ item tooltip category diagnostics are now Shift-gated; without Shift it only shows a short hint, and full matched-category calculation runs only when Shift is held (commit `eb6c69f`).
* ✅ removed/superseded: no automatic movement of categories between columns based on visual overflow; columns now follow persisted assignment + explicit column-count/resize behavior.
* ✅ [superseded by layout policy] breaking of groups/overflow split behavior no longer applies after moving to explicit column assignment + resize-driven layout.
  * note: this concern was tied to an older design where assignment tried to react to visual overflow. Current policy is to keep assignment/layout deterministic and handle visual fit via sizing/column controls.
* ✅ query categorizer now uses explicit custom-category priority scores (defaulting to raw numeric category id), with deterministic tie-breaks and GUI editing.
* ✅ item tooltip now supports MyBags match diagnostics with Shift-gated category list and reason tags (manual assignment vs query priority).
* ✅ stack splitting support is enabled for MyBags empty-slot flow (hooked `C_Container.SplitContainerItem` to allow split-drop behavior; commit `af35368`).
* ✅ highlight selected category in the bags and make it temporary visible via always visible or similar functionality. 
* ✅ unassigned group should always be visible
* ✅ search focus now locks combined-bag top edge while typing in bag search (frame still resizes for filtered items, but top/search field stays visually fixed; default Blizzard anchoring resumes when search loses focus).
* ✅ completed item-drag category hint UX: non-interactive category overlays + dark floating text frame, protected/unassigned action messaging, assign-to text for normal targets, left-anchored column-width layout, persistent target highlighting while dragging over item buttons, and category hover info shown in the same dark frame (no old `GameTooltip`).
* ✅ edit mode category creation now uses a single in-grid `+ Add Category` row after the last category in the last column (opens the existing create-category popup), newly created categories default to appending in the last column (except first-time empty-layout bootstrap, which keeps round-robin placement), and the side-panel `New` button was removed.
* ✅ modify the build process to not include any *.md files apart from README.md and QUERY_ATTRIBUTES.md
* ✅ add trash/delete icon on the right side of in-bag category headers (title anchored left of the icon) and open delete confirmation popup on click.
* ✅ delete-header tooltip now shows `Delete "{category name}" category` and supports Shift-click to skip confirmation prompt by running the same deletion accept path directly.
* ✅ in edit mode category layout now always renders each category on its own full-width row, with follow-up `main.lua` cleanup to explicit flags (`isHeaderOnly`, `categoryRequiresNewLine`, `categoryRequiresFullRowWidth`) and simplified boundary expansion math.
* ✅ refreshed query documentation in `QUERY_ATTRIBUTES.md` to match current parser/runtime behavior (including priority order, syntax, and case sensitivity) and added `README.md` link to the query reference.
* ✅ added in-game query documentation panel opened by a `MainHelpPlateButton`-styled Help trigger next to `Save Priority`; content is sourced from generated Lua docs built from `QUERY_ATTRIBUTES.md`, rendered with WoW-style formatting (headings/bullets/table-to-list/inline-code coloring) and a refined softer color palette.
* ✅ query parser now supports quoted multi-word `itemName` values (for example `itemName = "Epic Sword"`), while keeping existing unquoted pattern behavior; query docs were updated accordingly.
* ✅ query attribute names are now case-insensitive (`itemType`, `ItemType`, `ITEMTYPE` all work); docs updated while keeping canonical-case examples.
* ✅ query match ordering now ties by alphabetical category name after priority (with deterministic id fallback); query docs updated accordingly.
* ✅ finalized custom-category import/export: plain Lua payload with strict validation, create-only import of rules + manual item assignments (`items`) (no `externalId` upsert, no layout import/export), and completed UX polish (list sizing, Shift-range select fix in `MyLibrary_GUI` `WowList-1.5`, independent import/export windows, scrollable read-only import analysis, centered import window).
* ✅ create some nice default categories with queries - purely using queries (seeded via built-in import payload on empty custom DB; includes default first-launch layout reset).
* ✅ query syntax/help window now stays open when custom category GUI is closed (it still closes when the bag/container itself is hidden).
* ✅ finalized search-query union feature: search now includes Blizzard default matches plus valid query-language matches from the same text (invalid query ignored), query-only matches are not dimmed, search text is captured via direct `OnTextChanged` wrappers on `BagItemSearchBox` and `BankItemSearchBox`, custom GUI query-to-search sync stays local to `categoriesGUI.lua`, temporary debug/race-workaround code was removed, and `README.md` was updated.
* ✅ custom query-edit preview flow finalized: editing/focusing query text in custom categories GUI mirrors into bag search for live results, search anchor lock stays active while query editor is focused in edit mode, and bag/bank search max length is 255.
* ✅ added in-bag free-space text in the money/footer strip showing remaining generic bag slots and reagent-bag slots.
* ✅ custom-category editor flow is now decoupled from edit-mode toggle: the panel no longer auto-opens, its in-panel category list was removed and replaced by an explicit selected-category header (`Category: ...`), closing the panel clears selected-category highlight (`>>`), in-bag custom headers gained a yellow `GM-icon-settings` edit button (left of trash) that opens/selects category config, and header left-click in edit mode now collapses/uncollapses like normal mode.
* ✅ redesigned custom-category editor to a centered Blizzard-style movable panel with staged editing: changes are applied only on `Save`, `Revert Changes` restores drafts to the selected category baseline, panel-side delete remains removed, Escape cancels in-field name draft text, closing with pending edits prompts `Save and Exit` or `Exit`, action buttons are kept in the bottom-right corner with a tighter overall panel height, leaving query-editor focus clears the mirrored bag search text, saving a rename now updates the config-window title immediately, and missing field tooltips were added (including a clearer priority explanation that it resolves which matching category receives the item).
* ✅ query help panel content is now selectable/copyable, includes in-panel search with `Prev`/`Next` navigation that scrolls to and highlights each match without stealing search-box focus, and opens scrolled to the top (when no active search query).
* ✅ invalid query syntax in the custom-category editor now shows inline validation (red query box styling + red note under the field) using the same query compiler path as runtime, and save is blocked with an explicit inline error when query syntax is invalid (including `Save and Exit` flow) without force-changing focus/lock state; search-anchor lock now also stays requested while query editor text is non-empty (not only while query field has focus) to avoid anchor drift/rescale jumps.
* ✅ column hover tooltip now uses the full column width (instead of the hovered category frame width).
* ✅ [bug] fixed right-click on bag-column background during drag: it no longer triggers category move for the dragged item's category.
* ✅ [bug] `CATEGORIZER_CATEGORIES_UPDATED` handler now skips `TriggerContainerOnTokenWatchChanged()` when the bag container is hidden, avoiding needless refreshes.
* ✅ bank now has MyBags category rendering/assignment support with separate layout scopes (`bag`, `bank-character`, `bank-account`), account/warband bank remains a separate tab/scope (no forced merge), bank search now also supports query-union matching from search text (same include rules as bag search), and bag edit-mode controls remain bag-only.
* ✅ added bank MyBags vertical scrolling with a dark bounded viewport and native Blizzard minimal scrollbar/wheel handling; overflow is clipped to the visible area and scroll offset is preserved across refreshes (clamped when content shrinks).
* ✅ added temporary bank-only debug overlays that visualize background drop-to-column zones used by category drag/drop assignment.
* ✅ bank scope column count is now forced to 4 on addon initialization for both `bank-character` and `bank-account`.
* ✅ reduced bank search query-union visual blip by applying bank `INVENTORY_SEARCH_UPDATE` with immediate `RefreshNow()` instead of deferred `QueueRefresh()`, so query-match de-greying is applied in the same update path.
* ✅ fixed persistent greying of query-union matches in both bag and bank by explicitly setting per-item `SetMatchesSearch(includeInSearch)` during MyBags categorization loops and reapplying query-union match state after Blizzard `UpdateSearchResults` runs.
* ✅ reduced query-search stutter by removing extra post-search full-pass hooks and reusing per-item query payload data between search-union filtering and custom categorization (avoids duplicate expensive item-info payload builds per keystroke); reverted a later over-aggressive `INVENTORY_SEARCH_UPDATE` gate after it broke normal filtering behavior.
* ✅ aligned bank search-refresh flow closer to bag performance characteristics by avoiding full all-tab item-button pool rebuilds on every refresh when tab/slot signature is unchanged (regenerate only when bank type/tab set/slot counts change or pool is empty).
* ✅ fixed regression where only first bank tab items could remain visible after optimization by tightening regenerate conditions: now bank also regenerates when active pooled button count differs from expected total slot count across visible tabs.
* ✅ fixed dimming regression while keeping search performance by caching per-item search inclusion (`_myBagsIncludeInSearch`) during bag/bank refresh and reapplying that cached state after Blizzard `UpdateSearchResults` (no extra payload/query recomputation pass).
* ✅ simplified search visuals per request: visible bag/bank item buttons are now always forced undimmed (`SetMatchesSearch(true)`), while filtering still relies on include/exclude layout decisions rather than dim state.
* ✅ fixed bank Actions button runtime error (`EasyMenu` nil on modern Retail) by migrating to Blizzard `MenuUtil.CreateContextMenu`; menu now uses the supported context-menu API and the button is anchored to the bank search row for stable placement.
* ✅ fixed drag hint regression where hovering item buttons did not keep category highlight active; hint mapping resolves by category id + scope and bag item buttons now also set `MyBagsScope = "bag"` (matching bank) so hover-to-header highlighting works in both bag and bank while still avoiding cross-frame tooltip stealing.
* ✅ bank MyBags view now renders all purchased tabs at once per active bank type (character/account), hides Blizzard bank tab strip while active, tracks visible tab IDs for `BAG_UPDATE` refreshes, and shows purchase-next-tab via a dedicated `+` button instead of an `Actions` menu.
* ✅ fixed bank move-to-empty-slot icon bug: MyBags bank refresh now calls Blizzard `BankPanelItemButtonMixin:Refresh()` for each active button so icons/count/lock state update immediately when an item is moved into a previously empty bank slot.
* ✅ fixed bank<->bag drag transfer regression by normalizing cross-scope item drags to merchant-style (`cross-scope => pickedItemButton = nil`) across `OnDragStop`, `OnReceiveDrag`, and `PreClick`; category/background drops now use the standard available empty slot path, while same-scope drags keep fast-path swap behavior.
* ✅ bank/bags edit-mode UI parity is now implemented: bank cleanup button is replaced by a MyBags edit toggle, bank search width matches bags, bank edit mode now shows category header `Edit/Delete` plus in-grid `+ Add Category`/`Export`/`Import`, bag and bank capacity labels both use `taken / total` format with full tooltips, bank auto-deposit controls are anchored in the bottom strip (deposit centered, capacity on the left), bank tab header text is hidden in MyBags bank view, and the old bank `Actions` dropdown is replaced by a bottom-strip `+` purchase-tab button visible only when purchase is possible.
* ✅ bag/bank drag-hover parity is now aligned across resize changes: bank layout keeps scroll-free auto-resize + shared bank/warbank resize behavior, bank frame size stays locked during search filtering, bank top-right edit cog matches bag styling, and both bag + bank background drag flows now first hit-test the actual category group frame under cursor (including item-gap regions) with fallback to hovered-column last-category highlighting/assignment only when no specific group frame is under cursor.
* ✅ fixed category hover hint placement regression by forcing bag header hint anchoring to the hovered category frame/title (matching bank behavior) instead of side/column anchoring fallback.
* ✅ fixed category hover hint vertical placement to always anchor above the category title (removed below-category fallback branch).
* ✅ category hover hint frame now matches the hovered bag/bank effective scale, and assign-hover text now uses toned-green `Assign` styling for consistency with existing toned status colors.
* ✅ increased category hover hint readability (larger text/padding) and added dynamic width expansion so long category names can widen the hint when needed (capped to available UI width).
* ✅ fixed Shift-tooltip category diagnostics via separate match-list path: `Categorize` is fast single-match only, while tooltip uses dedicated full-match collection (manual first + query candidates), including duplicate-category diagnostics when the same custom category matches both manually and by query (`X (Manual assignment)` + `X (Priority: ...)`).
* ✅ custom manual assignment now silently ignores redundant assignment only when target custom category is already the global category winner (`Categories:Categorize`) for that item; if another categorizer would win otherwise, manual assignment is still persisted (move flow still clears previous manual source assignment).
* ✅ Shift item tooltip now also lists non-zero query retriever payload values under matched categories, with value-meaning labels from query docs (for example `itemType: 2 (Weapon)` and `itemSubType` labels resolved by current `itemType`); tooltip attribute definitions/order now live centrally in `Categorizers/custom/query.lua` and rows use explicit attribute/value/meaning coloring, including `expansionID` value labels (`0..12`).
* ✅ updated `QUERY_ATTRIBUTES.md` core value tables with explicit `expansionID` mapping (`0..12`) to keep docs aligned with tooltip/query metadata.
* ✅ fixed query numeric comparators (`>`, `>=`, `<`, `<=`) to safely return `false` when attribute value is missing/non-numeric (for example `questid > 0`) instead of throwing runtime errors.
* ✅ fixed bank-frame position drift during category/layout refreshes by removing forced `UpdateUIPanelPositions(BankFrame)` from MyBags bank content sizing, so moving/reordering categories no longer pushes the bank frame downward unexpectedly.
* ✅ fixed first-open-after-reload bank bottom overflow edge case by making initial bank position correction run once on the next frame after first-size/scale pass (`UpdateUIPanelPositions(BankFrame)` + rescale), instead of repeating reposition on every refresh.
* ✅ assigning an item via category background or column background now moves it to the end of the entire item order list, while item-on-item drop ordering remains unchanged.
* ✅ fixed Shift tooltip refresh in bank/item tooltips by handling `MODIFIER_STATE_CHANGED` (`LSHIFT`/`RSHIFT`) and forcing tooltip bag-slot rebind; tooltip owner resolution now walks parent frames to find the actual item button.
* ✅ tightened bank footer capacity/purchase-tab spacing: switched capacity text to compact `taken/total`, constrained the capacity label width so it cannot overlap the purchase control, and switched the purchase icon to `128-RedButton-Plus` for stronger visibility.
* ✅ fixed warband-bank footer overlap and anchor-dependency error: account/warband mode now anchors controls in explicit left-to-right order `Deposit All Warbound Items` -> include-reagents checkbox -> include-reagents label -> `MoneyFrame`, computes checkbox-to-money spacing from live label width, and avoids anchoring the checkbox to its own label region (`Cannot anchor to a region dependent on it`).
* ✅ removed Shift tooltip query-attribute noise filtering; tooltip now shows every non-`nil` payload field (including `0`, `false`, and empty strings).
* ✅ fixed bank search/category-query sync targeting so custom category query editing mirrors to the active container search (bank when bank is open, otherwise bags), and fixed bank-search blanking by keeping category headers/layout visible when search yields zero visible items (retry/hide only while bank item data is still loading).
* ✅ completed search performance and correctness rework for bags+bank: stabilized query-editor/search sync, removed one-keystroke stale-filter delays (queued+deduped search refresh), introduced shared `ContainerItemInfoCache` with strict invalidation, kept filtering correctness via captured Blizzard default-match state, fixed bank empty-result header spacing fallback, and resolved regressions from unsafe intermediate caching; final profiling dropped bank search from ~20ms avg to ~3.3ms avg.
* ✅ stabilized bag/bank search clear resize behavior: search-anchor/size lock now avoids transient unlock/re-anchor races (including clear via `x`), preventing frame fly-away/oversize jumps when clearing filter text.
* ✅ filtering now preserves visible category headers in both bags and bank by seeding search baseline categories from live item categorization (not persisted layout), while header counts remain filtered counts.
* ✅ fixed bank resize-handle visibility during active filtering: the handle now stays visible while search is active (matching bag behavior), but remains non-interactive until filtering ends.
* ✅ reduced bank auto-deposit button width to 70% of Blizzard baseline width to free footer space while preserving existing anchors/behavior, and fixed a Lua local-function-order regression in that path.
* ✅ locked bank and warbank minimum column count to 5 across persisted layout clamping and resize interactions.
* ✅ set scope-specific max column limits: bags stay capped at 8, while bank and warbank can resize up to 10 (including bank resize-handle max cap + persistence/resize test coverage).
* ✅ fixed bank/warbank layout scope mixing on resize: resizing now updates only the active scope (`bank-character` or `bank-account`) so category layouts no longer cross-apply between tabs.
* ✅ fixed `New` categorizer drag runtime error by aligning `OnItemUnassigned(itemId, context)` with the category wrapper callback contract.
* ✅ when item is matched against a category which is disabled we now continue to the next eligible match (manual/query within custom categorizer) instead of falling back directly to unassigned.
* ✅ the bank again is tainting the bags :/// need to see what regression was introduced - fixed by changing ToggleAllBags function override
* ✅ move search in bank to the left as it is in combined bags
* ✅ add icon with question mark right to the search box in both banks and bags as it is available next to a query in category configuration which will open the same frame with info about query
* ✅ completed `QUERY_ATTRIBUTES.md` item subtype coverage for previously missing `itemType` classes (Container, Projectile, Tradegoods, ItemEnhancement, CurrencyTokenObsolete, Quiver, Questitem, Key, PermanentObsolete, Glyph, Battlepet, WoWToken).
* ✅ category header hover tooltip that only shows category name/description now appears only when hovering the category title text (not the whole category row) in both bags and bank; drag/drop hint tooltips are unchanged.
* ✅ fixed bank category-background drag retargeting for category drags: background now resolves hovered bank category body and forwards to category drop handler for both item-drag and category-drag flows (instead of only item-drag), so category body drops no longer fall back to column background.
* ✅ simplified `README.md` structure and wording, including a shorter and clearer `How it works` flow and a compact but more complete `Other features` section.
* ✅ in edit mode add next to the question mark which is next to the search bars a checkbox which by default will be disabled. It will steer whether categories disabled to be used in a given scope should be visible or not. By default they should not be visible in config mode. Toggling this checkbox will make them visible.
* ✅ expanded README import/export docs to explain normal payload-based import/export behavior, plus a small AI prompt workflow subsection with a reusable template and the 3-step instruction list.
* ✅ added a new default starter custom category `Uncollected Transmog` (query-based) and placed it in seeded default layout.

### TODO

* draggin an item from vendor or inventory or another container should not show category highlight as this will not assign by default (at least from vendor) this item to a given category based on background afaik. If that is true then in other cases it also should not reassign category when dropping on background
* changing tab between warband bank and bank while having search selected freezes the resize. We should either clear the search before switchng and leave it empty, or clean it, switch, paste it.

#### Low priority

* creating new category should assign that new category to last column in all contrainers at the same time. currently adding a category in bank results in category added in bank to the last column, but first in the bags

### DOUBTFUL - to check at later stages

* make update container layout based on events, not so that changing state causes that. Collapsed already does that..
* resizing via scrolling should work on all empty spaces
* make collapsed a part of a mixin for container, not separate entity
* [in progress] clearup the todos as I think there are duplicates and also these have become unordered due to that

### REJECTED
* add info at the top, and in bright colour, of query expanation in game that this information is available also at https://github.com/MyGamesDevelopmentAcc/MyBags/blob/main/QUERY_ATTRIBUTES.md
  * I have added search functionality and copy
* Add ability to hide category so it won't show, nor the items in it
  * I dont want to create this, items should be visible not cause confusion "where is my item, oh I have hidden it"
* I have decided to not include button for authenticator that is available in normal bags. Consider adding it via adding to layout update self:LayoutAddSlots(); as well as support for this button. Although I have no idea how I could test it
* add ability to disable category so it will stop catching items, but will exist. Items assigned by category will no longer be caught by this category. If they are moved to another category from unassigned, they will get removed from this category.
* add an ability to move categories on the list, so that categorization would not be based on the order of (well, currently random) alhabet
  * this is done using priorities
* [this was done differently] if ther was a way to properly higlight that an item would have been categorized differentlty by QL if it was unassigned directly by id to a category, we maybe would not need protected categories(Although I think it always should be an option, and those categories would also work before assignment by id). In the menu there should be an option to "always show given category".
  * categorize by QL if protected
  * categorize by id assignment
  * categorize by QL
  * unassigned

## Technical focused

Tasks which after implementation user will not see.

### DONE

* ✅ added explicit fail-fast load-order guard in `categoriesColumnAssignment.lua` so it errors clearly if `categories.lua` has not initialized `AddonNS.Categories` yet.
* ✅ added opt-in performance probes for bag-open hotspots (main iteration/categorization/layout, custom categorizer query path, items sort path) plus debug toggles to enable/disable profiling in-game.
* ✅ added detailed profiling breakdown inside `ArrangeCategoriesIntoColumns` to identify exact time split (constants/layout match/unmatched build-sort-insert/sort-only/add-category totals).
* ✅ added edit-mode bottom-left drag resize handle for bag columns (x-axis only), with release-time hysteresis mapping (`+0.5` grow / `-0.5` shrink) to persisted column count.
* ✅ added live resize preview overlays in edit mode: soft-blue baseline over current columns, green overlays for projected added columns, red overlays for projected removed columns, plus `start -> target` count label while dragging.
* ✅ items sort now uses fail-fast cached item ids from main iterator (`itemButton._myBagsItemId`) and no longer calls `GetContainerItemInfo` inside `ItemsOrder:Sort`.
* ✅ added deeper `ItemsOrder:Sort` profiling split (map/sort/append) and tiny-list fast paths (`<=1`, `==2`) to reduce sort overhead.
* ✅ removed unnecessary `order_map_changed` invalidation in `ItemsOrder:Sort`; order-map rebuild now happens only after real order mutations.
* ✅ added agent skill `.agent/skills/blizzard-code-explorer` to guide Blizzard UI source lookup (path resolution, targeted `rg` patterns, source-cited output contract).
* ✅ updated `.agent/skills/blizzard-code-explorer` to default to `/mnt/c/Program Files (x86)/World of Warcraft/_retail_/BlizzardInterfaceCode`.
* ✅ enabled `BankFrame_Open` override in `ContainerFrameMyBagsMixin.lua` (`OpenAllBags(BankFrame)` before calling original) as the current workaround that resolves the observed bank taint path.
* ✅ replaced failed reagent `IsBagOpen` shim with a dedicated `ToggleAllBags` override in `ContainerFrameMyBagsMixin.lua` that mirrors Blizzard logic while excluding merged reagent from combined-mode close/open accounting.
* ✅ refactored search-lock ownership so `ContainerFrameMyBagsMixin` is the single owner/mutator of search lock runtime state; `main.lua` now calls mixin methods instead of writing lock fields directly.
* ✅ simplified search-lock internals in `ContainerFrameMyBagsMixin` (centralized pending check helper + reused capture/apply stored-lock methods) without behavior changes.
* ✅ simplified search-lock flow further by removing pending-state bookkeeping; active lock now always captures/applies around layout updates while enabled.
* ✅ hard separation between custom/user-managed categories and dynamic ones is now in place (CustomCategories owns custom persistence/query/manual assignment; CategoryStore owns wrappers/shared layout).
* ✅ naming convention for categories/categorizers is now considered done (implemented convention differs from the original `sys:*`/`ext:*` proposal).
  * chosen convention: categorizer ids are short stable tokens (`unassigned`, `new`, `cus`, `eq`) and runtime wrapper category ids are namespaced as `<categorizerId>-<rawId>` (with `unassigned` kept as a sentinel singleton id).
* ✅ tooltip category diagnostics are now Shift-gated, so full match-list calculation is no longer done unless Shift is held.
* ✅ added profiling for bag refresh, `ArrangeCategoriesIntoColumns`, `ItemsOrder:Sort`, and `CustomCategorizer:Categorize` to pinpoint hotspots.
* ✅ addon freezes when opening bags or changing categories.
  * optimized item sorting, still CustomCategorizer:Categorize could be improved which was separated to another ticket
* ✅ bag column resize handle is now always visible/usable while bags are open (not gated to edit mode; still hidden in combat lockdown).
* ✅ documented new engineering principle in `AGENTS.md`: debug from lifecycle entry points/state boundaries first (with explicit bank `BankFrame_Open` example) before introducing deeper runtime lock/state machinery.
* ✅ release workflow now removes `tools/` before packager runs, so dev scripts are excluded from shipped addon archives.
* ✅ fixed bag resize regression introduced during bank-scope support: resize baseline now always reads bag scope column count (not current global layout scope), restoring correct preview sizing and release-to-column mapping.
* ✅ disabled temporary bank column drop-area debug overlays by default (`SHOW_COLUMN_DROP_AREAS = false` in `bankView.lua`).
* ✅ kept `BankFrame_Open` global override in `ContainerFrameMyBagsMixin.lua` with explicit taint-workaround documentation; open-all close behavior is handled separately by dedicated `ToggleAllBags` override.
* ✅ fixed bag/bank resize-handle cursor drift under non-default frame scale by normalizing drag cursor X against the resized frame effective scale (not `UIParent` scale), keeping the dragged corner aligned with the mouse.
* ✅ implemented scope-aware custom category visibility (`bag` / `bank-character` / `bank-account`) with config-panel checkboxes (Bags/Bank/Warbank), edit-mode header quick-toggle icons in bag+bank views, scope-filtered categorization/rendering, and Shift-tooltip diagnostics that still list disabled categories and mark when disabled in the current scope.
* ✅ fixed edit-mode visibility behavior for scope-disabled custom categories: they now remain visible in categories-config mode (so they can be edited/toggled back) while still showing disabled-state icon and staying excluded from normal scope categorization.
* ✅ adjusted category-config wording from `Visible in` to `Used in` to better reflect that scope toggles control categorizer usage, not just header visibility.
* ✅ fixed category editor scope-toggle UI layout: `Used in` controls now share the `Always show` row, priority/query are no longer pushed into save/revert controls, scope checkboxes are aligned, and only checkbox icons (not text labels) are interactive.
* ✅ fixed bank category in-column row packing parity: in normal mode bank categories can now share a row within a column (matching bag behavior for small categories), while edit mode remains one-category-per-row with full-width headers.
* ✅ regenerated `generated/queryHelpDocs.lua` from updated `QUERY_ATTRIBUTES.md`, expanded query tooltip `itemSubType` value map coverage in `Categorizers/custom/query.lua` for previously missing `itemType` classes, corrected Tradegoods subclass ids (`Jewelcrafting=4`, `Cloth=5`, `OptionalReagents=18`), switched obsolete Tradegoods subtype labels to human-readable text with spaces, and synchronized readable naming between `QUERY_ATTRIBUTES.md` and tooltip maps (for example `Axe 1H`, `Food / drink`, `Optional Reagents`).
* ✅ restored query item-data async refresh in `Categorizers/custom.lua`: when `C_Item.GetItemInfo` is not ready, custom categorizer now schedules a throttled (`~1s` per item id) `Item:ContinueOnItemLoad` callback that triggers `CATEGORIZER_CATEGORIES_UPDATED`, recovering first-open miscategorization cases (including mythic keystone-style delayed item data).
* ✅ fixed stale refresh after clearing `New`: `Categorizers/new.lua` now emits `CATEGORIZER_CATEGORIES_UPDATED` after `ClearAll` so bag/bank categorization caches invalidate and refresh correctly; regression coverage added in `tests/Categorizers/new_test.lua`.
* ✅ fixed combined-bags oversize edge case during dynamic growth (for example `New` category expansion on incoming items): bag refresh/token-watch paths now explicitly reapply combined-bags scale after layout updates (`AddonNS.ApplyContainerFrameScale`), so frame scale clamps to screen bounds as content height changes.
* ✅ enforced global per-scope layout uniqueness for category ids in `CategoryStore` (dedupe across all columns during layout normalization), with integration coverage for both load-time cleanup of already-duplicated SavedVariables and runtime `SetLayoutColumns` persistence normalization.
* ✅ fixed bag/bank overlap on simultaneous open by reapplying combined-bags scale immediately after bank frame size/scale refresh and once more after first-frame bank position settle in `bankView.lua` sizing flow.
* ✅ tightened bag-vs-bank separation in container scale math by enforcing a positive post-bank gap (`BankFrame:GetRight() + gap`) instead of the previous negative offset allowance, reducing residual overlap after simultaneous open/resize flows.
* ✅ simplified `FrameParameters.lua` scaling model to shared width fit + per-frame height fit, then upgraded it with a second-pass effective-width reclaim: after initial `widthScale`/height comparison, each frame recomputes its width limit using remaining width after the other frame’s effective occupied width (`otherWidth * otherScale`), so a height-limited bank can free width for bags (and vice versa); final per-frame scales are clamped to `[0.05, 1]`; bag-refresh paths in `main.lua` now reapply both container and bank scales (when bank is shown) so bank scale tracks bag-size changes under the shared-width model; `bankView.lua` now also re-runs `UpdateUIPanelPositions(BankFrame)` when bank panel height grows (not only on first show) to keep vertical placement aligned as size increases; dedicated pure-math coverage lives in `tests/frame_parameters_scale_test.lua`.
* ✅ added five non-derivable query attributes (`isAnimaItem`, `isArtifactPowerItem`, `isCorruptedItem`, `description`, `isTransmogCollected`) with docs/tests updates, and added temporary combined profiling for new-attribute extraction cost in `CustomCategorizer:Categorize` profiling output (`newAttrsAvg`).
* ✅ changed `isTransmogCollected` payload semantics so missing transmog source info now yields `nil` (not `false`), with query docs/help and unit/integration tests updated.
* ✅ query string matching is now case-insensitive (`itemName` and `description`) by lowercasing both candidate and pattern in the string comparator, with docs/help and query unit tests updated.
* ✅ added `isWarbound` query attribute via `C_Item.IsBoundToAccountUntilEquip(ItemLocation:CreateFromBagAndSlot(...))`, and updated docs/help plus unit/integration test coverage.
* ✅ expanded query documentation notes/examples for recently added attributes (`isAnimaItem`, `isArtifactPowerItem`, `isCorruptedItem`, `isWarbound`, `description`, `isTransmogCollected`) and regenerated in-game query help docs.
* ✅ restructured recent-attribute documentation to user-facing dedicated headers under `Core Value Tables` (`isAnimaItem`, `isArtifactPowerItem`, `isCorruptedItem`, `isWarbound`, `description`, `isTransmogCollected`) and removed mixed technical note block.
* ✅ switched default seeded `Warbound` category query from `bindType = 9` to `isWarbound = true` (still gated by `isBound = false`) and synced integration default-query expectations.

### TODO

* change release process to produce only zip file with addon code, not release.json or Source code zips. Unless this would break population to wowuphub?
* remove all logs, debug logs, profiling code, triggers etc.
* refactor the code so that triggers, window etc related to query window was exported to separate file as now this code seem to be mixed inside categoriesGui.
* remove defensive silent-guard anti-patterns (e.g. `if not x then return end` in internal domain flow) and replace with fail-fast preconditions so bugs are surfaced instead of hidden.
* addon was changed but in many cases it is no longer event based. We have look for different places, especially around actions, triggers etc. where action causes a reaction in multiple places, requires changes in multiple places at once. We should refactor those places to be event based. Please look for all the places where we could cleanup the code and reduce direct calls and use event based instead for clear separation of responsibilities.
* normalize naming convention across codebase: standalone/local functions to lower camel case (e.g. `doSomething`), and table methods defined with `:` to UpperCamelCase (e.g. `SomeTable:DoSomething()`).
* extract bag-search anchor-lock behavior into a dedicated module/file (separate from `ContainerFrameMyBagsMixin.lua`/`main.lua`) with a clear interface for state transitions and anchor reapply hooks.
* improve categorization performance path (`CustomCategorizer:Categorize`) after sort/layout fixes.
  * use profiling before each optimization pass:
  * `/run GLOBAL_MyBagsEnableProfiling()`
  * reproduce with bag open/refresh and review `PROFILE ...` lines in chat
  * `/run GLOBAL_MyBagsDisableProfiling()`
  * target next split: manual-assignment checks vs query evaluation vs category-iteration overhead.
* [PARTIAL] Code overall should try to as much as possible stop using ids or names to retrieve information about a category and try to as much as possible use references to categories.
  * ✅ completed: custom category GUI drag/drop no longer uses `GetCategoryByName` fallback lookup.
  * ✅ completed: category column assignment now hydrates runtime layout state on load and serializes back on logout.
  * ✅ decision update: category move/layout event flow uses category ids in `categoriesColumnAssignment.lua` by design (stable persisted shape and lower load-order/wrapper coupling).
  * ⏳ remaining: continue reducing id-based handling where persistence/UI boundary still legitimately uses ids.


#### Low priority

* setting on collapsed and column assignment should be stored under another entity "bag", as in the future we will have another for "bank" where what is collapsed or to which column assigned will be stored separately.
* the checks in drag and drop using pickedItemButton could be replaced with  C_Cursor.GetCursorItem() .

