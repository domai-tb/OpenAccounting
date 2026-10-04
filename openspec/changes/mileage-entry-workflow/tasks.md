## 1. mileage-entry: Capture traceable business mileage

- [ ] 1.1 Write failing test `test_record_a_business_trip` in `test/features/mileage/mileage_entry_workflow_test.dart` for scenario "Record a business trip"; assert it fails for the right reason.
- [ ] 1.2 Implement the specified behavior for "Record a business trip" to pass 1.1.
- [ ] 1.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.4 Write failing test `test_reject_invalid_trip_facts` in `test/features/mileage/mileage_entry_workflow_test.dart` for scenario "Reject invalid trip facts"; assert it fails for the right reason.
- [ ] 1.5 Implement the specified behavior for "Reject invalid trip facts" to pass 1.4.
- [ ] 1.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.7 Write failing test `test_preserve_posted_source_facts` in `test/features/mileage/mileage_entry_workflow_test.dart` for scenario "Preserve posted source facts"; assert it fails for the right reason.
- [ ] 1.8 Implement the specified behavior for "Preserve posted source facts" to pass 1.7.
- [ ] 1.9 Refactor the affected code; keep the focused and full suites green.

## 2. mileage-entry: Mileage amounts require an approved effective policy

- [ ] 2.1 Write failing test `test_calculate_from_an_approved_policy` in `test/features/mileage/mileage_entry_workflow_test.dart` for scenario "Calculate from an approved policy"; assert it fails for the right reason.
- [ ] 2.2 Implement the specified behavior for "Calculate from an approved policy" to pass 2.1.
- [ ] 2.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.4 Write failing test `test_keep_an_unresolved_trip_out_of_accounting` in `test/features/mileage/mileage_entry_workflow_test.dart` for scenario "Keep an unresolved trip out of accounting"; assert it fails for the right reason.
- [ ] 2.5 Implement the specified behavior for "Keep an unresolved trip out of accounting" to pass 2.4.
- [ ] 2.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.7 Write failing test `test_do_not_treat_the_eks_allowance_as_the_general_deduction` in `test/features/mileage/mileage_entry_workflow_test.dart` for scenario "Do not treat the EKS allowance as the general deduction"; assert it fails for the right reason.
- [ ] 2.8 Implement the specified behavior for "Do not treat the EKS allowance as the general deduction" to pass 2.7.
- [ ] 2.9 Refactor the affected code; keep the focused and full suites green.

## 3. mileage-entry: Post resolved mileage through the accounting boundary

- [ ] 3.1 Write failing test `test_post_a_confirmed_resolved_mileage_expense` in `test/features/mileage/mileage_entry_workflow_test.dart` for scenario "Post a confirmed resolved mileage expense"; assert it fails for the right reason.
- [ ] 3.2 Implement the specified behavior for "Post a confirmed resolved mileage expense" to pass 3.1.
- [ ] 3.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.4 Write failing test `test_reject_duplicate_or_incomplete_posting` in `test/features/mileage/mileage_entry_workflow_test.dart` for scenario "Reject duplicate or incomplete posting"; assert it fails for the right reason.
- [ ] 3.5 Implement the specified behavior for "Reject duplicate or incomplete posting" to pass 3.4.
- [ ] 3.6 Refactor the affected code; keep the focused and full suites green.

## Implementation Notes

- Follow `design.md` for implementation decisions and dependency order.
- Keep each scenario in red-green-refactor order; do not implement behavior before its failing test.
- Keep `test-plan.md` red until its named test passes.
