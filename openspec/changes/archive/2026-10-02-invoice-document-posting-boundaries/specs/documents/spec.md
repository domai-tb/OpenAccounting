## MODIFIED Requirements

### Requirement: Lagerführung — Stock auf Finalisierung

When an outgoing sales invoice (`typ = rechnung` without a supplier link) is finalized, the system MUST decrement stock by the combined ordered quantity for each inventory-enabled position. If negative stock is disallowed and an article's combined quantity would cause negative stock, finalization MUST be blocked. Incoming invoices and document-only records MUST NOT change stock or be blocked by sales-stock validation. Storno SHALL restore only quantities recorded as negative inventory movements for the source document.

#### Scenario: Multi-position stock update
- **GIVEN** an outgoing invoice has Position A (quantity 5, inventory enabled) and Position B (quantity 3, inventory enabled)
- **WHEN** the invoice is finalized
- **THEN** stock for Article A decreases by 5 and stock for Article B decreases by 3

#### Scenario: Stock change logged with reference
- **GIVEN** outgoing invoice #500 has Article Widget (quantity 10)
- **WHEN** the invoice is finalized
- **THEN** one negative stock movement references invoice #500 and records quantity 10

#### Scenario: Incoming invoice does not reduce sales stock
- **GIVEN** an incoming invoice has an inventory-enabled article line and the article has stock 20
- **WHEN** the incoming invoice is finalized
- **THEN** stock remains 20 and no negative invoice stock movement is recorded

#### Scenario: Document-only finalization ignores insufficient stock
- **GIVEN** an offer with an inventory-enabled article has quantity 5, stock 2, and negative stock is disallowed
- **WHEN** the offer is finalized
- **THEN** it is finalized with its offer number and stock remains 2

## ADDED Requirements

### Requirement: Generic finalization effects follow invoice type

Generic finalization SHALL create journal and partner receivable records only for supported outgoing and incoming invoice types. Incoming types are `rechnung_eingang`, `eingangsrechnung`, and `eingang`; matching SHALL use `RechnungTyp.canonicalize` so case and surrounding whitespace are normalized. A legacy `rechnung` linked to a supplier is also incoming. A supplier link on any other document type SHALL NOT make it an invoice. Incoming invoices SHALL use the `rechnung_eingang` number range and outgoing invoices SHALL use `rechnung_ausgang`. A missing, inactive, or malformed selected range SHALL fail without fallback. Generic finalization SHALL accept document-only types `angebot`, `auftrag`, `proforma`, and `lieferschein` with their own number ranges. Gutschrift and Storno SHALL use their dedicated operations and SHALL be rejected by generic finalization. Unsupported persisted types SHALL fail before numbering, PDF, stock, or accounting writes. Document-only finalization SHALL preserve number, snapshot, PDF, and transaction behavior while creating no generic financial or stock effects.

#### Scenario: Outgoing invoice gets sales accounting only
- **GIVEN** an outgoing invoice with a customer and output VAT is finalized
- **WHEN** generic finalization commits
- **THEN** one journal entry and one customer receivable are linked to the invoice
- **AND** no input-tax claim is created

#### Scenario: Outgoing late posting failure rolls back stock and artifact
- **GIVEN** an outgoing invoice has a customer, output VAT, an inventory-enabled article, and a profile directory
- **WHEN** finalization fails after its journal, receivable, stock movement, and PDF have been created
- **THEN** the invoice remains a draft, its outgoing counter is unchanged, and stock returns to its starting value
- **AND** no journal, receivable, tax claim, stock movement, or PDF from the failed attempt remains
- **AND** retry finalizes the invoice once with one negative stock movement and no input-tax claim

#### Scenario: Incoming aliases use purchase range and accounting
- **GIVEN** each of `rechnung_eingang`, `eingangsrechnung`, and `eingang` is linked to a supplier and has input VAT
- **WHEN** each invoice is finalized
- **THEN** each number comes from `rechnung_eingang`
- **AND** each has one expense journal entry, supplier payable, and input-tax claim
- **AND** each article's sales stock remains unchanged

#### Scenario: Incoming type matching is canonicalized
- **GIVEN** a draft's persisted type contains an incoming alias with mixed case and surrounding whitespace
- **WHEN** the draft is finalized
- **THEN** it uses the incoming number range and incoming invoice effects

