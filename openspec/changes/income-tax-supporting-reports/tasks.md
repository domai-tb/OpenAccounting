## 1. accounting: S/G report values require versioned accounting mappings

- [ ] 1.1 Write failing test `test_s_g_source_mapping_is_not_accepted` in `test/features/accounting/income_tax_supporting_reports_test.dart` for scenario "S/G source mapping is not accepted"; assert it fails for the right reason.
- [ ] 1.2 Implement the specified behavior for "S/G source mapping is not accepted" to pass 1.1.
- [ ] 1.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 1.4 Write failing test `test_schedule_choice_is_explicit` in `test/features/accounting/income_tax_supporting_reports_test.dart` for scenario "Schedule choice is explicit"; assert it fails for the right reason.
- [ ] 1.5 Implement the specified behavior for "Schedule choice is explicit" to pass 1.4.
- [ ] 1.6 Refactor the affected code; keep the focused and full suites green.

## 2. income-tax-supporting-reports: Generate versioned S/G supporting workpapers from accounting records

- [ ] 2.1 Write failing test `test_supported_schedule_fields_have_traceable_values` in `test/features/income_tax_supporting_reports/income_tax_supporting_reports_test.dart` for scenario "Supported schedule fields have traceable values"; assert it fails for the right reason.
- [ ] 2.2 Implement the specified behavior for "Supported schedule fields have traceable values" to pass 2.1.
- [ ] 2.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.4 Write failing test `test_unsupported_tax_year_form_edition` in `test/features/income_tax_supporting_reports/income_tax_supporting_reports_test.dart` for scenario "Unsupported tax-year form edition"; assert it fails for the right reason.
- [ ] 2.5 Implement the specified behavior for "Unsupported tax-year form edition" to pass 2.4.
- [ ] 2.6 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.7 Write failing test `test_accounting_source_or_classification_is_incomplete` in `test/features/income_tax_supporting_reports/income_tax_supporting_reports_test.dart` for scenario "Accounting source or classification is incomplete"; assert it fails for the right reason.
- [ ] 2.8 Implement the specified behavior for "Accounting source or classification is incomplete" to pass 2.7.
- [ ] 2.9 Refactor the affected code; keep the focused and full suites green.
- [ ] 2.10 Write failing test `test_workpaper_is_not_filed` in `test/features/income_tax_supporting_reports/income_tax_supporting_reports_test.dart` for scenario "Workpaper is not filed"; assert it fails for the right reason.
- [ ] 2.11 Implement the specified behavior for "Workpaper is not filed" to pass 2.10.
- [ ] 2.12 Refactor the affected code; keep the focused and full suites green.

## 3. income-tax-supporting-reports: S/G workpapers follow the desktop design system

- [ ] 3.1 Write failing test `test_workpaper_can_be_reviewed_by_keyboard` in `test/features/income_tax_supporting_reports/income_tax_supporting_reports_test.dart` for scenario "Workpaper can be reviewed by keyboard"; assert it fails for the right reason.
- [ ] 3.2 Implement the specified behavior for "Workpaper can be reviewed by keyboard" to pass 3.1.
- [ ] 3.3 Refactor the affected code; keep the focused and full suites green.

## 4. typed-route-workspaces: Income-tax supporting report view

- [ ] 4.1 Write failing test `test_open_an_s_g_supporting_report` in `test/core/router/income_tax_supporting_reports_routes_test.dart` for scenario "Open an S/G supporting report"; assert it fails for the right reason.
- [ ] 4.2 Implement the specified behavior for "Open an S/G supporting report" to pass 4.1.
- [ ] 4.3 Refactor the affected code; keep the focused and full suites green.
- [ ] 4.4 Write failing test `test_report_service_is_unavailable` in `test/core/router/income_tax_supporting_reports_routes_test.dart` for scenario "Report service is unavailable"; assert it fails for the right reason.
- [ ] 4.5 Implement the specified behavior for "Report service is unavailable" to pass 4.4.
- [ ] 4.6 Refactor the affected code; keep the focused and full suites green.

## Implementation Notes

- Follow `design.md` for implementation decisions and dependency order.
- Keep each scenario in red-green-refactor order; do not implement behavior before its failing test.
- Keep `test-plan.md` red until its named test passes.
