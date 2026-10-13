## ADDED Requirements

### Requirement: Invoice decimal inputs retain their accepted scale

Invoice calculations SHALL parse finite caller values from their decimal representation and SHALL use exact integer fixed-point arithmetic. Unit prices range from `0.0000` through `99,999,999.9999`, quantities from `0.000` through `999,999,999.999`, percentages and tax rates from `0.00` through `100.00`, and currency amounts from `0.00` through `9,999,999,999.99`. Unit prices accept at most four fractional digits, quantities at most three, percentages and tax rates at most two, and currency amounts exactly cents. Caller-supplied money and quantities SHALL be non-negative. Every rounded line amount before and after line discount, per-rate subtotal/net/VAT/gross amount, document discount, and document subtotal/net/VAT/gross amount SHALL remain within the same 12-digit currency range. Exact products and intermediate calculations MUST use overflow-safe arithmetic; any supported rounded intermediate or derived amount outside that range SHALL fail with `valueOutOfRange` before persistence. The application SHALL validate these scales and ranges; SQLite `NUMERIC` affinity SHALL NOT be treated as a scale constraint. Accepted quantity and unit-price values SHALL survive persistence, reload, and supported document conversion and replacement unchanged.

#### Scenario: Four-place price and three-place quantity round-trip
- **GIVEN** a draft position has unit price `12.3456` and quantity `1.234`
- **WHEN** the draft is saved, reloaded, and converted to another supported draft type
- **THEN** each resulting position retains unit price `12.3456` and quantity `1.234`

#### Scenario: Converted drafts preserve discounted calculated headers
- **GIVEN** a saved Angebot has one `100.00` net line at `19.00%` VAT and a 10% document discount
- **WHEN** it is converted to an Auftrag and finalized
- **THEN** the converted document retains the discount and has net `90.00`, VAT `17.10`, and gross `107.10`

#### Scenario: Replacement drafts preserve discounted calculated headers
- **GIVEN** a finalized Rechnung has one `100.00` net line at `19.00%` VAT and a 10% document discount, then is storniert
- **WHEN** a replacement draft is created and finalized
- **THEN** it retains the discount and has net `90.00`, VAT `17.10`, and gross `107.10`

#### Scenario: Excess scale and negative caller values are rejected
- **GIVEN** an invoice position has a quantity with four fractional digits or a negative unit price
- **WHEN** preview or draft creation validates it
- **THEN** a typed validation error identifies the invalid field and no document, position, or number is persisted

#### Scenario: Values beyond the supported range are rejected
- **GIVEN** a caller supplies a unit price above `99,999,999.9999` or currency amount above `9,999,999,999.99`
- **WHEN** preview or draft creation validates it
- **THEN** it returns `valueOutOfRange` and persists no rounded substitute

#### Scenario: A derived amount beyond the currency range is rejected safely
- **GIVEN** a netto line has unit price `99,999,999.9999`, quantity `100.000`, asserted amount `9,999,999,999.99`, and VAT `100.00%`
- **WHEN** the calculator derives its VAT and gross amounts
- **THEN** it returns `valueOutOfRange` without integer overflow or persistence

### Requirement: Invoice line and tax arithmetic uses one cent boundary

For each line, the calculator SHALL multiply the accepted unit price and quantity, apply the line discount to the exact product before its single half-up rounding to cents at the entered-mode boundary, and reject a mismatching asserted line amount. In netto mode, each line's rounded net cents SHALL be its tax base. In brutto mode, each line's rounded gross cents SHALL be used to derive that line's net with half-up rounding; that line's VAT is gross minus net. Document discounts SHALL be calculated from the summed post-line-discount net subtotal. A percentage discount SHALL first round once to cents on that subtotal; a fixed discount SHALL already be in cents. Either amount SHALL first be allocated across tax-rate buckets in proportion to their net cents by largest remainder, with equal remainders assigned to the lower tax rate first, then within each bucket across persisted positions by largest remainder with lower persisted position as the tie-break. After a document discount, VAT SHALL be recalculated and rounded per position from each discounted line net and tax rate, then summed. Gross SHALL equal summed net plus summed per-position VAT.

