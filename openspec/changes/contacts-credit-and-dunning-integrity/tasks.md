## Implementation Tasks

## 1. Contacts are data-backed and credit decisions are auditable — Customer change is visible in linked workflows

- [ ] 1.1 Write failing test test/integration/audit/contacts-credit-and-dunning-integrity_test.dart → test_contacts_credit_and_dunning_integrity_1_1_customer_change_is_visible_in_linked_workflows (assert it fails for the right reason)
- [ ] 1.2 Implement the behavior required by Contacts are data-backed and credit decisions are auditable to pass 1.1
- [ ] 1.3 Refactor the implementation and fixtures; the full suite stays green

## 2. Contacts are data-backed and credit decisions are auditable — Credit decision leaves an audit trail

- [ ] 2.1 Write failing test test/integration/audit/contacts-credit-and-dunning-integrity_test.dart → test_contacts_credit_and_dunning_integrity_1_2_credit_decision_leaves_an_audit_trail (assert it fails for the right reason)
- [ ] 2.2 Implement the behavior required by Contacts are data-backed and credit decisions are auditable to pass 2.1
- [ ] 2.3 Refactor the implementation and fixtures; the full suite stays green

## 3. Dunning letters are durable and linked — Eligible receivable produces a letter

- [ ] 3.1 Write failing test test/integration/audit/contacts-credit-and-dunning-integrity_test.dart → test_contacts_credit_and_dunning_integrity_2_1_eligible_receivable_produces_a_letter (assert it fails for the right reason)
- [ ] 3.2 Implement the behavior required by Dunning letters are durable and linked to pass 3.1
- [ ] 3.3 Refactor the implementation and fixtures; the full suite stays green

## 4. Dunning letters are durable and linked — Ineligible or failed run is safe

- [ ] 4.1 Write failing test test/integration/audit/contacts-credit-and-dunning-integrity_test.dart → test_contacts_credit_and_dunning_integrity_2_2_ineligible_or_failed_run_is_safe (assert it fails for the right reason)
- [ ] 4.2 Implement the behavior required by Dunning letters are durable and linked to pass 4.1
- [ ] 4.3 Refactor the implementation and fixtures; the full suite stays green
