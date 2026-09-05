## Implementation Tasks

## 1. The production schema is defined by migrations — Fresh database has the complete schema

- [ ] 1.1 Write failing test test/integration/audit/schema-evolution-safety_test.dart → test_schema_evolution_safety_1_1_fresh_database_has_the_complete_schema (assert it fails for the right reason)
- [ ] 1.2 Implement the behavior required by The production schema is defined by migrations to pass 1.1
- [ ] 1.3 Refactor the implementation and fixtures; the full suite stays green

## 2. The production schema is defined by migrations — A workflow cannot hide missing schema

- [ ] 2.1 Write failing test test/integration/audit/schema-evolution-safety_test.dart → test_schema_evolution_safety_1_2_a_workflow_cannot_hide_missing_schema (assert it fails for the right reason)
- [ ] 2.2 Implement the behavior required by The production schema is defined by migrations to pass 2.1
- [ ] 2.3 Refactor the implementation and fixtures; the full suite stays green

## 3. Migrations fail safely and preserve data — Unsupported future database is rejected

- [ ] 3.1 Write failing test test/integration/audit/schema-evolution-safety_test.dart → test_schema_evolution_safety_2_1_unsupported_future_database_is_rejected (assert it fails for the right reason)
- [ ] 3.2 Implement the behavior required by Migrations fail safely and preserve data to pass 3.1
- [ ] 3.3 Refactor the implementation and fixtures; the full suite stays green

## 4. Migrations fail safely and preserve data — Legacy rebuild preserves extended data

- [ ] 4.1 Write failing test test/integration/audit/schema-evolution-safety_test.dart → test_schema_evolution_safety_2_2_legacy_rebuild_preserves_extended_data (assert it fails for the right reason)
- [ ] 4.2 Implement the behavior required by Migrations fail safely and preserve data to pass 4.1
- [ ] 4.3 Refactor the implementation and fixtures; the full suite stays green