#### Scenario: A half-cent line product rounds once before VAT
- **GIVEN** a netto line has unit price `0.3350`, quantity `3`, no line discount, and VAT `19.00%`
- **WHEN** the preview is calculated with asserted line amount `1.01`
- **THEN** line net is `1.01`, VAT is `0.19`, and gross is `1.20`

#### Scenario: VAT rounds per position before summing
- **GIVEN** three netto lines each have net `0.03` and VAT `19.00%`
- **WHEN** the preview is calculated
- **THEN** each line VAT is `0.01` and invoice net, VAT, and gross are `0.09`, `0.03`, and `0.12`

#### Scenario: Same-rate discount ties use persisted position order
- **GIVEN** netto position 1 has net `0.03` and position 2 has net `0.15`, both at `19.00%`, with a fixed document discount of `0.03`
- **WHEN** the preview is calculated
- **THEN** position 1 receives the tied remainder cent, and totals are net `0.15`, VAT `0.02`, and gross `0.17`

#### Scenario: Gross-mode tax bases round per position
- **GIVEN** two brutto lines each have gross `0.03` and VAT `19.00%`
- **WHEN** previews are calculated without a document discount and with a fixed document discount of `0.02`
- **THEN** the undiscounted totals are net `0.06`, VAT `0.00`, and gross `0.06`, and the discounted totals are net `0.04`, VAT `0.00`, and gross `0.04`

#### Scenario: Line discount is applied before the single cent rounding
- **GIVEN** a netto line has unit price `0.3350`, quantity `3`, a `50.00%` line discount, and VAT `19.00%`
- **WHEN** the preview is calculated with asserted line amount `0.50`
- **THEN** line net is `0.50`, VAT is `0.10`, and gross is `0.60`

#### Scenario: Mismatched asserted line amount is rejected
- **GIVEN** a netto line has unit price `0.3350`, quantity `3`, no discount, and asserted line amount `1.00`
- **WHEN** draft creation validates the line
- **THEN** it returns `aggregateMismatch` before inserting a document or position

#### Scenario: A mixed-rate percentage discount is allocated deterministically
- **GIVEN** net lines total `100.00` at `19.00%` and `50.00` at `7.00%`, with a document discount of `10.00%`
- **WHEN** the preview is calculated
- **THEN** discounted bucket net is `90.00` and `45.00`, VAT is `17.10` and `3.15`, and totals are net `135.00`, VAT `20.25`, gross `155.25`

#### Scenario: Percentage discount rounds once before mixed-rate allocation
- **GIVEN** net buckets of `0.05` at `7.00%` and `0.05` at `19.00%` have a `10.00%` document discount
- **WHEN** the preview is calculated
- **THEN** the total discount is `0.01`, allocated to the `7.00%` bucket by the tie rule, and discounted net totals `0.04` and `0.05`

#### Scenario: Discounted draft headers survive reload
- **GIVEN** a draft has a `100.00` net line at `19.00%` VAT and a `10.00%` document discount
- **WHEN** it is saved and reloaded through the repository
- **THEN** persisted headers remain net `90.00`, VAT `17.10`, and gross `107.10`

#### Scenario: A discount cannot exceed subtotal or combine with another discount
- **GIVEN** a document has a net subtotal of `100.00`
- **WHEN** the caller requests a fixed discount of `100.01` or sets both non-zero document discount fields
- **THEN** calculation returns the specified typed validation error and persists no amounts

### Requirement: Proportional cent allocation conserves cents

Proportional money allocation SHALL use non-negative integer-cent amounts and integer weights. Each initial allocation SHALL be the floor of `amount × weight / totalWeight`; remaining cents SHALL go by descending fractional remainder and then by the caller's stable ascending key. Allocations SHALL sum exactly to the requested amount and SHALL NOT exceed the corresponding weight. A zero total weight accepts only a zero allocation. Invoice discount and mixed-category EÜR settlement allocation SHALL use this rule.

