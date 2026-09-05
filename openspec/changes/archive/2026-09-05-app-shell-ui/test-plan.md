## Test Plan

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/app-shell/spec.md → Desktop Shell Layout | Shell renders on every primary route | test/app/app_shell_test.dart | test_shell_renders_on_every_primary_route | 🔴 red |
| specs/app-shell/spec.md → Desktop Shell Layout | Shell does not render as black full-screen fallback | test/app/app_shell_test.dart | test_shell_not_black_fallback | 🔴 red |
| specs/app-shell/spec.md → Sidebar Navigation | Expanded sidebar at wide window | test/app/app_shell_test.dart | test_sidebar_expanded_at_1280 | 🔴 red |
| specs/app-shell/spec.md → Sidebar Navigation | Compact rail at medium window | test/app/app_shell_test.dart | test_sidebar_compact_at_1024 | 🔴 red |
| specs/app-shell/spec.md → Sidebar Navigation | Drawer at narrow window | test/app/app_shell_test.dart | test_sidebar_drawer_at_800 | 🔴 red |
| specs/app-shell/spec.md → Sidebar Navigation | Sidebar collapses and persists | test/app/app_shell_test.dart | test_sidebar_collapses_and_persists | 🔴 red |
| specs/app-shell/spec.md → Sidebar Navigation | Sidebar navigation highlights correctly | test/app/app_shell_test.dart | test_sidebar_highlights_correctly | 🔴 red |
| specs/app-shell/spec.md → Page Header | Header shows title and primary action | test/design_system/app_page_header_test.dart | test_header_shows_title_and_primary | 🟢 green |
| specs/app-shell/spec.md → Page Header | Header filter toolbar present | test/design_system/app_page_header_test.dart | test_header_filter_toolbar_present | 🟢 green |
| specs/app-shell/spec.md → Page Header | Header without primary action still renders subtitle | test/design_system/app_page_header_test.dart | test_header_without_primary_shows_subtitle | 🟢 green |
| specs/app-shell/spec.md → Content Canvas and Layout Constraints | Form width constrained on ultrawide | test/design_system/app_page_test.dart | test_form_width_constrained_on_ultrawide | 🔴 red |
| specs/app-shell/spec.md → Content Canvas and Layout Constraints | Page padding adapts to window size | test/design_system/app_page_test.dart | test_page_padding_adapts | 🔴 red |
| specs/app-shell/spec.md → Content Canvas and Layout Constraints | Table uses full width | test/design_system/app_page_test.dart | test_table_uses_full_width | 🔴 red |
| specs/app-shell/spec.md → Optional Inspector | Inspector opens on row selection | test/design_system/app_inspector_test.dart | test_inspector_opens_on_selection | 🔴 red |
| specs/app-shell/spec.md → Optional Inspector | Inspector adapts at narrow width | test/design_system/app_inspector_test.dart | test_inspector_adapts_at_narrow | 🔴 red |
| specs/app-shell/spec.md → Window Behavior | Window respects minimum size | test/app/window_test.dart | test_window_respects_minimum_size | 🔴 red |
| specs/app-shell/spec.md → Window Behavior | Window state persists | test/app/window_test.dart | test_window_state_persists | 🔴 red |
| specs/app-theme/spec.md → Material 3 Theming | Light theme uses seed and correct surfaces | test/app/app_theme_test.dart | test_light_theme_seed_surfaces | 🔴 red |
| specs/app-theme/spec.md → Material 3 Theming | Dark theme avoids pure black | test/app/app_theme_test.dart | test_dark_theme_avoids_pure_black | 🔴 red |
| specs/app-theme/spec.md → Material 3 Theming | System mode follows platform | test/app/app_theme_test.dart | test_system_mode_follows_platform | 🔴 red |
| specs/app-theme/spec.md → Material 3 Theming | Theme toggle persists | test/app/app_theme_test.dart | test_theme_toggle_persists | 🔴 red |
| specs/app-theme/spec.md → Material 3 Theming | Invalid stored theme falls back to system | test/app/app_theme_test.dart | test_invalid_theme_falls_back | 🔴 red |
| specs/app-theme/spec.md → Typography and Locale | Financial number formatted for de-DE | test/l10n/format_test.dart | test_financial_number_de_de | 🔴 red |
| specs/app-theme/spec.md → Typography and Locale | Date formatted for de-DE | test/l10n/format_test.dart | test_date_formatted_de_de | 🔴 red |
| specs/app-theme/spec.md → Typography and Locale | Language switch without restart | test/l10n/locale_test.dart | test_language_switch_without_restart | 🔴 red |
| specs/app-theme/spec.md → Design Tokens | Shell uses tokens not raw values | test/design_system/tokens_test.dart | test_shell_uses_tokens | 🔴 red |
| specs/app-theme/spec.md → Design Tokens | Tokens lint | test/design_system/tokens_test.dart | test_tokens_lint | 🔴 red |
| specs/app-theme/spec.md → Semantic Accounting Colors | Status chip uses semantic colors with icon+text | test/design_system/app_status_chip_test.dart | test_status_chip_semantic | 🔴 red |
| specs/app-theme/spec.md → Semantic Accounting Colors | Hover state differs in dark theme | test/design_system/app_status_chip_test.dart | test_hover_state_differs_dark | 🔴 red |
| specs/app-theme/spec.md → Semantic Accounting Colors | Missing ThemeExtension falls back safely | test/design_system/app_status_chip_test.dart | test_missing_extension_fallback | 🔴 red |
| specs/app-theme/spec.md → Elevation, Borders and Radius Consistency | Card radius correct | test/design_system/app_card_test.dart | test_card_radius_correct | 🔴 red |
| specs/app-theme/spec.md → Elevation, Borders and Radius Consistency | Dialog radius and shadow | test/design_system/app_dialog_test.dart | test_dialog_radius_and_shadow | 🔴 red |
| specs/app/spec.md → Layout Structure | Sidebar taxonomy supersedes old sections | test/app/app_shell_test.dart | test_sidebar_taxonomy_supersedes_old | 🔴 red |
| specs/app/spec.md → Layout Structure | Old layout tests are retired | test/app/app_shell_test.dart | test_old_layout_tests_retired | 🔴 red |
| specs/app/spec.md → Layout Structure | Deep link still highlights correct section | test/app/app_shell_test.dart | test_deep_link_highlights_correct | 🔴 red |

## Coverage Notes

- Shell tests use `tester.view.physicalSize` + `pumpWidget` with `ProviderScope` and `GoRouter` memory config, no `window_manager` channel mock needed for layout (window size mocked via `view`).
- Theme tests verify `ThemeData.colorScheme.primary`, `scaffoldBackgroundColor`, `cardColor`, `dividerColor` via `AppTheme.light/dark` and `ThemeMode` persistence via `SharedPreferences.setMockInitialValues`.
- L10n tests use `AppLocalizations` from `assets/l10n` with `fvm flutter gen-l10n` output `lib/l10n/l10n.dart`.
- Tokens tests grep for `AppSpacing`/`AppRadius`/`AppDuration` usage; non-executable guard via `analysis_options` custom lint (informational).
- Shared fixtures: `createTestAppShell`, `createTestTheme`, `createTestRouter` helpers in `test/test_helpers.dart`.
