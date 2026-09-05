## Implementation Tasks

## 1. Finalization creates the complete accounting posting set — Outgoing invoice creates a receivable

- [ ] 1.1 Write failing test test/integration/audit/invoice-accounting-posting-lifecycle_test.dart → test_invoice_accounting_posting_lifecycle_1_1_outgoing_invoice_creates_a_receivable (assert it fails for the right reason)
- [ ] 1.2 Implement the behavior required by Finalization creates the complete accounting posting set to pass 1.1
- [ ] 1.3 Refactor the implementation and fixtures; the full suite stays green

## 2. Finalization creates the complete accounting posting set — Incoming invoice creates input-tax state

- [ ] 2.1 Write failing test test/integration/audit/invoice-accounting-posting-lifecycle_test.dart → test_invoice_accounting_posting_lifecycle_1_2_incoming_invoice_creates_input_tax_state (assert it fails for the right reason)
- [ ] 2.2 Implement the behavior required by Finalization creates the complete accounting posting set to pass 2.1
- [ ] 2.3 Refactor the implementation and fixtures; the full suite stays green

## 3. Finalization creates the complete accounting posting set — Failure leaves no partial posting

- [ ] 3.1 Write failing test test/integration/audit/invoice-accounting-posting-lifecycle_test.dart → test_invoice_accounting_posting_lifecycle_1_3_failure_leaves_no_partial_posting (assert it fails for the right reason)
- [ ] 3.2 Implement the behavior required by Finalization creates the complete accounting posting set to pass 3.1
- [ ] 3.3 Refactor the implementation and fixtures; the full suite stays green

## 4. Finalization is idempotent and audit-linked — Retry does not duplicate accounting

- [ ] 4.1 Write failing test test/integration/audit/invoice-accounting-posting-lifecycle_test.dart → test_invoice_accounting_posting_lifecycle_2_1_retry_does_not_duplicate_accounting (assert it fails for the right reason)
- [ ] 4.2 Implement the behavior required by Finalization is idempotent and audit-linked to pass 4.1
- [ ] 4.3 Refactor the implementation and fixtures; the full suite stays green

## 5. Finalization is idempotent and audit-linked — Correction can find its source

- [ ] 5.1 Write failing test test/integration/audit/invoice-accounting-posting-lifecycle_test.dart → test_invoice_accounting_posting_lifecycle_2_2_correction_can_find_its_source (assert it fails for the right reason)
- [ ] 5.2 Implement the behavior required by Finalization is idempotent and audit-linked to pass 5.1
- [ ] 5.3 Refactor the implementation and fixtures; the full suite stays green
