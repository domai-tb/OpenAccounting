## ADDED Requirements

### Requirement: Balanced, source-linked posting groups

Every posted financial event SHALL be stored as a source-linked posting group with at least two account-backed journal lines. Each line SHALL carry exactly one non-zero side in integer cents (debit > 0 XOR credit > 0, the other zero) from the accepted invoice-money contract. Proportional splits SHALL use non-negative integer-cent amounts and integer weights, floor each initial share, and assign remaining cents by descending fractional remainder and then by a stable ascending key; mixed-category settlement allocations SHALL use the source journal ID as that key. The sum of debit values SHALL equal the sum of credit values for the group, and all lines SHALL be created atomically. The group root SHALL store `(source_kind, source_id)` under a unique constraint (`invoice_event` for issue, `bank_transaction`/`cash_payment` for settlement); all lines SHALL share the root's group id. Repeating the same source event SHALL return the committed group and SHALL NOT create duplicate groups. A posted group SHALL be reversed by a new linked immutable group; posted lines SHALL NOT be edited or deleted. A reversal SHALL link any required input-tax-claim reversal and document-correction record under their maintained contracts instead of adjusting the original claim or document in place. In-scope invoice and settlement events SHALL route through this posting boundary and SHALL NOT use the legacy single gross row or the first-active-category/fallback-account-`1` path; recurring templates, setup opening balances, and other direct `JournalRepository.create` rows are explicitly out of scope and keep their maintained behavior. Pre-existing rows without balanced legs SHALL carry a durable `legacy_unverified` marker and SHALL be excluded from balanced-group assertions.

#### Scenario: Post a finalized invoice
- **GIVEN** an issued invoice has valid configured accounts and tax mapping
- **WHEN** its accounting event is posted
- **THEN** a source-linked journal group with at least two account-backed lines SHALL be committed
- **AND** total debit SHALL equal total credit
- **AND** the invoice SHALL reference that group

#### Scenario: Required posting mapping is missing
- **GIVEN** an invoice cannot resolve a required account or tax mapping
- **WHEN** finalization attempts to post its accounting event
- **THEN** the transaction SHALL roll back the invoice finalization and all journal lines
- **AND** the user SHALL receive a field/actionable mapping error

#### Scenario: Retry a source event
- **GIVEN** a source event already has a committed posting group
- **WHEN** the same event is submitted again
- **THEN** the original group SHALL be returned or recognized
- **AND** no additional journal lines SHALL be created
- **AND** no additional allocation or balance change SHALL occur

#### Scenario: Reverse a posted group
- **GIVEN** an immutable balanced posting group exists
- **WHEN** an authorized reversal is posted
- **THEN** a new immutable group SHALL link to the original and contain the exact opposite account balances
- **AND** the original group SHALL remain unchanged
- **AND** a duplicate reversal of the same group SHALL be rejected

#### Scenario: Reverse a settlement restores the open item
- **GIVEN** a settlement group has an applied allocation reducing a receivable
- **WHEN** its authorized reversal commits
- **THEN** the open-item balance SHALL be restored by the reversed amount in the same transaction
- **AND** the settled portion SHALL no longer be recognized in EÜR
- **AND** the reversal SHALL be recorded in the reversal period, not the original settlement period

#### Scenario: Reject invoice reversal with applied settlements
- **GIVEN** an invoice group has one or more applied settlement allocations
- **WHEN** an invoice-group reversal is requested before those settlements are reversed
- **THEN** the reversal SHALL be rejected with the blocking settlement identified
- **AND** no journal, allocation, or balance change SHALL occur

### Requirement: Payment and invoice posting linkage

Invoice issue events and payment events SHALL have distinct source identifiers and posting groups. A payment posting SHALL identify its bank/cash account, counterparty, applied receivable or payable, settlement date, and applied amount. One confirmed bank transaction SHALL map to exactly one settlement group holding one or more allocation rows; applied amounts plus the unapplied remainder SHALL reconcile to the signed bank amount. A positive bank row SHALL apply only to a customer receivable and a negative bank row only to a supplier payable. A confirmed customer overpayment SHALL close the receivable and retain the excess as a separately classified credit; a supplier overpayment SHALL retain the excess as supplier credit per the maintained receivables contract. Partial payment SHALL reduce only the applied open balance; any unapplied remainder SHALL remain separately identifiable.

