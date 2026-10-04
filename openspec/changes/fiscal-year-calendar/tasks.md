## 1. Business-year report availability is explicit

- [ ] 1.1 Write failing test `test_accounting_dashboard_business_fiscal_filter_remains_unavailable` from `test-plan.md` (assert it fails for the right reason)
- [ ] 1.2 Implement the `Dashboard business-fiscal filter remains unavailable` behavior from `specs/accounting/spec.md` to pass 1.1
- [ ] 1.3 Refactor; full suite stays green
- [ ] 1.4 Write failing test `test_accounting_eur_does_not_relabel_a_calendar_year` from `test-plan.md` (assert it fails for the right reason)
- [ ] 1.5 Implement the `EÜR does not relabel a calendar year` behavior from `specs/accounting/spec.md` to pass 1.4
- [ ] 1.6 Refactor; full suite stays green
- [ ] 1.7 Write failing test `test_accounting_explicit_calendar_year_eur_remains_available` from `test-plan.md` (assert it fails for the right reason)
- [ ] 1.8 Implement the `Explicit calendar-year EÜR remains available` behavior from `specs/accounting/spec.md` to pass 1.7
- [ ] 1.9 Refactor; full suite stays green

## 2. Company fiscal-year start month migration

- [ ] 2.1 Write failing test `test_db_fresh_company_schema_defaults_to_january` from `test-plan.md` (assert it fails for the right reason)
- [ ] 2.2 Implement the `Fresh company schema defaults to January` behavior from `specs/db/spec.md` to pass 2.1
- [ ] 2.3 Refactor; full suite stays green
- [ ] 2.4 Write failing test `test_db_existing_company_rows_are_migrated` from `test-plan.md` (assert it fails for the right reason)
- [ ] 2.5 Implement the `Existing company rows are migrated` behavior from `specs/db/spec.md` to pass 2.4
- [ ] 2.6 Refactor; full suite stays green
- [ ] 2.7 Write failing test `test_db_migration_failure_preserves_the_prior_database` from `test-plan.md` (assert it fails for the right reason)
- [ ] 2.8 Implement the `Migration failure preserves the prior database` behavior from `specs/db/spec.md` to pass 2.7
- [ ] 2.9 Refactor; full suite stays green

## 3. Company fiscal-year configuration

- [ ] 3.1 Write failing test `test_fiscal_year_calendar_existing_profile_retains_calendar_year_default` from `test-plan.md` (assert it fails for the right reason)
- [ ] 3.2 Implement the `Existing profile retains calendar year default` behavior from `specs/fiscal-year-calendar/spec.md` to pass 3.1
- [ ] 3.3 Refactor; full suite stays green
- [ ] 3.4 Write failing test `test_fiscal_year_calendar_user_configures_an_alternate_start_month` from `test-plan.md` (assert it fails for the right reason)
- [ ] 3.5 Implement the `User configures an alternate start month` behavior from `specs/fiscal-year-calendar/spec.md` to pass 3.4
- [ ] 3.6 Refactor; full suite stays green
- [ ] 3.7 Write failing test `test_fiscal_year_calendar_invalid_configuration_is_rejected` from `test-plan.md` (assert it fails for the right reason)
- [ ] 3.8 Implement the `Invalid configuration is rejected` behavior from `specs/fiscal-year-calendar/spec.md` to pass 3.7
- [ ] 3.9 Refactor; full suite stays green
- [ ] 3.10 Write failing test `test_fiscal_year_calendar_save_failure_retains_the_persisted_setting` from `test-plan.md` (assert it fails for the right reason)
- [ ] 3.11 Implement the `Save failure retains the persisted setting` behavior from `specs/fiscal-year-calendar/spec.md` to pass 3.10
- [ ] 3.12 Refactor; full suite stays green

## 4. Shared fiscal-year boundaries

