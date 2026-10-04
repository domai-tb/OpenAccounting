## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/desktop-lifecycle-and-command-wiring/spec.md → Global search shortcut has one production intent | Global search shortcut opens the palette | test/features/desktop/desktop_global_search_shortcut_test.dart | test_global_search_shortcut_opens_the_palette | 🔴 red |
| specs/desktop-lifecycle-and-command-wiring/spec.md → Global search shortcut has one production intent | Shortcut does not consume text input | test/features/desktop/desktop_global_search_shortcut_test.dart | test_shortcut_does_not_consume_text_input | 🔴 red |
| specs/desktop-lifecycle-and-command-wiring/spec.md → Global search shortcut has one production intent | Shortcut registration is unavailable | test/features/desktop/desktop_global_search_shortcut_test.dart | test_shortcut_registration_is_unavailable | 🔴 red |
| specs/global-business-search/spec.md → Global search palette | Find and open a business record | test/features/global_search/global_business_search_test.dart | test_find_and_open_a_business_record | 🔴 red |
| specs/global-business-search/spec.md → Global search palette | Find and select a bank transaction | test/features/global_search/global_business_search_test.dart | test_find_and_select_a_bank_transaction | 🔴 red |
| specs/global-business-search/spec.md → Global search palette | Search includes supported destination and command | test/features/global_search/global_business_search_test.dart | test_search_includes_supported_destination_and_command | 🔴 red |
| specs/global-business-search/spec.md → Global search palette | Search fails without fabricating records | test/features/global_search/global_business_search_test.dart | test_search_fails_without_fabricating_records | 🔴 red |
| specs/global-business-search/spec.md → Global search palette | Empty search and unsupported fields | test/features/global_search/global_business_search_test.dart | test_empty_search_and_unsupported_fields | 🔴 red |
| specs/global-business-search/spec.md → Search palette interaction and accessibility | Keyboard search preserves the current page | test/features/global_search/global_business_search_test.dart | test_keyboard_search_preserves_the_current_page | 🔴 red |
| specs/global-business-search/spec.md → Search palette interaction and accessibility | Keyboard and assistive-technology navigation | test/features/global_search/global_business_search_test.dart | test_keyboard_and_assistive_technology_navigation | 🔴 red |
| specs/global-business-search/spec.md → Search palette interaction and accessibility | Narrow-window palette | test/features/global_search/global_business_search_test.dart | test_narrow_window_palette | 🔴 red |
| specs/typed-route-workspaces/spec.md → Business-document search and combined filters | Combine invoice criteria | test/core/router/typed_route_workspace_search_test.dart | test_combine_invoice_criteria | 🔴 red |
| specs/typed-route-workspaces/spec.md → Business-document search and combined filters | Combine receipt and banking criteria | test/core/router/typed_route_workspace_search_test.dart | test_combine_receipt_and_banking_criteria | 🔴 red |
| specs/typed-route-workspaces/spec.md → Business-document search and combined filters | Invalid filter or query failure | test/core/router/typed_route_workspace_search_test.dart | test_invalid_filter_or_query_failure | 🔴 red |
| specs/typed-route-workspaces/spec.md → Business-document search and combined filters | Clear one or all filters | test/core/router/typed_route_workspace_search_test.dart | test_clear_one_or_all_filters | 🔴 red |
| specs/typed-route-workspaces/spec.md → Banking selection is addressable through the canonical route | Open a selected bank transaction | test/core/router/typed_route_workspace_search_test.dart | test_open_a_selected_bank_transaction | 🔴 red |
| specs/typed-route-workspaces/spec.md → Banking selection is addressable through the canonical route | Invalid or missing transaction selection | test/core/router/typed_route_workspace_search_test.dart | test_invalid_or_missing_transaction_selection | 🔴 red |
<!-- Non-executable change (docs/config/schema): map to a mechanical check instead. -->
<!-- | specs/<cap>/spec.md → <Requirement Name> | <Scenario Name> | openspec schema validate anvil | schema-validates | N/A — non-executable | -->

## Coverage Notes

<!-- Any notes on test infrastructure, shared fixtures, or test utilities needed. -->
<!-- For N/A — non-executable entries, justify why no code test exists and name the check that gates the change. -->

All 17 executable scenarios across the three delta specs have named Flutter tests. Desktop shortcut, typed route, and global search behavior remain separately testable. Every row starts red; no tests were run while preparing this plan.
