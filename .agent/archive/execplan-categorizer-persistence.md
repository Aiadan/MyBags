# Per-Categorizer Persistence and Registration

This ExecPlan is a living document and must be maintained in accordance with .agent/PLANS.md. Update every section as work proceeds so another contributor can finish the task using only this file.

## Purpose / Big Picture

Shift category persistence to be owned by each categorizer. Each categorizer will load and store its own categories, register them with the central store (which will extend IDs and share layout/collapsed/order structures), and allow stale references to disappear over time. A unique categorizer ID will namespace category records; store-assigned IDs will still be used for layout and collapse, and stale IDs can remain harmlessly until reclaimed. Goal: disabling a categorizer removes its influence, and each categorizer controls its data lifecycle.

## Progress

- [x] (2025-12-11 00:00Z) Drafted ExecPlan.
- [ ] Design/store API changes to support per-categorizer registration and ID extension.
- [ ] Implement per-categorizer load/store flows and registration hooks; migrate existing custom and system categorizers.
- [ ] Update persistence layout/collapse/order handling for namespaced IDs; add migrations/tests; validate suite.

## Surprises & Discoveries

- None yet; record with evidence when encountered.

## Decision Log

- None yet; log decisions with rationale and timestamp.

## Outcomes & Retrospective

Pending; summarize when milestones complete.

## Context and Orientation

Current state: `categoryStore.lua` loads all categories from SavedVariables into `db.categories`, hydrates assignments, layout, collapsed state, and exposes Category objects. Categorizers (custom/user, equipment set, new items) rely on the store and do not manage persistence themselves. Layout/collapse/order all use store-assigned category IDs. Stale IDs are currently cleared when categories are removed.

Target model: each categorizer owns its data load/save. On load, a categorizer reads its storage (likely namespaced under its ID), registers each category with the store (store extends IDs and tracks layout/collapse/order), and can unregister on disable. Stale IDs in layout/collapse/order may persist; this is acceptable per requirement.

## Plan of Work

Describe new interfaces: add a categorizer registry API where each categorizer has a unique ID. The store should offer functions to request/extend category IDs and to register/deregister categories from a given categorizer. Persisted data should be stored per-categorizer (e.g., under `db.categorizers[<id>]`), while layout/collapse/order continue to live centrally but can reference store IDs that include categorizer prefixes. Introduce a reconciliation step where the store tolerates missing categories in layout/collapse/order (stale entries allowed).

Implementation steps:
1) Define categorizer IDs and registration contract in `categories.lua` or a new module. Update `CategoryStore` to allow registering categories with a source categorizer ID and to assign/extend unique IDs (e.g., `<categorizerId>:<localId>` or similar).
2) Adjust store schema to add `db.categorizers` keyed by categorizer ID, leaving layout/collapse/order as-is but referencing full store IDs. Allow stale IDs to remain without causing errors.
3) Update each categorizer (custom, equipment set, new items, showAlways/query helpers) to load its own data from `db.categorizers[itsId]`, create categories locally, and register them with the store at load time; ensure disabling a categorizer removes only its registrations.
4) Migrate existing data: read old `db.categories` and map records to the appropriate categorizer buckets. Provide fallback if an old record’s categorizer is unknown (assign to a default bucket) and maintain backward compatibility.
5) Update tests and add new ones covering per-categorizer persistence, registration, and stale layout/collapse entries. Extend integration to verify that disabling/removing a categorizer leaves stale layout IDs but no runtime breakage.

## Concrete Steps

1. Introduce categorizer ID constants and registration helpers in `categories.lua` (or new module) and extend `CategoryStore` with:
   - A method to register a category with a given categorizer ID and local ID/name/query/flags.
   - Namespaced ID generation (e.g., `cat-<categorizerId>-<seq>` or `<categorizerId>:<seq>`).
   - Storage for per-categorizer data under `db.categorizers`.
2. Add tolerant layout/collapse/order resolution: when layout references missing IDs, skip them but leave them persisted. Ensure unassigned/system categories remain available.
3. Update categorizers:
   - Custom: load from `db.categorizers.custom`, register categories, and persist its own assignments/queries/flags there.
   - EquipmentSet, New, ShowAlways: register their categories using their categorizer IDs and avoid writing into other buckets.
   - Query helper: ensure it reads/writes queries within the custom bucket.
4. Migration path:
   - On load, if `db.categories` exists, distribute records into the appropriate `db.categorizers` entries based on their `categorizer` field, then register them. Keep legacy fields readable for rollback until migration is stable.
5. Testing:
   - Add unit tests for per-categorizer registration and ID generation.
   - Integration: migration from old schema, tolerance of stale layout IDs, disabling a categorizer removing its categories while leaving harmless layout entries.
6. Run test suite:
   - `lua tests/categories_test.lua`
   - `lua tests/Categorizers/query_test.lua`
   - `lua tests/integration/persistence/savedvariable_test.lua`

## Validation and Acceptance

Acceptance when: each categorizer loads/saves its own data via `db.categorizers[<id>]`, registers categories through the store with namespaced IDs, and the store uses those IDs for layout/collapse/order while tolerating stale references. Migrated installs retain existing categories. Disabling a categorizer removes its runtime categories; other categorizers are unaffected. All tests above pass, and new tests cover per-categorizer persistence and stale layout tolerance.

## Idempotence and Recovery

Registration should be idempotent: re-running load should not duplicate categories. Migration should leave legacy data intact until confirmed. Stale layout/collapse entries should be safely ignored at runtime. Re-running tests should restore a clean state via the harness.

## Artifacts and Notes

Record test outputs, migration logs, or diffs here as work proceeds.

## Interfaces and Dependencies

Proposed APIs:

    AddonNS.CategoryStore:RegisterCategorizerCategory(categorizerId, payload) -> categoryObject
    AddonNS.CategoryStore:GetByCategorizer(categorizerId) -> {categoryObjects}
    AddonNS.CategoryStore:GenerateCategoryId(categorizerId) -> id

Payload should include local id/name/query/flags, assignments, and hooks. Layout/collapse/order should reference the generated store IDs. Adjust as implementation proceeds and document decisions in the Decision Log.
