## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/receivables-ledger-integrity/spec.md → Statements account for every payment exactly once | Partial payment leaves the remainder | test/integration/audit/receivables-ledger-integrity_test.dart | test_receivables_ledger_integrity_1_1_partial_payment_leaves_the_remainder | 🔴 red |
| specs/receivables-ledger-integrity/spec.md → Statements account for every payment exactly once | Full and overpayment are represented | test/integration/audit/receivables-ledger-integrity_test.dart | test_receivables_ledger_integrity_1_2_full_and_overpayment_are_represented | 🔴 red |
| specs/receivables-ledger-integrity/spec.md → Statements account for every payment exactly once | Opening balance includes prior activity | test/integration/audit/receivables-ledger-integrity_test.dart | test_receivables_ledger_integrity_1_3_opening_balance_includes_prior_activity | 🔴 red |
| specs/receivables-ledger-integrity/spec.md → Receivables schema is ready after normal startup | Fresh startup supports receivables | test/integration/audit/receivables-ledger-integrity_test.dart | test_receivables_ledger_integrity_2_1_fresh_startup_supports_receivables | 🔴 red |
| specs/receivables-ledger-integrity/spec.md → Receivables schema is ready after normal startup | Legacy startup migrates safely | test/integration/audit/receivables-ledger-integrity_test.dart | test_receivables_ledger_integrity_2_2_legacy_startup_migrates_safely | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
