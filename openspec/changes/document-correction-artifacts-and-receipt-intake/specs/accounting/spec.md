## MODIFIED Requirements

### Requirement: GoBD Export

The system SHALL generate a GoBD audit export as a ZIP file for an explicitly selected period. Period membership SHALL use the owning accounting source's effective date: journal entries use their journal date, tax reports use their returned reporting period, and finalized business documents and corrections use their immutable document date. A correction SHALL be included in the period containing its own document date; its source document SHALL remain linked evidence even when the source predates the selected period. A record with no valid effective date or an unavailable required report source SHALL make the inventory incomplete and block a complete result; the exporter SHALL NOT guess a date or silently omit the record. The package SHALL include the period's journal ledger and applicable EÜR/UStVA reports produced through `accounting-reporting-workspaces`, finalized business-document artifacts, linked source evidence, and metadata sufficient to trace numbering, finalization state, source/correction/conversion relationships, and accounting chronology. Report generation and its data sources are a prerequisite; this change SHALL NOT independently recalculate reports. The export SHALL include a manifest with SHA-256 hashes for every included file and a human-readable inventory and verification result. ZIP verification SHALL be streaming and MUST NOT extract untrusted paths; it SHALL reject absolute paths, parent traversal, duplicate normalized paths, symlink entries, more than 20,000 entries, archives above 2 GiB, and total declared uncompressed content above 5 GiB. It SHALL count actual bytes emitted by each entry while streaming, stop before exceeding the content limit, and require the normalized archive file-entry set to exactly match the manifest. The application SHALL expose period selection, export, and verification through a localized accounting/report workflow and SHALL allow the user to save the generated package. This evidence package SHALL NOT be described as certified statutory compliance unless its legal criteria have been separately established.

#### Scenario: GoBD ZIP generation
- **GIVEN** a valid period is selected and all referenced artifacts are readable
- **WHEN** the user requests and saves the GoBD export
- **THEN** the ZIP contains the period ledger and applicable reports, finalized document PDFs, linked source evidence, traceable record metadata, a SHA-256 manifest, and a human-readable inventory marked complete

#### Scenario: GoBD integrity verification
- **GIVEN** a previously generated GoBD export has an intact manifest
- **WHEN** the user verifies it
- **THEN** the verifier recomputes each included file's SHA-256 digest and reports a valid result only if every digest matches

#### Scenario: GoBD export with missing documents
- **GIVEN** a selected period contains a finalized record or linked evidence whose artifact is missing or unreadable
- **WHEN** the export is generated
- **THEN** the inventory identifies each missing artifact and affected record, marks the package incomplete, and does not report verification as valid

#### Scenario: GoBD verification detects a changed file
- **GIVEN** a file in a previously generated export differs from its manifest digest
- **WHEN** the user verifies the export
- **THEN** verification reports the affected file and digest mismatch and returns an invalid result

#### Scenario: GoBD verification rejects unsafe or oversized ZIP content
- **GIVEN** a selected ZIP contains an absolute or parent-traversal path, a symlink, duplicate normalized path, too many entries, or exceeds a configured archive/content bound
- **WHEN** the user verifies the ZIP
- **THEN** verification stops without extracting any entry, reports the unsafe or oversized input, and returns an invalid result

#### Scenario: GoBD verification rejects manifest mismatch and streamed-size overflow
- **GIVEN** a selected ZIP contains an unmanifested entry, omits a manifest entry, or emits more than the allowed uncompressed bytes despite smaller declared sizes
- **WHEN** the user verifies the ZIP
- **THEN** verification reports the exact manifest or content-bound failure and returns invalid without extracting files
