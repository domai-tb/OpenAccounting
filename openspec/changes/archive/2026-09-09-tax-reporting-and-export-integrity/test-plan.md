## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/tax-reporting-and-export-integrity/spec.md → UStVA classifies bookings and Kennzahlen correctly | An expense is not turnover | test/integration/audit/tax-reporting-and-export-integrity_test.dart | test_tax_reporting_and_export_integrity_1_1_an_expense_is_not_turnover | 🔴 red |
| specs/tax-reporting-and-export-integrity/spec.md → UStVA classifies bookings and Kennzahlen correctly | Zero-valued required keys are present | test/integration/audit/tax-reporting-and-export-integrity_test.dart | test_tax_reporting_and_export_integrity_1_2_zero_valued_required_keys_are_present | 🔴 red |
| specs/tax-reporting-and-export-integrity/spec.md → UStVA classifies bookings and Kennzahlen correctly | Reverse charge uses the declared base | test/integration/audit/tax-reporting-and-export-integrity_test.dart | test_tax_reporting_and_export_integrity_1_3_reverse_charge_uses_the_declared_base | 🔴 red |
| specs/tax-reporting-and-export-integrity/spec.md → EÜR applies booking direction and period policy | Income and expense directions are respected | test/integration/audit/tax-reporting-and-export-integrity_test.dart | test_tax_reporting_and_export_integrity_2_1_income_and_expense_directions_are_respected | 🔴 red |
| specs/tax-reporting-and-export-integrity/spec.md → EÜR applies booking direction and period policy | Disposal stops AfA | test/integration/audit/tax-reporting-and-export-integrity_test.dart | test_tax_reporting_and_export_integrity_2_2_disposal_stops_afa | 🔴 red |
| specs/tax-reporting-and-export-integrity/spec.md → EÜR applies booking direction and period policy | Default cutover is deterministic | test/integration/audit/tax-reporting-and-export-integrity_test.dart | test_tax_reporting_and_export_integrity_2_3_default_cutover_is_deterministic | 🔴 red |
| specs/tax-reporting-and-export-integrity/spec.md → Tax and GoBD exports are real validated artifacts | A successful export is reopenable | test/integration/audit/tax-reporting-and-export-integrity_test.dart | test_tax_reporting_and_export_integrity_3_1_a_successful_export_is_reopenable | 🔴 red |
| specs/tax-reporting-and-export-integrity/spec.md → Tax and GoBD exports are real validated artifacts | Export failure is truthful | test/integration/audit/tax-reporting-and-export-integrity_test.dart | test_tax_reporting_and_export_integrity_3_2_export_failure_is_truthful | 🔴 red |
| specs/tax-reporting-and-export-integrity/spec.md → Customer-scoped reports honor their customer filter | EKS excludes another customer's bookings | test/integration/audit/tax-reporting-and-export-integrity_test.dart | test_tax_reporting_and_export_integrity_4_1_eks_excludes_another_customer_s_bookings | 🔴 red |
| specs/tax-reporting-and-export-integrity/spec.md → Customer-scoped reports honor their customer filter | Missing customer scope is explicit | test/integration/audit/tax-reporting-and-export-integrity_test.dart | test_tax_reporting_and_export_integrity_4_2_missing_customer_scope_is_explicit | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
