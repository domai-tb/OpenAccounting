## Test Plan

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/invoice-money-invariants/spec.md → Persisted totals are derived from validated positions | A valid discount round-trips | test/integration/audit/invoice-money-invariants_test.dart | test_invoice_money_invariants_1_1_a_valid_discount_round_trips | 🟢 green |
| specs/invoice-money-invariants/spec.md → Persisted totals are derived from validated positions | Inconsistent aggregate is rejected | test/integration/audit/invoice-money-invariants_test.dart | test_invoice_money_invariants_1_2_inconsistent_aggregate_is_rejected | 🟢 green |
| specs/invoice-money-invariants/spec.md → Invalid external money and discounts are rejected | Invalid discount is rejected | test/integration/audit/invoice-money-invariants_test.dart | test_invoice_money_invariants_2_1_invalid_discount_is_rejected | 🟢 green |
| specs/invoice-money-invariants/spec.md → Invalid external money and discounts are rejected | Negative caller amount is not normalized | test/integration/audit/invoice-money-invariants_test.dart | test_invoice_money_invariants_2_2_negative_caller_amount_is_not_normalized | 🟢 green |
| specs/invoice-money-invariants/spec.md → Generated corrections preserve validated signed money | A generated correction reverses the validated source | test/integration/audit/invoice-money-invariants_test.dart | test_invoice_money_invariants_3_1_generated_correction_reverses_source | 🟢 green |
| specs/invoice-money-invariants/spec.md → Generated corrections preserve validated signed money | An inconsistent source cannot create a correction | test/integration/audit/invoice-money-invariants_test.dart | test_invoice_money_invariants_3_2_inconsistent_source_blocks_correction | 🟢 green |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