#### Scenario: Equal remainders use the stable key
- **GIVEN** one cent is allocated across two equal non-zero weights with keys `a` and `b`
- **WHEN** the remaining cent is assigned
- **THEN** key `a` receives the cent, key `b` receives zero, and the allocations sum to one cent

#### Scenario: Largest remainder precedes the stable key
- **GIVEN** two cents are allocated across weights `a=2`, `b=3`, and `c=5`
- **WHEN** proportional allocation runs
- **THEN** the allocations are `a=0`, `b=1`, and `c=1`, and they sum to two cents

#### Scenario: Zero weights cannot receive a positive allocation
- **GIVEN** a positive cent amount is allocated across weights whose total is zero
- **WHEN** proportional allocation runs
- **THEN** it returns a typed validation error without producing an allocation

### Requirement: Invoice lifecycle paths share the calculator

Use-case and datasource entry points for draft and generic document creation, finalization, conversion, replacement, and correction SHALL apply the same validation and calculation contract. Generic draft creation SHALL reject unsupported document types, including `gutschrift` and `storno`; corrections SHALL be created only by their dedicated operations. Finalization SHALL recompute the saved draft and compare exact-cent net, VAT, and gross headers before number reservation, stock changes, journal/receivable writes, PDF creation, or status changes. A mismatch SHALL fail atomically. Supported conversions and replacement drafts SHALL preserve input mode, line scales, discounts, and calculated totals. A correction SHALL reject negative stored source quantity or unit-price values, and SHALL reject source line amounts whose persisted sign disagrees with the source document type or whose value disagrees with the calculator, before reserving a number or writing a target document.

#### Scenario: Generic correction creation is rejected before side effects
- **GIVEN** a caller requests a generic `storno` or `gutschrift` draft
- **WHEN** use-case or direct datasource creation validates the type
- **THEN** it returns `unsupportedDocumentType` and leaves document rows and number counters unchanged

#### Scenario: Unsupported generic draft types are rejected before side effects
- **GIVEN** a caller requests a generic draft with an unsupported document type
- **WHEN** direct datasource creation validates the type
- **THEN** it returns `unsupportedDocumentType` and leaves document rows and number counters unchanged

#### Scenario: Finalization rejects altered stored totals before posting
- **GIVEN** a valid draft whose saved header total was changed to disagree with its positions
- **WHEN** finalization runs
- **THEN** it returns `headerMismatch` and leaves number counters, stock, journal, receivables, PDF artifacts, and document status unchanged

#### Scenario: Finalization rejects stored headers with fractional cents
- **GIVEN** a valid draft whose saved header contains a non-zero sub-cent fraction
- **WHEN** finalization validates the header
- **THEN** it returns `headerMismatch` without rounding the stored value or performing side effects

#### Scenario: Storno rejects negative stored source quantity or unit price
- **GIVEN** a finalized invoice has a negative stored quantity or unit price
- **WHEN** Storno validates its source positions
- **THEN** it returns `negativeInput` with the offending field and leaves number counters and document rows unchanged

#### Scenario: Storno rejects a wrong-sign stored line total
- **GIVEN** a finalized invoice has a positive quantity and unit price but a negative stored line total
- **WHEN** Storno validates its source positions
- **THEN** it returns `negativeInput` with field `gesamt` and leaves number counters and document rows unchanged

### Requirement: Generated correction signs reverse the source

Caller input SHALL remain non-negative. A standalone Gutschrift and a Gutschrift created from a Rechnung SHALL persist line, net, VAT, and gross amounts with a negative sign. Storno SHALL be the exact arithmetic inverse of its eligible finalized source: an outgoing or incoming Rechnung produces negative amounts; a negative Gutschrift produces positive amounts. Storno SHALL accept only finalized invoice types supported by generic finalization or Gutschrift sources. Source discounts and tax buckets SHALL be included when the source is validated and reversed. A source/header mismatch SHALL reject the correction before any durable side effect.

