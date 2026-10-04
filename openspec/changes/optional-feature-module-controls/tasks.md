## 1. feature-modules: Optional modules have an explicit, validated business state

- [ ] 1.1 Write failing test `test_available_module_state_is_restored` in `test/features/feature_modules/optional_feature_module_controls_test.dart` for scenario "Available module state is restored"; assert it fails for the right reason.
- [ ] 1.2 Implement the specified behavior for "Available module state is restored" to pass 1.1.
- [ ] 1.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.4 Write failing test `test_unknown_or_unavailable_module_cannot_be_enabled` in `test/features/feature_modules/optional_feature_module_controls_test.dart` for scenario "Unknown or unavailable module cannot be enabled"; assert it fails for the right reason.
- [ ] 1.5 Implement the specified behavior for "Unknown or unavailable module cannot be enabled" to pass 1.4.
- [ ] 1.6 Refactor the affected code; keep the focused and full suites green.

## 2. feature-modules: Disabling a module hides its entry points without deleting data

- [ ] 2.1 Write failing test `test_module_is_disabled_while_it_has_existing_records` in `test/features/feature_modules/optional_feature_module_controls_test.dart` for scenario "Module is disabled while it has existing records"; assert it fails for the right reason.
- [ ] 2.2 Implement the specified behavior for "Module is disabled while it has existing records" to pass 2.1.
- [ ] 2.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.4 Write failing test `test_direct_navigation_reaches_a_safe_unavailable_state` in `test/features/feature_modules/optional_feature_module_controls_test.dart` for scenario "Direct navigation reaches a safe unavailable state"; assert it fails for the right reason.
- [ ] 2.5 Implement the specified behavior for "Direct navigation reaches a safe unavailable state" to pass 2.4.
- [ ] 2.6 Refactor the affected code; keep the focused and full suites green.

## 3. feature-modules: Module controls follow the Settings and accessibility design

- [ ] 3.1 Write failing test `test_user_changes_a_supported_module` in `test/features/feature_modules/optional_feature_module_controls_test.dart` for scenario "User changes a supported module"; assert it fails for the right reason.
- [ ] 3.2 Implement the specified behavior for "User changes a supported module" to pass 3.1.
- [ ] 3.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 3.4 Write failing test `test_module_setting_cannot_be_saved` in `test/features/feature_modules/optional_feature_module_controls_test.dart` for scenario "Module setting cannot be saved"; assert it fails for the right reason.
- [ ] 3.5 Implement the specified behavior for "Module setting cannot be saved" to pass 3.4.
- [ ] 3.6 Refactor the affected code; keep the focused and full suites green.

## Implementation Notes

- Follow `design.md` for implementation decisions and dependency order.
- Keep each scenario in red-green-refactor order; do not implement behavior before its failing test.
- Keep `test-plan.md` red until its named test passes.
