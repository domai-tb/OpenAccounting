## ADDED Requirements

### Requirement: Persisted totals are derived from validated positions

Invoice creation and preview MUST use the same calculation for discounted line totals, net, VAT, and gross, and MUST reject a caller total that differs beyond the defined money precision.

Implementation evidence: The datasource trusts gesamt while preview recomputes discounted totals, and the use case skips validation for discounted lines.

#### Scenario: A valid discount round-trips

- Given a line has a valid percentage discount and tax rate
- When preview and persistence run
- Then both expose identical rounded net/VAT/gross values derived from the line

#### Scenario: Inconsistent aggregate is rejected

- Given the caller supplies a total that does not equal the discounted positions
- When the invoice is saved
- Then validation fails before insertion and no draft with contradictory totals exists

### Requirement: Invalid money and discounts are rejected

The invoice boundary MUST reject negative prices/totals, discounts below zero or above the allowed maximum, and discounts greater than the line subtotal; it MUST NOT silently normalize invalid inputs.

Implementation evidence: Current code uses abs on negative values and lacks complete discount bound validation.

#### Scenario: Invalid discount is rejected

- Given a line discount is negative, over 100 percent, or exceeds the subtotal
- When the user saves or previews
- Then a localized validation error identifies the line and no money is persisted

#### Scenario: Negative amount is not normalized

- Given a caller supplies a negative unit price or total
- When the command runs
- Then the command fails rather than converting the value to a positive amount
