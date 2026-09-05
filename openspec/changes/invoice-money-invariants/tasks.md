## Implementation Tasks

## 1. Persisted totals are derived from validated positions — A valid discount round-trips

- [ ] 1.1 Write failing test test/integration/audit/invoice-money-invariants_test.dart → test_invoice_money_invariants_1_1_a_valid_discount_round_trips (assert it fails for the right reason)
- [ ] 1.2 Implement the behavior required by Persisted totals are derived from validated positions to pass 1.1
- [ ] 1.3 Refactor the implementation and fixtures; the full suite stays green

## 2. Persisted totals are derived from validated positions — Inconsistent aggregate is rejected

- [ ] 2.1 Write failing test test/integration/audit/invoice-money-invariants_test.dart → test_invoice_money_invariants_1_2_inconsistent_aggregate_is_rejected (assert it fails for the right reason)
- [ ] 2.2 Implement the behavior required by Persisted totals are derived from validated positions to pass 2.1
- [ ] 2.3 Refactor the implementation and fixtures; the full suite stays green

## 3. Invalid money and discounts are rejected — Invalid discount is rejected

- [ ] 3.1 Write failing test test/integration/audit/invoice-money-invariants_test.dart → test_invoice_money_invariants_2_1_invalid_discount_is_rejected (assert it fails for the right reason)
- [ ] 3.2 Implement the behavior required by Invalid money and discounts are rejected to pass 3.1
- [ ] 3.3 Refactor the implementation and fixtures; the full suite stays green

## 4. Invalid money and discounts are rejected — Negative amount is not normalized

- [ ] 4.1 Write failing test test/integration/audit/invoice-money-invariants_test.dart → test_invoice_money_invariants_2_2_negative_amount_is_not_normalized (assert it fails for the right reason)
- [ ] 4.2 Implement the behavior required by Invalid money and discounts are rejected to pass 4.1
- [ ] 4.3 Refactor the implementation and fixtures; the full suite stays green
