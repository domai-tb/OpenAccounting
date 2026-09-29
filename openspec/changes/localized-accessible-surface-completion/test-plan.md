## Test Plan

All rows are intentionally 🔴 red because production and test files are not changed by this planning task. The test file must mount the real `OpenAccountingApp`/GoRouter composition with service fixtures and generated localization delegates.

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/localized-accessible-surface/spec.md → Locale-complete visible UI | English state copy is complete | test/integration/audit/localized_accessible_surface_completion_test.dart | `test_english_production_state_copy_is_complete` | 🔴 red |
| specs/localized-accessible-surface/spec.md → Locale-complete visible UI | German production state copy is complete | test/integration/audit/localized_accessible_surface_completion_test.dart | `test_german_production_state_copy_is_complete` | 🔴 red |
| specs/localized-accessible-surface/spec.md → Locale-complete visible UI | Locale formats accounting values | test/integration/audit/localized_accessible_surface_completion_test.dart | `test_locale_formats_accounting_values` | 🔴 red |
| specs/localized-accessible-surface/spec.md → Locale-complete visible UI | Missing translation fails validation | test/integration/audit/localized_accessible_surface_completion_test.dart | `test_unkeyed_visible_copy_and_app_spec_parity_fail_validation` | 🔴 red |
| specs/localized-accessible-surface/spec.md → Active-locale accounting formatting | Active locale formats accounting values | test/integration/audit/localized_accessible_surface_completion_test.dart | `test_active_locale_formats_accounting_values` | 🔴 red |
| specs/localized-accessible-surface/spec.md → Active-locale accounting formatting | German locale remains stable | test/integration/audit/localized_accessible_surface_completion_test.dart | `test_german_locale_remains_stable` | 🔴 red |
| specs/localized-accessible-surface/spec.md → Active-locale accounting formatting | Hardcoded German formatting fails English smoke | test/integration/audit/localized_accessible_surface_completion_test.dart | `test_hardcoded_german_formatting_fails_english_smoke` | 🔴 red |
| specs/localized-accessible-surface/spec.md → Live locale switching preserves navigation context | Locale switch preserves route and filters | test/integration/audit/localized_accessible_surface_completion_test.dart | `test_locale_switch_preserves_route_query_and_filters` | 🔴 red |
| specs/localized-accessible-surface/spec.md → Live locale switching preserves navigation context | Unsupported persisted locale falls back safely | test/integration/audit/localized_accessible_surface_completion_test.dart | `test_unsupported_persisted_locale_falls_back_safely` | 🔴 red |
| specs/localized-accessible-surface/spec.md → German and English application language contract | English selection persists across restart | test/integration/audit/localized_accessible_surface_completion_test.dart | `test_english_selection_persists_across_restart` | 🔴 red |
| specs/localized-accessible-surface/spec.md → German and English application language contract | Locale persistence failure keeps the session usable | test/integration/audit/localized_accessible_surface_completion_test.dart | `test_locale_persistence_failure_keeps_session_usable` | 🔴 red |
| specs/localized-accessible-surface/spec.md → Production route and ARB parity coverage | Documented routes expose both locale catalogs | test/integration/audit/localized_accessible_surface_completion_test.dart | `test_documented_routes_expose_both_locale_catalogs` | 🔴 red |
| specs/localized-accessible-surface/spec.md → Production route and ARB parity coverage | Missing required route-state key fails parity check | test/integration/audit/localized_accessible_surface_completion_test.dart | `test_missing_required_route_state_key_fails_parity_check` | 🔴 red |
| specs/localized-accessible-surface/spec.md → Localized accessible interaction states | Localized control keeps keyboard and focus semantics | test/integration/audit/localized_accessible_surface_completion_test.dart | `test_localized_control_keeps_keyboard_and_focus_semantics` | 🔴 red |
| specs/localized-accessible-surface/spec.md → Localized accessible interaction states | Narrow loading and error states remain reachable | test/integration/audit/localized_accessible_surface_completion_test.dart | `test_narrow_loading_and_error_states_remain_reachable` | 🔴 red |

## Coverage Notes

The required-key manifest is part of the planned parity test and must be explicit before implementation. The existing 15 red rows remain unchanged; `/setup` and `/inventory` are added to the route fixture covered by `test_documented_routes_expose_both_locale_catalogs`. The existing `Missing translation fails validation` row also owns the app-spec parity assertion, so parity is part of the 15-row TDD ledger rather than an unlisted task.

