## ADDED Requirements

### Requirement: Customer disclosure uses declared relationship paths

The scoped exporter SHALL read one consistent profile-local snapshot and traverse only its maintained relationship inventory: `kunden_lieferadressen.kunde_id`; `rechnungen.kunde_id`/`lieferadresse_id`/`vorlage_id` and self-links `storno_von`, `gutschrift_von`, `ersatz_fuer`, `ersatzrechnung_id`, `konvertiert_von`, and `konvertiert_zu`; `rechnungspositionen.rechnung_id`; `mahnungen.kunde_id`/`rechnung_id`; `forderungen.kunde_id`/`rechnung_id`/`journal_id`/`ausgleich_journal_id`; `forderung_zahlungen.forderung_id`/`journal_id`; `rechnungsvorlagen.kunde_id`/`auftrag_id` (where `auftrag_id` references `rechnungen.id`); `rechnungsvorlagen_occurrences.vorlage_id`/`rechnung_id`; `journal.rechnung_id`; `vorsteuer_ansprueche.rechnung_id`; and `kunden_belege.kunde_id` to `belege.id`. `buchungsvorlagen_occurrences` rows MAY be projected only when their `rechnung_id` or `journal_id` reaches an already included invoice or journal row; their unrelated booking-template relationship SHALL NOT be traversed. Invoice-lineage, recurring-template source-invoice, and delivery-address traversal SHALL verify inverse conversion pointers when both are present and verify that any populated customer/address key resolves to the selected customer; conflict, missing relationship targets, or unresolved identity SHALL exclude the affected record and make the export incomplete. Any schema migration that adds a customer-linked table or relationship SHALL declare whether and how the disclosure inventory includes it before the exporter can report a complete result. This capability SHALL NOT infer links from text or amounts.

#### Scenario: New relationship is not in the reviewed inventory

- **GIVEN** a migrated profile contains a customer-linked table or foreign-key path absent from the disclosure inventory
- **WHEN** a scoped export is requested
- **THEN** the exporter SHALL report the unsupported relationship
- **AND** SHALL NOT mark the archive complete

#### Scenario: Snapshot cannot be acquired consistently

- **GIVEN** the profile database cannot provide one verified consistent snapshot
- **WHEN** a scoped export is requested
- **THEN** the export SHALL fail without publishing a final archive
- **AND** source records SHALL remain unchanged

### Requirement: Customer export completeness uses an accepted table inventory

The customer exporter SHALL validate the active profile's schema version and present table set against the accepted maintained `db` specification before it reports a complete archive. A change proposal or runtime count alone SHALL NOT establish the accepted inventory. Until the maintained contract reconciles its current 38-table requirement with the separately proposed inventory of 39 base and three feature-owned tables, the customer export SHALL remain incomplete. The exporter SHALL NOT create or repair tables. A required table missing at the accepted schema version, an absent lazily created table without an accepted durable marker proving the feature was never initialized, or an unknown customer-relevant table SHALL be reported and SHALL prevent a complete outcome.

#### Scenario: Profile table inventory has not been accepted

- **GIVEN** the maintained `db` specification does not yet reconcile the profile's known table inventory
- **WHEN** a customer disclosure export is requested
- **THEN** the export MAY include safely projected records but SHALL be marked incomplete
- **AND** it SHALL NOT create or repair missing tables

#### Scenario: Required or unknown customer table is missing or present

- **GIVEN** an accepted required table is absent, an unmarked lazy table is absent, or an unknown customer-relevant table is present
- **WHEN** the customer disclosure export checks the profile schema
- **THEN** it SHALL identify the table condition in the manifest
- **AND** it SHALL not report the archive as complete
