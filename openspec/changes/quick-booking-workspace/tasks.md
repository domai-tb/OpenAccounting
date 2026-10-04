# Implementation Tasks

Do not create journal rows or claim execution until an independently accepted typed posting contract provides the required amount, tax, date, and stable source-identity inputs.

## 1. Enforce the accounting dependency gate

- [ ] 1.1 Confirm the accepted posting contract supplies the preset input fields; keep the execution action unavailable until that prerequisite is accepted.

## 2. Schnellbuchungen

- [ ] 2.1 Write failing test: `test_quick_booking_preset` in `test/features/quick_booking/quick_booking_execution_test.dart` for “Quick booking preset” (assert it fails for the right reason).
- [ ] 2.2 Implement the behavior specified by “Quick booking preset” in `specs/accounting/spec.md` to pass the preceding test.
- [ ] 2.3 Refactor the related code; focused tests and the full suite stay green.
- [ ] 2.4 Write failing test: `test_quick_booking_execution` in `test/features/quick_booking/quick_booking_execution_test.dart` for “Quick booking execution” (assert it fails for the right reason).
- [ ] 2.5 Implement the behavior specified by “Quick booking execution” in `specs/accounting/spec.md` to pass the preceding test.
- [ ] 2.6 Refactor the related code; focused tests and the full suite stay green.
- [ ] 2.7 Write failing test: `test_quick_booking_with_invalid_preset` in `test/features/quick_booking/quick_booking_execution_test.dart` for “Quick booking with invalid preset” (assert it fails for the right reason).
- [ ] 2.8 Implement the behavior specified by “Quick booking with invalid preset” in `specs/accounting/spec.md` to pass the preceding test.
- [ ] 2.9 Refactor the related code; focused tests and the full suite stay green.

## 3. Quick-booking presets store explicit execution semantics

- [ ] 3.1 Write failing test: `test_fresh_schema_stores_the_complete_preset_contract` in `test/core/db/quick_booking_migration_test.dart` for “Fresh schema stores the complete preset contract” (assert it fails for the right reason).
- [ ] 3.2 Implement the behavior specified by “Fresh schema stores the complete preset contract” in `specs/db/spec.md` to pass the preceding test.
- [ ] 3.3 Refactor the related code; focused tests and the full suite stay green.
- [ ] 3.4 Write failing test: `test_legacy_preset_migration_preserves_values` in `test/core/db/quick_booking_migration_test.dart` for “Legacy preset migration preserves values” (assert it fails for the right reason).
- [ ] 3.5 Implement the behavior specified by “Legacy preset migration preserves values” in `specs/db/spec.md` to pass the preceding test.
- [ ] 3.6 Refactor the related code; focused tests and the full suite stay green.
- [ ] 3.7 Write failing test: `test_failed_table_rebuild_rolls_back` in `test/core/db/quick_booking_migration_test.dart` for “Failed table rebuild rolls back” (assert it fails for the right reason).
- [ ] 3.8 Implement the behavior specified by “Failed table rebuild rolls back” in `specs/db/spec.md` to pass the preceding test.
- [ ] 3.9 Refactor the related code; focused tests and the full suite stay green.

## 4. Quick-booking presets preserve explicit transaction inputs

- [ ] 4.1 Write failing test: `test_create_a_complete_preset` in `test/features/quick_booking/quick_booking_workspace_test.dart` for “Create a complete preset” (assert it fails for the right reason).
- [ ] 4.2 Implement the behavior specified by “Create a complete preset” in `specs/quick-booking-workspace/spec.md` to pass the preceding test.
- [ ] 4.3 Refactor the related code; focused tests and the full suite stay green.
- [ ] 4.4 Write failing test: `test_legacy_preset_requires_review` in `test/features/quick_booking/quick_booking_workspace_test.dart` for “Legacy preset requires review” (assert it fails for the right reason).
- [ ] 4.5 Implement the behavior specified by “Legacy preset requires review” in `specs/quick-booking-workspace/spec.md` to pass the preceding test.
- [ ] 4.6 Refactor the related code; focused tests and the full suite stay green.
- [ ] 4.7 Write failing test: `test_referenced_configuration_is_no_longer_active` in `test/features/quick_booking/quick_booking_workspace_test.dart` for “Referenced configuration is no longer active” (assert it fails for the right reason).
- [ ] 4.8 Implement the behavior specified by “Referenced configuration is no longer active” in `specs/quick-booking-workspace/spec.md` to pass the preceding test.
- [ ] 4.9 Refactor the related code; focused tests and the full suite stay green.

