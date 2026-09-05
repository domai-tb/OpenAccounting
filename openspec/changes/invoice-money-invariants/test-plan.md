## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/invoice-money-invariants/spec.md → Persisted totals are derived from validated positions | A valid discount round-trips | test/integration/audit/invoice-money-invariants_test.dart | test_invoice_money_invariants_1_1_a_valid_discount_round_trips | 🔴 red |
| specs/invoice-money-invariants/spec.md → Persisted totals are derived from validated positions | Inconsistent aggregate is rejected | test/integration/audit/invoice-money-invariants_test.dart | test_invoice_money_invariants_1_2_inconsistent_aggregate_is_rejected | 🔴 red |
| specs/invoice-money-invariants/spec.md → Invalid money and discounts are rejected | Invalid discount is rejected | test/integration/audit/invoice-money-invariants_test.dart | test_invoice_money_invariants_2_1_invalid_discount_is_rejected | 🔴 red |
| specs/invoice-money-invariants/spec.md → Invalid money and discounts are rejected | Negative amount is not normalized | test/integration/audit/invoice-money-invariants_test.dart | test_invoice_money_invariants_2_2_negative_amount_is_not_normalized | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
