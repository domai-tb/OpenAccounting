## ADDED Requirements

### Requirement: Persisted totals are derived from validated positions

Preview, draft creation, direct persistence, finalization, conversion, Gutschrift, and Storno MUST use the calculator
defined in design.md. Unit price supports four decimals, quantity supports three, and persisted money uses integer cents
with positive half-up rounding. Each caller line aggregate MUST exactly equal the calculated discounted line cents.
Header net, VAT, and gross MUST equal the sum of calculated tax buckets with no tolerance.

#### Scenario: A valid discount round-trips

- **GIVEN** net lines of 100.00 at 19% VAT and 50.00 at 7% VAT with a valid 10% document discount
- **WHEN** preview, draft persistence, and reload run
- **THEN** each path reports net 135.00, VAT 20.25, and gross 155.25 from the same calculation

#### Scenario: Inconsistent aggregate is rejected

- **GIVEN** quantity 2, unit price 100.0000, and 10% line discount but a caller aggregate other than 180.00
- **WHEN** the use case or datasource attempts to save the invoice
- **THEN** an `aggregateMismatch` error identifies that line before insertion and no contradictory draft exists

### Requirement: Invalid external money and discounts are rejected

External preview/draft inputs MUST reject negative unit prices, quantities, line totals, document totals, and amount
discounts. Line and document percentage discounts MUST be within 0.00 through 100.00 inclusive. A document amount
discount MUST NOT exceed the post-line-discount net subtotal, and percentage and amount document discounts MUST NOT
both be non-zero. Failures MUST expose a stable domain error code and line metadata where applicable.

#### Scenario: Invalid discount is rejected

- **GIVEN** a line percentage below 0 or above 100, or a document amount discount greater than the net subtotal
- **WHEN** the user previews or saves
- **THEN** a typed validation error identifies the invalid field and line where applicable and no money is persisted

#### Scenario: Negative caller amount is not normalized

- **GIVEN** a caller supplies a negative unit price, quantity, aggregate, total, or amount discount
- **WHEN** preview, use-case, or direct datasource validation runs
- **THEN** a `negativeInput` error is returned rather than converting the value to positive

### Requirement: Generated corrections preserve validated signed money

Gutschrift and Storno generation MUST validate and calculate a non-negative source first, then apply a negative sign
exactly once to every persisted line and header net/VAT/gross amount. Correction VAT MUST retain the source tax-bucket
calculation and MUST NOT be replaced with zero.

#### Scenario: A generated correction reverses the validated source

- **GIVEN** a valid finalized source with net 100.00, VAT 19.00, and gross 119.00
- **WHEN** a Gutschrift or Storno is generated
- **THEN** the correction persists net -100.00, VAT -19.00, gross -119.00, and negative lines without accepting negative caller input

#### Scenario: An inconsistent source cannot create a correction

- **GIVEN** a stored source whose header differs from its calculated positions
- **WHEN** correction generation runs
- **THEN** generation fails before insertion and the source remains unchanged
