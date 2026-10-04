# Implementation Tasks

Keep search read-only and restricted to the typed fields, registered destinations, and canonical routes in the accepted design.

## 1. Global search shortcut has one production intent

- [ ] 1.1 Write failing test: `test_global_search_shortcut_opens_the_palette` in `test/features/desktop/desktop_global_search_shortcut_test.dart` for “Global search shortcut opens the palette” (assert it fails for the right reason).
- [ ] 1.2 Implement the typed, profile-scoped behavior for “Global search shortcut opens the palette” in `specs/desktop-lifecycle-and-command-wiring/spec.md` to pass the preceding test.
- [ ] 1.3 Refactor the related code; focused tests and the full suite stay green.
- [ ] 1.4 Write failing test: `test_shortcut_does_not_consume_text_input` in `test/features/desktop/desktop_global_search_shortcut_test.dart` for “Shortcut does not consume text input” (assert it fails for the right reason).
- [ ] 1.5 Implement the typed, profile-scoped behavior for “Shortcut does not consume text input” in `specs/desktop-lifecycle-and-command-wiring/spec.md` to pass the preceding test.
- [ ] 1.6 Refactor the related code; focused tests and the full suite stay green.
- [ ] 1.7 Write failing test: `test_shortcut_registration_is_unavailable` in `test/features/desktop/desktop_global_search_shortcut_test.dart` for “Shortcut registration is unavailable” (assert it fails for the right reason).
- [ ] 1.8 Implement the typed, profile-scoped behavior for “Shortcut registration is unavailable” in `specs/desktop-lifecycle-and-command-wiring/spec.md` to pass the preceding test.
- [ ] 1.9 Refactor the related code; focused tests and the full suite stay green.

## 2. Global search palette

- [ ] 2.1 Write failing test: `test_find_and_open_a_business_record` in `test/features/global_search/global_business_search_test.dart` for “Find and open a business record” (assert it fails for the right reason).
- [ ] 2.2 Implement the typed, profile-scoped behavior for “Find and open a business record” in `specs/global-business-search/spec.md` to pass the preceding test.
- [ ] 2.3 Refactor the related code; focused tests and the full suite stay green.
- [ ] 2.4 Write failing test: `test_find_and_select_a_bank_transaction` in `test/features/global_search/global_business_search_test.dart` for “Find and select a bank transaction” (assert it fails for the right reason).
- [ ] 2.5 Implement the typed, profile-scoped behavior for “Find and select a bank transaction” in `specs/global-business-search/spec.md` to pass the preceding test.
- [ ] 2.6 Refactor the related code; focused tests and the full suite stay green.
- [ ] 2.7 Write failing test: `test_search_includes_supported_destination_and_command` in `test/features/global_search/global_business_search_test.dart` for “Search includes supported destination and command” (assert it fails for the right reason).
- [ ] 2.8 Implement the typed, profile-scoped behavior for “Search includes supported destination and command” in `specs/global-business-search/spec.md` to pass the preceding test.
- [ ] 2.9 Refactor the related code; focused tests and the full suite stay green.
- [ ] 2.10 Write failing test: `test_search_fails_without_fabricating_records` in `test/features/global_search/global_business_search_test.dart` for “Search fails without fabricating records” (assert it fails for the right reason).
- [ ] 2.11 Implement the typed, profile-scoped behavior for “Search fails without fabricating records” in `specs/global-business-search/spec.md` to pass the preceding test.
- [ ] 2.12 Refactor the related code; focused tests and the full suite stay green.
- [ ] 2.13 Write failing test: `test_empty_search_and_unsupported_fields` in `test/features/global_search/global_business_search_test.dart` for “Empty search and unsupported fields” (assert it fails for the right reason).
- [ ] 2.14 Implement the typed, profile-scoped behavior for “Empty search and unsupported fields” in `specs/global-business-search/spec.md` to pass the preceding test.
- [ ] 2.15 Refactor the related code; focused tests and the full suite stay green.

## 3. Search palette interaction and accessibility

