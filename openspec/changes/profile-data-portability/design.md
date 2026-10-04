## Context

The feature map describes profile data portability and privacy. The current `/settings` page has no export workflow; its active proposal permits only exports with an owning OpenSpec scope and explicitly leaves complete-profile export and permanent erasure unresolved (`settings-setup-workspace-completion/design.md:44,72`). `DatevService` contains a CSV formatter but has no production route or `AppServices` caller; `BackupService` creates SQLite snapshots for migration use, while its user-facing Settings workflow is still proposed. Report, GoBD, and document-package export are not assumed to be available runtime workflows. None of these code paths currently provides the typed portable profile archive defined here. The app stores business records in the active profile database and file references in profile records.

## Goals / Non-Goals

**Goals:**

- Export supported records and their relationships from one active profile as a versioned archive.
- Include referenced local evidence and generated artifacts with an integrity manifest and truthful missing-file status.
- Keep source data unchanged, isolate export to the active profile, and exclude credential secrets.
- Limit the operation to the profile owner's full profile; customer- or supplier-subject disclosure remains a separate privacy workflow.
- Make the scope and result visible from Settings → Daten & Datenschutz.

**Non-Goals:**

- Import an archive into another profile or claim compatibility with another accounting product.
- Replace backups, DATEV, GoBD, tax-report, or document-package workflows.
- Permanently erase or anonymize data, decide record-class retention durations, or make legal-compliance claims.
- Produce a customer- or supplier-specific data disclosure archive or decide which records are legally disclosable for an individual.
- Export operating-system configuration, secret-store contents, cache/temp files, or data from other profiles.

## Decisions

1. **Create a logical archive, not a renamed backup.** Use a ZIP containing UTF-8 `manifest.json`, UTF-8 JSON Lines files at `records/<table>.jsonl`, and referenced evidence under `evidence/`. Version the archive schema and record serialization independently, starting at version 1. A raw SQLite snapshot mechanism is useful for recovery but is not the user-readable structured export requested here. The archive does not replace separately specified exchange or audit formats.
2. **Use one versioned database/export inventory.** Use the exact shared 46-name health inventory in the modified db Table Definitions requirement: 39 pre-existing AppDatabase.allTableNames entries, one separate shared feature_table_state table, and six feature-owned tables. The six are forderung_zahlungen (migration v8), buchungsvorlagen_occurrences and rechnungsvorlagen_occurrences (lazy; v9 marker states), mileage_trips and mileage_trip_corrections (migration v9), and category_mapping_history (accounting-catalog-provenance migration v10). The existing 39 table names remain unchanged; the shared marker is not folded into that legacy count. At the current v8 baseline, v9 introduces the marker and mileage tables; v10 introduces category_mapping_history. If migration ordering changes, reassign the category migration to the next sequential version after v9 before implementation. Pre-v9 profiles may be valid for their own schema version without the marker or mileage tables, but cannot be reported as complete v10 exports. A payment table absent before v8 is created by the normal v7-to-v8 migration; at v8 or later it is an integrity failure detected before any repair can erase the missing-table signal. Keep the original profile unavailable until verified recovery and do not create an empty replacement. The v9 marker migration classifies present valid occurrence tables as initialized and absent tables as unknown; it never infers never_initialized from absence. Complete v10 export requires all migration-required tables and valid lazy-state pairs. The same inventory gates customer disclosure schema health; mileage and category history are health-inventory only for that scoped export because they have no accepted customer relationship.
3. **Snapshot before packaging.** Obtain a WAL-safe profile snapshot through the existing backup/database lifecycle, then serialize from that immutable snapshot. This avoids exporting records from different points in time while writes continue. Release the snapshot on success, failure, or cancellation.
4. **Inventory referenced artifacts explicitly.** Current persisted file-reference fields are `unternehmen.logo_pfad`, `belege.dateipfad`, and `rechnungen.original_pdf_pfad`. Resolve each target canonically and include it only if it remains inside the active profile root, using a relative archive path and content hash. Missing, unreadable, or out-of-profile references make the archive incomplete. The manifest reports exclusions only as stable record type, record ID, field name, and a fixed reason code; it never includes source paths, basenames, canonical paths, path fragments, or absolute operating-system paths. Retain non-path `datev_export_log` fields but omit `datei_pfad`; also omit `unternehmen.backup_extern_pfad` and `backup_extern_pfad_lokal_ok`. Document package rows remain records and links; no package archive file path exists in the declared table inventory.
5. **Exclude secrets and transient machine state.** Export non-secret integration settings only if they are typed profile business configuration and useful to restore context; never serialize password/token values, OS keychain data, absolute paths, or caches. The manifest can state that credentials were omitted without naming or revealing their values.
6. **Publish atomically to a user-selected destination.** Write to a sibling temporary file, validate archive structure and hashes, then rename to the final path. Use the established safe destination dialog, prevent accidental overwrite, and clean only temporary artifacts created by the failed attempt.
7. **Keep this operation read-only.** The export does not change statuses, retention dates, profile registry, or source files. Anonymization/deletion remains a separate future contract because its record-class eligibility and permitted effects are not yet specified.
8. **Reuse the Settings capability index.** Add the action under Daten & Datenschutz and identify it as the complete profile archive. If separately scoped report/backup actions are implemented and surfaced later, label their distinct scope there. Keep profile export available only when an active profile snapshot service is registered; otherwise show the truthful unavailable state.

## Risks / Trade-offs

- [Risk] A new feature-owned table or artifact type is omitted. → Mitigation: require a maintained export inventory tied to the database table registry and feature data sources; a missing supported type prevents a complete status.
- [Risk] An export is confused with a GoBD submission or restorable backup. → Mitigation: label purpose, content, archive version, and restore/import limitations in Settings and the manifest.
- [Risk] A profile contains very large evidence files. → Mitigation: stream copies from a stable snapshot, expose progress, and report insufficient storage as failure without publishing a partial final archive.
- [Risk] A source changes while the snapshot is being packaged. → Mitigation: serialize records from the stable database snapshot and copy artifact bytes into the temporary archive before validation.
- [Risk] Secret settings leak through an apparently typed configuration object. → Mitigation: use a positive allowlist of export fields and include a test fixture containing sentinel secret values.

## Migration Plan

Implement the shared migrations sequentially from the current v8 baseline: v9 adds and seeds `feature_table_state`, preserves uncertainty for absent lazy occurrence tables, and creates the mileage tables; v10 adds `category_mapping_history`. The payment-table pre-repair health check SHALL run before any migration or repair can hide a missing v8+ table. If migration ordering changes, reassign the category-history migration to the next sequential version after v9 before implementation. Then add the typed export inventory and snapshot reader, versioned serializer, safe artifact copier, archive verifier, and Settings action. Keep export disabled if a table or referenced artifact class has not been included in the reviewed inventory. Rollback removes the action/service but leaves user-created archives and source data untouched. No erase or cleanup operation is part of export or rollback.

## Open Questions

- Which user-facing interchange formats beyond the versioned JSON archive are required (for example, per-table CSV)? Any additional format must preserve the documented relationship and value types or be clearly labeled as a lossy extract.
- Which supported profile fields are considered non-secret integration configuration, and should those be exported as disabled placeholders?
- Which export size limit and progress/cancel behavior fit the target desktop platforms?
- What approved data-class retention and erasure policy will govern a separate anonymization/deletion capability? This proposal does not select one or enable destructive operations.
- What separate, approved scope defines subject-specific customer/supplier disclosure and its linked records? This profile archive does not answer that question.
