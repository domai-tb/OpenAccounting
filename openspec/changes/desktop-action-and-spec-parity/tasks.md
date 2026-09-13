# Tasks — desktop-action-and-spec-parity

## 1. DesktopCapabilityRegistry infrastructure

- [ ] 1.1 Write failing test `test_drop_callback_fires` — verify DropCapability invokes onEvent callback with file path
- [ ] 1.2 Implement `DesktopCapability<T>` sealed class and `DesktopCapabilityRegistry` with `register<T>()` and `isAvailable<T>()`
- [ ] 1.3 Refactor; full suite stays green
- [ ] 1.4 Write failing test `test_unsupported_target_reports_unavailable` — verify unavailable capability returns reason
- [ ] 1.5 Implement `Unavailable<T>` variant with reason string
- [ ] 1.6 Refactor; full suite stays green

## 2. Bootstrap wiring

- [ ] 2.1 Wire `DesktopCapabilityRegistry` into `AppServices` constructor
- [ ] 2.2 Register tray, shortcuts, file assoc, drop, PDF viewer, updater adapters in bootstrap with idempotent guards
- [ ] 2.3 Refactor; full suite stays green

## 3. Updater fail-closed

- [ ] 3.1 Write failing test `test_updater_unavailable_without_policy` — verify updater reports unavailable when no signing policy
- [ ] 3.2 Implement updater availability state exposed via registry
- [ ] 3.3 Refactor; full suite stays green
- [ ] 3.4 Write failing test `test_untrusted_update_rejected` — verify update blocked without trusted root
- [ ] 3.5 Implement deny-all gate in updater service
- [ ] 3.6 Refactor; full suite stays green
- [ ] 3.7 Write failing test `test_updater_unavailable_no_policy` — verify UI shows unavailable message
- [ ] 3.8 Implement updater unavailable UI state
- [ ] 3.9 Refactor; full suite stays green
- [ ] 3.10 Write failing tests for remaining updater scenarios (update available, download/install, cancelled, signing failure, no update)
- [ ] 3.11 Implement updater notification, download, cancel, signing verification flows
- [ ] 3.12 Refactor; full suite stays green

## 4. Window state persistence

- [ ] 4.1 Write failing test `test_window_state_persistence` — verify bounds restored after reload
- [ ] 4.2 Implement window state serialization/deserialization with SharedPreferences
- [ ] 4.3 Refactor; full suite stays green
- [ ] 4.4 Write failing test `test_minimum_size_enforcement` — verify 960x640 minimum
- [ ] 4.5 Update minimum size constants in window_state.dart and main.dart
- [ ] 4.6 Refactor; full suite stays green
- [ ] 4.7 Write failing test `test_maximize_state_persistence` — verify maximized flag restored
- [ ] 4.8 Implement maximize state save/restore
- [ ] 4.9 Refactor; full suite stays green
- [ ] 4.10 Write failing test `test_window_state_corruption_recovery` — verify fallback on invalid bounds
- [ ] 4.11 Implement bounds validation with fallback to defaults
- [ ] 4.12 Refactor; full suite stays green

## 5. Platform profile paths

- [ ] 5.1 Write failing tests `test_macos_profile_path`, `test_linux_profile_path`, `test_windows_profile_path`
- [ ] 5.2 Update `data_paths.dart` to use `OpenAccounting` and `profiles/<name>/` structure
- [ ] 5.3 Refactor; full suite stays green

## 6. Documentation parity

- [ ] 6.1 Run `grep -r "FastAPI\|React\|Vite\|Tailwind\|Tauri\|Python" docs/ openspec/specs/` — confirm no active doc matches
- [ ] 6.2 Create `scripts/check_architecture_parity.sh` that fails on stale architecture identifiers
- [ ] 6.3 Run `openspec validate` — confirm desktop specs pass with no contradictions
- [ ] 6.4 Update stale docs (`docs/01-rechnungen.md` etc.) to remove obsolete architecture references
