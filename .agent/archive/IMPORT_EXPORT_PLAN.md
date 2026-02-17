# Import/Export Custom Categories Plan (Implemented)

## Decisions

- Export/import uses plain Lua table literal text payloads (no leading `return`).
- Matching/upsert key is exact `externalId` string.
- Imported categories keep their imported `externalId` even after rename.
- Local categories use a persisted installation-scoped random prefix when auto-generating `externalId`.
- Import is strict all-or-nothing; any validation failure aborts the whole import.
- Import updates category rule + layout fields (`column`, `order`, `collapsed`) and does not overwrite manual item assignments.

## Implemented Surface

- `CustomCategories:GetExternalId(categoryOrId)`
- `CustomCategories:BuildExportPayload(categoryIds)`
- `CustomCategories:EncodeExportPayload(payload)`
- `CustomCategories:DecodeImportPayload(text)`
- `CustomCategories:PreviewImport(payloadOrText)`
- `CustomCategories:ApplyImportPreview(preview)`

## UI

- Categories GUI now exposes `Export` and `Import` buttons.
- Export view supports multi-select list and generated payload text.
- Import view supports text input, analysis preview (create/update counts), and explicit confirmation before apply.
