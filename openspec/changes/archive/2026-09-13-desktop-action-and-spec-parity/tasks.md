# Tasks — desktop-action-and-spec-parity

## 1. DesktopCapabilityRegistry infrastructure

- [x] 1.1 Write failing test `test_drop_callback_fires` — verify DropCapability invokes onEvent callback with file path
- [x] 1.2 Implement `DesktopCapability<T>` sealed class and `DesktopCapabilityRegistry` with `register<T>()` and `isAvailable<T>()`
- [x] 1.3 Refactor; full suite stays green
- [x] 1.4 Write failing test `test_unsupported_target_reports_unavailable` — verify unavailable capability returns reason
- [x] 1.5 Implement `Unavailable<T>` variant with reason string
- [x] 1.6 Refactor; full suite stays green

## 2. Bootstrap wiring

- [x] 2.1 Wire `DesktopCapabilityRegistry` into `AppServices` constructor
- [x] 2.2 Register tray, shortcuts, file assoc, drop, PDF viewer, updater adapters in bootstrap with idempotent guards
- [x] 2.3 Refactor; full suite stays green

## 3. Updater fail-closed

- [x] 3.1 Write failing test `test_updater_unavailable_without_policy` — verify updater reports unavailable when no signing policy
- [x] 3.2 Implement updater availability state exposed via registry
- [x] 3.3 Refactor; full suite stays green
- [x] 3.4 Write failing test `test_untrusted_update_rejected` — verify update blocked without trusted root
- [x] 3.5 Implement deny-all gate in updater service
- [x] 3.6 Refactor; full suite stays green
- [x] 3.7 Write failing test `test_updater_unavailable_no_policy` — verify UI shows unavailable message
- [x] 3.8 Implement updater unavailable UI state
- [x] 3.9 Refactor; full suite stays green
- [x] 3.10 Write failing tests for remaining updater scenarios (update available, download/install, cancelled, signing failure, no update)
- [x] 3.11 Implement updater notification, download, cancel, signing verification flows
- [x] 3.12 Refactor; full suite stays green

## 4. Window state persistence

- [x] 4.1 Write failing test `test_window_state_persistence` — verify bounds restored after reload
- [x] 4.2 Implement window state serialization/deserialization with SharedPreferences
- [x] 4.3 Refactor; full suite stays green
- [x] 4.4 Write failing test `test_minimum_size_enforcement` — verify 960x640 minimum
- [x] 4.5 Update minimum size constants in window_state.dart and main.dart
- [x] 4.6 Refactor; full suite stays green
- [x] 4.7 Write failing test `test_maximize_state_persistence` — verify maximized flag restored
- [x] 4.8 Implement maximize state save/restore
- [x] 4.9 Refactor; full suite stays green
- [x] 4.10 Write failing test `test_window_state_corruption_recovery` — verify fallback on invalid bounds
- [x] 4.11 Implement bounds validation with fallback to defaults
- [x] 4.12 Refactor; full suite stays green

## 5. Platform profile paths

- [x] 5.1 Write failing tests `test_macos_profile_path`, `test_linux_profile_path`, `test_windows_profile_path`
- [x] 5.2 Update `data_paths.dart` to use `OpenAccounting` and `profiles/<name>/` structure
- [x] 5.3 Refactor; full suite stays green

## 6. Documentation parity

- [x] 6.1 Run `grep -r "FastAPI\|React\|Vite\|Tailwind\|Tauri\|Python" docs/ openspec/specs/` — confirm no active doc matches
- [x] 6.2 Create `scripts/check_architecture_parity.sh` that fails on stale architecture identifiers
- [x] 6.3 Run `openspec validate` — confirm desktop specs pass with no contradictions
- [x] 6.4 Update stale docs (`docs/01-rechnungen.md` etc.) to remove obsolete architecture references
