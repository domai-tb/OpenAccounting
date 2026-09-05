## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/localization-settings-and-data-protection/spec.md → Settings controls change live persisted application state | Language switch retains context | test/integration/audit/localization-settings-and-data-protection_test.dart | test_localization_settings_and_data_protection_1_1_language_switch_retains_context | 🔴 red |
| specs/localization-settings-and-data-protection/spec.md → Settings controls change live persisted application state | Theme/privacy changes are durable | test/integration/audit/localization-settings-and-data-protection_test.dart | test_localization_settings_and_data_protection_1_2_theme_privacy_changes_are_durable | 🔴 red |
| specs/localization-settings-and-data-protection/spec.md → Local-first backup and integrations report real outcomes | A backup can be created and restored | test/integration/audit/localization-settings-and-data-protection_test.dart | test_localization_settings_and_data_protection_2_1_a_backup_can_be_created_and_restored | 🔴 red |
| specs/localization-settings-and-data-protection/spec.md → Local-first backup and integrations report real outcomes | Integration failure is truthful | test/integration/audit/localization-settings-and-data-protection_test.dart | test_localization_settings_and_data_protection_2_2_integration_failure_is_truthful | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
