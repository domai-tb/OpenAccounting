## Implementation Tasks

## 1. One opened application graph owns feature lifecycles — Normal startup shares one ready database

- [ ] 1.1 Write failing test test/integration/audit/runtime-composition-and-database-lifecycle_test.dart → test_runtime_composition_and_database_lifecycle_1_1_normal_startup_shares_one_ready_database (assert it fails for the right reason)
- [ ] 1.2 Implement the behavior required by One opened application graph owns feature lifecycles to pass 1.1
- [ ] 1.3 Refactor the implementation and fixtures; the full suite stays green

## 2. One opened application graph owns feature lifecycles — Dependency resolution cannot use an unopened default

- [ ] 2.1 Write failing test test/integration/audit/runtime-composition-and-database-lifecycle_test.dart → test_runtime_composition_and_database_lifecycle_1_2_dependency_resolution_cannot_use_an_unopened_default (assert it fails for the right reason)
- [ ] 2.2 Implement the behavior required by One opened application graph owns feature lifecycles to pass 2.1
- [ ] 2.3 Refactor the implementation and fixtures; the full suite stays green

## 3. Feature UI respects the clean dependency direction — A page calls its use case

- [ ] 3.1 Write failing test test/integration/audit/runtime-composition-and-database-lifecycle_test.dart → test_runtime_composition_and_database_lifecycle_2_1_a_page_calls_its_use_case (assert it fails for the right reason)
- [ ] 3.2 Implement the behavior required by Feature UI respects the clean dependency direction to pass 3.1
- [ ] 3.3 Refactor the implementation and fixtures; the full suite stays green

## 4. Feature UI respects the clean dependency direction — A missing service is diagnosed at composition time

- [ ] 4.1 Write failing test test/integration/audit/runtime-composition-and-database-lifecycle_test.dart → test_runtime_composition_and_database_lifecycle_2_2_a_missing_service_is_diagnosed_at_composition_time (assert it fails for the right reason)
- [ ] 4.2 Implement the behavior required by Feature UI respects the clean dependency direction to pass 4.1
- [ ] 4.3 Refactor the implementation and fixtures; the full suite stays green
