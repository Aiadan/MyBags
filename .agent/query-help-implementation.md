# Query Help In-Game Documentation Decision

- Canonical source remains `QUERY_ATTRIBUTES.md`.
- Runtime in-game help content is loaded from generated Lua file: `generated/queryHelpDocs.lua`.
- Local regeneration command: `lua tools/generate_query_help.lua`.
- Release pipeline always regenerates and verifies generated docs are in sync before packaging.
- Categories UI adds a `Help` button next to `Save Priority` and opens a scrollable help frame.
