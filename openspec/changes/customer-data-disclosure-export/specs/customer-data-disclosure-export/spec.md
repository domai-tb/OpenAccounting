## ADDED Requirements

### Requirement: Export one customer's explicitly linked data

The application SHALL provide a user-initiated disclosure export for exactly one persisted customer from the customer detail workspace. The export SHALL use one consistent active-profile snapshot and a versioned manifest. Its current relationship inventory SHALL include the selected `kunden` row; that customer's `kunden_lieferadressen`; `rechnungen` linked by `kunde_id` or by `lieferadresse_id` to one of those customer addresses; and connected correction/conversion invoices reached in either direction through `storno_von`, `gutschrift_von`, `ersatz_fuer`, `ersatzrechnung_id`, `konvertiert_von`, or `konvertiert_zu`. The exporter SHALL follow those invoice lineage links until no additional invoice is reached and SHALL verify that inverse `konvertiert_von`/`konvertiert_zu` pointers agree whenever both are populated. It SHALL require populated `kunde_id` and delivery-address references to resolve to the selected customer. A missing or conflicting lineage, customer, supplier, or address identity SHALL cause the affected record to be excluded, identified in the manifest, and make the archive incomplete. The inventory SHALL then include `rechnungspositionen` belonging to those invoices; `mahnungen` and `forderungen` linked by customer or those invoices; `forderung_zahlungen` for those receivables; journal rows reached through invoice `rechnung_id`, receivable `journal_id`/`ausgleich_journal_id`, or linked receivable-payment rows; `vorsteuer_ansprueche` whose `rechnung_id` references those invoices; `rechnungsvorlagen` whose `kunde_id` is the selected customer or which are verified through `rechnungen.vorlage_id`; invoices reached from those templates through `auftrag_id`; generated invoices and `rechnungsvorlagen_occurrences` for those templates; `kunden_belege` links for the customer; and `belege` rows reached by those links. `buchungsvorlagen_occurrences` MAY be included only as a projected occurrence when its `rechnung_id` or `journal_id` already resolves to an included invoice or journal row; its unrelated booking-template identifier SHALL be omitted. The exporter SHALL preserve verified relationship paths and SHALL NOT infer relationships by name, free-text note, or bank counterparty text. It SHALL NOT include unrelated parties' master records or present the result as a full-profile export.

Each record type SHALL use a versioned field allowlist. Unknown columns SHALL NOT be serialized. Cross-party references, including `rechnungen.lieferant_id`, `belege.lieferant_id`, `journal.vorlage_id`, and `vorsteuer_ansprueche.beleg_id`, SHALL be omitted. `journal.beleg_id` MAY be retained only when it resolves to evidence already linked to the selected customer. `forderungen.partner_typ`/`partner_id` SHALL be retained only when they resolve to the selected customer. Any omitted field containing a non-empty value whose scope cannot be proven outside this disclosure SHALL be listed in the manifest and make the result incomplete. A contradictory required relationship, unknown table, or non-empty unclassified field SHALL also make the result incomplete. The manifest SHALL identify the record projection version. This defines the supported export projection and SHALL NOT be described as legally sufficient disclosure.

#### Scenario: Export an unambiguous customer's linked records

- **GIVEN** the selected customer exists and its declared linked records are readable from one consistent snapshot
- **WHEN** the user starts a disclosure export from that customer's detail workspace
- **THEN** the archive SHALL include the customer and only the records reached through the declared relationship inventory
- **AND** the manifest SHALL identify its schema version, selected customer reference, included record counts, relationship paths, exclusions, and outcome
- **AND** source records SHALL remain unchanged

#### Scenario: No customer is selected or the ID is invalid

- **GIVEN** the requested customer ID is missing or does not resolve to exactly one record
- **WHEN** the disclosure export is requested
- **THEN** the action SHALL return a localized unavailable/not-found state
- **AND** no archive SHALL be published

#### Scenario: Unlinked data is not guessed

- **GIVEN** a bank transaction or journal row mentions the customer only in free text and has no declared customer relationship
- **WHEN** the export is generated
- **THEN** the row SHALL NOT be included based only on that text
- **AND** the archive SHALL NOT claim that free-text matches were searched or exported

#### Scenario: Unclassified fields prevent a complete outcome

- **GIVEN** a linked row contains a non-empty field outside the reviewed field allowlist and the field's scope cannot be proven to exclude unrelated parties
- **WHEN** the customer archive is projected
- **THEN** the field SHALL be omitted and identified in the manifest
- **AND** the archive SHALL be marked incomplete

### Requirement: Linked evidence has a truthful completeness state

For linked records that reference files, the exporter SHALL resolve only paths beneath the active profile's canonical data root and SHALL package readable files using relative archive paths and integrity hashes. Missing, unreadable, out-of-profile, mixed-party, or unsupported linked content SHALL be listed in the manifest and SHALL prevent a complete outcome until its inclusion or reviewed redaction behavior is approved. The exporter SHALL NOT automatically modify source evidence or claim that an incomplete package is legally sufficient.

#### Scenario: Linked evidence is profile-local and readable

- **GIVEN** a linked receipt or invoice artifact resolves to a readable path inside the active profile
- **WHEN** the package is created
- **THEN** the file SHALL be included with a relative path and integrity hash
- **AND** no absolute machine path SHALL be written to the archive

#### Scenario: Linked evidence is missing or has unresolved third-party content

- **GIVEN** a linked file is missing, unreadable, outside the active profile, or has unresolved mixed-party disclosure scope
- **WHEN** the package is generated
- **THEN** the manifest SHALL identify the excluded or unavailable reference
- **AND** the result SHALL be incomplete or failed, never complete

### Requirement: Customer disclosure export is separate from erasure and profile portability

The customer detail workspace SHALL describe this operation as a read-only, customer-scoped export and distinguish it from whole-profile portability, backup, and other export capabilities. The export SHALL NOT delete, anonymize, change retention, or mark a request as legally completed. If no approved policy defines third-party disclosure, retention, or erasure behavior, the UI SHALL state the unresolved boundary and SHALL expose no destructive action.

#### Scenario: User sees the export scope before saving

- **GIVEN** the customer disclosure action is available
- **WHEN** the user opens its confirmation
- **THEN** the UI SHALL describe that the export follows verified links for one customer and may report unsupported or excluded content
- **AND** SHALL distinguish the action from a whole-profile archive or database backup

#### Scenario: Export failure or cancellation

- **GIVEN** snapshot, destination, serialization, linked-file, or validation work fails or is cancelled
- **WHEN** the export stops
- **THEN** no incomplete final archive SHALL be reported as successful
- **AND** customer and related source records SHALL remain unchanged

### Requirement: Customer export follows the desktop design system

The export flow SHALL be keyboard accessible, provide visible focus and semantic labels, use localized scope, progress, empty, unavailable, error, and outcome states, and adapt to narrow windows and text scaling as specified in `DESIGN.md`. German and English translations SHALL be available, and dates SHALL use the active locale.

#### Scenario: Keyboard operation

- **GIVEN** the customer export action is focused
- **WHEN** the user activates it with the keyboard and confirms a destination
- **THEN** the same scoped export flow SHALL run as for pointer input
- **AND** completion, incompleteness, failure, or cancellation SHALL be announced as a localized semantic status
