## Context

The repository is a local-first Flutter desktop application with invoice lifecycle use cases, a profile-local database and artifact root, PDF rendering, and routed invoice artifact actions. The ordinary invoice finalization path now invokes the PDF generator, but the Storno, Gutschrift, replacement, and conversion paths do not consistently create real artifacts for results they mark finalized. Existing Belege/package tables are not backed by a production receipt import and review workflow, and the GoBD ZIP requirements are not exposed as a complete, verifiable export workflow.

The implementation should keep the established dependency direction: page → use case/service → repository → data source or platform adapter. UI obtains use cases through `AppServices`; it does not write database rows or files itself. The existing `invoice-authoring-and-lifecycle-workspace` proposal owns the invoice editor and entry points for correction/conversion actions. This design owns the integrity of those operations and the receipt, package, and audit-export surfaces.

The accepted calculation and persistence contract for invoice amounts remains a prerequisite. The archived `invoice-money-invariants` change ended in `VERDICT: REVISE`; this design must consume a separately accepted or superseding contract and must not infer arithmetic precision, rounding, allocation, or correction signs.

## Goals / Non-Goals

**Goals:**

- Make every finalized correction or conversion artifact a real, readable file committed with its document lifecycle state, links, numbering, and applicable effects.
- Preserve source-document context and traceable links when creating replacement and converted drafts.
- Provide an inbox for importing original supporting files, reviewing evidence and recognition suggestions, and previewing the source in context.
- Provide package listing, grouping, and ZIP snapshot export for accounting documents and supporting evidence without mutating the member records.
- Provide a period-scoped GoBD audit export with manifest hashing, integrity verification, and an inspectable completeness result.
- Meet the relevant `DESIGN.md` requirements for responsive desktop workflows, localization, keyboard use, focus, semantics, and reusable components.

**Non-Goals:**

- Define invoice calculations, accepted numeric scales, rounding, discount allocation, tax rules, or correction sign behavior.
- Implement or select OCR/e-invoice providers, define recognition confidence policy, or silently post recognized values.
- Decide statutory retention or deletion schedules, PDF/A conformance, or claim that a generated package is legally certified.
- Add invoice-editor or correction/conversion action entry points owned by the separate workspace proposal.
- Add batch-print or email-delivery providers; package batch print/email actions remain deferred and SHALL NOT be represented as available until those integrations are specified.

## Decisions

### Keep lifecycle operations behind the existing application boundary

Correction and conversion requests continue through `RechnungenUseCases` and the repository. The lifecycle owner resolves eligibility and the accepted money contract, builds a complete target snapshot, and delegates rendering to the PDF service. The renderer returns bytes and does not persist paths or mutate records. The data source owns numbering, persistence, links, and type-specific effects. A result created as a draft stays editable and does not store a path that claims a final PDF exists.

For any operation that produces a finalized result, the lifecycle transaction SHALL write bytes to a unique temporary file below the active profile root, verify that the file is readable, atomically rename it to its final path, and commit the row, path, source relationships, number allocation, and applicable effects only after the rename succeeds. SQLite and filesystem writes cannot be one atomic transaction, so user-visible success is defined by the committed document path resolving to a readable artifact. At startup, a reconciler scans only the application-owned generated-document directory: it removes owned staging files and uniquely named generated artifacts without a database reference, and marks referenced missing/unreadable artifacts unavailable for repair. It SHALL never delete unknown files. A crash before rename leaves the source at its pre-operation state plus removable staging output; a crash after rename and before database commit leaves the source unchanged plus removable unreferenced generated output. For a pre-existing draft, its draft state remains intact. After commit, the referenced artifact is present. Retries and concurrent requests follow the existing artifact transaction contract; this change does not invent a second writer or idempotency mechanism.

The target snapshot includes the target document type, persisted header and positions, required source links, and the company snapshot required by the maintained document contract. It uses the appropriate existing document renderer/template. The stored source and generated correction remain separate artifacts. Any arithmetic or sign input comes from the accepted domain contract; no widget or artifact service recomputes money.

### Treat imported source files as immutable evidence

The receipt import use case coordinates file validation, profile-scoped storage, metadata and digest creation, inbox persistence, and optional association. It SHALL not expose raw path construction to widgets. Accept PDF, PNG, JPEG, and XML used by XRechnung or ZUGFeRD/Factur-X, with a maximum of 50 MiB per file; inspect content signatures and parse XML with external entity and network access disabled. A successful import records the selected filename, media metadata available from the platform, stored size, upload time, and SHA-256 digest alongside the stored source. The original bytes remain unchanged when a user previews, reviews, or recognizes a receipt.

