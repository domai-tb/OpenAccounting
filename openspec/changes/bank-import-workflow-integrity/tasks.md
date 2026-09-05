## Implementation Tasks

## 1. Banking exposes a reviewable import lifecycle — User reviews before import

- [ ] 1.1 Write failing test test/integration/audit/bank-import-workflow-integrity_test.dart → test_bank_import_workflow_integrity_1_1_user_reviews_before_import (assert it fails for the right reason)
- [ ] 1.2 Implement the behavior required by Banking exposes a reviewable import lifecycle to pass 1.1
- [ ] 1.3 Refactor the implementation and fixtures; the full suite stays green

## 2. Banking exposes a reviewable import lifecycle — Unsupported input remains safe

- [ ] 2.1 Write failing test test/integration/audit/bank-import-workflow-integrity_test.dart → test_bank_import_workflow_integrity_1_2_unsupported_input_remains_safe (assert it fails for the right reason)
- [ ] 2.2 Implement the behavior required by Banking exposes a reviewable import lifecycle to pass 2.1
- [ ] 2.3 Refactor the implementation and fixtures; the full suite stays green

## 3. Import outcomes are truthful and recoverable — Successful batch counts persisted rows

- [ ] 3.1 Write failing test test/integration/audit/bank-import-workflow-integrity_test.dart → test_bank_import_workflow_integrity_2_1_successful_batch_counts_persisted_rows (assert it fails for the right reason)
- [ ] 3.2 Implement the behavior required by Import outcomes are truthful and recoverable to pass 3.1
- [ ] 3.3 Refactor the implementation and fixtures; the full suite stays green

## 4. Import outcomes are truthful and recoverable — A row failure is surfaced

- [ ] 4.1 Write failing test test/integration/audit/bank-import-workflow-integrity_test.dart → test_bank_import_workflow_integrity_2_2_a_row_failure_is_surfaced (assert it fails for the right reason)
- [ ] 4.2 Implement the behavior required by Import outcomes are truthful and recoverable to pass 4.1
- [ ] 4.3 Refactor the implementation and fixtures; the full suite stays green

## 5. Import outcomes are truthful and recoverable — Retry does not duplicate rows

- [ ] 5.1 Write failing test test/integration/audit/bank-import-workflow-integrity_test.dart → test_bank_import_workflow_integrity_2_3_retry_does_not_duplicate_rows (assert it fails for the right reason)
- [ ] 5.2 Implement the behavior required by Import outcomes are truthful and recoverable to pass 5.1
- [ ] 5.3 Refactor the implementation and fixtures; the full suite stays green
