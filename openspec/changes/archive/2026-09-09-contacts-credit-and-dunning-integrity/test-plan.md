## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/contacts-credit-and-dunning-integrity/spec.md → Contacts are data-backed and credit decisions are auditable | Customer change is visible in linked workflows | test/integration/audit/contacts-credit-and-dunning-integrity_test.dart | test_contacts_credit_and_dunning_integrity_1_1_customer_change_is_visible_in_linked_workflows | 🔴 red |
| specs/contacts-credit-and-dunning-integrity/spec.md → Contacts are data-backed and credit decisions are auditable | Credit decision leaves an audit trail | test/integration/audit/contacts-credit-and-dunning-integrity_test.dart | test_contacts_credit_and_dunning_integrity_1_2_credit_decision_leaves_an_audit_trail | 🔴 red |
| specs/contacts-credit-and-dunning-integrity/spec.md → Dunning letters are durable and linked | Eligible receivable produces a letter | test/integration/audit/contacts-credit-and-dunning-integrity_test.dart | test_contacts_credit_and_dunning_integrity_2_1_eligible_receivable_produces_a_letter | 🔴 red |
| specs/contacts-credit-and-dunning-integrity/spec.md → Dunning letters are durable and linked | Ineligible or failed run is safe | test/integration/audit/contacts-credit-and-dunning-integrity_test.dart | test_contacts_credit_and_dunning_integrity_2_2_ineligible_or_failed_run_is_safe | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
