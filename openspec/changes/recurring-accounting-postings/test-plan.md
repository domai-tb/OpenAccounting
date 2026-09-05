## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/recurring-accounting-postings/spec.md → Recurring invoices preserve position tax rates | Mixed-rate template generates correct totals | test/integration/audit/recurring-accounting-postings_test.dart | test_recurring_accounting_postings_1_1_mixed_rate_template_generates_correct_totals | 🔴 red |
| specs/recurring-accounting-postings/spec.md → Recurring invoices preserve position tax rates | Invalid template rate is handled | test/integration/audit/recurring-accounting-postings_test.dart | test_recurring_accounting_postings_1_2_invalid_template_rate_is_handled | 🔴 red |
| specs/recurring-accounting-postings/spec.md → Recurring bookings calculate input tax from tax semantics | Gross expense yields only its tax component | test/integration/audit/recurring-accounting-postings_test.dart | test_recurring_accounting_postings_2_1_gross_expense_yields_only_its_tax_component | 🔴 red |
| specs/recurring-accounting-postings/spec.md → Recurring bookings calculate input tax from tax semantics | Retry is idempotent | test/integration/audit/recurring-accounting-postings_test.dart | test_recurring_accounting_postings_2_2_retry_is_idempotent | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