- [ ] 3.1 Write failing test: `test_keyboard_search_preserves_the_current_page` in `test/features/global_search/global_business_search_test.dart` for “Keyboard search preserves the current page” (assert it fails for the right reason).
- [ ] 3.2 Implement the typed, profile-scoped behavior for “Keyboard search preserves the current page” in `specs/global-business-search/spec.md` to pass the preceding test.
- [ ] 3.3 Refactor the related code; focused tests and the full suite stay green.
- [ ] 3.4 Write failing test: `test_keyboard_and_assistive_technology_navigation` in `test/features/global_search/global_business_search_test.dart` for “Keyboard and assistive-technology navigation” (assert it fails for the right reason).
- [ ] 3.5 Implement the typed, profile-scoped behavior for “Keyboard and assistive-technology navigation” in `specs/global-business-search/spec.md` to pass the preceding test.
- [ ] 3.6 Refactor the related code; focused tests and the full suite stay green.
- [ ] 3.7 Write failing test: `test_narrow_window_palette` in `test/features/global_search/global_business_search_test.dart` for “Narrow-window palette” (assert it fails for the right reason).
- [ ] 3.8 Implement the typed, profile-scoped behavior for “Narrow-window palette” in `specs/global-business-search/spec.md` to pass the preceding test.
- [ ] 3.9 Refactor the related code; focused tests and the full suite stay green.

## 4. Business-document search and combined filters

- [ ] 4.1 Write failing test: `test_combine_invoice_criteria` in `test/core/typed_route_workspace_search_test.dart` for “Combine invoice criteria” (assert it fails for the right reason).
- [ ] 4.2 Implement the typed, profile-scoped behavior for “Combine invoice criteria” in `specs/typed-route-workspaces/spec.md` to pass the preceding test.
- [ ] 4.3 Refactor the related code; focused tests and the full suite stay green.
- [ ] 4.4 Write failing test: `test_combine_receipt_and_banking_criteria` in `test/core/typed_route_workspace_search_test.dart` for “Combine receipt and banking criteria” (assert it fails for the right reason).
- [ ] 4.5 Implement the typed, profile-scoped behavior for “Combine receipt and banking criteria” in `specs/typed-route-workspaces/spec.md` to pass the preceding test.
- [ ] 4.6 Refactor the related code; focused tests and the full suite stay green.
- [ ] 4.7 Write failing test: `test_invalid_filter_or_query_failure` in `test/core/typed_route_workspace_search_test.dart` for “Invalid filter or query failure” (assert it fails for the right reason).
- [ ] 4.8 Implement the typed, profile-scoped behavior for “Invalid filter or query failure” in `specs/typed-route-workspaces/spec.md` to pass the preceding test.
- [ ] 4.9 Refactor the related code; focused tests and the full suite stay green.
- [ ] 4.10 Write failing test: `test_clear_one_or_all_filters` in `test/core/typed_route_workspace_search_test.dart` for “Clear one or all filters” (assert it fails for the right reason).
- [ ] 4.11 Implement the typed, profile-scoped behavior for “Clear one or all filters” in `specs/typed-route-workspaces/spec.md` to pass the preceding test.
- [ ] 4.12 Refactor the related code; focused tests and the full suite stay green.

## 5. Banking selection is addressable through the canonical route

- [ ] 5.1 Write failing test: `test_open_a_selected_bank_transaction` in `test/core/typed_route_workspace_search_test.dart` for “Open a selected bank transaction” (assert it fails for the right reason).
- [ ] 5.2 Implement the typed, profile-scoped behavior for “Open a selected bank transaction” in `specs/typed-route-workspaces/spec.md` to pass the preceding test.
- [ ] 5.3 Refactor the related code; focused tests and the full suite stay green.
- [ ] 5.4 Write failing test: `test_invalid_or_missing_transaction_selection` in `test/core/typed_route_workspace_search_test.dart` for “Invalid or missing transaction selection” (assert it fails for the right reason).
- [ ] 5.5 Implement the typed, profile-scoped behavior for “Invalid or missing transaction selection” in `specs/typed-route-workspaces/spec.md` to pass the preceding test.
- [ ] 5.6 Refactor the related code; focused tests and the full suite stay green.
