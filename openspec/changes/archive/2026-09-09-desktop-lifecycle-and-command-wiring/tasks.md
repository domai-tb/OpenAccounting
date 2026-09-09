## Implementation Tasks

## 1. Window state has one lifecycle owner — Window state survives restart

- [x] 1.1 Write failing test test/integration/audit/desktop-lifecycle-and-command-wiring_test.dart → test_desktop_lifecycle_and_command_wiring_1_1_window_state_survives_restart (assert it fails for the right reason)
- [x] 1.2 Implement the behavior required by Window state has one lifecycle owner to pass 1.1
- [x] 1.3 Refactor the implementation and fixtures; the full suite stays green

## 2. Window state has one lifecycle owner — Invalid/off-screen state is repaired

- [x] 2.1 Write failing test test/integration/audit/desktop-lifecycle-and-command-wiring_test.dart → test_desktop_lifecycle_and_command_wiring_1_2_invalid_off_screen_state_is_repaired (assert it fails for the right reason)
- [x] 2.2 Implement the behavior required by Window state has one lifecycle owner to pass 2.1
- [x] 2.3 Refactor the implementation and fixtures; the full suite stays green

## 3. Commands and shortcuts invoke real intents — Shortcut opens the intended workflow

- [x] 3.1 Write failing test test/integration/audit/desktop-lifecycle-and-command-wiring_test.dart → test_desktop_lifecycle_and_command_wiring_2_1_shortcut_opens_the_intended_workflow (assert it fails for the right reason)
- [x] 3.2 Implement the behavior required by Commands and shortcuts invoke real intents to pass 3.1
- [x] 3.3 Refactor the implementation and fixtures; the full suite stays green

## 4. Commands and shortcuts invoke real intents — Shortcut is guarded in text input

- [x] 4.1 Write failing test test/integration/audit/desktop-lifecycle-and-command-wiring_test.dart → test_desktop_lifecycle_and_command_wiring_2_2_shortcut_is_guarded_in_text_input (assert it fails for the right reason)
- [x] 4.2 Implement the behavior required by Commands and shortcuts invoke real intents to pass 4.1
- [x] 4.3 Refactor the implementation and fixtures; the full suite stays green

## 5. Updater verifies and installs authentic releases — Authentic update installs

- [x] 5.1 Write failing test test/integration/audit/desktop-lifecycle-and-command-wiring_test.dart → test_desktop_lifecycle_and_command_wiring_3_1_authentic_update_installs (assert it fails for the right reason)
- [x] 5.2 Implement the behavior required by Updater verifies and installs authentic releases to pass 5.1
- [x] 5.3 Refactor the implementation and fixtures; the full suite stays green

## 6. Updater verifies and installs authentic releases — Tampering or failure is rejected

- [x] 6.1 Write failing test test/integration/audit/desktop-lifecycle-and-command-wiring_test.dart → test_desktop_lifecycle_and_command_wiring_3_2_tampering_or_failure_is_rejected (assert it fails for the right reason)
- [x] 6.2 Implement the behavior required by Updater verifies and installs authentic releases to pass 6.1
- [x] 6.3 Refactor the implementation and fixtures; the full suite stays green
