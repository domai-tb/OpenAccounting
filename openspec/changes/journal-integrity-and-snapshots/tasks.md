## Implementation Tasks

## 1. Storno enforces immutable finalized journal rules — Finalized source can be reversed once

- [ ] 1.1 Write failing test test/integration/audit/journal-integrity-and-snapshots_test.dart → test_journal_integrity_and_snapshots_1_1_finalized_source_can_be_reversed_once (assert it fails for the right reason)
- [ ] 1.2 Implement the behavior required by Storno enforces immutable finalized journal rules to pass 1.1
- [ ] 1.3 Refactor the implementation and fixtures; the full suite stays green

## 2. Storno enforces immutable finalized journal rules — Mutable or already reversed source is rejected

- [ ] 2.1 Write failing test test/integration/audit/journal-integrity-and-snapshots_test.dart → test_journal_integrity_and_snapshots_1_2_mutable_or_already_reversed_source_is_rejected (assert it fails for the right reason)
- [ ] 2.2 Implement the behavior required by Storno enforces immutable finalized journal rules to pass 2.1
- [ ] 2.3 Refactor the implementation and fixtures; the full suite stays green

## 3. Journal rows carry audit-stable snapshots — Missing snapshots are resolved

- [ ] 3.1 Write failing test test/integration/audit/journal-integrity-and-snapshots_test.dart → test_journal_integrity_and_snapshots_2_1_missing_snapshots_are_resolved (assert it fails for the right reason)
- [ ] 3.2 Implement the behavior required by Journal rows carry audit-stable snapshots to pass 3.1
- [ ] 3.3 Refactor the implementation and fixtures; the full suite stays green

## 4. Journal rows carry audit-stable snapshots — Historical read is stable after master-data edit

- [ ] 4.1 Write failing test test/integration/audit/journal-integrity-and-snapshots_test.dart → test_journal_integrity_and_snapshots_2_2_historical_read_is_stable_after_master_data_edit (assert it fails for the right reason)
- [ ] 4.2 Implement the behavior required by Journal rows carry audit-stable snapshots to pass 4.1
- [ ] 4.3 Refactor the implementation and fixtures; the full suite stays green
