## Test Plan

<!-- Every scenario in specs/ maps to a named test. -->
<!-- During implementation, flip 🔴 red to 🟢 green when its test passes. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/specs/feature-modules/spec.md → Optional modules have an explicit, validated business state | Available module state is restored | test/features/feature_modules/optional_feature_module_controls_test.dart | test_available_module_state_is_restored | 🔴 red |
| specs/specs/feature-modules/spec.md → Optional modules have an explicit, validated business state | Unknown or unavailable module cannot be enabled | test/features/feature_modules/optional_feature_module_controls_test.dart | test_unknown_or_unavailable_module_cannot_be_enabled | 🔴 red |
| specs/specs/feature-modules/spec.md → Disabling a module hides its entry points without deleting data | Module is disabled while it has existing records | test/features/feature_modules/optional_feature_module_controls_test.dart | test_module_is_disabled_while_it_has_existing_records | 🔴 red |
| specs/specs/feature-modules/spec.md → Disabling a module hides its entry points without deleting data | Direct navigation reaches a safe unavailable state | test/features/feature_modules/optional_feature_module_controls_test.dart | test_direct_navigation_reaches_a_safe_unavailable_state | 🔴 red |
| specs/specs/feature-modules/spec.md → Module controls follow the Settings and accessibility design | User changes a supported module | test/features/feature_modules/optional_feature_module_controls_test.dart | test_user_changes_a_supported_module | 🔴 red |
| specs/specs/feature-modules/spec.md → Module controls follow the Settings and accessibility design | Module setting cannot be saved | test/features/feature_modules/optional_feature_module_controls_test.dart | test_module_setting_cannot_be_saved | 🔴 red |

## Coverage Notes

- Every scenario is mapped once to a named executable test; all rows start red.
- Tests use the repository’s Flutter test infrastructure and focused fixtures for the affected feature and persistence boundaries.
- These are planned tests; this artifact does not claim that the tests already exist or have passed.
