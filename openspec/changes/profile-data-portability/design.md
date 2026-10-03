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

1. **Create a logical archive, not a renamed backup.** Use a versioned structured data document or set of JSON files plus referenced evidence files and a manifest. A raw SQLite snapshot mechanism is useful for recovery but is not the user-readable structured export requested here. The archive does not replace separately specified exchange or audit formats.
2. **Fix and export the current persisted-record inventory.** The current production `AppDatabase.allTableNames` has 39 tables, while the maintained DB specification still says 38. This change updates the maintained table-definition contract to the 39 names already registered and created at runtime. The profile archive exports typed records from each table, preserving stable IDs and relationships, with explicit path-field transformations below. Inventory: company/configuration (`unternehmen`, `kategorien`, `konten`, `nummernkreise`, `ust_saetze`, `eu_laender`, `mahnwesen_einstellungen`, `eks_einstellungen`); contacts and catalog (`kunden`, `lieferanten`, `kunden_lieferadressen`, `artikel`, `artikel_gruppen`); invoices and evidence (`rechnungen`, `rechnungspositionen`, `belege`, `kunden_belege`, `dokumentenpakete`, `dokumentenpaket_belege`); accounting and tax records (`journal`, `forderungen`, `tagesabschluesse`, `anlageverzeichnis`, `vorsteuer_ansprueche`, `inventarbewegungen`, `ustva_exporte`, `euer_exporte`, `eks_exporte`, `datev_export_log`); banking (`bank_transaktionen`, `bank_templates`, `bank_imports`); and workflow templates/rules (`rechnungsvorlagen`, `buchungsvorlagen`, `mahnungen`, `mahnstufen`, `schnellbuchungen`, `auto_filter_regeln`, `import_mapping_vorlagen`). A release that adds a table must update the database registry and this versioned export inventory; if a runtime table is absent from the exporter inventory, export SHALL be incomplete. This inventory is profile-owner data and is not a customer-specific disclosure projection.
3. **Snapshot before packaging.** Obtain a WAL-safe profile snapshot through the existing backup/database lifecycle, then serialize from that immutable snapshot. This avoids exporting records from different points in time while writes continue. Release the snapshot on success, failure, or cancellation.
4. **Inventory referenced artifacts explicitly.** Current persisted file-reference fields are `unternehmen.logo_pfad`, `belege.dateipfad`, and `rechnungen.original_pdf_pfad`. Include each non-empty file when its canonical path resolves inside the active profile root, storing only relative archive paths and content hashes. Missing, unreadable, or out-of-profile files are listed and make the archive incomplete. `unternehmen.backup_extern_pfad` and `backup_extern_pfad_lokal_ok` are machine/backup configuration and excluded; `datev_export_log.datei_pfad` is an export destination path and its host path is excluded while the log record is retained. Document package rows are included as records and links; no package archive file path exists in the current table registry.
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

No database migration is needed. Add the typed export inventory and snapshot reader, versioned serializer, safe artifact copier, archive verifier, and Settings action. Keep export disabled if a table or referenced artifact class has not been included in the reviewed inventory. Rollback removes the action/service but leaves user-created archives and source data untouched. No erase or cleanup operation is part of export or rollback.

## Open Questions

- Which user-facing interchange formats beyond the versioned JSON archive are required (for example, per-table CSV)? Any additional format must preserve the documented relationship and value types or be clearly labeled as a lossy extract.
- Which supported profile fields are considered non-secret integration configuration, and should those be exported as disabled placeholders?
- Which export size limit and progress/cancel behavior fit the target desktop platforms?
- What approved data-class retention and erasure policy will govern a separate anonymization/deletion capability? This proposal does not select one or enable destructive operations.
- What separate, approved scope defines subject-specific customer/supplier disclosure and its linked records? This profile archive does not answer that question.
