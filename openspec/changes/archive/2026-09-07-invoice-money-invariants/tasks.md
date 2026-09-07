## Implementation Tasks

## 1. Persisted totals are derived from validated positions — A valid discount round-trips

- [x] 1.1 Write failing test test/integration/audit/invoice-money-invariants_test.dart → test_invoice_money_invariants_1_1_a_valid_discount_round_trips (assert it fails for the right reason)
- [x] 1.2 Implement the behavior required by Persisted totals are derived from validated positions to pass 1.1
- [x] 1.3 Refactor the implementation and fixtures; the full suite stays green

## 2. Persisted totals are derived from validated positions — Inconsistent aggregate is rejected

- [x] 2.1 Write failing test test/integration/audit/invoice-money-invariants_test.dart → test_invoice_money_invariants_1_2_inconsistent_aggregate_is_rejected (assert it fails for the right reason)
- [x] 2.2 Implement the behavior required by Persisted totals are derived from validated positions to pass 2.1
- [x] 2.3 Refactor the implementation and fixtures; the full suite stays green

## 3. Invalid external money and discounts are rejected — Invalid discount is rejected

- [x] 3.1 Write failing test test/integration/audit/invoice-money-invariants_test.dart → test_invoice_money_invariants_2_1_invalid_discount_is_rejected (assert it fails for the right reason)
- [x] 3.2 Implement the behavior required by Invalid external money and discounts are rejected to pass 3.1
- [x] 3.3 Refactor the implementation and fixtures; the full suite stays green

## 4. Invalid external money and discounts are rejected — Negative caller amount is not normalized

- [x] 4.1 Write failing test test/integration/audit/invoice-money-invariants_test.dart → test_invoice_money_invariants_2_2_negative_caller_amount_is_not_normalized (assert it fails for the right reason)
- [x] 4.2 Implement the behavior required by Invalid external money and discounts are rejected to pass 4.1
- [x] 4.3 Refactor the implementation and fixtures; the full suite stays green

## 5. Generated corrections preserve validated signed money — A generated correction reverses the validated source

- [x] 5.1 Write failing test test/integration/audit/invoice-money-invariants_test.dart → test_invoice_money_invariants_3_1_generated_correction_reverses_source (assert it fails for the right reason)
- [x] 5.2 Implement the behavior required by Generated corrections preserve validated signed money to pass 5.1
- [x] 5.3 Refactor the implementation and fixtures; the full suite stays green

## 6. Generated corrections preserve validated signed money — An inconsistent source cannot create a correction

- [x] 6.1 Write failing test test/integration/audit/invoice-money-invariants_test.dart → test_invoice_money_invariants_3_2_inconsistent_source_blocks_correction (assert it fails for the right reason)
- [x] 6.2 Implement the behavior required by Generated corrections preserve validated signed money to pass 6.1
- [x] 6.3 Refactor the implementation and fixtures; the full suite stays green
