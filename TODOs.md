# Things to consider to change
There is a number of things that I can consdier for implementation. Some are more impacting user, some are rather technical - hence the split.

Some of the things are marked with [!] indicating their cruciallity before exposing this addon to wider audience.

## Design changes needed
* [PLAN] Plan for proper groupping:
    ```
    local sampleCategory = {
        name="",
        categorizer = "", -- whewther categorizer was used to generate this one. These are special kind of categories and should be treated separtely. Most operations such as renames should not be available to these.
        ~protected = "",~ -- this has to be removed, ie. when categorizer is set, it is protected as it is protected and automatically calculated. Can be hidden under "isProtected()"
        query = "",
        isAlwaysVisible()
        is
    }

    Stored per custom category:
    * name
    * query
    * alwaysVisible
    * items
        * itemid
        * maxilvl ?


    Per container setttings:
    stored:
    * collapsed
    * column assignment
    dynamic:
    * assigned items


    Generic:
    * items order
    ```

## User focused
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
* rewrite categorization [or rather where each piece is stored for a given category]
    * custom category for whatever reason disapears.
    * there is a bug in custom categories making the assignments to custom categories list grow and grow.
    * the rename I am quite certian does not work as it should ie. will loose some preassigned items
    * TECH - categoriesColumnAssignment should be a part of a Mixin as it contains container specific setup. 
    * does it mean collapsed should also be a per container setting?
    * The main error I made was to add new functionalities when I was supposed to in reality just extend custom categorizer. If I'd do that, then there wouldn't be issues.
* remove the movement of categories to separate columns when overflow happens - it did not work, and now with proper scaling it is no longer an issue - the bag will just get smaller. Remove other tickets.
* [!!!] position of the window should be changed to top if we are to be filtering.
* [!!!] ~✅ [I think, as I no longer observe this]~ breaking of groups does not seem to work properly - looks like it calculates only the amount within a given group whether it goes above the limit, not the entire amount of items in the column
    *  (see todo-1) this should not be handled here. Currently i am thinking th9at it is a responsibility of the drawing layer to make sure everything fits. This should just assign columns as is defined by user, without splitting as at this stage we have no knowledge about size in pixels of the column or the screen size. So to resolve it we'd need to do split logic of the same thing in the drawin layer anyways.



* make update container layout based on events, not so that changing state causes that. Collapsed already does that.
* could make search actually filter items (without changing bag size). Still not convinved that is a proper way to do that. Maybe there should be a check box whether to filter or not? Also while filtering is turned on, that is the only moment resizing is not in effect. As soon as filtering is empty, the bags should resize to original size. Best would be if the size was calculated as if those items were not filtered. Not sure how to do that, maybe rewriting the categorization would help.
* resizing via scrolling should work on all empty spaces
* ✅ in custom categories GUI it should state "Query" above the query text input.
* ✅ tech - rename folded to collapsed
* ✅ show many items are inside collapsed group
* add option to force new line on a given category
* unassigned group should always be visible
* query categorizer should check categories in the order of alphabet till category ordering is introduced
* add an ability to move categories on the list, so that categorization would not be based on the order of (well, currently random) alhabet
* ✅ category should be selected after creation and list should scroll to it so it was visible
* categories that currently do not catch any items from backpack into their group, could be considered as rendered at the bottom of the list of categories? Or maybe that is a stupid idea which will only complicate this further. the reason is that when one have a lot of categories, this creates this quite complex list to navigate.
* add colours to categories
* highlight selected category in the bags and make it temporary visible via always visible or similar functionality.
* [not an issue] how to change a bag to a different bag? edit: the same as way any other bag. Click the arrow at the bottom, then you can replace them
* make collapsed a part of a mixin for container, not separate entity
* [in progress] clearup the todos as I think there are duplicates and also these have become unordered due to that
* if ther was a way to properly higlight that an item would have been categorized differentlty by QL if it was unassigned directly by id to a category, we maybe would not need protected categories(Although I think it always should be an option, and those categories would also work before assignment by id). In the menu there should be an option to "always show given category".
    * categorize by QL if protected
    * categorize by id assignment
    * categorize by QL
    * unassigned
