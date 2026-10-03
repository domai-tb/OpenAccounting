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
