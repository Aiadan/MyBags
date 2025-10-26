# Repository Agent Instructions

- Do not create any tests that would be purly based on checking whether given method is called. Such tests bring zero value and cause it to be harder to modify code afterwards.
- Place automated tests under the `tests/` directory, mirroring the source tree of the files they cover (e.g., tests for `Categorizers/query.lua` belong in `tests/Categorizers/query_test.lua`).
- When perfoming any task make sure proper adjustments to documentation in markdown files are done, especially make sure if there is a ticket in TODOs.md that is being resolve, that it is properly prefixed with checkmark icon.

## Code readability
Make sure that simple things like `obj[key] = obj[key] or default` are not wrapped unnecessarly into function unless this clearly increases clarity.

## Storage and memory

- Make sure that whatever is stored in SavedVariable is necessary. Avoid storing empty values, strings, tables. This can cause big overhead while storing this data or even reading into memory - avoid this as long as it does not hinder the efficiency. 

## Backward compatibility

- Make sure that whenever you change how things are stored, that users updating their addons will not loose their addon setup. That means there should always be a function which reads old format of data stored and translates it to a new one.
- Simple extensions of information stored usually does not require keeping backward compatibility.
- When making big changes to how and or what data is stored consider using a new SavedVariables variable so it is safe when needed to rollback to old data until a version is stable when a new code will be created to remove the old variable.

## Planning

Any plans, documentation, decisions or anything else you would like to create yourself please store in .md files inside .agents directory in this project.

You can modify TODO.md only when resolving one of the items listed there.

You can modify README.md only when explicitly asked or when esolving one of the items listed in TODO.md