#### Scenario: Post a partial receipt
- **GIVEN** a customer receivable has an open balance of 100.00
- **WHEN** a confirmed receipt of 40.00 is applied to it
- **THEN** one balanced payment group SHALL reference the receipt and receivable
- **AND** the receivable balance SHALL become 60.00
- **AND** the payment date SHALL be retained

#### Scenario: Do not post an unconfirmed bank row
- **GIVEN** an imported bank transaction has no confirmed invoice/payment application
- **WHEN** accounting postings are requested
- **THEN** no receipt settlement group SHALL be created
- **AND** the transaction SHALL remain available as unreconciled work

#### Scenario: Post a supplier payment
- **GIVEN** a supplier payable has an open balance of 200.00 and a negative bank row of 200.00 is confirmed against it
- **WHEN** the settlement is saved
- **THEN** one balanced payment group SHALL reference the bank row and payable
- **AND** the payable balance SHALL become 0.00 with status `bezahlt`

#### Scenario: Split one transaction across invoices
- **GIVEN** one confirmed bank receipt of 100.00 is applied 40.00 and 60.00 to two customer receivables
- **WHEN** the settlement is saved
- **THEN** exactly one settlement group SHALL hold two allocation rows for the two receivables
- **AND** applied plus unapplied amounts SHALL reconcile to 100.00

#### Scenario: Retain an overpayment as credit
- **GIVEN** a customer receivable has an open balance of 100.00 and a confirmed receipt of 120.00 is applied
- **WHEN** the settlement is saved
- **THEN** 100.00 SHALL close the receivable and 20.00 SHALL remain as a separately classified credit per the maintained receivables contract

#### Scenario: Repeated confirmation does not re-apply
- **GIVEN** a confirmed bank transaction already has a committed settlement group
- **WHEN** the same confirmation is submitted again
- **THEN** the original settlement group SHALL be returned
- **AND** no additional allocation or balance change SHALL occur

## MODIFIED Requirements

### Requirement: Journal Entries

New invoice-issue and settlement events SHALL NOT use the single gross `betrag` row path; they SHALL post only through the balanced, source-linked posting-group boundary defined above, with explicit debit/credit legs, `(source_kind, source_id)` uniqueness, and transaction-level balance validation. For these in-scope events the boundary overrides the legacy first-active-category/fallback-account-`1` behavior: unresolvable accounts or tax mappings SHALL fail before commit. The following existing writers are explicitly out of scope and keep their maintained single-row behavior until a separate contract routes them: recurring-template postings, setup opening-balance rows, and other direct `JournalRepository.create` rows. Pre-existing rows without balanced legs SHALL carry a durable `legacy_unverified` marker and remain readable history; they SHALL NOT be auto-balanced or relabeled as balanced.

#### Scenario: Booking creation

- GIVEN a valid category, art, and brutto_betrag
- WHEN a new journal entry is created
- THEN the system SHALL insert a row with auto-generated id, current date, description, category_id, brutto_betrag, art, and GoBD trigger protection (immutable=0 initially)

#### Scenario: GoBD immutability

- GIVEN a journal entry with immutable=1 (finalized)
- WHEN an UPDATE or DELETE operation is attempted on that row
- THEN the GoBD trigger SHALL prevent the operation and return an error

#### Scenario: Storno entry

- GIVEN a finalized journal entry to be reversed
- WHEN a Storno is created
- THEN the system SHALL create a new entry with negative betrag, reference to the original entry via id, and immutability flag

#### Scenario: Buchungsgruppen

- GIVEN a journal entry that is part of a booking group (original + storno + new)
- WHEN the entry is created
- THEN the system SHALL link original, storno, and new entries via gruppe_id (FK → journal.id)

#### Scenario: Missing required fields

- GIVEN a journal entry creation request with category_id = NULL or brutto_betrag = NULL
- WHEN the entry is submitted
- THEN the system SHALL reject creation with a validation error

#### Scenario: In-scope invoice does not use the single-row path
- **GIVEN** an invoice finalization event is in scope for balanced posting
- **WHEN** its accounting event is posted
- **THEN** no single gross `betrag` row SHALL be created for it
- **AND** its lines SHALL satisfy the balanced-group invariants above

#### Scenario: Out-of-scope writer keeps its maintained behavior
- **GIVEN** a recurring-template or setup opening-balance posting
- **WHEN** it is created
- **THEN** its maintained single-row behavior SHALL remain unchanged
- **AND** no invoice/settlement group SHALL be required for it by this change

