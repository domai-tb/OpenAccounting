# Test Plan — desktop-action-and-spec-parity

## desktop-capability-availability

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| Production desktop action wiring | Dropped file callback fires | test/features/desktop/desktop_capability_registry_test.dart | test_drop_callback_fires | 🔴 red |
| Production desktop action wiring | Unsupported target reports availability | test/features/desktop/desktop_capability_registry_test.dart | test_unsupported_target_reports_unavailable | 🔴 red |
| Updater remains fail-closed | Unapproved updater visible as unavailable | test/features/desktop/desktop_updater_test.dart | test_updater_unavailable_without_policy | 🔴 red |
| Updater remains fail-closed | Untrusted update rejected | test/features/desktop/desktop_updater_test.dart | test_untrusted_update_rejected | 🔴 red |

## specification-source-parity

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| Flutter source-of-truth documentation | Architecture links match source | N/A — non-executable | `grep -r "FastAPI\\|React\\|Vite\\|Tailwind\\|Tauri\\|Python" docs/ openspec/specs/` returns no matches in active docs | N/A — non-executable |
| Flutter source-of-truth documentation | Stale architecture is detected | N/A — non-executable | `scripts/check_architecture_parity.sh` exits non-zero when stale identifier found | N/A — non-executable |
| Desktop specifications are semantically consistent | Desktop specs agree | N/A — non-executable | `openspec validate` passes with no contradictions in desktop specs | N/A — non-executable |
| Desktop specifications are semantically consistent | Contradictory spec rejected | N/A — non-executable | `scripts/check_architecture_parity.sh` fails when contradictory desktop requirements detected | N/A — non-executable |

## desktop (delta — Auto-Update)

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| Auto-Update | Update Available Notification | test/features/desktop/desktop_updater_test.dart | test_update_available_shows_notification | 🔴 red |
| Auto-Update | Update Download and Install | test/features/desktop/desktop_updater_test.dart | test_update_download_and_install | 🔴 red |
| Auto-Update | Update Download Cancelled | test/features/desktop/desktop_updater_test.dart | test_update_download_cancelled | 🔴 red |
| Auto-Update | Signing Verification Failure | test/features/desktop/desktop_updater_test.dart | test_signing_verification_failure | 🔴 red |
| Auto-Update | Updater Unavailable | test/features/desktop/desktop_updater_test.dart | test_updater_unavailable_no_policy | 🔴 red |
| Auto-Update | No Update Available | test/features/desktop/desktop_updater_test.dart | test_no_update_available_silent | 🔴 red |

## desktop (delta — Window Management)

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| Window Management | Window State Persistence | test/features/desktop/window_state_test.dart | test_window_state_persistence | 🔴 red |
| Window Management | Minimum Size Enforcement | test/features/desktop/window_state_test.dart | test_minimum_size_enforcement | 🔴 red |
| Window Management | Maximize State Persistence | test/features/desktop/window_state_test.dart | test_maximize_state_persistence | 🔴 red |
| Window Management | Window State Corruption Recovery | test/features/desktop/window_state_test.dart | test_window_state_corruption_recovery | 🔴 red |

## desktop (delta — Platform Workarounds)

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| Platform Workarounds | Windows Console Hide | N/A — non-executable | Platform-specific; verified by desktop build on Windows CI | N/A — non-executable |
| Platform Workarounds | macOS Profile Path | test/features/desktop/platform_paths_test.dart | test_macos_profile_path | 🔴 red |
| Platform Workarounds | Linux Profile Path | test/features/desktop/platform_paths_test.dart | test_linux_profile_path | 🔴 red |
| Platform Workarounds | Windows Profile Path | test/features/desktop/platform_paths_test.dart | test_windows_profile_path | 🔴 red |