- [ ] 4.1 Write failing test `test_fiscal_year_calendar_date_belongs_to_a_fiscal_year_starting_in_january` from `test-plan.md` (assert it fails for the right reason)
- [ ] 4.2 Implement the `Date belongs to a fiscal year starting in January` behavior from `specs/fiscal-year-calendar/spec.md` to pass 4.1
- [ ] 4.3 Refactor; full suite stays green
- [ ] 4.4 Write failing test `test_fiscal_year_calendar_date_before_the_configured_start_month` from `test-plan.md` (assert it fails for the right reason)
- [ ] 4.5 Implement the `Date before the configured start month` behavior from `specs/fiscal-year-calendar/spec.md` to pass 4.4
- [ ] 4.6 Refactor; full suite stays green
- [ ] 4.7 Write failing test `test_fiscal_year_calendar_date_on_the_configured_start_month_boundary` from `test-plan.md` (assert it fails for the right reason)
- [ ] 4.8 Implement the `Date on the configured start month boundary` behavior from `specs/fiscal-year-calendar/spec.md` to pass 4.7
- [ ] 4.9 Refactor; full suite stays green
- [ ] 4.10 Write failing test `test_fiscal_year_calendar_fiscal_month_and_quarter_follow_the_configured_start` from `test-plan.md` (assert it fails for the right reason)
- [ ] 4.11 Implement the `Fiscal month and quarter follow the configured start` behavior from `specs/fiscal-year-calendar/spec.md` to pass 4.10
- [ ] 4.12 Refactor; full suite stays green
- [ ] 4.13 Write failing test `test_fiscal_year_calendar_invalid_fiscal_month_or_quarter_index_is_rejected` from `test-plan.md` (assert it fails for the right reason)
- [ ] 4.14 Implement the `Invalid fiscal month or quarter index is rejected` behavior from `specs/fiscal-year-calendar/spec.md` to pass 4.13
- [ ] 4.15 Refactor; full suite stays green
- [ ] 4.16 Write failing test `test_fiscal_year_calendar_tax_filing_period_remains_separately_owned` from `test-plan.md` (assert it fails for the right reason)
- [ ] 4.17 Implement the `Tax filing period remains separately owned` behavior from `specs/fiscal-year-calendar/spec.md` to pass 4.16
- [ ] 4.18 Refactor; full suite stays green
- [ ] 4.19 Write failing test `test_fiscal_year_calendar_calendar_only_eur_is_unavailable_for_an_alternate_fiscal_year` from `test-plan.md` (assert it fails for the right reason)
- [ ] 4.20 Implement the `Calendar-only EÜR is unavailable for an alternate fiscal year` behavior from `specs/fiscal-year-calendar/spec.md` to pass 4.19
- [ ] 4.21 Refactor; full suite stays green
- [ ] 4.22 Write failing test `test_fiscal_year_calendar_eur_consumes_the_configured_fiscal_boundary` from `test-plan.md` (assert it fails for the right reason)
- [ ] 4.23 Implement the `EÜR consumes the configured fiscal boundary` behavior from `specs/fiscal-year-calendar/spec.md` to pass 4.22
- [ ] 4.24 Refactor; full suite stays green

## 5. Fiscal-year configuration follows the design system

- [ ] 5.1 Write failing test `test_fiscal_year_calendar_user_saves_a_setting_with_keyboard_controls` from `test-plan.md` (assert it fails for the right reason)
- [ ] 5.2 Implement the `User saves a setting with keyboard controls` behavior from `specs/fiscal-year-calendar/spec.md` to pass 5.1
- [ ] 5.3 Refactor; full suite stays green
- [ ] 5.4 Write failing test `test_fiscal_year_calendar_save_failure_keeps_the_fiscal_setting_accessible_and_unchanged` from `test-plan.md` (assert it fails for the right reason)
- [ ] 5.5 Implement the `Save failure keeps the fiscal setting accessible and unchanged` behavior from `specs/fiscal-year-calendar/spec.md` to pass 5.4
- [ ] 5.6 Refactor; full suite stays green

## 6. Company fiscal-year settings

- [ ] 6.1 Write failing test `test_stammdaten_company_settings_display_saved_fiscal_year` from `test-plan.md` (assert it fails for the right reason)
- [ ] 6.2 Implement the `Company settings display saved fiscal year` behavior from `specs/stammdaten/spec.md` to pass 6.1
- [ ] 6.3 Refactor; full suite stays green
- [ ] 6.4 Write failing test `test_stammdaten_company_settings_reject_an_invalid_update` from `test-plan.md` (assert it fails for the right reason)
- [ ] 6.5 Implement the `Company settings reject an invalid update` behavior from `specs/stammdaten/spec.md` to pass 6.4
- [ ] 6.6 Refactor; full suite stays green
