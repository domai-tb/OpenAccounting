## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/schema-evolution-safety/spec.md → The production schema is defined by migrations | Fresh database has the complete schema | test/integration/audit/schema-evolution-safety_test.dart | test_schema_evolution_safety_1_1_fresh_database_has_the_complete_schema | 🔴 red |
| specs/schema-evolution-safety/spec.md → The production schema is defined by migrations | A workflow cannot hide missing schema | test/integration/audit/schema-evolution-safety_test.dart | test_schema_evolution_safety_1_2_a_workflow_cannot_hide_missing_schema | 🔴 red |
| specs/schema-evolution-safety/spec.md → Migrations fail safely and preserve data | Unsupported future database is rejected | test/integration/audit/schema-evolution-safety_test.dart | test_schema_evolution_safety_2_1_unsupported_future_database_is_rejected | 🔴 red |
| specs/schema-evolution-safety/spec.md → Migrations fail safely and preserve data | Legacy rebuild preserves extended data | test/integration/audit/schema-evolution-safety_test.dart | test_schema_evolution_safety_2_2_legacy_rebuild_preserves_extended_data | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