| Route/surface | Required key groups | State fixtures |
|---------------|---------------------|----------------|
| `/` dashboard | `app.*`, `dashboard.*`, `global.*` | loading, data, empty, error, refresh, customize |
| `/settings` | `settings.*`, `language.*`, `theme.*`, `privacy.*`, `global.*` | data, preference-write failure, dialog, tooltip |
| `/banking` | `banking.*`, `import.*`, `global.*` | file selection, CSV dialog, loading, preview, empty, failed rows, retry, history |
| `/invoices` | `invoices.*`, `document.*`, `global.*` | list loading/empty/error, editor actions, detail, PDF action, not-found |
| `/receipts` | `receipts.*`, `document.*`, `global.*` | loading, empty, import action, error, retry |
| `/contacts` | `contacts.*`, `global.*` | loading, data, empty, create dialog, error |
| `/taxes` | `taxes.*`, `reports.*`, `global.*` | loading, data, empty, export action, error |
| `/reports` | `reports.*`, `global.*` | loading, data, empty, date controls, error |
| `/help` | `help.*`, `global.*` | headings, links, empty/error state |
| `/setup` | `setup.*`, `global.*` | wizard loading, company/account/category steps, validation failure, persistence failure, completion, retry |
| `/inventory` | `inventory.*`, `global.*`, `a11y.*` | unavailable boundary, read-only explanation, retry/back action, no generic data fallback |
| shared controls | `a11y.*`, `global.*` | focus, selected state, keyboard activation, narrow overflow |

The manifest must include at least `setupTitle`, `setupStart`, `setupStep`, `setupCompanyName`, `setupIban`, `setupCashBalance`, `setupCategories`, `setupRequired`, `setupInvalidIban`, `setupDatabaseError`, `setupRetry`, `setupComplete`, `inventoryTitle`, `inventoryUnavailable`, `inventoryUnavailableDescription`, `inventoryReadOnly`, `inventoryRetry`, and `inventoryBack` in both ARB files. The parity test must assert equal key sets for `l10n_de.arb` and `l10n_en.arb`, require every manifest key in both files, and report the missing locale/key. Display assertions normalize Intl non-breaking spaces; semantic labels use exact localized strings.

The single `test_documented_routes_expose_both_locale_catalogs` row must execute these concrete production assertions for both locales: `assertLocalizedRoute('/')`, `assertLocalizedRoute('/settings')`, `assertLocalizedRoute('/banking')`, `assertLocalizedRoute('/invoices')`, `assertLocalizedRoute('/receipts')`, `assertLocalizedRoute('/contacts')`, `assertLocalizedRoute('/taxes')`, `assertLocalizedRoute('/reports')`, `assertLocalizedRoute('/help')`, `assertSetupWizardFailureState()`, `assertSetupWizardCompletionState()`, `assertInventoryUnavailableState()`, `assertInventoryReadOnlyState()`, and `assertInventoryRetryAction()`. These assertions must use the real router and service fixtures, not a route-name list.

The active-locale formatter coverage in `test_active_locale_formats_accounting_values` and `test_locale_formats_accounting_values` must exercise `formatMoney`, `formatDate`, and `formatDateLong` from both `app_money.dart` and `AppTypography`, plus `MoneyText`, `finance_list_surface.dart`, bank-import page/service date helpers, invoice-document formatting, and PDF/document date paths where visible. PDF acceptance must additionally generate the same snapshot through the production finalize boundary with `de_DE` and `en_US`, extract text, and assert localized labels/date/number/currency output. `test_hardcoded_german_formatting_fails_english_smoke` must include the source guard that rejects implicit `de_DE` defaults or omitted active-locale propagation; existing assertions that call `formatMoney(...)` or `AppTypography.formatDate(...)` without an active locale are migration targets, not acceptance evidence.

The `test_unkeyed_visible_copy_and_app_spec_parity_fail_validation` row must fail when either a visible source string lacks an ARB key or `openspec/specs/app/spec.md` retains the German-only requirement. Its implementation task must update that exact base requirement to the approved German-primary/English-secondary contract while preserving German informal `Du` wording.

Platform static evidence is required, without runtime claims:

- macOS: `test -f macos/Runner/Info.plist`, `test -f macos/Runner/AppDelegate.swift`, `test -f macos/Runner.xcodeproj/project.pbxproj`, `test -f macos/Runner.xcworkspace/contents.xcworkspacedata`, and `test ! -e macos/Podfile` (the Podfile absence is expected evidence in this repository); then `rg -n "GeneratedPluginRegistrant|CFBundle|openaccounting" macos/Runner macos/Flutter` and `rg -n "dart.library.io|Platform.isMacOS" lib macos`.
- Windows: `test -f windows/CMakeLists.txt`, `test -f windows/runner/Runner.rc`, `test -f windows/runner/main.cpp`, `test -f windows/runner/runner.exe.manifest`; then `rg -n "generated_plugin_registrant|PRODUCT_VERSION|openaccounting|Runner.exe" windows/` and `rg -n "dart.library.io|Platform.isWindows" lib windows/`. The Windows scans must stay rooted at `windows/` and must not inspect macOS files.

Linux runs the production route smoke and debug build. macOS and Windows are static tree/manifest/conditional-branch checks only on this host.
