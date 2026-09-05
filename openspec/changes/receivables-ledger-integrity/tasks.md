## Implementation Tasks

## 1. Statements account for every payment exactly once — Partial payment leaves the remainder

- [ ] 1.1 Write failing test test/integration/audit/receivables-ledger-integrity_test.dart → test_receivables_ledger_integrity_1_1_partial_payment_leaves_the_remainder (assert it fails for the right reason)
- [ ] 1.2 Implement the behavior required by Statements account for every payment exactly once to pass 1.1
- [ ] 1.3 Refactor the implementation and fixtures; the full suite stays green

## 2. Statements account for every payment exactly once — Full and overpayment are represented

- [ ] 2.1 Write failing test test/integration/audit/receivables-ledger-integrity_test.dart → test_receivables_ledger_integrity_1_2_full_and_overpayment_are_represented (assert it fails for the right reason)
- [ ] 2.2 Implement the behavior required by Statements account for every payment exactly once to pass 2.1
- [ ] 2.3 Refactor the implementation and fixtures; the full suite stays green

## 3. Statements account for every payment exactly once — Opening balance includes prior activity

- [ ] 3.1 Write failing test test/integration/audit/receivables-ledger-integrity_test.dart → test_receivables_ledger_integrity_1_3_opening_balance_includes_prior_activity (assert it fails for the right reason)
- [ ] 3.2 Implement the behavior required by Statements account for every payment exactly once to pass 3.1
- [ ] 3.3 Refactor the implementation and fixtures; the full suite stays green

## 4. Receivables schema is ready after normal startup — Fresh startup supports receivables

- [ ] 4.1 Write failing test test/integration/audit/receivables-ledger-integrity_test.dart → test_receivables_ledger_integrity_2_1_fresh_startup_supports_receivables (assert it fails for the right reason)
- [ ] 4.2 Implement the behavior required by Receivables schema is ready after normal startup to pass 4.1
- [ ] 4.3 Refactor the implementation and fixtures; the full suite stays green

## 5. Receivables schema is ready after normal startup — Legacy startup migrates safely

- [ ] 5.1 Write failing test test/integration/audit/receivables-ledger-integrity_test.dart → test_receivables_ledger_integrity_2_2_legacy_startup_migrates_safely (assert it fails for the right reason)
- [ ] 5.2 Implement the behavior required by Receivables schema is ready after normal startup to pass 5.1
- [ ] 5.3 Refactor the implementation and fixtures; the full suite stays green
