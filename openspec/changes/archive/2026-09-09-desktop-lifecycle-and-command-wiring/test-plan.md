## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/desktop-lifecycle-and-command-wiring/spec.md → Window state has one lifecycle owner | Window state survives restart | test/integration/audit/desktop-lifecycle-and-command-wiring_test.dart | test_desktop_lifecycle_and_command_wiring_1_1_window_state_survives_restart | 🔴 red |
| specs/desktop-lifecycle-and-command-wiring/spec.md → Window state has one lifecycle owner | Invalid/off-screen state is repaired | test/integration/audit/desktop-lifecycle-and-command-wiring_test.dart | test_desktop_lifecycle_and_command_wiring_1_2_invalid_off_screen_state_is_repaired | 🔴 red |
| specs/desktop-lifecycle-and-command-wiring/spec.md → Commands and shortcuts invoke real intents | Shortcut opens the intended workflow | test/integration/audit/desktop-lifecycle-and-command-wiring_test.dart | test_desktop_lifecycle_and_command_wiring_2_1_shortcut_opens_the_intended_workflow | 🔴 red |
| specs/desktop-lifecycle-and-command-wiring/spec.md → Commands and shortcuts invoke real intents | Shortcut is guarded in text input | test/integration/audit/desktop-lifecycle-and-command-wiring_test.dart | test_desktop_lifecycle_and_command_wiring_2_2_shortcut_is_guarded_in_text_input | 🔴 red |
| specs/desktop-lifecycle-and-command-wiring/spec.md → Updater verifies and installs authentic releases | Authentic update installs | test/integration/audit/desktop-lifecycle-and-command-wiring_test.dart | test_desktop_lifecycle_and_command_wiring_3_1_authentic_update_installs | 🔴 red |
| specs/desktop-lifecycle-and-command-wiring/spec.md → Updater verifies and installs authentic releases | Tampering or failure is rejected | test/integration/audit/desktop-lifecycle-and-command-wiring_test.dart | test_desktop_lifecycle_and_command_wiring_3_2_tampering_or_failure_is_rejected | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
