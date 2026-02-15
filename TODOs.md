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

### TODO

* [!] create some nice default categories based on what I end up with as my query categories in TWW
* [!] add boxes with explanations over categories when draggin an item
  * the challange is that it should not hinder the ability to place item after/before another item
  * maybe if unassigned group is visible it should be added a bit more info to the tooltip what will happen if you move item over that group - that it will get unassigned from a custom group and can be picked by other categorizers
  * add the effect when dragging to indicate that a given cateogry is protected so you cannot assign to it - ie red background, shield pickture and some small text? And when howevering over a category to which you can assign indicate with text that it will be assigned to this one?
* ✅ search focus now locks combined-bag top edge while typing in bag search (frame still resizes for filtered items, but top/search field stays visually fixed; default Blizzard anchoring resumes when search loses focus).
* show somewhere how many empty spaces are left
* display empty space if available to show how many items we can still add.
* BUG: the handler for `CATEGORIZER_CATEGORIES_UPDATED` calls `TriggerContainerOnTokenWatchChanged()` even when the container/bag UI is hidden, causing needless refreshes; guard so it only runs when the container is visible.

#### Low priority

* add support for other bags (well, bank?). This is not a priority. I am doing this for fun and I feel current implementation of handling of the main bag kinda of works, I want to be adjusting it to a point I will be happy with it's behaviour. when I will extend the support onto other bags. But clean up the code toward proper mixin that maybe could be put on top of other frames if that is even possible.

### DOUBTFUL - to check at later stages

* make update container layout based on events, not so that changing state causes that. Collapsed already does that..
* resizing via scrolling should work on all empty spaces
* make collapsed a part of a mixin for container, not separate entity
* [in progress] clearup the todos as I think there are duplicates and also these have become unordered due to that


### REJECTED

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
* ✅ refactored search-lock ownership so `ContainerFrameMyBagsMixin` is the single owner/mutator of search lock runtime state; `main.lua` now calls mixin methods instead of writing lock fields directly.
* ✅ hard separation between custom/user-managed categories and dynamic ones is now in place (CustomCategories owns custom persistence/query/manual assignment; CategoryStore owns wrappers/shared layout).
* ✅ naming convention for categories/categorizers is now considered done (implemented convention differs from the original `sys:*`/`ext:*` proposal).
  * chosen convention: categorizer ids are short stable tokens (`unassigned`, `new`, `cus`, `eq`) and runtime wrapper category ids are namespaced as `<categorizerId>-<rawId>` (with `unassigned` kept as a sentinel singleton id).
* ✅ tooltip category diagnostics are now Shift-gated, so full match-list calculation is no longer done unless Shift is held.
* ✅ added profiling for bag refresh, `ArrangeCategoriesIntoColumns`, `ItemsOrder:Sort`, and `CustomCategorizer:Categorize` to pinpoint hotspots.
* ✅ addon freezes when opening bags or changing categories.
  * optimized item sorting, still CustomCategorizer:Categorize could be improved which was separated to another ticket

### TODO

* remove defensive silent-guard anti-patterns (e.g. `if not x then return end` in internal domain flow) and replace with fail-fast preconditions so bugs are surfaced instead of hidden.
* normalize naming convention across codebase: standalone/local functions to lower camel case (e.g. `doSomething`), and table methods defined with `:` to UpperCamelCase (e.g. `SomeTable:DoSomething()`).
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

