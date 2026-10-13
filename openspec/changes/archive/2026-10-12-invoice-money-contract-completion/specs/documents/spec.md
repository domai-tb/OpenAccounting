## MODIFIED Requirements

### Requirement: Rabatt — Position and Document Level

The system MUST support position-level percentage discounts and either a document-level percentage or fixed-amount discount; both document discount fields MUST NOT be non-zero together. Position discount SHALL be applied to the exact price-times-quantity result before its single cent rounding. A document percentage SHALL be applied once to the summed post-line-discount net subtotal. Fixed or percentage document discount cents SHALL first be allocated across VAT buckets proportionally by largest remainder, ties by ascending VAT rate, then within each bucket across persisted positions proportionally by largest remainder, ties by ascending persisted position. VAT SHALL be recalculated and rounded per discounted position, then summed. A document amount discount MUST NOT exceed the post-line-discount net subtotal. The PDF MUST show the discount and subtotal when a discount is active.

#### Scenario: Document fixed discount spans two VAT rates
- **GIVEN** net buckets of `0.01` at `7.00%` and `0.01` at `19.00%` have a fixed discount of `0.01`
- **WHEN** the document total is calculated
- **THEN** the cent is allocated to the `7.00%` bucket by the stable tie rule and bucket totals reconcile exactly

#### Scenario: Position Rabatt
- **GIVEN** a position has unit price `200.00`, quantity `2`, and a `10%` position discount
- **WHEN** its line total is calculated
- **THEN** the result is `360.00` after applying the discount before the single cent rounding

#### Scenario: Document-level fixed Rabatt
- **GIVEN** a document subtotal is `1000.00` and its fixed discount is `50.00`
- **WHEN** the document total is calculated
- **THEN** the pre-tax discounted subtotal is `950.00`

#### Scenario: Conflicting document-level Rabatt rejected
- **GIVEN** a document has a non-zero percentage discount
- **WHEN** a non-zero fixed discount is also set
- **THEN** validation rejects it with `conflictingDocumentDiscounts` before amounts are persisted

#### Scenario: Excessive or conflicting document discount is rejected
- **GIVEN** a document has net subtotal `100.00`
- **WHEN** its fixed discount exceeds `100.00` or both document discount fields are non-zero
- **THEN** validation rejects it with the corresponding stable error code before amounts are persisted

#### Scenario: Discounted invoice PDF shows subtotal and discount
- **GIVEN** a Rechnung has a net subtotal of `100.00` and an active document discount of `10.00`
- **WHEN** its PDF is generated
- **THEN** the PDF shows the subtotal `100.00` and discount `10.00`
