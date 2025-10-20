# Repository Agent Instructions

- Do not create any tests that would be purly based on checking whether given method is called. Such tests bring zero value and cause it to be harder to modify code afterwards.
- Place automated tests under the `tests/` directory, mirroring the source tree of the files they cover (e.g., tests for `Categorizers/query.lua` belong in `tests/Categorizers/query_test.lua`).
- When perfoming any task make sure proper adjustments to documentation in markdown files are done, especially make sure if there is a ticket in TODOs.md that is being resolve, that it is properly prefixed with checkmark icon.

## Backward compatibility

- Make sure that whenever you change how things are stored, that users updating their addons will not loose their addon setup. That means there should always be a function which reads old format of data stored and translates it to a new one.
- Simple extensions of information stored usually does not require keeping backward compatibility.
- When making big changes to how and or what data is stored consider using a new SavedVariables variable so it is safe when needed to rollback to old data until a version is stable when a new code will be created to remove the old variable.