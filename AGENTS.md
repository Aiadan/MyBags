# Repository Agent Instructions

- Do not create any tests that would be purly based on checking whether given method is called. Such tests bring zero value and cause it to be harder to modify code afterwards.
- Place automated tests under the `tests/` directory, mirroring the source tree of the files they cover (e.g., tests for `Categorizers/query.lua` belong in `tests/Categorizers/query_test.lua`).
- When perfoming any task make sure proper adjustments to documentation in markdown files are done, especially make sure if there is a ticket in TODOs.md that is being resolve, that it is properly prefixed with checkmark icon.

## Testing

- Run categorizer unit tests with `lua tests/Categorizers/query_test.lua`.
- Run category registration tests with `lua tests/categories_test.lua`.
- Run SavedVariable integration coverage with `lua tests/integration/persistence/savedvariable_test.lua`.

## Code readability

Make sure that simple things like `obj[key] = obj[key] or default` are not wrapped unnecessarly into function unless this clearly increases clarity.

## Storage and memory

- Make sure that whatever is stored in SavedVariable is necessary. Avoid storing empty values, strings, tables. This can cause big overhead while storing this data or even reading into memory - avoid this as long as it does not hinder the efficiency.
- Avoid storage of data duplication. Things like these are prohibited:
  - storing id mapped to value which again is mapped to id - such things can be read and created dynamically upon loading if needed and adds unnecessary overhead to storage and hence is prohibited:

    ```lua
    ["items"] = {
        [191229] = {
            ["itemid"] = 191229,
        },
    }
    ```

  - storing same information under different entity ie. for categories storing in which column it resides and separately having entity which stores information per column which categories are associated with it - that is prohibited:

    ```lua
    ["categories"] = {
        ["byId"] = {
        },
    },
    ["categoryState"] = {
        ["equipment-set:5"] = {
            ["column"] = 1,
        },
        ["equipment-set:1"] = {
            ["column"] = 2,
        },
        ["equipment-set:2"] = {
            ["column"] = 3,
        },
    },
    ["categoryLayout"] = {
        ["columns"] = {
            {
                "equipment-set:5",
            },
            {
                "equipment-set:1",
            },
            {
                "equipment-set:2",
            },
        },
    },
        ```

## Backward compatibility

- Make sure that whenever you change how things are stored, that users updating their addons will not loose their addon setup. That means there should always be a function which reads old format of data stored and translates it to a new one.
- Simple extensions of information stored usually does not require keeping backward compatibility.
- When making big changes to how and or what data is stored consider using a new SavedVariables variable so it is safe when needed to rollback to old data until a version is stable when a new code will be created to remove the old variable.

## Planning

Any plans, documentation, decisions or anything else you would like to create yourself please store in .md files inside .agents directory in this project.

You can modify TODO.md only when resolving one of the items listed there.

You can modify README.md only when explicitly asked or when esolving one of the items listed in TODO.md