* taking of an item to just drop it onto a bag behaved weirdly. I think in such situation it should by default add it to unassigned maybe? Maybe if unassigned was always visible it owouldnt be an issue though.
* the categorizers might need a rework. With custom query like option, assignments by mouse, and ability to show always - this is needed, and needed to be easily changed. Also prioritisation of them, if we are talking about query like language as it will be based on the first one to catch with the query will get the item.
* maybe if unassigned group is visible it should be added a bit more info to the tooltip what will happen if you move item over that group - that it will get unassigned from a custom group and can be picked by other categorizers
* make it so that when a category is selected, the custom category becomes always visible during that time (?). Alternative is also to allow for multiselect and those selected are always shown, even after categories menu close.
* show somewhere how many empty spaces are left
* display empty space if available to show how many items we can still add as well as allow for stack splits.
* add the effect when dragging to indicate that a given cateogry is protected so you cannot assign to it - ie red background, shield pickture and some small text? And when howevering over a category to which you can assign indicate with text that it will be assigned to this one?
* add sound when picking a category - maybe use the same sound that is used picking up items for simplicity
* there is a lot of bad code, broken domains. Especially in the place of:
  * custom categories and categories,
  * which code [class/domain] should trigger visual updates as it is a random to an extent at this point
* a lot of todo's
* add support for other bags. This is not a priority. I am doing this for fun and I feel current implementation of handling of the main bag kinda of works, I want to be adjusting it to a point I will be happy with it's behaviour. when I will extend the support onto other bags. But clean up the code toward proper mixin that maybe could be put on top of other frames if that is even possible.
* consider actually adding some options - number of columns, items per column, always break category to new line.
* ~the draggin workaround with empty button might not work properly when the bag is full, reagent is bought or pulled from bank / merchant. We could verify the type of the item dragged and then if it is reagent then try by default to put in the reagent. Or maybe there is some other, more generic function which would just put the item into the bags?~ Actually it seems game somehow handles this correctly when trying to assign from merchant, but still not from bank. Either I figure this out, leave as it [as you can still right click], or create a check if reagent then assign another empty button from reagent frame.
* Add ability to hide category so it won't show, nor the items in it
* add ability to disable category so it will stop catching items, but will exist. Items assigned by category will no longer be caught by this category. If they are moved to another category from unassigned, they will get removed from this category.
* Handle use case when opening bag with something inside, so that preferably, if possible, the place where the item bag was a second ago, did not disapear and remain either empty, or replaced with an empty itembutton. That makes me actually wonderr -what happens if I move an item onto an empty item button? Will it assing a new category properly? I think it should as at this point in time that item button should not be yet recategorized... Anyway - here is a sample output of opening a container with items inside it:
```
    itemOnClick
    BAG_UPDATE 1
    FREE BAGS 93 10000
    FIRED
    UpdateItemLayout
    EnumerateValidItems override used
    called anchor again?
    Anchor 0 4
    money frame: table: 0000025B2C9B1330 table: 0000025B2C9B1330
    You receive item: [Blessing Blossom ]x3
    You receive item: [Ironclaw Ore ]x2
    BAG_UPDATE 5
    FREE BAGS 91 93
    BAG_UPDATE 5
    FREE BAGS 91 91
    BAG_UPDATE 5
    FREE BAGS 91 91
    BAG_UPDATE 5
    FREE BAGS 91 91
    FIRED
    UpdateItemLayout
    EnumerateValidItems override used
    called anchor again?
    Anchor 0 4
    money frame: table: 0000025B2C9B1330 table: 0000025B2C9B1330
```
* when opening bags sometimes not all info about items is available. Create a callback to readjust after data is loaded. Might cause a weird flicker so would need to verify how acceptable that is.
* create some nice default categories based on what I end up with as my query categories in TWW
* I have decided to not include button for authenticator that is available in normal bags. Consider adding it via adding to layout update self:LayoutAddSlots(); as well as support for this button. Although I have no idea how I could test it
* [REJECTED - in order to keep simplicity and default behaviour ] consider making the number of columns configurable

### unknown what they were about, meaning lost in the ether
* unassigned to junk was behaving weirdly

## Technical focused
* the checks in drag and drop using pickedItemButton could be replaced with  C_Cursor.GetCursorItem() .