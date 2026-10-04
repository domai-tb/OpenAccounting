## Context

`SeedData._seedKategorien` writes IDs 1–85, generated `8001..8085` / `4001..4085` account strings, and formulaic EÜR lines on every database open. `kategorien` has no catalog source or trust metadata. EÜR groups journal rows by `euer_zeile`; DATEV reads category account values. The maintained `db` spec calls the seed a standard 80-category chart, the accounting spec calls it 65+ predefined categories, and docs describe both as preconfigured mappings. The archived `seed-master-data-contract` review approved the intended behavior, but its acceptance record does not match the current production seed.

The category table currently stores editable values directly, and existing profile rows have no reliable provenance. A row cannot be considered unedited merely because its current values resemble the old generator.

## Goals / Non-Goals

**Goals:**

- Never create or report synthetic SKR/EÜR/EKS mappings as a standard catalog.
- Preserve existing rows and user changes while making their mapping trust status explicit.
- Let new catalog values be traced to an approved source release and distinguish later user-confirmed values.
- Keep EÜR and DATEV from silently treating unresolved category values as authoritative. GuV remains outside this change until its report owner accepts an output-provenance contract.

**Non-Goals:**

- Selecting, reproducing, or licensing a specific SKR chart or tax-line catalog.
- Reworking bank-template seeds, journal posting semantics, or report calculations beyond mapping validation and provenance.
- Claiming legal or tax correctness from a syntactic mapping check.

## Decisions

### Catalog source is a release gate

The repository has no reviewed catalog manifest. Until product/accounting owners approve an exact source, edition, redistribution right, and mapping review, a fresh profile receives no preconfigured accounting mappings and is shown an explicit unconfigured state. The seed must not derive account numbers or tax lines from IDs, ranges, labels, or arithmetic. A manifest is eligible only when it contains stable entry keys, source reference and version, and review status for its bundled SKR03, SKR04, EÜR, and EKS fields.

Rejected: copy mappings from examples or infer them from an official-looking number. Neither proves that the data is correct, current, or redistributable.

### Keep provenance separate from mutable category values

Persist a mapping status (`catalog_verified`, `user_confirmed`, `legacy_unverified`, `review_required`, or `unmapped`) plus the catalog entry/source release when one exists. Catalog-derived values begin `catalog_verified`. Editing any mapping field moves the whole mapping to `review_required`; it becomes `user_confirmed` only after the user reviews all populated mapping fields. The original catalog release remains visible as the baseline, while the current status makes clear that edited values are no longer catalog-verified. An unmapped category may label a balanced posting only when that posting supplies account and tax data independently; it cannot participate in an operation that requires category mapping values. Legacy or edited mapping values likewise block only operations that consume those values; they are never silently treated as verified.

Rejected: a single `system_seeded` boolean or matching a category name/number pattern. Neither distinguishes an edited mapping from a verified one.

### Migrate conservatively and add catalog values without overwriting

Use the existing backup-before-migration and transactional migration path. Classify all preexisting categories as `legacy_unverified`; do not attempt to infer user edits by matching the old generator. Preserve every existing category field, ID, active flag, and journal reference. Existing rows remain readable; they require explicit review before new postings or mapping-dependent outputs use them. New approved catalog entries use stable catalog keys. Reopening or upgrading never overwrites a user-configured or unverified row; matching an existing profile row to a catalog entry requires an explicit user action in the category workspace.

Rejected: rewrite rows whose values happen to equal the synthetic formula. A user may have edited another field or may intentionally depend on the existing row ID.

### Make EÜR and DATEV disclose or reject unresolved category mappings

EÜR and DATEV may use `catalog_verified` category mappings. They may use `user_confirmed` mappings only while clearly identifying them as user-configured and not source-verified in the preview and persisted export metadata. Each persisted output snapshot records the exact resolved mapping values and immutable history-row IDs used. DATEV resolves the `Konto` and `Gegenkonto` slots independently from their corresponding posting legs; each snapshot records the slot, exact number, source, and category/history reference when applicable. A configured company account is eligible only when the posting leg explicitly selects it. Generation fails with affected journal/category IDs if either required slot has no eligible source. No implicit `1200`/`8400` or other default account is produced. GuV is not changed by this proposal because its report owner has not accepted a provenance contract.

Rejected: silently omit unresolved rows or substitute a generic account, because either can make an incomplete result look complete.

### Keep category activation separate from mapping trust

Deactivation hides a category from new-entry selectors but does not change its provenance status. An otherwise eligible deactivated category may be used by an already configured recurring booking only when the accepted posting contract permits it and the occurrence displays the inactive-category warning. Category status blocks a posting only when the posting needs mapping values from that category; an inactive warning never counts as a mapping review.

## Risks / Trade-offs

- **[Risk]** New profiles have no convenient default chart until a source is approved. → **Mitigation:** show an explicit setup state and allow user-defined categories with clearly marked mappings.
- **[Risk]** Existing profiles must review old categories before mapped output. → **Mitigation:** preserve history and list affected categories with a direct review action; do not rewrite persisted rows.
- **[Risk]** A source can be licensed but mappings can still be wrong for a supported tax case. → **Mitigation:** require accounting review and record source version and review scope; validation does not claim legal correctness.

## Migration Plan

1. Obtain approval for the exact catalog source/edition, redistribution rights, and accounting mapping scope before bundling any mapped values.
2. Add provenance fields through the versioned migration, transactionally mark existing category rows `legacy_unverified`, and verify that all existing values, IDs, active flags, and references are unchanged.
3. Remove the formulaic seed. Seed only entries from the approved manifest; otherwise leave the profile unconfigured. Make repeated seed and migration runs idempotent.
4. Add explicit mapping review to the category workspace, preserve original source release when mappings are edited, and require review after any mapping-field change.
5. Validate EÜR/DATEV inputs against mapping status; include user-configured provenance and reject unresolved categories without fallback accounts.
6. Update docs and maintained specs to describe the unconfigured and provenance states. Rollback restores the pre-migration backup; do not drop provenance fields or revert category values in-place.

## Open Questions

- Which exact SKR edition/source may be bundled, under what redistribution terms, and who signs off the EÜR/EKS relationships? No catalog values can be shipped until this is answered.
- Category review is owned by the `/settings/categories` workspace in `master-data-workspaces-and-crud`. This change is gated on that workspace's route and review action being accepted and available. Until then, category provenance is read-only, legacy/unreviewed mappings remain blocked from new postings and mapping-dependent outputs, and no hidden setter may mark them trusted.
