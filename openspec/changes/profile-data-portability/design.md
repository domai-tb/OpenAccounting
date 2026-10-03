## Context

The feature map describes profile data portability and privacy. The current `/settings` page has no export workflow; its active proposal permits only exports with an owning OpenSpec scope and explicitly leaves complete-profile export and permanent erasure unresolved (`settings-setup-workspace-completion/design.md:44,72`). Existing DATEV/report outputs, GoBD export, document packages, and database backups have different purposes and do not provide one typed portable profile archive. The app stores business records in the active profile database and document artifacts below the profile root.

## Goals / Non-Goals

**Goals:**

- Export supported records and their relationships from one active profile as a versioned archive.
- Include referenced local evidence and generated artifacts with an integrity manifest and truthful missing-file status.
- Keep source data unchanged, isolate export to the active profile, and exclude credential secrets.
- Make the scope and result visible from Settings → Daten & Datenschutz.

**Non-Goals:**

- Import an archive into another profile or claim compatibility with another accounting product.
- Replace backups, DATEV, GoBD, tax-report, or document-package workflows.
- Permanently erase or anonymize data, decide record-class retention durations, or make legal-compliance claims.
- Export operating-system configuration, secret-store contents, cache/temp files, or data from other profiles.

## Decisions

1. **Create a logical archive, not a renamed backup.** Use a versioned structured data document or set of JSON files plus referenced evidence files and a manifest. A raw SQLite backup is useful for recovery but is not the user-readable structured export requested here. DATEV and GoBD remain their own defined exchange/audit formats.
2. **Inventory exportable data by typed record owner.** Enumerate each profile-local business entity and its relationships, serialize through explicit typed projections, and preserve stable identifiers/references within the archive. Do not copy arbitrary `SELECT *` rows or include migration internals. The implementation must reconcile the list with `AppDatabase.allTableNames` and every feature-owned table before claiming completeness.
3. **Snapshot before packaging.** Obtain a WAL-safe profile snapshot through the existing backup/database lifecycle, then serialize from that immutable snapshot. This avoids exporting records from different points in time while writes continue. Release the snapshot on success, failure, or cancellation.
4. **Inventory referenced artifacts explicitly.** Resolve only allowlisted paths under the active profile's canonical data root. Store relative archive paths and content hashes; never package an absolute host path. A missing or unreadable reference is listed, and the archive is not reported complete.
5. **Exclude secrets and transient machine state.** Export non-secret integration settings only if they are typed profile business configuration and useful to restore context; never serialize password/token values, OS keychain data, absolute paths, or caches. The manifest can state that credentials were omitted without naming or revealing their values.
6. **Publish atomically to a user-selected destination.** Write to a sibling temporary file, validate archive structure and hashes, then rename to the final path. Use the established safe destination dialog, prevent accidental overwrite, and clean only temporary artifacts created by the failed attempt.
7. **Keep this operation read-only.** The export does not change statuses, retention dates, profile registry, or source files. Anonymization/deletion remains a separate future contract because its record-class eligibility and permitted effects are not yet specified.
8. **Reuse the Settings capability index.** Add the action under Daten & Datenschutz and label scope next to narrower report/backup exports. Keep it available only when an active profile snapshot service is registered; otherwise show the truthful unavailable state.

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
- Should application-owned PDF snapshots, uploaded receipts, document-package archives, and import mapping templates all be included, or should any be separately selectable? The default must not silently omit referenced accounting evidence.
- Which supported profile fields are considered non-secret integration configuration, and should those be exported as disabled placeholders?
- Which export size limit and progress/cancel behavior fit the target desktop platforms?
- What approved data-class retention and erasure policy will govern a separate anonymization/deletion capability? This proposal does not select one or enable destructive operations.
