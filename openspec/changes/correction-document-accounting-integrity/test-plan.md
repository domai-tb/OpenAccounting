## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/correction-document-accounting-integrity/spec.md → Correction totals preserve signed VAT mathematics | Mixed-rate credit note reverses tax | test/integration/audit/correction-document-accounting-integrity_test.dart | test_correction_document_accounting_integrity_1_1_mixed_rate_credit_note_reverses_tax | 🔴 red |
| specs/correction-document-accounting-integrity/spec.md → Correction totals preserve signed VAT mathematics | Invalid source totals are not copied | test/integration/audit/correction-document-accounting-integrity_test.dart | test_correction_document_accounting_integrity_1_2_invalid_source_totals_are_not_copied | 🔴 red |
| specs/correction-document-accounting-integrity/spec.md → Replacement and reversal links are complete and unique | Second replacement is rejected | test/integration/audit/correction-document-accounting-integrity_test.dart | test_correction_document_accounting_integrity_2_1_second_replacement_is_rejected | 🔴 red |
| specs/correction-document-accounting-integrity/spec.md → Replacement and reversal links are complete and unique | A valid correction is traceable | test/integration/audit/correction-document-accounting-integrity_test.dart | test_correction_document_accounting_integrity_2_2_a_valid_correction_is_traceable | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