Write intake sources to a unique importer-owned temporary path, validate content and digest, atomically rename to a unique final source path, then commit the inbox row referencing that path. At startup, reconcile final source files with Beleg rows as well as temporary files: remove only uniquely named importer-owned files with no committed row, and mark a Beleg with a missing/unreadable source as unavailable for repair. Unrelated files are preserved. A crash before final rename leaves only removable temporary bytes; a crash after rename and before inbox commit leaves an unreferenced importer-owned source that recovery removes; after commit, the referenced source exists. Links to invoices, existing journal records, contacts, or packages use typed operations and validate that each target belongs to the active profile. Adding evidence does not create a posting or allocate a payment. Removing a package or contact membership never deletes the underlying evidence. Customer document deletion removes only the `kunden_belege` association; supplier/customer memberships are removed explicitly before underlying evidence can be deleted. Explicit deletion is permitted only after the Beleg is unlinked from invoices, journal records, templates, packages, customers, and suppliers; it removes metadata and source bytes. A configured `loeschdatum` is informational until a retention policy is accepted, so it never triggers automatic purging; existing due/overdue warnings remain visible.

Recognition is an injected capability that returns proposed fields and provenance separately from the source. The receipt workflow displays those suggestions for review and requires explicit acceptance before applying them to a draft assignment or posting flow. A recognition failure preserves the source and falls back to manual review. Provider choice, offline behavior, confidence thresholds, and data-processing policy remain open questions.

### Preview source evidence inside the record workflow

The receipt detail/inbox should keep the selected accounting record visible while the user previews its source. Use the existing viewer/platform abstraction where it supports the file type and return an explicit missing, unsupported, or unreadable state otherwise. Preview must not navigate away from the record or change its review status. Do not make a raw storage path the user's only recovery information.

At wide desktop widths, follow `DESIGN.md` §16's list, source preview, and extracted-fields/booking panes. At narrower widths, preserve the same context through a responsive inspector or sequential tabs instead of forcing three squeezed columns. Use window-width breakpoints from §34, not platform detection. Drag-over shows the clear drop target specified by §16.

### Represent package membership without copying member records

The package workspace preserves the existing data model: accounting documents retain their `dokumentenpaket_id` field and Belege use `dokumentenpaket_belege`. It lists packages, creates packages from selected members, and loads members through their owning repositories to present record type, identifier, status, and available artifact state. Membership changes are transactional and profile-scoped. Package export creates a ZIP snapshot and manifest using the same bounded writer and verifier as the GoBD export; missing members or artifacts are listed and prevent a complete result. The package is an organizational relationship only: it does not post accounting effects or mutate source records. Do not create a second generic membership table. Batch print and email are deferred; the package screen does not show fake send/print success or enable those unavailable actions.

### Build the audit export from a stable period snapshot

The GoBD export use case depends on `accounting-reporting-workspaces` for EÜR/UStVA outputs and captures an explicit period selection, journal and report data, finalized document artifacts, linked source evidence, and traceable metadata/relationships. It creates a ZIP from this snapshot, a manifest containing a SHA-256 digest for each included file, and a human-readable inventory. Before reporting success, it verifies that included files can be read and that manifest digests match. ZIP verification streams entries without extraction; it rejects absolute paths, parent traversal, duplicate normalized paths, symlinks, more than 20,000 entries, archives above 2 GiB, and total declared uncompressed content above 5 GiB. Missing or unreadable artifacts appear in the inventory and make the result explicitly incomplete; they are never silently omitted while claiming completeness.

Verification of a saved ZIP recomputes its manifest hashes and reports each missing or changed file. The report UI displays the selected period, included and missing record counts, generation/verification state, and save action. A successful technical integrity check is not represented as certification of legal compliance. Exact statutory scope, record date-selection semantics, PDF/A requirements, and retention rules require domain/legal decisions before implementation.

### Apply the existing design system and accessibility rules

Use `AppPage`, `AppPageHeader`, `AppDataTable`, `FilterBar`, `DetailInspector`, and existing tokenized cards, buttons, statuses, spacing, and money components where applicable. All new or touched copy, status labels, errors, empty/loading states, tooltips, and accessibility labels use generated localization resources; date, number, and money display use active-locale formatters. Layouts must support text expansion and scaling without clipping or horizontal overflow. Controls expose semantic labels, logical focus order, visible focus, keyboard operation, and non-color status cues as required by `DESIGN.md` §§23–24 and 33.

