## Implementation Tasks

## 1. UStVA classifies bookings and Kennzahlen correctly — An expense is not turnover

- [ ] 1.1 Write failing test test/integration/audit/tax-reporting-and-export-integrity_test.dart → test_tax_reporting_and_export_integrity_1_1_an_expense_is_not_turnover (assert it fails for the right reason)
- [ ] 1.2 Implement the behavior required by UStVA classifies bookings and Kennzahlen correctly to pass 1.1
- [ ] 1.3 Refactor the implementation and fixtures; the full suite stays green

## 2. UStVA classifies bookings and Kennzahlen correctly — Zero-valued required keys are present

- [ ] 2.1 Write failing test test/integration/audit/tax-reporting-and-export-integrity_test.dart → test_tax_reporting_and_export_integrity_1_2_zero_valued_required_keys_are_present (assert it fails for the right reason)
- [ ] 2.2 Implement the behavior required by UStVA classifies bookings and Kennzahlen correctly to pass 2.1
- [ ] 2.3 Refactor the implementation and fixtures; the full suite stays green

## 3. UStVA classifies bookings and Kennzahlen correctly — Reverse charge uses the declared base

- [ ] 3.1 Write failing test test/integration/audit/tax-reporting-and-export-integrity_test.dart → test_tax_reporting_and_export_integrity_1_3_reverse_charge_uses_the_declared_base (assert it fails for the right reason)
- [ ] 3.2 Implement the behavior required by UStVA classifies bookings and Kennzahlen correctly to pass 3.1
- [ ] 3.3 Refactor the implementation and fixtures; the full suite stays green

## 4. EÜR applies booking direction and period policy — Income and expense directions are respected

- [ ] 4.1 Write failing test test/integration/audit/tax-reporting-and-export-integrity_test.dart → test_tax_reporting_and_export_integrity_2_1_income_and_expense_directions_are_respected (assert it fails for the right reason)
- [ ] 4.2 Implement the behavior required by EÜR applies booking direction and period policy to pass 4.1
- [ ] 4.3 Refactor the implementation and fixtures; the full suite stays green

## 5. EÜR applies booking direction and period policy — Disposal stops AfA

- [ ] 5.1 Write failing test test/integration/audit/tax-reporting-and-export-integrity_test.dart → test_tax_reporting_and_export_integrity_2_2_disposal_stops_afa (assert it fails for the right reason)
- [ ] 5.2 Implement the behavior required by EÜR applies booking direction and period policy to pass 5.1
- [ ] 5.3 Refactor the implementation and fixtures; the full suite stays green

## 6. EÜR applies booking direction and period policy — Default cutover is deterministic

- [ ] 6.1 Write failing test test/integration/audit/tax-reporting-and-export-integrity_test.dart → test_tax_reporting_and_export_integrity_2_3_default_cutover_is_deterministic (assert it fails for the right reason)
- [ ] 6.2 Implement the behavior required by EÜR applies booking direction and period policy to pass 6.1
- [ ] 6.3 Refactor the implementation and fixtures; the full suite stays green

## 7. Tax and GoBD exports are real validated artifacts — A successful export is reopenable

- [ ] 7.1 Write failing test test/integration/audit/tax-reporting-and-export-integrity_test.dart → test_tax_reporting_and_export_integrity_3_1_a_successful_export_is_reopenable (assert it fails for the right reason)
- [ ] 7.2 Implement the behavior required by Tax and GoBD exports are real validated artifacts to pass 7.1
- [ ] 7.3 Refactor the implementation and fixtures; the full suite stays green

## 8. Tax and GoBD exports are real validated artifacts — Export failure is truthful

- [ ] 8.1 Write failing test test/integration/audit/tax-reporting-and-export-integrity_test.dart → test_tax_reporting_and_export_integrity_3_2_export_failure_is_truthful (assert it fails for the right reason)
- [ ] 8.2 Implement the behavior required by Tax and GoBD exports are real validated artifacts to pass 8.1
- [ ] 8.3 Refactor the implementation and fixtures; the full suite stays green

## 9. Customer-scoped reports honor their customer filter — EKS excludes another customer's bookings

- [ ] 9.1 Write failing test test/integration/audit/tax-reporting-and-export-integrity_test.dart → test_tax_reporting_and_export_integrity_4_1_eks_excludes_another_customer_s_bookings (assert it fails for the right reason)
- [ ] 9.2 Implement the behavior required by Customer-scoped reports honor their customer filter to pass 9.1
- [ ] 9.3 Refactor the implementation and fixtures; the full suite stays green

## 10. Customer-scoped reports honor their customer filter — Missing customer scope is explicit

- [ ] 10.1 Write failing test test/integration/audit/tax-reporting-and-export-integrity_test.dart → test_tax_reporting_and_export_integrity_4_2_missing_customer_scope_is_explicit (assert it fails for the right reason)
- [ ] 10.2 Implement the behavior required by Customer-scoped reports honor their customer filter to pass 10.1
- [ ] 10.3 Refactor the implementation and fixtures; the full suite stays green
