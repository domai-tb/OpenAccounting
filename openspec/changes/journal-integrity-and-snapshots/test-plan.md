## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/journal-integrity-and-snapshots/spec.md → Storno enforces immutable finalized journal rules | Finalized source can be reversed once | test/integration/audit/journal-integrity-and-snapshots_test.dart | test_journal_integrity_and_snapshots_1_1_finalized_source_can_be_reversed_once | 🔴 red |
| specs/journal-integrity-and-snapshots/spec.md → Storno enforces immutable finalized journal rules | Mutable or already reversed source is rejected | test/integration/audit/journal-integrity-and-snapshots_test.dart | test_journal_integrity_and_snapshots_1_2_mutable_or_already_reversed_source_is_rejected | 🔴 red |
| specs/journal-integrity-and-snapshots/spec.md → Journal rows carry audit-stable snapshots | Missing snapshots are resolved | test/integration/audit/journal-integrity-and-snapshots_test.dart | test_journal_integrity_and_snapshots_2_1_missing_snapshots_are_resolved | 🔴 red |
| specs/journal-integrity-and-snapshots/spec.md → Journal rows carry audit-stable snapshots | Historical read is stable after master-data edit | test/integration/audit/journal-integrity-and-snapshots_test.dart | test_journal_integrity_and_snapshots_2_2_historical_read_is_stable_after_master_data_edit | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
