## 1. Locale catalog and parity red tests

- [ ] 1.1 Write failing test `test_missing_required_route_state_key_fails_parity_check` from the test plan; assert it fails because the required German/English route-state manifest is incomplete.
- [ ] 1.2 Implement the explicit route/state key manifest and equal-key validation for both ARB catalogs to pass 1.1.
- [ ] 1.3 Refactor catalog/parity helpers; focused and full suites stay green.

## 2. Production English state copy

- [ ] 2.1 Write failing test `test_english_production_state_copy_is_complete`; mount the real app and assert English labels/actions/tooltips/loading/empty/error copy across the documented routes, including setup wizard and inventory unavailable states.
- [ ] 2.2 Implement the English ARB keys and replace production German literals in router/settings, dashboard, setup, inventory, bank import, invoice/document, receipts, contacts, taxes, reports, and help surfaces.
- [ ] 2.3 Refactor shared localized widgets; focused and full suites stay green.

## 3. Production German state copy

- [ ] 3.1 Write failing test `test_german_production_state_copy_is_complete`; assert the same production states resolve to German catalog values and informal `Du` wording.
- [ ] 3.2 Implement the matching German ARB keys and translations without reintroducing route-local literals.
- [ ] 3.3 Refactor paired catalog values and remove duplicate wording; focused and full suites stay green.

## 4. Visible-string enforcement

- [ ] 4.1 Write failing test `test_unkeyed_visible_copy_and_app_spec_parity_fail_validation`; assert the scoped production source/key check reports an unkeyed visible string and the base app spec still contains the German-only requirement.
- [ ] 4.2 Implement the mechanical source/key check and wire it to the required-key manifest; include the exact `openspec/specs/app/spec.md` parity assertion in this same red test.
- [ ] 4.3 Refactor the check output for stable file/key diagnostics; focused and full suites stay green.

## 5. Active-locale money and date formatting

- [ ] 5.1 Write failing test `test_active_locale_formats_accounting_values`; assert English amount, decimal, short-date, long-date, and semantic-label output through production widgets and both `app_money.dart` and `AppTypography` helpers; generate the same PDF snapshot through the finalize boundary in German and English and inspect extracted text.
- [ ] 5.2 Implement an explicit active-locale boundary for `formatMoney`, `formatDate`, `formatDateLong`, `AppTypography.formatMoney`, `AppTypography.formatDate`, `AppTypography.formatDateLong`, `MoneyText`, all named shared/page formatter callers, and `PdfGenerator.generate`'s required render-locale input; remove implicit `de_DE` production defaults.
- [ ] 5.3 Refactor formatter call sites and normalize Intl whitespace only at assertions; focused and full suites stay green.

## 5b. Locale-complete accounting formatting regression

- [ ] 5b.1 Write failing test `test_locale_formats_accounting_values` for the base locale-complete scenario; assert date, decimal separator, currency symbol, and accessibility text use the active formatter.
- [ ] 5b.2 Implement the shared locale boundary so the base requirement's accounting scenario passes through the production route.
- [ ] 5b.3 Refactor the duplicate coverage into the shared formatter fixture; focused and full suites stay green.

## 6. German formatter regression

- [ ] 6.1 Write failing test `test_german_locale_remains_stable`; assert German separators, month order, and semantic labels through the same production path.
- [ ] 6.2 Implement the German formatter mapping and localized amount-hidden semantics.
- [ ] 6.3 Refactor duplicated locale conversion; focused and full suites stay green.

## 7. English hardcoded-format guard

- [ ] 7.1 Write failing test `test_hardcoded_german_formatting_fails_english_smoke`; assert English route smoke rejects German-only formatting or semantics and run the active-locale source guard over `AppTypography`, `app_money`, finance-list, bank-import, invoice-document, and PDF paths.
- [ ] 7.2 Remove remaining German-only formatter and accessibility defaults from production call paths, including `AppTypography` and page-local helpers.
- [ ] 7.3 Refactor the guard to identify the owning route/helper; focused and full suites stay green.

## 8. Live locale switch

