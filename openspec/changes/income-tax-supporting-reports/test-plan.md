## Test Plan

<!-- Every scenario in specs/ maps to a named test. -->
<!-- During implementation, flip 🟢 green to 🟢 green when its test passes. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/specs/accounting/spec.md → S/G report values require versioned accounting mappings | S/G source mapping is not accepted | test/features/accounting/income_tax_supporting_reports_test.dart | test_s_g_source_mapping_is_not_accepted | 🟢 green |
| specs/specs/accounting/spec.md → S/G report values require versioned accounting mappings | Schedule choice is explicit | test/features/accounting/income_tax_supporting_reports_test.dart | test_schedule_choice_is_explicit | 🟢 green |
| specs/specs/income-tax-supporting-reports/spec.md → Generate versioned S/G supporting workpapers from accounting records | Supported schedule fields have traceable values | test/features/income_tax_supporting_reports/income_tax_supporting_reports_test.dart | test_supported_schedule_fields_have_traceable_values | 🟢 green |
| specs/specs/income-tax-supporting-reports/spec.md → Generate versioned S/G supporting workpapers from accounting records | Unsupported tax-year form edition | test/features/income_tax_supporting_reports/income_tax_supporting_reports_test.dart | test_unsupported_tax_year_form_edition | 🟢 green |
| specs/specs/income-tax-supporting-reports/spec.md → Generate versioned S/G supporting workpapers from accounting records | Accounting source or classification is incomplete | test/features/income_tax_supporting_reports/income_tax_supporting_reports_test.dart | test_accounting_source_or_classification_is_incomplete | 🟢 green |
| specs/specs/income-tax-supporting-reports/spec.md → Generate versioned S/G supporting workpapers from accounting records | Workpaper is not filed | test/features/income_tax_supporting_reports/income_tax_supporting_reports_test.dart | test_workpaper_is_not_filed | 🟢 green |
| specs/specs/income-tax-supporting-reports/spec.md → S/G workpapers follow the desktop design system | Workpaper can be reviewed by keyboard | test/features/income_tax_supporting_reports/income_tax_supporting_reports_test.dart | test_workpaper_can_be_reviewed_by_keyboard | 🟢 green |
| specs/specs/typed-route-workspaces/spec.md → Income-tax supporting report view | Open an S/G supporting report | test/core/income_tax_supporting_reports_routes_test.dart | test_open_an_s_g_supporting_report | 🟢 green |
| specs/specs/typed-route-workspaces/spec.md → Income-tax supporting report view | Report service is unavailable | test/core/income_tax_supporting_reports_routes_test.dart | test_report_service_is_unavailable | 🟢 green |

## Coverage Notes

- Every scenario is mapped once to a named executable test; all rows start red.
- Tests use the repository’s Flutter test infrastructure and focused fixtures for the affected feature and persistence boundaries.
- These are planned tests; this artifact does not claim that the tests already exist or have passed.