#### Scenario: Invoice-derived and standalone Gutschrift amounts are negative
- **GIVEN** a finalized positive Rechnung or positive standalone Gutschrift input has net `100.00`, VAT `19.00`, gross `119.00`
- **WHEN** a Gutschrift is created from the Rechnung or standalone input
- **THEN** all Gutschrift lines and header amounts are `-100.00`, `-19.00`, and `-119.00`

#### Scenario: Gutschrift reverses the source's discounted totals
- **GIVEN** a finalized Rechnung has net `90.00`, VAT `17.10`, and gross `107.10` after a document discount
- **WHEN** a Gutschrift is created from it
- **THEN** the Gutschrift has net `-90.00`, VAT `-17.10`, and gross `-107.10`

#### Scenario: Incoming Storno reverses line, header, and input-tax amounts
- **GIVEN** a finalized incoming invoice has line and header net `100.00`, VAT `19.00`, gross `119.00`, and an input-tax claim
- **WHEN** it is storniert
- **THEN** the Storno line and header net, VAT, and gross are `-100.00`, `-19.00`, and `-119.00`, with an equal-and-opposite input-tax claim

#### Scenario: Storno of a Gutschrift exactly reverses its negative totals
- **GIVEN** a finalized Gutschrift has line and header net `-100.00`, VAT `-19.00`, and gross `-119.00`
- **WHEN** the Gutschrift is storniert
- **THEN** the Storno persists line and header net `100.00`, VAT `19.00`, and gross `119.00`

#### Scenario: Storno of a Rechnung reverses its positive balances
- **GIVEN** a finalized outgoing Rechnung has line and header net `100.00`, VAT `19.00`, and gross `119.00`
- **WHEN** it is storniert
- **THEN** the Storno line and header net, VAT, and gross are `-100.00`, `-19.00`, and `-119.00`

### Requirement: Invoice PDFs preserve signed snapshot amounts

The PDF generator SHALL render the signed net, tax, and gross amounts supplied in an invoice snapshot without changing their signs. Snapshot construction owns the calculation and sign selection.

#### Scenario: Gross-mode Storno snapshot preserves supplied signed amounts
- **GIVEN** a Storno snapshot from a finalized brutto invoice contains negative line and header net, VAT, and gross amounts
- **WHEN** the snapshot is rendered
- **THEN** the PDF position row preserves net `-100.00`, VAT `-19.00`, and gross `-119.00`

#### Scenario: A mismatched source or unsupported source type is not corrected
- **GIVEN** a finalized source has inconsistent stored header totals or has type `storno`
- **WHEN** a correction is requested
- **THEN** a typed validation error is returned before number counters or source state change

### Requirement: Invoice validation errors have a stable shape

Invoice validation SHALL throw `InvoiceMoneyValidationException`, retaining `ArgumentError` compatibility, with a closed code set: `invalidMode`, `invalidInput`, `negativeInput`, `invalidMoneyScale`, `invalidQuantityScale`, `invalidPercentage`, `invalidTaxRate`, `valueOutOfRange`, `invalidDescription`, `aggregateMismatch`, `conflictingDocumentDiscounts`, `excessiveDocumentDiscount`, `headerMismatch`, `unsupportedDocumentType`, and `unsupportedCorrectionSource`. Every error SHALL expose a stable `fields` list; line errors SHALL also expose zero-based `lineIndex` and the persisted position when available. Document-level errors SHALL not claim line metadata. Header mismatch errors SHALL identify every mismatching header field.

#### Scenario: Line validation reports code, field, and both line indexes
- **GIVEN** line index `1` has an invalid four-place quantity and persisted position `7`
- **WHEN** validation rejects the invoice
- **THEN** the exception code is `invalidQuantityScale`, fields contains `menge`, lineIndex is `1`, and position is `7`

#### Scenario: Document validation reports header fields without a line index
- **GIVEN** stored net and VAT headers disagree with the recalculated totals
- **WHEN** finalization rejects the draft
- **THEN** the exception code is `headerMismatch`, fields contains `netto_betrag` and `ust_betrag`, and lineIndex and position are null
