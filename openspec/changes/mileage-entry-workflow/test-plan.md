## Test Plan

<!-- Every scenario in specs/ maps to a named test. -->
<!-- During implementation, flip 🔴 red to 🟢 green when its test passes. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/specs/mileage-entry/spec.md → Capture traceable business mileage | Record a business trip | test/features/mileage/mileage_entry_workflow_test.dart | test_record_a_business_trip | 🔴 red |
| specs/specs/mileage-entry/spec.md → Capture traceable business mileage | Reject invalid trip facts | test/features/mileage/mileage_entry_workflow_test.dart | test_reject_invalid_trip_facts | 🔴 red |
| specs/specs/mileage-entry/spec.md → Capture traceable business mileage | Preserve posted source facts | test/features/mileage/mileage_entry_workflow_test.dart | test_preserve_posted_source_facts | 🔴 red |
| specs/specs/mileage-entry/spec.md → Mileage amounts require an approved effective policy | Calculate from an approved policy | test/features/mileage/mileage_entry_workflow_test.dart | test_calculate_from_an_approved_policy | 🔴 red |
| specs/specs/mileage-entry/spec.md → Mileage amounts require an approved effective policy | Keep an unresolved trip out of accounting | test/features/mileage/mileage_entry_workflow_test.dart | test_keep_an_unresolved_trip_out_of_accounting | 🔴 red |
| specs/specs/mileage-entry/spec.md → Mileage amounts require an approved effective policy | Do not treat the EKS allowance as the general deduction | test/features/mileage/mileage_entry_workflow_test.dart | test_do_not_treat_the_eks_allowance_as_the_general_deduction | 🔴 red |
| specs/specs/mileage-entry/spec.md → Post resolved mileage through the accounting boundary | Post a confirmed resolved mileage expense | test/features/mileage/mileage_entry_workflow_test.dart | test_post_a_confirmed_resolved_mileage_expense | 🔴 red |
| specs/specs/mileage-entry/spec.md → Post resolved mileage through the accounting boundary | Reject duplicate or incomplete posting | test/features/mileage/mileage_entry_workflow_test.dart | test_reject_duplicate_or_incomplete_posting | 🔴 red |

## Coverage Notes

- Every scenario is mapped once to a named executable test; all rows start red.
- Tests use the repository’s Flutter test infrastructure and focused fixtures for the affected feature and persistence boundaries.
- These are planned tests; this artifact does not claim that the tests already exist or have passed.
