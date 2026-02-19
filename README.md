# My Bags

*Disclaimer: I do this for fun. I do this mainly for myself :). There are other bag addons with great support, but just lacked the flexibility in the setup of the bags that I wanted. To be on a safe side you might consider using those as I cannot guarantee keeping this up to date. I am exposing it though so it was easier for my friends who wanted to use it to download it :)*

## What is this

This is yet another bag addon with a focus on manually creating groups and easy management of them to keep the bags organised.

**Both regular bags and bank are supported (including account/warband bank as a separate scope).**

## Features

Main features provided by the addon

### Easy category adjustments

Drag a category header onto another category to reorder it.  
Hold `Shift` while releasing the drag to move the dragged category together with all categories below it in that source column.

![Category adjustments](https://raw.githubusercontent.com/MyGamesDevelopmentAcc/MyBags/main/.previews/cat_move.gif)

### Easy item category change

Moving items between categories easily reassgins to a new category. Please note it is intentionally restricted to assign an item to a equipment set category.

![item category change](https://raw.githubusercontent.com/MyGamesDevelopmentAcc/MyBags/main/.previews/items_movement.gif)

### Easy category creation

![Category creation](https://raw.githubusercontent.com/MyGamesDevelopmentAcc/MyBags/main/.previews/cat_creation.gif)

### Built in always visible categories

![Category always visible](https://raw.githubusercontent.com/MyGamesDevelopmentAcc/MyBags/main/.previews/cat_always_visible.gif)

Other notable features:

* Keeps item order.
* Built-in always-available categories:
  * `Junk`
  * `Equipment Sets` (with set icons)
  * `New Items` (right-click the category header to clear it by moving those items back to their normal categories)
* New items go to `Unassigned` by default until you assign them.
* Dropping an item on `Unassigned` removes its manual custom-category assignment.
* Left-click a category header to collapse or expand it.
* Hold `Shift` while dropping a dragged category to move that category and all categories below it.
* Search filters visible bag items.
* Search combines Blizzard's default match with valid MyBags query-text match from the same input.
* Invalid query text in search is ignored instead of breaking results.
* Bank uses the same category-based organization flow as bags.
* Bank has separate layout scopes for character bank and account/warband bank.
* Bank view uses the same edit-mode affordances as bags (category header edit/delete and in-grid add/export/import controls).
* Custom categories support per-scope visibility (`Bags`, `Bank`, `Warbank`) via category config and edit-mode header toggles.
* Bank purchase-next-tab is exposed through a `+` button in the bottom strip (shown only when a new tab can be purchased).
* Bag and bank footer capacity now uses `taken / total` formatting with tooltip details.
* While editing a custom category query, the text is mirrored into bag search for live preview.
* Custom query categories support priority scores (higher priority wins first).
* Query syntax and attributes reference: [QUERY_ATTRIBUTES.md](QUERY_ATTRIBUTES.md)
* Query editor includes an in-game `Help` button with a scrollable syntax and priority reference.
* Item tooltip diagnostics are shown only while holding `Shift` (matched categories + reason tags).
* Custom categories support import and export using in-game text payloads.

## Q&A
List of questions about things regarding the addon or possible extentions.

### Show simple ilvl
Can be achieved using this addon:
* [Simple Item Levels](https://www.curseforge.com/wow/addons/simple-item-level)

## Design Decisions

Below are the key decisions made during the development of this addon:

#### Simplicity First

This addon is designed to be extremely simple and straightforward. It is not intended to be configurable. Instead, it follows a set of default behaviors that I believe will meet the needs of users who choose to use it.

#### Built on Existing Bags

The addon is designed to enhance the functionality of the default game bags rather than create an entirely new bag system. I’ve observed that many bag addons, when disabled, leave behind features added by the default bags that aren't available in those addons—whether intentionally or not. This addon aims to build on what’s already there, avoiding such issues.

#### Preserves Default Bag Item Slot Layout

The addon will display items exactly as they appear in the default bag slots. This approach ensures that any new features supported by the default game bags will be available without any additional work.

## TODOs, Ideas and other things considering for this addon

See "[TODOs, Ideas and other things considering for this addon](https://github.com/MyGamesDevelopmentAcc/MyBags/blob/main/TODOs.md)" to learn more.
