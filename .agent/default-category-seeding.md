# Default Category Seeding Decision

- Seed trigger: `next(userCategories.categories) == nil`.
- Seeding mechanism: reuse import pipeline with `AddonNS.CustomDefaultImportPayload`.
- Layout handling: import remains category-only; when seeding triggers, bootstrap resets layout columns to curated defaults and clears collapsed state.
- Preservation rule: if custom categories are non-empty, no default seeding and no layout overwrite.