#### Scenario: Incoming aliases use the generic invoice PDF with supplier counterparty
- **GIVEN** an incoming alias has both a customer and supplier link and a profile directory
- **WHEN** it is finalized with a supported incoming range
- **THEN** PDF generation uses the existing invoice layout, identifies the supplier as counterparty, and stores the artifact under that document row's unique path

#### Scenario: Supplier-linked legacy Rechnung is incoming
- **GIVEN** a legacy `rechnung` with a supplier and article line is finalized
- **WHEN** generic finalization commits
- **THEN** the incoming range and supplier payable are used
- **AND** no sales stock is deducted

#### Scenario: Incoming invoice with customer only has no customer receivable
- **GIVEN** an incoming invoice has a customer link, no supplier link, and input VAT
- **WHEN** generic finalization commits
- **THEN** one expense journal entry and one input-tax claim are linked to it
- **AND** no customer receivable is created
- **AND** sales stock remains unchanged

#### Scenario: Supplier-linked offer has no invoice effects
- **GIVEN** an offer with a supplier, VAT, and an inventory-enabled article has quantity 5, stock 2, and negative stock is disallowed
- **WHEN** the offer is finalized
- **THEN** it receives an offer number and finalized state without an error
- **AND** no journal entry, receivable, input-tax claim, stock change, or stock movement is created

#### Scenario: Unsupported raw types are rejected
- **GIVEN** drafts have raw types `rechnung_ausgang`, `gutschrift`, `storno`, or an unknown value
- **WHEN** generic finalization is attempted for each draft
- **THEN** each attempt fails before changing the draft, either counter, stock, postings, or PDF files

#### Scenario: Incoming number range failure does not use outgoing range
- **GIVEN** an incoming alias has a missing, inactive, or malformed incoming range while a valid outgoing range is active
- **WHEN** finalization is attempted
- **THEN** it fails and leaves both counters, document state, stock, postings, and PDF files unchanged

#### Scenario: Incoming posting failure rolls back its PDF and records
- **GIVEN** an incoming alias uses the incoming range and has supplier, VAT, and an article line
- **WHEN** finalization fails after its input-tax claim was inserted
- **THEN** the invoice remains a draft, the incoming counter is unchanged, and no journal, payable, tax, stock, or PDF artifact from the failed attempt remains
- **AND** retry finalizes it once using the same number

#### Scenario: Document-only failure after artifact creation rolls back
- **GIVEN** a draft offer has a profile directory and a supplier link
- **WHEN** finalization fails after its PDF is renamed and document row is updated
- **THEN** the offer remains a draft, its counter is unchanged, no file from the failed attempt remains, and no financial or stock rows are created
- **AND** retry finalizes the offer once

### Requirement: PDF storage is independent of document number

Each new generated document PDF SHALL be stored at a path unique to its persisted document row, independent of the display number or number range. Finalization SHALL refuse to overwrite a pre-existing target. Failure cleanup SHALL remove only the temporary file and a final file successfully created by that same attempt. Existing `original_pdf_pfad` values and files SHALL NOT be renamed or deleted as a side effect of this change.

#### Scenario: Same display number produces separate PDF artifacts
- **GIVEN** an outgoing invoice and an incoming invoice use separate ranges configured to produce the same display number
- **WHEN** both are finalized under one profile directory
- **THEN** they retain the same display number but have distinct `original_pdf_pfad` values and both PDF files remain present

#### Scenario: Pre-existing row-identity target is preserved
- **GIVEN** an incoming draft's row-identity PDF target is occupied by an existing file and an outgoing invoice with the same display number has a separate PDF
- **WHEN** incoming finalization is attempted
- **THEN** finalization fails without overwriting or deleting either file, and the incoming document and counter remain unchanged

### Requirement: Invoice-derived receivables use invoice classification

`ForderungenRepository.createForRechnung` SHALL create an invoice-derived receivable or payable only for the supported outgoing and incoming invoice types defined above. Supplier or customer links SHALL NOT make a finalized offer, order, delivery note, pro-forma document, correction, or unsupported type eligible.

#### Scenario: Finalized offer is rejected by invoice-derived receivable operation
- **GIVEN** a finalized offer has a supplier or customer link
- **WHEN** `createForRechnung` is called for that offer
- **THEN** the operation rejects the document type and creates no receivable

#### Scenario: Incoming alias creates supplier payable
- **GIVEN** a finalized incoming alias is linked to a supplier and has no existing receivable
- **WHEN** `createForRechnung` is called
- **THEN** it creates one `rechnung_eingang` payable for that supplier
