## Test Plan

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/adaptive-shell-motion/spec.md → Width-aware shell motion | Rail expands without route loss | test/features/shell/adaptive_shell_test.dart | test_rail_expands_without_route_loss | 🔴 red |
| specs/adaptive-shell-motion/spec.md → Width-aware shell motion | Breakpoint edges preserve route and filters | test/features/shell/adaptive_shell_test.dart | test_breakpoint_edges_preserve_route_and_filters | 🔴 red |
| specs/adaptive-shell-motion/spec.md → Width-aware shell motion | Reduced motion bypasses animation | test/features/shell/adaptive_shell_test.dart | test_reduced_motion_bypasses_animation | 🔴 red |
| specs/adaptive-shell-motion/spec.md → Stable persisted navigation lifecycle | Persisted compact state is first-frame stable | test/features/shell/adaptive_shell_test.dart | test_persisted_compact_state_is_first_frame_stable | 🔴 red |
| specs/adaptive-shell-motion/spec.md → Stable persisted navigation lifecycle | Invalid preference uses safe default | test/features/shell/adaptive_shell_test.dart | test_invalid_preference_uses_safe_default | 🔴 red |
| specs/adaptive-shell-motion/spec.md → Stable persisted navigation lifecycle | Drawer navigation closes and preserves focus | test/features/shell/adaptive_shell_test.dart | test_drawer_navigation_closes_and_preserves_focus | 🔴 red |
| specs/adaptive-shell-motion/spec.md → Stable persisted navigation lifecycle | Preference write failure is recoverable | test/features/shell/adaptive_shell_test.dart | test_preference_write_failure_is_recoverable | 🔴 red |
| specs/loading-state-previews/spec.md → Content-shaped loading previews | Dashboard card shows skeleton content | test/features/state_surfaces/loading_state_test.dart | test_dashboard_card_shows_skeleton_content | 🔴 red |
| specs/loading-state-previews/spec.md → Content-shaped loading previews | Skeleton resolves to an error state | test/features/state_surfaces/loading_state_test.dart | test_skeleton_resolves_to_error_state | 🔴 red |
| specs/loading-state-previews/spec.md → Content-shaped loading previews | Routed page keeps title and controls while loading | test/features/state_surfaces/loading_state_test.dart | test_routed_page_keeps_title_and_controls_while_loading | 🔴 red |
| specs/loading-state-previews/spec.md → State transition identity | Empty list offers a primary action | test/features/state_surfaces/loading_state_test.dart | test_empty_list_offers_primary_action | 🔴 red |
| specs/loading-state-previews/spec.md → State transition identity | Failed request preserves context | test/features/state_surfaces/loading_state_test.dart | test_failed_request_preserves_context | 🔴 red |
| specs/loading-state-previews/spec.md → State transition identity | Failed mutation rolls back safely | test/features/state_surfaces/loading_state_test.dart | test_failed_mutation_rolls_back_safely | 🔴 red |
| specs/localized-accessible-surface/spec.md → Locale-complete visible UI | English state copy is complete | test/features/localized_accessible_surface/localized_test.dart | test_english_state_copy_is_complete | 🔴 red |
| specs/localized-accessible-surface/spec.md → Locale-complete visible UI | Missing translation fails validation | test/features/localized_accessible_surface/localized_test.dart | test_missing_translation_fails_validation | 🔴 red |
| specs/localized-accessible-surface/spec.md → Locale-complete visible UI | Locale formats accounting values | test/features/localized_accessible_surface/localized_test.dart | test_locale_formats_accounting_values | 🔴 red |
| specs/localized-accessible-surface/spec.md → Accessible keyboard and semantics contract | Focused navigation activates | test/features/localized_accessible_surface/accessible_test.dart | test_focused_navigation_activates | 🔴 red |
| specs/localized-accessible-surface/spec.md → Accessible keyboard and semantics contract | Narrow action remains reachable | test/features/localized_accessible_surface/accessible_test.dart | test_narrow_action_remains_reachable | 🔴 red |
| specs/localized-accessible-surface/spec.md → Accessible keyboard and semantics contract | Focus semantics survive state settling | test/features/localized_accessible_surface/accessible_test.dart | test_focus_semantics_survive_state_settling | 🔴 red |

## Coverage Notes

Tests use `FakeShellPreferences`, `FakeAnimationPolicy`, `FakeAsyncStateAdapter`, `TestClock` per design. First-frame hydration injects preferences before pump; reduced motion tests set `MediaQuery.disableAnimations` and persisted preference independently with zero-duration clock. `fvm flutter gen-l10n` and `fvm flutter test --dart-define=platform=vm` gate.
