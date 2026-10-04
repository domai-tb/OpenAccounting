## Test Plan

<!-- Every scenario in specs/ maps to a named test. -->
<!-- During implementation, flip 🔴 red to 🟢 green when its test passes. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | EÜR Zeile 12 — Kleinunternehmer §19 | test/features/accounting/reporting/reporting_contracts_test.dart | test_e_r_zeile_12_kleinunternehmer_19 | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | EÜR Zeile 15 — Umsatzsteuerpflichtige Betriebseinnahmen | test/features/accounting/reporting/reporting_contracts_test.dart | test_e_r_zeile_15_umsatzsteuerpflichtige_betriebseinnahmen | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | EÜR Zeile 16 — Steuerfreie Betriebseinnahmen §4 | test/features/accounting/reporting/reporting_contracts_test.dart | test_e_r_zeile_16_steuerfreie_betriebseinnahmen_4 | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | EÜR Zeile 33 — Abschreibungen (AfA) | test/features/accounting/reporting/reporting_contracts_test.dart | test_e_r_zeile_33_abschreibungen_afa | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | EÜR Zeile 60 — Sonstige Betriebsausgaben | test/features/accounting/reporting/reporting_contracts_test.dart | test_e_r_zeile_60_sonstige_betriebsausgaben | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | EÜR Zeile 106/107 — Privatentnahme/Privateinlage | test/features/accounting/reporting/reporting_contracts_test.dart | test_e_r_zeile_106_107_privatentnahme_privateinlage | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | Vorsteuerabzug Soll-Prinzip | test/features/accounting/reporting/reporting_contracts_test.dart | test_vorsteuerabzug_soll_prinzip | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | EÜR with no journal entries | test/features/accounting/reporting/reporting_contracts_test.dart | test_e_r_with_no_journal_entries | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | EÜR 2026 has no accepted mapping | test/features/accounting/reporting/reporting_contracts_test.dart | test_e_r_2026_has_no_accepted_mapping | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | EÜR source contract is unapproved | test/features/accounting/reporting/reporting_contracts_test.dart | test_e_r_source_contract_is_unapproved | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | KZ 1 — Gesamtumsatz steuerpflichtig | test/features/accounting/reporting/reporting_contracts_test.dart | test_kz_1_gesamtumsatz_steuerpflichtig | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | KZ 3 — Umsatzsteuer (19%) | test/features/accounting/reporting/reporting_contracts_test.dart | test_kz_3_umsatzsteuer_19 | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | KZ 4 — Umsatzsteuer (7%) | test/features/accounting/reporting/reporting_contracts_test.dart | test_kz_4_umsatzsteuer_7 | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | KZ 18 — Differenzsteuer §25a | test/features/accounting/reporting/reporting_contracts_test.dart | test_kz_18_differenzsteuer_25a | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | KZ 61 — Vorsteuerabzug ig Erwerb | test/features/accounting/reporting/reporting_contracts_test.dart | test_kz_61_vorsteuerabzug_ig_erwerb | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | KZ 66 — Allgemeiner Vorsteuerabzug | test/features/accounting/reporting/reporting_contracts_test.dart | test_kz_66_allgemeiner_vorsteuerabzug | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | KZ 89/93 — Reverse Charge | test/features/accounting/reporting/reporting_contracts_test.dart | test_kz_89_93_reverse_charge | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | KZ 81/83 — Differenzbetrag §25a | test/features/accounting/reporting/reporting_contracts_test.dart | test_kz_81_83_differenzbetrag_25a | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | Quarterly filing | test/features/accounting/reporting/reporting_contracts_test.dart | test_quarterly_filing | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | No transactions in period | test/features/accounting/reporting/reporting_contracts_test.dart | test_no_transactions_in_period | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | UStVA year map or source is unavailable | test/features/accounting/reporting/reporting_contracts_test.dart | test_ustva_year_map_or_source_is_unavailable | 🔴 red |
| specs/accounting/spec.md → GuV (Gewinn- und Verlustrechnung) | Threshold exceeded | test/features/accounting/reporting/reporting_contracts_test.dart | test_threshold_exceeded | 🔴 red |
| specs/accounting/spec.md → GuV (Gewinn- und Verlustrechnung) | GuV computation | test/features/accounting/reporting/reporting_contracts_test.dart | test_guv_computation | 🔴 red |
| specs/accounting/spec.md → GuV (Gewinn- und Verlustrechnung) | Threshold not exceeded | test/features/accounting/reporting/reporting_contracts_test.dart | test_threshold_not_exceeded | 🔴 red |
| specs/accounting/spec.md → GuV (Gewinn- und Verlustrechnung) | §141 warning follows notice effective date | test/features/accounting/reporting/reporting_contracts_test.dart | test_141_warning_follows_notice_effective_date | 🔴 red |
| specs/accounting/spec.md → GuV (Gewinn- und Verlustrechnung) | §141 warning follows a non-calendar Wirtschaftsjahr | test/features/accounting/reporting/reporting_contracts_test.dart | test_141_warning_follows_a_non_calendar_wirtschaftsjahr | 🔴 red |
| specs/accounting/spec.md → GuV (Gewinn- und Verlustrechnung) | GuV is unavailable without approved postings | test/features/accounting/reporting/reporting_contracts_test.dart | test_guv_is_unavailable_without_approved_postings | 🔴 red |
| specs/accounting/spec.md → ZM (Zusammenfassende Meldung) | ZM with ig Lieferungen | test/features/accounting/reporting/reporting_contracts_test.dart | test_zm_with_ig_lieferungen | 🔴 red |
| specs/accounting/spec.md → ZM (Zusammenfassende Meldung) | ZM with ig Erwerb | test/features/accounting/reporting/reporting_contracts_test.dart | test_zm_with_ig_erwerb | 🔴 red |
| specs/accounting/spec.md → ZM (Zusammenfassende Meldung) | No EU transactions in period | test/features/accounting/reporting/reporting_contracts_test.dart | test_no_eu_transactions_in_period | 🔴 red |
| specs/accounting/spec.md → ZM (Zusammenfassende Meldung) | Missing ZM source field blocks preview | test/features/accounting/reporting/reporting_contracts_test.dart | test_missing_zm_source_field_blocks_preview | 🔴 red |
| specs/accounting/spec.md → ZM (Zusammenfassende Meldung) | Unsupported reportable service blocks ZM preview | test/features/accounting/reporting/reporting_contracts_test.dart | test_unsupported_reportable_service_blocks_zm_preview | 🔴 red |
| specs/accounting/spec.md → DATEV EXTF Export | DATEV export generation | test/features/accounting/reporting/reporting_contracts_test.dart | test_datev_export_generation | 🔴 red |
| specs/accounting/spec.md → DATEV EXTF Export | DATEV account mapping | test/features/accounting/reporting/reporting_contracts_test.dart | test_datev_account_mapping | 🔴 red |
| specs/accounting/spec.md → DATEV EXTF Export | DATEV metadata | test/features/accounting/reporting/reporting_contracts_test.dart | test_datev_metadata | 🔴 red |
| specs/accounting/spec.md → DATEV EXTF Export | DATEV export with missing company config | test/features/accounting/reporting/reporting_contracts_test.dart | test_datev_export_with_missing_company_config | 🔴 red |
| specs/accounting/spec.md → DATEV EXTF Export | DATEV export with missing source mapping | test/features/accounting/reporting/reporting_contracts_test.dart | test_datev_export_with_missing_source_mapping | 🔴 red |
| specs/accounting/spec.md → DATEV EXTF Export | DATEV fixture matches the pinned interface | test/features/accounting/reporting/reporting_contracts_test.dart | test_datev_fixture_matches_the_pinned_interface | 🔴 red |
| specs/accounting-reporting-workspaces/spec.md → Typed report workspaces expose only supported calculations | Generate a supported report preview | test/features/accounting/reporting/reporting_workspace_test.dart | test_generate_a_supported_report_preview | 🔴 red |
| specs/accounting-reporting-workspaces/spec.md → Typed report workspaces expose only supported calculations | Financial prerequisite is still unapproved | test/features/accounting/reporting/reporting_workspace_test.dart | test_financial_prerequisite_is_still_unapproved | 🔴 red |
| specs/accounting-reporting-workspaces/spec.md → Typed report workspaces expose only supported calculations | Unsupported EÜR year does not reuse 2025 | test/features/accounting/reporting/reporting_workspace_test.dart | test_unsupported_e_r_year_does_not_reuse_2025 | 🔴 red |
| specs/accounting-reporting-workspaces/spec.md → Typed report workspaces expose only supported calculations | EKS period contract is unavailable | test/features/accounting/reporting/reporting_workspace_test.dart | test_eks_period_contract_is_unavailable | 🔴 red |
| specs/accounting-reporting-workspaces/spec.md → Typed report workspaces expose only supported calculations | Unsupported ZM transaction prevents a false empty report | test/features/accounting/reporting/reporting_workspace_test.dart | test_unsupported_zm_transaction_prevents_a_false_empty_report | 🔴 red |
| specs/accounting-reporting-workspaces/spec.md → Annual accounting period summary uses one canonical result | Return a complete supported annual summary | test/features/accounting/reporting/reporting_workspace_test.dart | test_return_a_complete_supported_annual_summary | 🔴 red |
| specs/accounting-reporting-workspaces/spec.md → Annual accounting period summary uses one canonical result | Unsupported annual period has no summary | test/features/accounting/reporting/reporting_workspace_test.dart | test_unsupported_annual_period_has_no_summary | 🔴 red |
| specs/accounting-reporting-workspaces/spec.md → Annual accounting period summary uses one canonical result | Empty or zero-income supported year | test/features/accounting/reporting/reporting_workspace_test.dart | test_empty_or_zero_income_supported_year | 🔴 red |
| specs/accounting-reporting-workspaces/spec.md → Report status reflects evidence and unresolved input | Local result is not submitted | test/features/accounting/reporting/reporting_workspace_test.dart | test_local_result_is_not_submitted | 🔴 red |
| specs/accounting-reporting-workspaces/spec.md → Report status reflects evidence and unresolved input | Required inputs are unresolved | test/features/accounting/reporting/reporting_workspace_test.dart | test_required_inputs_are_unresolved | 🔴 red |
| specs/accounting-reporting-workspaces/spec.md → Reporting workspaces remain accessible at desktop sizes | Narrow workspace and keyboard navigation | test/features/accounting/reporting/reporting_workspace_test.dart | test_narrow_workspace_and_keyboard_navigation | 🔴 red |
| specs/dashboard/spec.md → Annual dashboard summary consumes the supported report result | Summary widget uses the canonical annual result | test/features/dashboard/accounting_period_summary_test.dart | test_summary_widget_uses_the_canonical_annual_result | 🔴 red |
| specs/dashboard/spec.md → Annual dashboard summary consumes the supported report result | Summary dependencies are not approved | test/features/dashboard/accounting_period_summary_test.dart | test_summary_dependencies_are_not_approved | 🔴 red |
| specs/dashboard/spec.md → Annual dashboard summary consumes the supported report result | Unsupported dashboard summary period | test/features/dashboard/accounting_period_summary_test.dart | test_unsupported_dashboard_summary_period | 🔴 red |
| specs/tax-reporting-and-export-integrity/spec.md → Reporting workspace file-output scope | DATEV export uses the maintained artifact lifecycle | test/features/accounting/reporting/report_export_lifecycle_test.dart | test_datev_export_uses_the_maintained_artifact_lifecycle | 🔴 red |
| specs/tax-reporting-and-export-integrity/spec.md → Reporting workspace file-output scope | Preview-only report has no file export | test/features/accounting/reporting/report_export_lifecycle_test.dart | test_preview_only_report_has_no_file_export | 🔴 red |
| specs/tax-reporting-and-export-integrity/spec.md → Reporting workspace file-output scope | Unsupported export format remains unavailable | test/features/accounting/reporting/report_export_lifecycle_test.dart | test_unsupported_export_format_remains_unavailable | 🔴 red |
| specs/typed-route-workspaces/spec.md → Report route selections resolve to typed owners | Report routes open a typed report catalog | test/core/reporting_routes_test.dart | test_report_routes_open_a_typed_report_catalog | 🔴 red |
| specs/typed-route-workspaces/spec.md → Report route selections resolve to typed owners | Report deep link selects its typed owner | test/core/reporting_routes_test.dart | test_report_deep_link_selects_its_typed_owner | 🔴 red |
| specs/typed-route-workspaces/spec.md → Report route selections resolve to typed owners | Export history deep link opens validated artifact history | test/core/reporting_routes_test.dart | test_export_history_deep_link_opens_validated_artifact_history | 🔴 red |
| specs/typed-route-workspaces/spec.md → Report route selections resolve to typed owners | Missing or invalid report selection fails closed | test/core/reporting_routes_test.dart | test_missing_or_invalid_report_selection_fails_closed | 🔴 red |

## Coverage Notes

- Every scenario begins red and maps to exactly one named test; route selections are table-driven where several report types share a contract.
- Reporting preview, accounting source/version, and DATEV mapping scenarios use focused reporting contract tests.
- Dashboard summary scenarios use dashboard/application-service tests; route and query/deep-link scenarios use router tests; artifact validation/history scenarios use export lifecycle tests.
- Implementation must add the listed tests, report fixtures, and typed result fakes before enabling any calculation; no test execution is claimed by this proposal artifact.