- [ ] 8.1 Write failing test `test_locale_switch_preserves_route_query_and_filters`; switch locale using the real settings control and assert visible copy changes while URI/query/search/tab/filter remain unchanged.
- [ ] 8.2 Implement the localized settings controls while keeping the existing router provider and page state stable.
- [ ] 8.3 Refactor locale switch rebuild boundaries; focused and full suites stay green.

## 9. Safe locale fallback

- [ ] 9.1 Write failing test `test_unsupported_persisted_locale_falls_back_safely`; inject an unsupported stored code and assert deterministic German fallback with a complete catalog.
- [ ] 9.2 Implement the fallback and mixed-catalog guard in the locale loading path.
- [ ] 9.3 Refactor preference error handling; focused and full suites stay green.

## 10. Locale persistence

- [ ] 10.1 Write failing test `test_english_selection_persists_across_restart`; select English, rebuild the production root, and assert the first route uses English.
- [ ] 10.2 Implement persistence coverage through the existing `AppLocaleNotifier` without changing the storage contract.
- [ ] 10.3 Refactor startup locale loading; focused and full suites stay green.

- [ ] 10.4 Write failing test `test_locale_persistence_failure_keeps_session_usable`; reject the preference write and assert the current English session and route remain usable.
- [ ] 10.5 Implement the session-safe persistence failure path.
- [ ] 10.6 Refactor notifier error handling; focused and full suites stay green.

## 11. Full route catalog smoke

- [ ] 11.1 Write failing test `test_documented_routes_expose_both_locale_catalogs`; mount all 11 documented routes with representative fixtures in both locales and assert setup wizard failure/completion plus inventory unavailable/read-only/retry states through the real router.
- [ ] 11.2 Implement missing route-state keys and localized branches until the production smoke passes.
- [ ] 11.3 Refactor route fixture setup and keep all route, bank, and receivable behavior unchanged; focused and full suites stay green.

## 12. Keyboard and focus semantics

- [ ] 12.1 Write failing test `test_localized_control_keeps_keyboard_and_focus_semantics`; assert localized names, roles, selected state, Enter/Space activation, and visible focus.
- [ ] 12.2 Implement localized `Semantics` labels and preserve the existing keyboard/focus behavior.
- [ ] 12.3 Refactor semantic helpers; focused and full suites stay green.

- [ ] 12.4 Write failing test `test_narrow_loading_and_error_states_remain_reachable`; assert 320px loading, empty, data, and error actions remain reachable and localized.
- [ ] 12.5 Implement narrow-state labels/overflow semantics without changing the documented layout contract.
- [ ] 12.6 Refactor narrow-state test fixtures; focused and full suites stay green.

## 13. Specification parity and final gates

- [ ] 13.1 The existing red test `test_unkeyed_visible_copy_and_app_spec_parity_fail_validation` covers the stale German-only `openspec/specs/app/spec.md` requirement and the approved two-locale delta; assert it fails for the right parity reason.
- [ ] 13.2 Update the base app requirement to German-primary/English-secondary while preserving informal German `Du` wording; regenerate l10n and document no product-policy change.
- [ ] 13.3 Refactor documentation/spec references; run focused tests, `fvm flutter analyze`, full VM suite, strict OpenSpec validation, Linux debug build, the named macOS/Windows static `test`/`rg` checks, formatting, and `git diff --check`.

## 14. Platform static acceptance evidence

- [ ] 14.1 Run macOS static checks against the actual repository: verify `macos/Runner/Info.plist`, `macos/Runner/AppDelegate.swift`, `macos/Runner.xcodeproj/project.pbxproj`, and `macos/Runner.xcworkspace/contents.xcworkspacedata`; assert `macos/Podfile` is absent as expected; inspect macOS plugin/bundle and conditional-platform references with the named `rg` commands; record no runtime/build claim.
- [ ] 14.2 Run Windows static checks against `windows/` only: verify `windows/CMakeLists.txt`, `windows/runner/Runner.rc`, `windows/runner/main.cpp`, and `windows/runner/runner.exe.manifest`; inspect Windows plugin/version/executable and conditional-platform references with the named `rg` commands; record no runtime/build claim.
- [ ] 14.3 Refactor platform evidence into the verification record; Linux route/build evidence remains separate from macOS/Windows static evidence.