### Requirement: EÜR (Einnahmen-Überschuss-Rechnung)

For ordinary cash-basis items, EÜR income and expense recognition SHALL use settlement allocations grouped by authoritative settlement date and `euer_zeile`, not invoice-issue journal dates. The eligible settlement source is a committed balanced settlement group with its allocation rows; unconfirmed bank rows, suggested matches, and legacy invoice-date gross rows SHALL NOT recognize income or expenses. Partial and mixed-category settlements SHALL allocate each settled portion across the invoice's persisted category/`euer_zeile`/tax proportions in integer cents. Direct cash receipts/expenses posted as settlement events SHALL be recognized on their settlement date; write-offs SHALL be excluded from operating receipts and follow the maintained write-off contract; customer-overpayment excess and supplier credits SHALL be classified per the maintained receivables contract; refunds and corrections SHALL be recognized only via their own settlement or correction records; reversals SHALL reclassify recognition in the reversal period. Rows carrying the `legacy_unverified` marker SHALL be excluded from settlement-based totals and SHALL fail closed when mixed with settlement data in an in-scope period. The separate Soll-principle input-tax claim timing SHALL remain independent of cash-basis settlement timing.

#### Scenario: EÜR Zeile 12 — Kleinunternehmer §19

- GIVEN journal entries exist for categories with euer_zeile=12 (Betriebseinnahmen without USt)
- WHEN the EÜR is generated
- THEN Zeile 12 SHALL show the sum of those entries' brutto_betrag

#### Scenario: EÜR Zeile 15 — Umsatzsteuerpflichtige Betriebseinnahmen

- GIVEN journal entries exist for categories with euer_zeile=15 (19% + 7% Betriebseinnahmen combined)
- WHEN the EÜR is generated
- THEN Zeile 15 SHALL show the sum of those entries' brutto_betrag

#### Scenario: EÜR Zeile 16 — Steuerfreie Betriebseinnahmen §4

- GIVEN journal entries exist for categories with euer_zeile=16 (steuerfreie innergemeinschaftliche Lieferungen)
- WHEN the EÜR is generated
- THEN Zeile 16 SHALL show the sum of those entries' brutto_betrag

#### Scenario: EÜR Zeile 33 — Abschreibungen (AfA)

- GIVEN Anlagenverzeichnis entries exist with AfA
- WHEN the EÜR is generated
- THEN Zeile 33 SHALL show the total AfA from the Anlagenverzeichnis, not from journal entries

#### Scenario: EÜR Zeile 60 — Sonstige Betriebsausgaben

- GIVEN journal entries exist for categories with euer_zeile=60 (e.g., Bauleistungen §13b, EU-DL §13b)
- WHEN the EÜR is generated
- THEN Zeile 60 SHALL show the sum of those entries' betrag

#### Scenario: EÜR Zeile 106/107 — Privatentnahme/Privateinlage

- GIVEN journal entries exist for Privatentnahme (euer_zeile=106) or Privateinlage (euer_zeile=107)
- WHEN the EÜR is generated
- THEN these SHALL appear as Hinweiszeilen (note lines) in the EÜR without affecting the Gewinn/Verlust computation

#### Scenario: Vorsteuerabzug Soll-Prinzip

- GIVEN a period ab CUTOVER_DATUM with vorsteuer_ansprueche entries
- WHEN the EÜR is generated
- THEN Vorsteuer SHALL be sourced from vorsteuer_ansprueche (Soll-Prinzip §15 UStG), not from journal.vorsteuer_betrag (Zahlungsprinzip)

#### Scenario: EÜR with no journal entries

- GIVEN a period with no journal entries
- WHEN the EÜR is generated
- THEN all Zeilen SHALL show 0,00 € and the Gewinn/Verlust SHALL be 0,00 €

#### Scenario: EÜR reads settlements, not invoice dates
- **GIVEN** a committed settlement allocation with a settlement date in April
- **WHEN** the April EÜR period is generated
- **THEN** the settled portion SHALL be included under its mapped `euer_zeile`
- **AND** the unpaid invoice-date amount SHALL remain excluded

#### Scenario: EÜR rejects mixed legacy and settlement data
- **GIVEN** an in-scope EÜR period contains both settlement allocations and `legacy_unverified` rows
- **WHEN** EÜR is generated
- **THEN** generation SHALL fail closed identifying the unverified rows
- **AND** no partial settlement-only total SHALL be presented as complete