### Alternatives considered

- **Write files directly from page callbacks:** rejected because it bypasses the use-case boundary, makes DB/file rollback hard to verify, and exposes profile paths to presentation code.
- **Replace the original with a normalized or OCR-produced copy:** rejected because the imported source is the evidence users need to verify; extracted values must remain separate suggestions.
- **Claim filesystem and database atomicity:** rejected because the two stores cannot commit together; startup reconciliation removes owned orphans and reports broken committed references.
- **Create package copies or a second generic membership model:** rejected because copies can diverge, duplicate storage, and conflict with existing `dokumentenpaket_id` and `dokumentenpaket_belege` data. Preserve those links and snapshot only during export.
- **Advertise package batch print/email before a provider exists:** rejected because there is no package route or service in the current runtime and a false success state would mislead users. Defer these actions until the print and mail integrations are specified.
- **Drop missing evidence from audit exports:** rejected because a package would appear complete while hiding broken record links. Missing items must be reported in the inventory.
- **Choose OCR, PDF/A conformance, or statutory retention intervals now:** deferred because requirements do not establish the provider or legal policy. Until retention rules are accepted, `loeschdatum` never triggers automatic purge.

## Risks / Trade-offs

- [The unresolved invoice-money contract can invalidate correction snapshots] → Treat an accepted or superseding calculation/persistence contract as a hard implementation precondition; add no formulas or signs here.
- [A database transaction cannot by itself roll back a filesystem rename] → Use owned unique paths, commit the database reference only after rename, reconcile crash leftovers at startup, and surface broken committed references.
- [Files may be unavailable or corrupted after import] → Track source state, verify reads when previewing/exporting, and mark audit packages incomplete when evidence is missing.
- [OCR can suggest incorrect values] → Keep original bytes immutable and require explicit review before values enter an assignment or posting.
- [Schema migration could strand existing Belege or packages] → Use additive migrations, retain legacy path fields and records, and represent unreadable legacy files as reviewable missing-source states.
- [An integrity-checked ZIP may still not satisfy a tax authority's format requirements] → Describe it as an export/integrity result, not certification, until the applicable legal criteria are established.

## Migration Plan

1. Resolve the accepted invoice money contract and posting/reporting prerequisites, then settle OCR/recognition and PDF/A decisions that affect persisted behavior. Keep `loeschdatum` informational and automatic purge disabled until retention policy is accepted.
2. Add repository/data-source abstractions and additive migrations for source metadata, review/extraction state, and artifact/source reconciliation. Reuse the existing package links and preserve existing records and paths.
3. Implement source intake, review, preview, and package operations behind use cases. Add failing repository/use-case tests for byte preservation, association, failure cleanup, and package isolation before implementation.
4. Extend the lifecycle artifact writer to all finalized correction/conversion paths; test generated bytes, row/path atomicity, rollback, idempotent retry, and type-specific side effects.
5. Implement GoBD export generation, completeness reporting, and verification over a stable selected-period snapshot; test intact, missing, unreadable, and modified-file cases.
6. Wire the inbox and export through `AppServices`, routes, localization, and the responsive design system. Keep invoice detail action entry points in the separately proposed workspace change.
7. During rollout, leave existing file bytes untouched. Backfill metadata/digests only for readable legacy source files where policy permits; report missing legacy paths instead of fabricating artifacts. Rollback may disable new routes and services but shall not delete imported files or records.

## Open Questions

- Which accepted OpenSpec change resolves or supersedes the archived `invoice-money-invariants` blockers before correction artifact work begins?
- Which OCR/recognition engine is permitted? Must it run offline? What confidence/provenance and data-processing rules apply?
- Which invoice fields beyond the supported XRechnung and ZUGFeRD/Factur-X source should recognition suggest, and how is provenance shown?
- Is PDF/A required for any source or generated artifact, which conformance level applies, and how will conformance be mechanically verified?
- What statutory retention, deletion, legal hold, and user-erasure rules apply to receipts, source evidence, generated PDFs, and exports?
- Which document date or accounting date determines inclusion in an export period, and how are cross-period corrections represented?
- Which exact report formats and metadata are required by the external tax-audit workflow, and are any electronic archive signatures required?
- Is the ZIP saved only through the local file picker, or is an external destination/encryption provider in scope?
- What fields are required in the immutable source and company snapshots for legacy documents, and can existing records be backfilled without changing historical evidence?