## 5. Execute presets through approved accounting posting

- [ ] 5.1 Write failing test: `test_posting_service_accepts_the_preset` in `test/features/quick_booking/quick_booking_workspace_test.dart` for “Posting service accepts the preset” (assert it fails for the right reason).
- [ ] 5.2 Implement the behavior specified by “Posting service accepts the preset” in `specs/quick-booking-workspace/spec.md` to pass the preceding test.
- [ ] 5.3 Refactor the related code; focused tests and the full suite stay green.
- [ ] 5.4 Write failing test: `test_posting_contract_is_unavailable` in `test/features/quick_booking/quick_booking_workspace_test.dart` for “Posting contract is unavailable” (assert it fails for the right reason).
- [ ] 5.5 Implement the behavior specified by “Posting contract is unavailable” in `specs/quick-booking-workspace/spec.md` to pass the preceding test.
- [ ] 5.6 Refactor the related code; focused tests and the full suite stay green.
- [ ] 5.7 Write failing test: `test_preset_has_no_default_amount` in `test/features/quick_booking/quick_booking_workspace_test.dart` for “Preset has no default amount” (assert it fails for the right reason).
- [ ] 5.8 Implement the behavior specified by “Preset has no default amount” in `specs/quick-booking-workspace/spec.md` to pass the preceding test.
- [ ] 5.9 Refactor the related code; focused tests and the full suite stay green.

## 6. Quick Bookings compose within Banking without changing other views

- [ ] 6.1 Write failing test: `test_open_quick_bookings_and_return_to_import_state` in `test/features/quick_booking/quick_booking_workspace_test.dart` for “Open Quick Bookings and return to import state” (assert it fails for the right reason).
- [ ] 6.2 Implement the behavior specified by “Open Quick Bookings and return to import state” in `specs/quick-booking-workspace/spec.md` to pass the preceding test.
- [ ] 6.3 Refactor the related code; focused tests and the full suite stay green.
- [ ] 6.4 Write failing test: `test_execution_is_unavailable` in `test/features/quick_booking/quick_booking_workspace_test.dart` for “Execution is unavailable” (assert it fails for the right reason).
- [ ] 6.5 Implement the behavior specified by “Execution is unavailable” in `specs/quick-booking-workspace/spec.md` to pass the preceding test.
- [ ] 6.6 Refactor the related code; focused tests and the full suite stay green.

## 7. Quick Bookings follow the desktop design schema

- [ ] 7.1 Write failing test: `test_preset_management_is_keyboard_accessible` in `test/features/quick_booking/quick_booking_workspace_test.dart` for “Preset management is keyboard accessible” (assert it fails for the right reason).
- [ ] 7.2 Implement the behavior specified by “Preset management is keyboard accessible” in `specs/quick-booking-workspace/spec.md` to pass the preceding test.
- [ ] 7.3 Refactor the related code; focused tests and the full suite stay green.

## 8. Quick-booking Banking view state

- [ ] 8.1 Write failing test: `test_quick_booking_view_uses_typed_route_state` in `test/core/router/quick_booking_route_test.dart` for “Quick-booking view uses typed route state” (assert it fails for the right reason).
- [ ] 8.2 Implement the behavior specified by “Quick-booking view uses typed route state” in `specs/typed-route-workspaces/spec.md` to pass the preceding test.
- [ ] 8.3 Refactor the related code; focused tests and the full suite stay green.
- [ ] 8.4 Write failing test: `test_database_outage_is_not_an_empty_quick_booking_view` in `test/core/router/quick_booking_route_test.dart` for “Database outage is not an empty quick-booking view” (assert it fails for the right reason).
- [ ] 8.5 Implement the behavior specified by “Database outage is not an empty quick-booking view” in `specs/typed-route-workspaces/spec.md` to pass the preceding test.
- [ ] 8.6 Refactor the related code; focused tests and the full suite stay green.
