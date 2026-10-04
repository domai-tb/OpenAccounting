## Test Plan

<!-- Every scenario maps to one named executable test and starts red. -->
<!-- Flip each row to green only when its named test passes during apply. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/accounting/spec.md → Business-year report availability is explicit | Dashboard business-fiscal filter remains unavailable | test/features/accounting/fiscal_year_compatibility_test.dart | test_accounting_dashboard_business_fiscal_filter_remains_unavailable | 🔴 red |
| specs/accounting/spec.md → Business-year report availability is explicit | EÜR does not relabel a calendar year | test/features/accounting/fiscal_year_compatibility_test.dart | test_accounting_eur_does_not_relabel_a_calendar_year | 🔴 red |
| specs/accounting/spec.md → Business-year report availability is explicit | Explicit calendar-year EÜR remains available | test/features/accounting/fiscal_year_compatibility_test.dart | test_accounting_explicit_calendar_year_eur_remains_available | 🔴 red |
| specs/db/spec.md → Company fiscal-year start month migration | Fresh company schema defaults to January | test/db/fiscal_year_migration_test.dart | test_db_fresh_company_schema_defaults_to_january | 🔴 red |
| specs/db/spec.md → Company fiscal-year start month migration | Existing company rows are migrated | test/db/fiscal_year_migration_test.dart | test_db_existing_company_rows_are_migrated | 🔴 red |
| specs/db/spec.md → Company fiscal-year start month migration | Migration failure preserves the prior database | test/db/fiscal_year_migration_test.dart | test_db_migration_failure_preserves_the_prior_database | 🔴 red |
| specs/fiscal-year-calendar/spec.md → Company fiscal-year configuration | Existing profile retains calendar year default | test/features/accounting/fiscal_year_calendar_test.dart | test_fiscal_year_calendar_existing_profile_retains_calendar_year_default | 🔴 red |
| specs/fiscal-year-calendar/spec.md → Company fiscal-year configuration | User configures an alternate start month | test/features/accounting/fiscal_year_calendar_test.dart | test_fiscal_year_calendar_user_configures_an_alternate_start_month | 🔴 red |
| specs/fiscal-year-calendar/spec.md → Company fiscal-year configuration | Invalid configuration is rejected | test/features/accounting/fiscal_year_calendar_test.dart | test_fiscal_year_calendar_invalid_configuration_is_rejected | 🔴 red |
| specs/fiscal-year-calendar/spec.md → Company fiscal-year configuration | Save failure retains the persisted setting | test/features/accounting/fiscal_year_calendar_test.dart | test_fiscal_year_calendar_save_failure_retains_the_persisted_setting | 🔴 red |
| specs/fiscal-year-calendar/spec.md → Shared fiscal-year boundaries | Date belongs to a fiscal year starting in January | test/features/accounting/fiscal_year_calendar_test.dart | test_fiscal_year_calendar_date_belongs_to_a_fiscal_year_starting_in_january | 🔴 red |
| specs/fiscal-year-calendar/spec.md → Shared fiscal-year boundaries | Date before the configured start month | test/features/accounting/fiscal_year_calendar_test.dart | test_fiscal_year_calendar_date_before_the_configured_start_month | 🔴 red |
| specs/fiscal-year-calendar/spec.md → Shared fiscal-year boundaries | Date on the configured start month boundary | test/features/accounting/fiscal_year_calendar_test.dart | test_fiscal_year_calendar_date_on_the_configured_start_month_boundary | 🔴 red |
| specs/fiscal-year-calendar/spec.md → Shared fiscal-year boundaries | Fiscal month and quarter follow the configured start | test/features/accounting/fiscal_year_calendar_test.dart | test_fiscal_year_calendar_fiscal_month_and_quarter_follow_the_configured_start | 🔴 red |
| specs/fiscal-year-calendar/spec.md → Shared fiscal-year boundaries | Invalid fiscal month or quarter index is rejected | test/features/accounting/fiscal_year_calendar_test.dart | test_fiscal_year_calendar_invalid_fiscal_month_or_quarter_index_is_rejected | 🔴 red |
| specs/fiscal-year-calendar/spec.md → Shared fiscal-year boundaries | Tax filing period remains separately owned | test/features/accounting/fiscal_year_calendar_test.dart | test_fiscal_year_calendar_tax_filing_period_remains_separately_owned | 🔴 red |
| specs/fiscal-year-calendar/spec.md → Shared fiscal-year boundaries | Calendar-only EÜR is unavailable for an alternate fiscal year | test/features/accounting/fiscal_year_calendar_test.dart | test_fiscal_year_calendar_calendar_only_eur_is_unavailable_for_an_alternate_fiscal_year | 🔴 red |
| specs/fiscal-year-calendar/spec.md → Shared fiscal-year boundaries | EÜR consumes the configured fiscal boundary | test/features/accounting/fiscal_year_calendar_test.dart | test_fiscal_year_calendar_eur_consumes_the_configured_fiscal_boundary | 🔴 red |
| specs/fiscal-year-calendar/spec.md → Fiscal-year configuration follows the design system | User saves a setting with keyboard controls | test/features/accounting/fiscal_year_calendar_test.dart | test_fiscal_year_calendar_user_saves_a_setting_with_keyboard_controls | 🔴 red |
| specs/fiscal-year-calendar/spec.md → Fiscal-year configuration follows the design system | Save failure keeps the fiscal setting accessible and unchanged | test/features/accounting/fiscal_year_calendar_test.dart | test_fiscal_year_calendar_save_failure_keeps_the_fiscal_setting_accessible_and_unchanged | 🔴 red |
| specs/stammdaten/spec.md → Company fiscal-year settings | Company settings display saved fiscal year | test/app/fiscal_year_settings_test.dart | test_stammdaten_company_settings_display_saved_fiscal_year | 🔴 red |
| specs/stammdaten/spec.md → Company fiscal-year settings | Company settings reject an invalid update | test/app/fiscal_year_settings_test.dart | test_stammdaten_company_settings_reject_an_invalid_update | 🔴 red |

## Coverage Notes

All 22 spec scenarios map to executable tests and begin red. Database migration, company-settings UI/use-case, fiscal boundary calculations, and explicit calendar-year versus business-year EÜR behavior use separate focused test files. No tests were run while completing these planning artifacts.
