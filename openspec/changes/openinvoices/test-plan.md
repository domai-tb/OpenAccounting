# Test Plan: OpenInvoices

> Map EVERY scenario in specs/ to a named test. Each row starts 🔴 red.

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/accounting/spec.md → Journal Entries | Booking creation | test/features/accounting/test_booking_creation.dart | test_booking_creation | 🔴 red |
| specs/accounting/spec.md → Journal Entries | GoBD immutability | test/features/accounting/test_gobd_immutability.dart | test_gobd_immutability | 🔴 red |
| specs/accounting/spec.md → Journal Entries | Storno entry | test/features/accounting/test_storno_entry.dart | test_storno_entry | 🔴 red |
| specs/accounting/spec.md → Journal Entries | Buchungsgruppen | test/features/accounting/test_buchungsgruppen.dart | test_buchungsgruppen | 🔴 red |
| specs/accounting/spec.md → Journal Entries | Missing required fields | test/features/accounting/test_missing_required_fields.dart | test_missing_required_fields | 🔴 red |
| specs/accounting/spec.md → Kategorien | Category with SKR mapping | test/features/accounting/test_category_with_skr_mapping.dart | test_category_with_skr_mapping | 🔴 red |
| specs/accounting/spec.md → Kategorien | User-modified SKR account | test/features/accounting/test_user_modified_skr_account.dart | test_user_modified_skr_account | 🔴 red |
| specs/accounting/spec.md → Kategorien | Inactive category | test/features/accounting/test_inactive_category.dart | test_inactive_category | 🔴 red |
| specs/accounting/spec.md → Kategorien | Category description | test/features/accounting/test_category_description.dart | test_category_description | 🔴 red |
| specs/accounting/spec.md → Kategorien | Category with missing SKR mapping | test/features/accounting/test_category_with_missing_skr_mapping.dart | test_category_with_missing_skr_mapping | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | EÜR Zeile 12 — Kleinunternehmer §19 | test/features/accounting/test_e_r_zeile_12_kleinunternehmer_19.dart | test_e_r_zeile_12_kleinunternehmer_19 | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | EÜR Zeile 15 — Umsatzsteuerpflichtige Betriebseinnahmen | test/features/accounting/test_e_r_zeile_15_umsatzsteuerpflichtige_betriebseinnahmen.dart | test_e_r_zeile_15_umsatzsteuerpflichtige_betriebseinnahmen | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | EÜR Zeile 16 — Steuerfreie Betriebseinnahmen §4 | test/features/accounting/test_e_r_zeile_16_steuerfreie_betriebseinnahmen_4.dart | test_e_r_zeile_16_steuerfreie_betriebseinnahmen_4 | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | EÜR Zeile 33 — Abschreibungen (AfA) | test/features/accounting/test_e_r_zeile_33_abschreibungen_afa.dart | test_e_r_zeile_33_abschreibungen_afa | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | EÜR Zeile 60 — Sonstige Betriebsausgaben | test/features/accounting/test_e_r_zeile_60_sonstige_betriebsausgaben.dart | test_e_r_zeile_60_sonstige_betriebsausgaben | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | EÜR Zeile 106/107 — Privatentnahme/Privateinlage | test/features/accounting/test_e_r_zeile_106_107_privatentnahme_privateinlage.dart | test_e_r_zeile_106_107_privatentnahme_privateinlage | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | Vorsteuerabzug Soll-Prinzip | test/features/accounting/test_vorsteuerabzug_soll_prinzip.dart | test_vorsteuerabzug_soll_prinzip | 🔴 red |
| specs/accounting/spec.md → EÜR (Einnahmen-Überschuss-Rechnung) | EÜR with no journal entries | test/features/accounting/test_e_r_with_no_journal_entries.dart | test_e_r_with_no_journal_entries | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | KZ 1 — Gesamtumsatz steuerpflichtig | test/features/accounting/test_kz_1_gesamtumsatz_steuerpflichtig.dart | test_kz_1_gesamtumsatz_steuerpflichtig | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | KZ 3 — Umsatzsteuer (19%) | test/features/accounting/test_kz_3_umsatzsteuer_19.dart | test_kz_3_umsatzsteuer_19 | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | KZ 4 — Umsatzsteuer (7%) | test/features/accounting/test_kz_4_umsatzsteuer_7.dart | test_kz_4_umsatzsteuer_7 | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | KZ 18 — Differenzsteuer §25a | test/features/accounting/test_kz_18_differenzsteuer_25a.dart | test_kz_18_differenzsteuer_25a | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | KZ 61 — Vorsteuerabzug ig Erwerb | test/features/accounting/test_kz_61_vorsteuerabzug_ig_erwerb.dart | test_kz_61_vorsteuerabzug_ig_erwerb | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | KZ 81/83 — Differenzbetrag §25a | test/features/accounting/test_kz_81_83_differenzbetrag_25a.dart | test_kz_81_83_differenzbetrag_25a | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | Quarterly filing | test/features/accounting/test_quarterly_filing.dart | test_quarterly_filing | 🔴 red |
| specs/accounting/spec.md → UStVA (Umsatzsteuer-Voranmeldung) | No transactions in period | test/features/accounting/test_no_transactions_in_period.dart | test_no_transactions_in_period | 🔴 red |
| specs/accounting/spec.md → EKS (Anlage EKS — Einnahmen-Kostenübersicht) | EKS Section D — Company data | test/features/accounting/test_eks_section_d_company_data.dart | test_eks_section_d_company_data | 🔴 red |
| specs/accounting/spec.md → EKS (Anlage EKS — Einnahmen-Kostenübersicht) | EKS Section F — Income and costs | test/features/accounting/test_eks_section_f_income_and_costs.dart | test_eks_section_f_income_and_costs | 🔴 red |
| specs/accounting/spec.md → EKS (Anlage EKS — Einnahmen-Kostenübersicht) | EKS B6_5 — Travel costs | test/features/accounting/test_eks_b6_5_travel_costs.dart | test_eks_b6_5_travel_costs | 🔴 red |
| specs/accounting/spec.md → EKS (Anlage EKS — Einnahmen-Kostenübersicht) | EKS B6_4_priv — Private car deduction | test/features/accounting/test_eks_b6_4_priv_private_car_deduction.dart | test_eks_b6_4_priv_private_car_deduction | 🔴 red |
| specs/accounting/spec.md → EKS (Anlage EKS — Einnahmen-Kostenübersicht) | EKS Page 9 — Summary | test/features/accounting/test_eks_page_9_summary.dart | test_eks_page_9_summary | 🔴 red |
| specs/accounting/spec.md → EKS (Anlage EKS — Einnahmen-Kostenübersicht) | Missing EKS required data | test/features/accounting/test_missing_eks_required_data.dart | test_missing_eks_required_data | 🔴 red |
| specs/accounting/spec.md → GuV (Gewinn- und Verlustrechnung) | Threshold exceeded | test/features/accounting/test_threshold_exceeded.dart | test_threshold_exceeded | 🔴 red |
| specs/accounting/spec.md → GuV (Gewinn- und Verlustrechnung) | GuV computation | test/features/accounting/test_guv_computation.dart | test_guv_computation | 🔴 red |
| specs/accounting/spec.md → GuV (Gewinn- und Verlustrechnung) | Threshold not exceeded | test/features/accounting/test_threshold_not_exceeded.dart | test_threshold_not_exceeded | 🔴 red |
| specs/accounting/spec.md → ZM (Zusammenfassende Meldung) | ZM with ig Lieferungen | test/features/accounting/test_zm_with_ig_lieferungen.dart | test_zm_with_ig_lieferungen | 🔴 red |
| specs/accounting/spec.md → ZM (Zusammenfassende Meldung) | ZM with ig Erwerb | test/features/accounting/test_zm_with_ig_erwerb.dart | test_zm_with_ig_erwerb | 🔴 red |
| specs/accounting/spec.md → ZM (Zusammenfassende Meldung) | No EU transactions in period | test/features/accounting/test_no_eu_transactions_in_period.dart | test_no_eu_transactions_in_period | 🔴 red |
| specs/accounting/spec.md → DATEV EXTF Export | DATEV export generation | test/features/accounting/test_datev_export_generation.dart | test_datev_export_generation | 🔴 red |
| specs/accounting/spec.md → DATEV EXTF Export | DATEV account mapping | test/features/accounting/test_datev_account_mapping.dart | test_datev_account_mapping | 🔴 red |
| specs/accounting/spec.md → DATEV EXTF Export | DATEV metadata | test/features/accounting/test_datev_metadata.dart | test_datev_metadata | 🔴 red |
| specs/accounting/spec.md → DATEV EXTF Export | DATEV export with missing company config | test/features/accounting/test_datev_export_with_missing_company_config.dart | test_datev_export_with_missing_company_config | 🔴 red |
| specs/accounting/spec.md → GoBD Export | GoBD ZIP generation | test/features/accounting/test_gobd_zip_generation.dart | test_gobd_zip_generation | 🔴 red |
| specs/accounting/spec.md → GoBD Export | GoBD integrity verification | test/features/accounting/test_gobd_integrity_verification.dart | test_gobd_integrity_verification | 🔴 red |
| specs/accounting/spec.md → GoBD Export | GoBD export with missing documents | test/features/accounting/test_gobd_export_with_missing_documents.dart | test_gobd_export_with_missing_documents | 🔴 red |
| specs/accounting/spec.md → Vorsteueransprüche | Eingangsrechnung booked | test/features/accounting/test_eingangsrechnung_booked.dart | test_eingangsrechnung_booked | 🔴 red |
| specs/accounting/spec.md → Vorsteueransprüche | Vorsteuerabzug ab CUTOVER | test/features/accounting/test_vorsteuerabzug_ab_cutover.dart | test_vorsteuerabzug_ab_cutover | 🔴 red |
| specs/accounting/spec.md → Vorsteueransprüche | Storno correction | test/features/accounting/test_storno_correction.dart | test_storno_correction | 🔴 red |
| specs/accounting/spec.md → Vorsteueransprüche | Duplicate vorsteuer_anspruch prevention | test/features/accounting/test_duplicate_vorsteuer_anspruch_prevention.dart | test_duplicate_vorsteuer_anspruch_prevention | 🔴 red |
| specs/accounting/spec.md → SKR03/SKR04 Parallel Display | Dual SKR display | test/features/accounting/test_dual_skr_display.dart | test_dual_skr_display | 🔴 red |
| specs/accounting/spec.md → SKR03/SKR04 Parallel Display | SKR toggle | test/features/accounting/test_skr_toggle.dart | test_skr_toggle | 🔴 red |
| specs/accounting/spec.md → Tax Calculation | Standard 19% USt | test/features/accounting/test_standard_19_ust.dart | test_standard_19_ust | 🔴 red |
| specs/accounting/spec.md → Tax Calculation | 7% USt | test/features/accounting/test_7_ust.dart | test_7_ust | 🔴 red |
| specs/accounting/spec.md → Tax Calculation | Kleinunternehmer §19 | test/features/accounting/test_kleinunternehmer_19.dart | test_kleinunternehmer_19 | 🔴 red |
| specs/accounting/spec.md → Tax Calculation | Differenzbesteuerung §25a | test/features/accounting/test_differenzbesteuerung_25a.dart | test_differenzbesteuerung_25a | 🔴 red |
| specs/accounting/spec.md → Tax Calculation | Mixed document | test/features/accounting/test_mixed_document.dart | test_mixed_document | 🔴 red |
| specs/accounting/spec.md → Tax Calculation | Invalid ust_satz | test/features/accounting/test_invalid_ust_satz.dart | test_invalid_ust_satz | 🔴 red |
| specs/accounting/spec.md → Skonto | Company-level Skonto | test/features/accounting/test_company_level_skonto.dart | test_company_level_skonto | 🔴 red |
| specs/accounting/spec.md → Skonto | Customer-level Skonto | test/features/accounting/test_customer_level_skonto.dart | test_customer_level_skonto | 🔴 red |
| specs/accounting/spec.md → Skonto | Invoice-level Skonto | test/features/accounting/test_invoice_level_skonto.dart | test_invoice_level_skonto | 🔴 red |
| specs/accounting/spec.md → Skonto | Skonto payment | test/features/accounting/test_skonto_payment.dart | test_skonto_payment | 🔴 red |
| specs/accounting/spec.md → Skonto | Skonto expiry | test/features/accounting/test_skonto_expiry.dart | test_skonto_expiry | 🔴 red |
| specs/accounting/spec.md → Payment Processing | Partial payment | test/features/accounting/test_partial_payment.dart | test_partial_payment | 🔴 red |
| specs/accounting/spec.md → Payment Processing | Full payment | test/features/accounting/test_full_payment.dart | test_full_payment | 🔴 red |
| specs/accounting/spec.md → Payment Processing | Überzahlung recognized | test/features/accounting/test_berzahlung_recognized.dart | test_berzahlung_recognized | 🔴 red |
| specs/accounting/spec.md → Payment Processing | Überzahlung not recognized | test/features/accounting/test_berzahlung_not_recognized.dart | test_berzahlung_not_recognized | 🔴 red |
| specs/accounting/spec.md → Payment Processing | Forderungsausfall | test/features/accounting/test_forderungsausfall.dart | test_forderungsausfall | 🔴 red |
| specs/accounting/spec.md → Payment Processing | Eingangsrechnung Überzahlung | test/features/accounting/test_eingangsrechnung_berzahlung.dart | test_eingangsrechnung_berzahlung | 🔴 red |
| specs/accounting/spec.md → Tagesabschluss | Tagesabschluss creation | test/features/accounting/test_tagesabschluss_creation.dart | test_tagesabschluss_creation | 🔴 red |
| specs/accounting/spec.md → Tagesabschluss | Counting discrepancy | test/features/accounting/test_counting_discrepancy.dart | test_counting_discrepancy | 🔴 red |
| specs/accounting/spec.md → Tagesabschluss | GoBD signature | test/features/accounting/test_gobd_signature.dart | test_gobd_signature | 🔴 red |
| specs/accounting/spec.md → Tagesabschluss | Double close prevention | test/features/accounting/test_double_close_prevention.dart | test_double_close_prevention | 🔴 red |
| specs/accounting/spec.md → Steuersätze Management | Default tax rates | test/features/accounting/test_default_tax_rates.dart | test_default_tax_rates | 🔴 red |
| specs/accounting/spec.md → Steuersätze Management | Custom tax rate | test/features/accounting/test_custom_tax_rate.dart | test_custom_tax_rate | 🔴 red |
| specs/accounting/spec.md → Steuersätze Management | Tax rate snapshot | test/features/accounting/test_tax_rate_snapshot.dart | test_tax_rate_snapshot | 🔴 red |
| specs/accounting/spec.md → Steuersätze Management | Deleting a tax rate in use | test/features/accounting/test_deleting_a_tax_rate_in_use.dart | test_deleting_a_tax_rate_in_use | 🔴 red |
| specs/accounting/spec.md → Buchungsvorlagen | Template creation | test/features/accounting/test_template_creation.dart | test_template_creation | 🔴 red |
| specs/accounting/spec.md → Buchungsvorlagen | Template execution | test/features/accounting/test_template_execution.dart | test_template_execution | 🔴 red |
| specs/accounting/spec.md → Buchungsvorlagen | Template with article | test/features/accounting/test_template_with_article.dart | test_template_with_article | 🔴 red |
| specs/accounting/spec.md → Buchungsvorlagen | Template lifecycle | test/features/accounting/test_template_lifecycle.dart | test_template_lifecycle | 🔴 red |
| specs/accounting/spec.md → Buchungsvorlagen | Template with deleted category | test/features/accounting/test_template_with_deleted_category.dart | test_template_with_deleted_category | 🔴 red |
| specs/accounting/spec.md → Schnellbuchungen | Quick booking preset | test/features/accounting/test_quick_booking_preset.dart | test_quick_booking_preset | 🔴 red |
| specs/accounting/spec.md → Schnellbuchungen | Quick booking execution | test/features/accounting/test_quick_booking_execution.dart | test_quick_booking_execution | 🔴 red |
| specs/accounting/spec.md → Schnellbuchungen | Quick booking with invalid preset | test/features/accounting/test_quick_booking_with_invalid_preset.dart | test_quick_booking_with_invalid_preset | 🔴 red |
| specs/accounting/spec.md → Reverse Charge | §13b Abs. 1 — EU-Dienstleistungen | test/features/accounting/test_13b_abs_1_eu_dienstleistungen.dart | test_13b_abs_1_eu_dienstleistungen | 🔴 red |
| specs/accounting/spec.md → Reverse Charge | §13b Abs. 2 — Bauleistungen | test/features/accounting/test_13b_abs_2_bauleistungen.dart | test_13b_abs_2_bauleistungen | 🔴 red |
| specs/accounting/spec.md → Reverse Charge | Innergemeinschaftlicher Erwerb | test/features/accounting/test_innergemeinschaftlicher_erwerb.dart | test_innergemeinschaftlicher_erwerb | 🔴 red |
| specs/accounting/spec.md → Reverse Charge | Invalid ust_sonderfall value | test/features/accounting/test_invalid_ust_sonderfall_value.dart | test_invalid_ust_sonderfall_value | 🔴 red |
| specs/accounting/spec.md → Anlagenverzeichnis | Asset registration | test/features/accounting/test_asset_registration.dart | test_asset_registration | 🔴 red |
| specs/accounting/spec.md → Anlagenverzeichnis | KFZ with private share | test/features/accounting/test_kfz_with_private_share.dart | test_kfz_with_private_share | 🔴 red |
| specs/accounting/spec.md → Anlagenverzeichnis | Asset disposal | test/features/accounting/test_asset_disposal.dart | test_asset_disposal | 🔴 red |
| specs/accounting/spec.md → Anlagenverzeichnis | AVEÜR integration | test/features/accounting/test_ave_r_integration.dart | test_ave_r_integration | 🔴 red |
| specs/accounting/spec.md → Kontenübersicht | Period summary | test/features/accounting/test_period_summary.dart | test_period_summary | 🔴 red |
| specs/accounting/spec.md → Kontenübersicht | Inactive categories excluded | test/features/accounting/test_inactive_categories_excluded.dart | test_inactive_categories_excluded | 🔴 red |
| specs/accounting/spec.md → Kontenübersicht | Empty period | test/features/accounting/test_empty_period.dart | test_empty_period | 🔴 red |
| specs/accounting/spec.md → Steuersätze Snapshot in Journal | Historical accuracy | test/features/accounting/test_historical_accuracy.dart | test_historical_accuracy | 🔴 red |
| specs/accounting/spec.md → Steuersätze Snapshot in Journal | SKR account snapshot | test/features/accounting/test_skr_account_snapshot.dart | test_skr_account_snapshot | 🔴 red |
| specs/accounting/spec.md → Steuersätze Snapshot in Journal | Snapshot on creation only | test/features/accounting/test_snapshot_on_creation_only.dart | test_snapshot_on_creation_only | 🔴 red |
| specs/accounting/spec.md → Voranmeldungsrhythmus | Monthly rhythm | test/features/accounting/test_monthly_rhythm.dart | test_monthly_rhythm | 🔴 red |
| specs/accounting/spec.md → Voranmeldungsrhythmus | Quarterly rhythm | test/features/accounting/test_quarterly_rhythm.dart | test_quarterly_rhythm | 🔴 red |
| specs/accounting/spec.md → Voranmeldungsrhythmus | Rhythm change | test/features/accounting/test_rhythm_change.dart | test_rhythm_change | 🔴 red |
| specs/accounting/spec.md → Differenzbesteuerung §25a Accounting | §25a journal entry | test/features/accounting/test_25a_journal_entry.dart | test_25a_journal_entry | 🔴 red |
| specs/accounting/spec.md → Differenzbesteuerung §25a Accounting | §25a UStVA KZ 81/83 | test/features/accounting/test_25a_ustva_kz_81_83.dart | test_25a_ustva_kz_81_83 | 🔴 red |
| specs/accounting/spec.md → Differenzbesteuerung §25a Accounting | §25a EÜR treatment | test/features/accounting/test_25a_e_r_treatment.dart | test_25a_e_r_treatment | 🔴 red |
| specs/accounting/spec.md → Differenzbesteuerung §25a Accounting | §25a with negative margin | test/features/accounting/test_25a_with_negative_margin.dart | test_25a_with_negative_margin | 🔴 red |
| specs/accounting/spec.md → Storno Correction | Storno at original period | test/features/accounting/test_storno_at_original_period.dart | test_storno_at_original_period | 🔴 red |
| specs/accounting/spec.md → Storno Correction | Storno EÜR impact | test/features/accounting/test_storno_e_r_impact.dart | test_storno_e_r_impact | 🔴 red |
| specs/accounting/spec.md → Storno Correction | Storno of already-storno'd entry | test/features/accounting/test_storno_of_already_storno_d_entry.dart | test_storno_of_already_storno_d_entry | 🔴 red |
| specs/accounting/spec.md → Storno Correction | Storno with Gruppenverknüpfung | test/features/accounting/test_storno_with_gruppenverkn_pfung.dart | test_storno_with_gruppenverkn_pfung | 🔴 red |
| specs/app/spec.md → Application Routing | Setup Guard Redirects Unconfigured App | test/features/app/test_setup_guard_redirects_unconfigured_app.dart | test_setup_guard_redirects_unconfigured_app | 🔴 red |
| specs/app/spec.md → Application Routing | Setup Guard Does Not Intercept Configured App | test/features/app/test_setup_guard_does_not_intercept_configured_app.dart | test_setup_guard_does_not_intercept_configured_app | 🔴 red |
| specs/app/spec.md → Application Routing | Nested Navigation Within Sections | test/features/app/test_nested_navigation_within_sections.dart | test_nested_navigation_within_sections | 🔴 red |
| specs/app/spec.md → Application Routing | Nested Navigation With Invalid ID | test/features/app/test_nested_navigation_with_invalid_id.dart | test_nested_navigation_with_invalid_id | 🔴 red |
| specs/app/spec.md → Application Routing | Deep Link With Query Parameters | test/features/app/test_deep_link_with_query_parameters.dart | test_deep_link_with_query_parameters | 🔴 red |
| specs/app/spec.md → State Management | Provider Caching | test/features/app/test_provider_caching.dart | test_provider_caching | 🔴 red |
| specs/app/spec.md → State Management | Provider Cache Expiry | test/features/app/test_provider_cache_expiry.dart | test_provider_cache_expiry | 🔴 red |
| specs/app/spec.md → State Management | Optimistic Update Rollback | test/features/app/test_optimistic_update_rollback.dart | test_optimistic_update_rollback | 🔴 red |
| specs/app/spec.md → State Management | Optimistic Update Success | test/features/app/test_optimistic_update_success.dart | test_optimistic_update_success | 🔴 red |
| specs/app/spec.md → State Management | Provider Invalidation After Mutation | test/features/app/test_provider_invalidation_after_mutation.dart | test_provider_invalidation_after_mutation | 🔴 red |
| specs/app/spec.md → Theme and Language | Theme Mode Switching | test/features/app/test_theme_mode_switching.dart | test_theme_mode_switching | 🔴 red |
| specs/app/spec.md → Theme and Language | Theme Persistence Failure | test/features/app/test_theme_persistence_failure.dart | test_theme_persistence_failure | 🔴 red |
| specs/app/spec.md → Theme and Language | System Theme Follow | test/features/app/test_system_theme_follow.dart | test_system_theme_follow | 🔴 red |
| specs/app/spec.md → Theme and Language | System Theme Follow Does Not Trigger When Manual | test/features/app/test_system_theme_follow_does_not_trigger_when_manual.dart | test_system_theme_follow_does_not_trigger_when_manual | 🔴 red |
| specs/app/spec.md → Theme and Language | German Du-Ansprache Enforcement | test/features/app/test_german_du_ansprache_enforcement.dart | test_german_du_ansprache_enforcement | 🔴 red |
| specs/app/spec.md → Layout Structure | Sidebar Section Collapse | test/features/app/test_sidebar_section_collapse.dart | test_sidebar_section_collapse | 🔴 red |
| specs/app/spec.md → Layout Structure | Sidebar Section Expand | test/features/app/test_sidebar_section_expand.dart | test_sidebar_section_expand | 🔴 red |
| specs/app/spec.md → Layout Structure | Responsive Layout Adaptation | test/features/app/test_responsive_layout_adaptation.dart | test_responsive_layout_adaptation | 🔴 red |
| specs/app/spec.md → Layout Structure | Responsive Layout Restoration | test/features/app/test_responsive_layout_restoration.dart | test_responsive_layout_restoration | 🔴 red |
| specs/app/spec.md → Layout Structure | Splitter Resize | test/features/app/test_splitter_resize.dart | test_splitter_resize | 🔴 red |
| specs/app/spec.md → Layout Structure | Splitter Resize Below Minimum | test/features/app/test_splitter_resize_below_minimum.dart | test_splitter_resize_below_minimum | 🔴 red |
| specs/app/spec.md → Error Handling | 422 Validation Error Display | test/features/app/test_422_validation_error_display.dart | test_422_validation_error_display | 🔴 red |
| specs/app/spec.md → Error Handling | 422 Validation Error With Multiple Fields | test/features/app/test_422_validation_error_with_multiple_fields.dart | test_422_validation_error_with_multiple_fields | 🔴 red |
| specs/app/spec.md → Error Handling | Backend Unreachable Screen | test/features/app/test_backend_unreachable_screen.dart | test_backend_unreachable_screen | 🔴 red |
| specs/app/spec.md → Error Handling | Backend Recovery After Unreachable State | test/features/app/test_backend_recovery_after_unreachable_state.dart | test_backend_recovery_after_unreachable_state | 🔴 red |
| specs/app/spec.md → Keyboard Shortcuts | Ctrl+F Focuses Search | test/features/app/test_ctrl_f_focuses_search.dart | test_ctrl_f_focuses_search | 🔴 red |
| specs/app/spec.md → Keyboard Shortcuts | Ctrl+F No Search Input Exists | test/features/app/test_ctrl_f_no_search_input_exists.dart | test_ctrl_f_no_search_input_exists | 🔴 red |
| specs/app/spec.md → Keyboard Shortcuts | Ctrl+Shift+E Navigates to Eingangsrechnungen | test/features/app/test_ctrl_shift_e_navigates_to_eingangsrechnungen.dart | test_ctrl_shift_e_navigates_to_eingangsrechnungen | 🔴 red |
| specs/app/spec.md → Keyboard Shortcuts | Plus Key Opens Buchung Dialog | test/features/app/test_plus_key_opens_buchung_dialog.dart | test_plus_key_opens_buchung_dialog | 🔴 red |
| specs/app/spec.md → Keyboard Shortcuts | Plus Key Ignored When Input Focused | test/features/app/test_plus_key_ignored_when_input_focused.dart | test_plus_key_ignored_when_input_focused | 🔴 red |
| specs/app/spec.md → Keyboard Shortcuts | E/A Toggles Art in Buchung Form | test/features/app/test_e_a_toggles_art_in_buchung_form.dart | test_e_a_toggles_art_in_buchung_form | 🔴 red |
| specs/app/spec.md → Keyboard Shortcuts | E/A Ignored When Input Focused | test/features/app/test_e_a_ignored_when_input_focused.dart | test_e_a_ignored_when_input_focused | 🔴 red |
| specs/app/spec.md → Keyboard Shortcuts | Global Zoom | test/features/app/test_global_zoom.dart | test_global_zoom | 🔴 red |
| specs/app/spec.md → Keyboard Shortcuts | Global Zoom Out | test/features/app/test_global_zoom_out.dart | test_global_zoom_out | 🔴 red |
| specs/app/spec.md → Form Validation | PLZ Country-Specific Validation | test/features/app/test_plz_country_specific_validation.dart | test_plz_country_specific_validation | 🔴 red |
| specs/app/spec.md → Form Validation | PLZ Valid German Format | test/features/app/test_plz_valid_german_format.dart | test_plz_valid_german_format | 🔴 red |
| specs/app/spec.md → Form Validation | USt-IdNr EU Format Validation | test/features/app/test_ust_idnr_eu_format_validation.dart | test_ust_idnr_eu_format_validation | 🔴 red |
| specs/app/spec.md → Form Validation | USt-IdNr DE Format Validation | test/features/app/test_ust_idnr_de_format_validation.dart | test_ust_idnr_de_format_validation | 🔴 red |
| specs/app/spec.md → Form Validation | Monetary Value Validation | test/features/app/test_monetary_value_validation.dart | test_monetary_value_validation | 🔴 red |
| specs/app/spec.md → Form Validation | Monetary Value Valid Input | test/features/app/test_monetary_value_valid_input.dart | test_monetary_value_valid_input | 🔴 red |
| specs/app/spec.md → API Client | Automatic Port Detection | test/features/app/test_automatic_port_detection.dart | test_automatic_port_detection | 🔴 red |
| specs/app/spec.md → API Client | Port Detection All Ports Fail | test/features/app/test_port_detection_all_ports_fail.dart | test_port_detection_all_ports_fail | 🔴 red |
| specs/app/spec.md → API Client | Retry on Transient Failure | test/features/app/test_retry_on_transient_failure.dart | test_retry_on_transient_failure | 🔴 red |
| specs/app/spec.md → API Client | Retry Exhausted | test/features/app/test_retry_exhausted.dart | test_retry_exhausted | 🔴 red |
| specs/app/spec.md → API Client | Backend Health Polling | test/features/app/test_backend_health_polling.dart | test_backend_health_polling | 🔴 red |
| specs/app/spec.md → Local Storage | Preference Persistence | test/features/app/test_preference_persistence.dart | test_preference_persistence | 🔴 red |
| specs/app/spec.md → Local Storage | Preference Corruption Recovery | test/features/app/test_preference_corruption_recovery.dart | test_preference_corruption_recovery | 🔴 red |
| specs/app/spec.md → Version Display | Sidebar Version Display | test/features/app/test_sidebar_version_display.dart | test_sidebar_version_display | 🔴 red |
| specs/app/spec.md → Version Display | Über Dialog Version Display | test/features/app/test_ber_dialog_version_display.dart | test_ber_dialog_version_display | 🔴 red |
| specs/app/spec.md → Print and Export | Inline PDF Display | test/features/app/test_inline_pdf_display.dart | test_inline_pdf_display | 🔴 red |
| specs/app/spec.md → Print and Export | PDF Display With Missing Document | test/features/app/test_pdf_display_with_missing_document.dart | test_pdf_display_with_missing_document | 🔴 red |
| specs/app/spec.md → Print and Export | CSV Export Save Dialog | test/features/app/test_csv_export_save_dialog.dart | test_csv_export_save_dialog | 🔴 red |
| specs/app/spec.md → Print and Export | CSV Export Cancelled | test/features/app/test_csv_export_cancelled.dart | test_csv_export_cancelled | 🔴 red |
| specs/app/spec.md → Print and Export | ZIP Export Save Dialog | test/features/app/test_zip_export_save_dialog.dart | test_zip_export_save_dialog | 🔴 red |
| specs/backup/spec.md → Local WAL-safe backup with rotation | Local backup creation | test/features/backup/test_local_backup_creation.dart | test_local_backup_creation | 🔴 red |
| specs/backup/spec.md → Local WAL-safe backup with rotation | Backup fails when disk is full | test/features/backup/test_backup_fails_when_disk_is_full.dart | test_backup_fails_when_disk_is_full | 🔴 red |
| specs/backup/spec.md → Backup before schema migration | Backup before schema migration | test/features/backup/test_backup_before_schema_migration.dart | test_backup_before_schema_migration | 🔴 red |
| specs/backup/spec.md → Backup before schema migration | Backup failure prevents migration | test/features/backup/test_backup_failure_prevents_migration.dart | test_backup_failure_prevents_migration | 🔴 red |
| specs/backup/spec.md → External AES-256-GCM encrypted backup | Encrypted external backup | test/features/backup/test_encrypted_external_backup.dart | test_encrypted_external_backup | 🔴 red |
| specs/backup/spec.md → External AES-256-GCM encrypted backup | Encrypted backup with wrong passphrase on restore | test/features/backup/test_encrypted_backup_with_wrong_passphrase_on_restore.dart | test_encrypted_backup_with_wrong_passphrase_on_restore | 🔴 red |
| specs/backup/spec.md → Restore from encrypted backup | Restore from encrypted backup | test/features/backup/test_restore_from_encrypted_backup.dart | test_restore_from_encrypted_backup | 🔴 red |
| specs/backup/spec.md → Restore from encrypted backup | Restore with corrupted encrypted backup | test/features/backup/test_restore_with_corrupted_encrypted_backup.dart | test_restore_with_corrupted_encrypted_backup | 🔴 red |
| specs/backup/spec.md → SMB network share backup | SMB backup with stored credentials | test/features/backup/test_smb_backup_with_stored_credentials.dart | test_smb_backup_with_stored_credentials | 🔴 red |
| specs/backup/spec.md → SMB network share backup | SMB backup fails with invalid credentials | test/features/backup/test_smb_backup_fails_with_invalid_credentials.dart | test_smb_backup_fails_with_invalid_credentials | 🔴 red |
| specs/backup/spec.md → System drive protection with opt-in override | System drive backup rejected | test/features/backup/test_system_drive_backup_rejected.dart | test_system_drive_backup_rejected | 🔴 red |
| specs/backup/spec.md → System drive protection with opt-in override | System drive override accepted | test/features/backup/test_system_drive_override_accepted.dart | test_system_drive_override_accepted | 🔴 red |
| specs/backup/spec.md → Restore from backup | Restore from local backup | test/features/backup/test_restore_from_local_backup.dart | test_restore_from_local_backup | 🔴 red |
| specs/backup/spec.md → Restore from backup | Restore with missing backup file | test/features/backup/test_restore_with_missing_backup_file.dart | test_restore_with_missing_backup_file | 🔴 red |
| specs/backup/spec.md → Backup scheduling | Scheduled daily backup | test/features/backup/test_scheduled_daily_backup.dart | test_scheduled_daily_backup | 🔴 red |
| specs/backup/spec.md → Backup scheduling | No duplicate backup within interval | test/features/backup/test_no_duplicate_backup_within_interval.dart | test_no_duplicate_backup_within_interval | 🔴 red |
| specs/backup/spec.md → Platform-specific backup paths | Linux backup path | test/features/backup/test_linux_backup_path.dart | test_linux_backup_path | 🔴 red |
| specs/backup/spec.md → Platform-specific backup paths | macOS backup path | test/features/backup/test_macos_backup_path.dart | test_macos_backup_path | 🔴 red |
| specs/backup/spec.md → Platform-specific backup paths | Windows backup path | test/features/backup/test_windows_backup_path.dart | test_windows_backup_path | 🔴 red |
| specs/bank-import/spec.md → 3-Step Import Workflow | Upload step completes | test/features/bank-import/test_upload_step_completes.dart | test_upload_step_completes | 🔴 red |
| specs/bank-import/spec.md → 3-Step Import Workflow | Upload fails with invalid file | test/features/bank-import/test_upload_fails_with_invalid_file.dart | test_upload_fails_with_invalid_file | 🔴 red |
| specs/bank-import/spec.md → Bank Templates | Predefined template selection | test/features/bank-import/test_predefined_template_selection.dart | test_predefined_template_selection | 🔴 red |
| specs/bank-import/spec.md → Bank Templates | No template matches uploaded file | test/features/bank-import/test_no_template_matches_uploaded_file.dart | test_no_template_matches_uploaded_file | 🔴 red |
| specs/bank-import/spec.md → Custom Template Creation | Create custom template | test/features/bank-import/test_create_custom_template.dart | test_create_custom_template | 🔴 red |
| specs/bank-import/spec.md → Custom Template Creation | Edit existing template | test/features/bank-import/test_edit_existing_template.dart | test_edit_existing_template | 🔴 red |
| specs/bank-import/spec.md → CAMT XML Import | Upload CAMT XML | test/features/bank-import/test_upload_camt_xml.dart | test_upload_camt_xml | 🔴 red |
| specs/bank-import/spec.md → CAMT XML Import | Upload non-CAMT XML | test/features/bank-import/test_upload_non_camt_xml.dart | test_upload_non_camt_xml | 🔴 red |
| specs/bank-import/spec.md → Auto-Categorization Rules | Pattern match assigns category | test/features/bank-import/test_pattern_match_assigns_category.dart | test_pattern_match_assigns_category | 🔴 red |
| specs/bank-import/spec.md → Auto-Categorization Rules | No pattern match | test/features/bank-import/test_no_pattern_match.dart | test_no_pattern_match | 🔴 red |
| specs/bank-import/spec.md → Score-Based Matching | High-confidence match | test/features/bank-import/test_high_confidence_match.dart | test_high_confidence_match | 🔴 red |
| specs/bank-import/spec.md → Score-Based Matching | No match | test/features/bank-import/test_no_match.dart | test_no_match | 🔴 red |
| specs/bank-import/spec.md → Deduplication | Duplicate detection | test/features/bank-import/test_duplicate_detection.dart | test_duplicate_detection | 🔴 red |
| specs/bank-import/spec.md → Deduplication | Manual override of duplicate | test/features/bank-import/test_manual_override_of_duplicate.dart | test_manual_override_of_duplicate | 🔴 red |
| specs/bank-import/spec.md → Bank Transactions Table | Transaction linked to journal entry | test/features/bank-import/test_transaction_linked_to_journal_entry.dart | test_transaction_linked_to_journal_entry | 🔴 red |
| specs/bank-import/spec.md → Bank Transactions Table | Transaction stored without journal link | test/features/bank-import/test_transaction_stored_without_journal_link.dart | test_transaction_stored_without_journal_link | 🔴 red |
| specs/bank-import/spec.md → Manual vs Automatic Mode | Automatic mode | test/features/bank-import/test_automatic_mode.dart | test_automatic_mode | 🔴 red |
| specs/bank-import/spec.md → Manual vs Automatic Mode | Manual mode | test/features/bank-import/test_manual_mode.dart | test_manual_mode | 🔴 red |
| specs/bank-import/spec.md → Per-Session Import Mode Override | Override for single import | test/features/bank-import/test_override_for_single_import.dart | test_override_for_single_import | 🔴 red |
| specs/bank-import/spec.md → Per-Session Import Mode Override | Override does not persist | test/features/bank-import/test_override_does_not_persist.dart | test_override_does_not_persist | 🔴 red |
| specs/bank-import/spec.md → Konto Selection Per Import | Select target Konto | test/features/bank-import/test_select_target_konto.dart | test_select_target_konto | 🔴 red |
| specs/bank-import/spec.md → Konto Selection Per Import | No Konto selected | test/features/bank-import/test_no_konto_selected.dart | test_no_konto_selected | 🔴 red |
| specs/bank-import/spec.md → DATEV Export Compatibility | Export to DATEV | test/features/bank-import/test_export_to_datev.dart | test_export_to_datev | 🔴 red |
| specs/bank-import/spec.md → DATEV Export Compatibility | No exportable transactions | test/features/bank-import/test_no_exportable_transactions.dart | test_no_exportable_transactions | 🔴 red |
| specs/bank-import/spec.md → Import Protocol / History | View import history | test/features/bank-import/test_view_import_history.dart | test_view_import_history | 🔴 red |
| specs/bank-import/spec.md → Import Protocol / History | Empty import history | test/features/bank-import/test_empty_import_history.dart | test_empty_import_history | 🔴 red |
| specs/bank-import/spec.md → Auto-Filter Rule CRUD | Create filter rule | test/features/bank-import/test_create_filter_rule.dart | test_create_filter_rule | 🔴 red |
| specs/bank-import/spec.md → Auto-Filter Rule CRUD | Delete filter rule | test/features/bank-import/test_delete_filter_rule.dart | test_delete_filter_rule | 🔴 red |
| specs/bank-import/spec.md → Transaction Classification Override | Override category | test/features/bank-import/test_override_category.dart | test_override_category | 🔴 red |
| specs/bank-import/spec.md → Transaction Classification Override | Override reverts on re-import | test/features/bank-import/test_override_reverts_on_re_import.dart | test_override_reverts_on_re_import | 🔴 red |
| specs/bank-import/spec.md → Import Statistics | Post-import summary | test/features/bank-import/test_post_import_summary.dart | test_post_import_summary | 🔴 red |
| specs/bank-import/spec.md → Import Statistics | Import with zero transactions | test/features/bank-import/test_import_with_zero_transactions.dart | test_import_with_zero_transactions | 🔴 red |
| specs/dashboard/spec.md → Widget-based layout | Default widget layout | test/features/dashboard/test_default_widget_layout.dart | test_default_widget_layout | 🔴 red |
| specs/dashboard/spec.md → Widget-based layout | Widget rendering with loading state | test/features/dashboard/test_widget_rendering_with_loading_state.dart | test_widget_rendering_with_loading_state | 🔴 red |
| specs/dashboard/spec.md → Widget-based layout | Widget with failed data fetch | test/features/dashboard/test_widget_with_failed_data_fetch.dart | test_widget_with_failed_data_fetch | 🔴 red |
| specs/dashboard/spec.md → 13+ available widgets | All widgets available | test/features/dashboard/test_all_widgets_available.dart | test_all_widgets_available | 🔴 red |
| specs/dashboard/spec.md → 13+ available widgets | Widget content varies by type | test/features/dashboard/test_widget_content_varies_by_type.dart | test_widget_content_varies_by_type | 🔴 red |
| specs/dashboard/spec.md → 13+ available widgets | Lagerwarnung with no low-stock items | test/features/dashboard/test_lagerwarnung_with_no_low_stock_items.dart | test_lagerwarnung_with_no_low_stock_items | 🔴 red |
| specs/dashboard/spec.md → Widget visibility configuration | Hide a widget | test/features/dashboard/test_hide_a_widget.dart | test_hide_a_widget | 🔴 red |
| specs/dashboard/spec.md → Widget visibility configuration | Show a previously hidden widget | test/features/dashboard/test_show_a_previously_hidden_widget.dart | test_show_a_previously_hidden_widget | 🔴 red |
| specs/dashboard/spec.md → Widget visibility configuration | Hidden widget does not fetch data | test/features/dashboard/test_hidden_widget_does_not_fetch_data.dart | test_hidden_widget_does_not_fetch_data | 🔴 red |
| specs/dashboard/spec.md → Widget reordering via drag-and-drop | Drag widget to new position | test/features/dashboard/test_drag_widget_to_new_position.dart | test_drag_widget_to_new_position | 🔴 red |
| specs/dashboard/spec.md → Widget reordering via drag-and-drop | Reorder persists across sessions | test/features/dashboard/test_reorder_persists_across_sessions.dart | test_reorder_persists_across_sessions | 🔴 red |
| specs/dashboard/spec.md → Widget reordering via drag-and-drop | Reorder does not affect visibility | test/features/dashboard/test_reorder_does_not_affect_visibility.dart | test_reorder_does_not_affect_visibility | 🔴 red |
| specs/dashboard/spec.md → Schnellzugriff-Links (Quick-Links widget) | Default quick links | test/features/dashboard/test_default_quick_links.dart | test_default_quick_links | 🔴 red |
| specs/dashboard/spec.md → Schnellzugriff-Links (Quick-Links widget) | Custom quick link | test/features/dashboard/test_custom_quick_link.dart | test_custom_quick_link | 🔴 red |
| specs/dashboard/spec.md → Schnellzugriff-Links (Quick-Links widget) | Quick link with invalid route | test/features/dashboard/test_quick_link_with_invalid_route.dart | test_quick_link_with_invalid_route | 🔴 red |
| specs/dashboard/spec.md → Data refresh on mount | Initial load | test/features/dashboard/test_initial_load.dart | test_initial_load | 🔴 red |
| specs/dashboard/spec.md → Data refresh on mount | Refresh after mutation | test/features/dashboard/test_refresh_after_mutation.dart | test_refresh_after_mutation | 🔴 red |
| specs/dashboard/spec.md → Data refresh on mount | Manual refresh | test/features/dashboard/test_manual_refresh.dart | test_manual_refresh | 🔴 red |
| specs/dashboard/spec.md → Dashboard config persistence | Config saved on change | test/features/dashboard/test_config_saved_on_change.dart | test_config_saved_on_change | 🔴 red |
| specs/dashboard/spec.md → Dashboard config persistence | Config loaded on start | test/features/dashboard/test_config_loaded_on_start.dart | test_config_loaded_on_start | 🔴 red |
| specs/dashboard/spec.md → Dashboard config persistence | Corrupted config falls back to defaults | test/features/dashboard/test_corrupted_config_falls_back_to_defaults.dart | test_corrupted_config_falls_back_to_defaults | 🔴 red |
| specs/db/spec.md → SQLite Engine Configuration | WAL Mode on Connection | test/db/schema_test.dart | WAL mode and FK enforcement active | 🟢 green |
| specs/db/spec.md → SQLite Engine Configuration | WAL Mode Already Active | test/features/db/test_wal_mode_already_active.dart | test_wal_mode_already_active | 🔴 red |
| specs/db/spec.md → SQLite Engine Configuration | Foreign Key Enforcement | test/db/schema_test.dart | FK enforcement rejects invalid reference | 🟢 green |
| specs/db/spec.md → SQLite Engine Configuration | Foreign Key Enforcement Disabled by Default | test/features/db/test_foreign_key_enforcement_disabled_by_default.dart | test_foreign_key_enforcement_disabled_by_default | 🔴 red |
| specs/db/spec.md → Data Type Precision | Money Column Precision | test/db/schema_test.dart | money precision — 123456789.12 stored exactly | 🟢 green |
| specs/db/spec.md → Data Type Precision | Money Column Overflow | test/features/db/test_money_column_overflow.dart | test_money_column_overflow | 🔴 red |
| specs/db/spec.md → Data Type Precision | Article Price Precision | test/db/schema_test.dart | vk_netto precision 2.9412 *100 =294.12 | 🟢 green |
| specs/db/spec.md → Data Type Precision | Article Price Zero | test/db/schema_test.dart | vk_netto precision 2.9412 *100 =294.12 | 🟢 green |
| specs/db/spec.md → Table Definitions | All Tables Created on Fresh Install | test/db/schema_test.dart | all 38 tables exist after creation | 🟢 green |
| specs/db/spec.md → Table Definitions | Table Count Verification | test/db/schema_test.dart | table count remains 38 after second open | 🟢 green |
| specs/db/spec.md → Table Definitions | Missing Table Detection | test/features/db/test_missing_table_detection.dart | test_missing_table_detection | 🔴 red |
| specs/db/spec.md → Schema Versioning | Fresh Database Gets Current Version | test/features/db/test_fresh_database_gets_current_version.dart | test_fresh_database_gets_current_version | 🔴 red |
| specs/db/spec.md → Schema Versioning | Outdated Database Triggers Migration | test/db/migration_test.dart | increments schema version after an outdated migration | 🟢 green |
| specs/db/spec.md → Schema Versioning | Already Current Database Skips Migration | test/features/db/test_already_current_database_skips_migration.dart | test_already_current_database_skips_migration | 🔴 red |
| specs/db/spec.md → Schema Versioning | Future Database Version Rejected | test/features/db/test_future_database_version_rejected.dart | test_future_database_version_rejected | 🔴 red |
| specs/db/spec.md → Migration System | Backup Before Migration | test/features/db/test_backup_before_migration.dart | test_backup_before_migration | 🔴 red |
| specs/db/spec.md → Migration System | Idempotent Migration Re-run | test/features/db/test_idempotent_migration_re_run.dart | test_idempotent_migration_re_run | 🔴 red |
| specs/db/spec.md → Migration System | Post-Migration Hooks | test/features/db/test_post_migration_hooks.dart | test_post_migration_hooks | 🔴 red |
| specs/db/spec.md → Migration System | Migration Failure Rolls Back | test/db/migration_test.dart | rolls back schema changes when migration fails | 🟢 green |
| specs/db/spec.md → GoBD Triggers | Immutable Journal Row Protection | test/db/gobd_test.dart | rejects UPDATE and DELETE for immutable journal rows | 🟢 green |
| specs/db/spec.md → GoBD Triggers | Mutable Journal Row Modification | test/db/gobd_test.dart | allows modification of mutable journal rows | 🟢 green |
| specs/db/spec.md → GoBD Triggers | Trigger Reinstall After Migration | test/db/gobd_test.dart | reinstall restores protection after triggers are removed | 🟢 green |
| specs/db/spec.md → GoBD Triggers | Trigger Protects Against Direct SQL | test/db/gobd_test.dart | rejects UPDATE and DELETE for immutable journal rows | 🟢 green |
| specs/db/spec.md → Profile Management | Profile Directory Isolation | test/db/profile_test.dart | creates isolated profile directory and database | 🟢 green |
| specs/db/spec.md → Profile Management | Profile Switch Requires Restart | test/db/profile_test.dart | switches profiles through profile.json and skips same-profile restart | 🟢 green |
| specs/db/spec.md → Profile Management | Profile Switch Does Not Affect Other Profiles | test/db/profile_test.dart | keeps identical invoice numbers isolated between profile databases | 🟢 green |
| specs/db/spec.md → Backup System | WAL-Safe Backup Creation | test/features/db/test_wal_safe_backup_creation.dart | test_wal_safe_backup_creation | 🔴 red |
| specs/db/spec.md → Backup System | Backup Rotation | test/features/db/test_backup_rotation.dart | test_backup_rotation | 🔴 red |
| specs/db/spec.md → Backup System | Encrypted External Backup | test/features/db/test_encrypted_external_backup.dart | test_encrypted_external_backup | 🔴 red |
| specs/db/spec.md → Backup System | Backup Directory Does Not Exist | test/features/db/test_backup_directory_does_not_exist.dart | test_backup_directory_does_not_exist | 🔴 red |
| specs/db/spec.md → Seed Data | USt-Sätze Seeded | test/db/seed_test.dart | seeds standard tax rates and document number ranges | 🟢 green |
| specs/db/spec.md → Seed Data | Nummernkreise Seeded | test/db/seed_test.dart | seeds standard tax rates and document number ranges | 🟢 green |
| specs/db/spec.md → Seed Data | Kategorien Seeded With SKR Accounts | test/db/seed_test.dart | seeds categories with both SKR mappings | 🟢 green |
| specs/db/spec.md → Seed Data | Seed Data Not Duplicated on Restart | test/db/seed_test.dart | is idempotent and preserves existing seed values | 🟢 green |
| specs/db/spec.md → Indexes and Constraints | Duplicate Konto-Nummer Rejected | test/features/db/test_duplicate_konto_nummer_rejected.dart | test_duplicate_konto_nummer_rejected | 🔴 red |
| specs/db/spec.md → Indexes and Constraints | Null Kundennummer Allowed | test/features/db/test_null_kundennummer_allowed.dart | test_null_kundennummer_allowed | 🔴 red |
| specs/db/spec.md → Indexes and Constraints | Duplicate Dedupe Hash Rejected | test/features/db/test_duplicate_dedupe_hash_rejected.dart | test_duplicate_dedupe_hash_rejected | 🔴 red |
| specs/db/spec.md → Indexes and Constraints | Dedupe Hash Null Allowed | test/features/db/test_dedupe_hash_null_allowed.dart | test_dedupe_hash_null_allowed | 🔴 red |
| specs/desktop/spec.md → System Tray | Tray Context Menu Actions | test/features/desktop/test_tray_context_menu_actions.dart | test_tray_context_menu_actions | 🔴 red |
| specs/desktop/spec.md → System Tray | Close to Tray | test/features/desktop/test_close_to_tray.dart | test_close_to_tray | 🔴 red |
| specs/desktop/spec.md → System Tray | Close to Tray Disabled | test/features/desktop/test_close_to_tray_disabled.dart | test_close_to_tray_disabled | 🔴 red |
| specs/desktop/spec.md → System Tray | Tray Icon Not Shown | test/features/desktop/test_tray_icon_not_shown.dart | test_tray_icon_not_shown | 🔴 red |
| specs/desktop/spec.md → Global Keyboard Shortcuts | Global Show/Hide | test/features/desktop/test_global_show_hide.dart | test_global_show_hide | 🔴 red |
| specs/desktop/spec.md → Global Keyboard Shortcuts | Global Show/Hide Toggles | test/features/desktop/test_global_show_hide_toggles.dart | test_global_show_hide_toggles | 🔴 red |
| specs/desktop/spec.md → Global Keyboard Shortcuts | Global New Invoice | test/features/desktop/test_global_new_invoice.dart | test_global_new_invoice | 🔴 red |
| specs/desktop/spec.md → Global Keyboard Shortcuts | Shortcut Conflict Detection | test/features/desktop/test_shortcut_conflict_detection.dart | test_shortcut_conflict_detection | 🔴 red |
| specs/desktop/spec.md → Auto-Update | Update Available Notification | test/features/desktop/test_update_available_notification.dart | test_update_available_notification | 🔴 red |
| specs/desktop/spec.md → Auto-Update | Update Download and Install | test/features/desktop/test_update_download_and_install.dart | test_update_download_and_install | 🔴 red |
| specs/desktop/spec.md → Auto-Update | Update Download Cancelled | test/features/desktop/test_update_download_cancelled.dart | test_update_download_cancelled | 🔴 red |
| specs/desktop/spec.md → Auto-Update | Signing Verification Failure | test/features/desktop/test_signing_verification_failure.dart | test_signing_verification_failure | 🔴 red |
| specs/desktop/spec.md → Auto-Update | No Update Available | test/features/desktop/test_no_update_available.dart | test_no_update_available | 🔴 red |
| specs/desktop/spec.md → Window Management | Window State Persistence | test/features/desktop/test_window_state_persistence.dart | test_window_state_persistence | 🔴 red |
| specs/desktop/spec.md → Window Management | Minimum Size Enforcement | test/features/desktop/test_minimum_size_enforcement.dart | test_minimum_size_enforcement | 🔴 red |
| specs/desktop/spec.md → Window Management | Maximize State Persistence | test/features/desktop/test_maximize_state_persistence.dart | test_maximize_state_persistence | 🔴 red |
| specs/desktop/spec.md → Window Management | Window State Corruption Recovery | test/features/desktop/test_window_state_corruption_recovery.dart | test_window_state_corruption_recovery | 🔴 red |
| specs/desktop/spec.md → File Associations | PDF File Association | test/features/desktop/test_pdf_file_association.dart | test_pdf_file_association | 🔴 red |
| specs/desktop/spec.md → File Associations | CSV File Association | test/features/desktop/test_csv_file_association.dart | test_csv_file_association | 🔴 red |
| specs/desktop/spec.md → File Associations | File Association With No App Running | test/features/desktop/test_file_association_with_no_app_running.dart | test_file_association_with_no_app_running | 🔴 red |
| specs/desktop/spec.md → File Associations | Unsupported File Type Double-Click | test/features/desktop/test_unsupported_file_type_double_click.dart | test_unsupported_file_type_double_click | 🔴 red |
| specs/desktop/spec.md → PDF Viewer Window | PDF Inline Display | test/features/desktop/test_pdf_inline_display.dart | test_pdf_inline_display | 🔴 red |
| specs/desktop/spec.md → PDF Viewer Window | PDF Print | test/features/desktop/test_pdf_print.dart | test_pdf_print | 🔴 red |
| specs/desktop/spec.md → PDF Viewer Window | PDF Save As | test/features/desktop/test_pdf_save_as.dart | test_pdf_save_as | 🔴 red |
| specs/desktop/spec.md → PDF Viewer Window | PDF Viewer Closed by User | test/features/desktop/test_pdf_viewer_closed_by_user.dart | test_pdf_viewer_closed_by_user | 🔴 red |
| specs/desktop/spec.md → Drag-and-Drop File Import | Drag PDF to Belege | test/features/desktop/test_drag_pdf_to_belege.dart | test_drag_pdf_to_belege | 🔴 red |
| specs/desktop/spec.md → Drag-and-Drop File Import | Drag Unsupported File Type | test/features/desktop/test_drag_unsupported_file_type.dart | test_drag_unsupported_file_type | 🔴 red |
| specs/desktop/spec.md → Drag-and-Drop File Import | Drag Multiple Supported Files | test/features/desktop/test_drag_multiple_supported_files.dart | test_drag_multiple_supported_files | 🔴 red |
| specs/desktop/spec.md → Drag-and-Drop File Import | Drag File Outside Drop Zone | test/features/desktop/test_drag_file_outside_drop_zone.dart | test_drag_file_outside_drop_zone | 🔴 red |
| specs/desktop/spec.md → Single Instance Enforcement | Second Instance Launch | test/features/desktop/test_second_instance_launch.dart | test_second_instance_launch | 🔴 red |
| specs/desktop/spec.md → Single Instance Enforcement | Deep Link to Running Instance | test/features/desktop/test_deep_link_to_running_instance.dart | test_deep_link_to_running_instance | 🔴 red |
| specs/desktop/spec.md → Single Instance Enforcement | First Instance Launch | test/features/desktop/test_first_instance_launch.dart | test_first_instance_launch | 🔴 red |
| specs/desktop/spec.md → Backend Process Management (Sidecar) | Backend Auto-Start | test/features/desktop/test_backend_auto_start.dart | test_backend_auto_start | 🔴 red |
| specs/desktop/spec.md → Backend Process Management (Sidecar) | Backend Crash Recovery | test/features/desktop/test_backend_crash_recovery.dart | test_backend_crash_recovery | 🔴 red |
| specs/desktop/spec.md → Backend Process Management (Sidecar) | Backend Shutdown on App Quit | test/features/desktop/test_backend_shutdown_on_app_quit.dart | test_backend_shutdown_on_app_quit | 🔴 red |
| specs/desktop/spec.md → Backend Process Management (Sidecar) | Backend Port Conflict | test/features/desktop/test_backend_port_conflict.dart | test_backend_port_conflict | 🔴 red |
| specs/desktop/spec.md → Platform Workarounds | Linux GPU Workaround | test/features/desktop/test_linux_gpu_workaround.dart | test_linux_gpu_workaround | 🔴 red |
| specs/desktop/spec.md → Platform Workarounds | Windows Console Hide | test/features/desktop/test_windows_console_hide.dart | test_windows_console_hide | 🔴 red |
| specs/desktop/spec.md → Platform Workarounds | macOS Profile Path | test/features/desktop/test_macos_profile_path.dart | test_macos_profile_path | 🔴 red |
| specs/desktop/spec.md → Platform Workarounds | Linux Profile Path | test/features/desktop/test_linux_profile_path.dart | test_linux_profile_path | 🔴 red |
| specs/documents/spec.md → Document Types | All types have number ranges | test/features/documents/test_all_types_have_number_ranges.dart | test_all_types_have_number_ranges | 🔴 red |
| specs/documents/spec.md → Document Types | Unknown document type rejected | test/features/documents/test_unknown_document_type_rejected.dart | test_unknown_document_type_rejected | 🔴 red |
| specs/documents/spec.md → Document Lifecycle — Entwurf | Draft not in EÜR | test/features/documents/test_draft_not_in_e_r.dart | test_draft_not_in_e_r | 🔴 red |
| specs/documents/spec.md → Document Lifecycle — Entwurf | Draft editable | test/features/documents/test_draft_editable.dart | test_draft_editable | 🔴 red |
| specs/documents/spec.md → Document Lifecycle — Entwurf | Lieferschein created without draft state | test/features/documents/test_lieferschein_created_without_draft_state.dart | test_lieferschein_created_without_draft_state | 🔴 red |
| specs/documents/spec.md → Document Lifecycle — Finalization | Finalization locks document | test/features/documents/test_finalization_locks_document.dart | test_finalization_locks_document | 🔴 red |
| specs/documents/spec.md → Document Lifecycle — Finalization | Finalization captures company snapshot | test/features/documents/test_finalization_captures_company_snapshot.dart | test_finalization_captures_company_snapshot | 🔴 red |
| specs/documents/spec.md → Document Lifecycle — Finalization | Re-finalization blocked | test/features/documents/test_re_finalization_blocked.dart | test_re_finalization_blocked | 🔴 red |
| specs/documents/spec.md → Document Lifecycle — Bezahlt | Full payment | test/features/documents/test_full_payment.dart | test_full_payment | 🔴 red |
| specs/documents/spec.md → Document Lifecycle — Bezahlt | Partial payment keeps status open | test/features/documents/test_partial_payment_keeps_status_open.dart | test_partial_payment_keeps_status_open | 🔴 red |
| specs/documents/spec.md → Storno | Storno with stock restoration | test/features/documents/test_storno_with_stock_restoration.dart | test_storno_with_stock_restoration | 🔴 red |
| specs/documents/spec.md → Storno | Storno requires reason | test/features/documents/test_storno_requires_reason.dart | test_storno_requires_reason | 🔴 red |
| specs/documents/spec.md → Storno | Storno of already-storned invoice blocked | test/features/documents/test_storno_of_already_storned_invoice_blocked.dart | test_storno_of_already_storned_invoice_blocked | 🔴 red |
| specs/documents/spec.md → Gutschrift | Gutschrift from invoice | test/features/documents/test_gutschrift_from_invoice.dart | test_gutschrift_from_invoice | 🔴 red |
| specs/documents/spec.md → Gutschrift | Standalone Gutschrift without invoice reference | test/features/documents/test_standalone_gutschrift_without_invoice_reference.dart | test_standalone_gutschrift_without_invoice_reference | 🔴 red |
| specs/documents/spec.md → Ersatzrechnung | Ersatzrechnung bidirectional link | test/features/documents/test_ersatzrechnung_bidirectional_link.dart | test_ersatzrechnung_bidirectional_link | 🔴 red |
| specs/documents/spec.md → Ersatzrechnung | Ersatzrechnung from non-storned invoice blocked | test/features/documents/test_ersatzrechnung_from_non_storned_invoice_blocked.dart | test_ersatzrechnung_from_non_storned_invoice_blocked | 🔴 red |
| specs/documents/spec.md → Conversion Chains | Angebot → Auftrag conversion | test/features/documents/test_angebot_auftrag_conversion.dart | test_angebot_auftrag_conversion | 🔴 red |
| specs/documents/spec.md → Conversion Chains | Lieferschein → Rechnung conversion | test/features/documents/test_lieferschein_rechnung_conversion.dart | test_lieferschein_rechnung_conversion | 🔴 red |
| specs/documents/spec.md → Conversion Chains | Unsupported conversion blocked | test/features/documents/test_unsupported_conversion_blocked.dart | test_unsupported_conversion_blocked | 🔴 red |
| specs/documents/spec.md → Position Propagation | Position fields preserved | test/features/documents/test_position_fields_preserved.dart | test_position_fields_preserved | 🔴 red |
| specs/documents/spec.md → Position Propagation | Position IDs regenerated | test/features/documents/test_position_ids_regenerated.dart | test_position_ids_regenerated | 🔴 red |
| specs/documents/spec.md → Dokumentenpakete | Create package from multiple documents | test/features/documents/test_create_package_from_multiple_documents.dart | test_create_package_from_multiple_documents | 🔴 red |
| specs/documents/spec.md → Dokumentenpakete | Empty package creation blocked | test/features/documents/test_empty_package_creation_blocked.dart | test_empty_package_creation_blocked | 🔴 red |
| specs/documents/spec.md → Belege — Upload and Attach | Attach receipt to invoice | test/features/documents/test_attach_receipt_to_invoice.dart | test_attach_receipt_to_invoice | 🔴 red |
| specs/documents/spec.md → Belege — Upload and Attach | Unsupported file type rejected | test/features/documents/test_unsupported_file_type_rejected.dart | test_unsupported_file_type_rejected | 🔴 red |
| specs/documents/spec.md → Original PDF Storage | Kopie with watermark | test/features/documents/test_kopie_with_watermark.dart | test_kopie_with_watermark | 🔴 red |
| specs/documents/spec.md → Original PDF Storage | Original PDF preserved on copy | test/features/documents/test_original_pdf_preserved_on_copy.dart | test_original_pdf_preserved_on_copy | 🔴 red |
| specs/documents/spec.md → Absender_snapshot | Company change does not affect old invoices | test/features/documents/test_company_change_does_not_affect_old_invoices.dart | test_company_change_does_not_affect_old_invoices | 🔴 red |
| specs/documents/spec.md → Absender_snapshot | Snapshot immutable after finalization | test/features/documents/test_snapshot_immutable_after_finalization.dart | test_snapshot_immutable_after_finalization | 🔴 red |
| specs/documents/spec.md → Überzahlung Handling | Overpayment creates Forderung | test/features/documents/test_overpayment_creates_forderung.dart | test_overpayment_creates_forderung | 🔴 red |
| specs/documents/spec.md → Überzahlung Handling | Overpayment acknowledged without Forderung | test/features/documents/test_overpayment_acknowledged_without_forderung.dart | test_overpayment_acknowledged_without_forderung | 🔴 red |
| specs/documents/spec.md → Skonto Handling | Invoice-level skonto overrides customer default | test/features/documents/test_invoice_level_skonto_overrides_customer_default.dart | test_invoice_level_skonto_overrides_customer_default | 🔴 red |
| specs/documents/spec.md → Skonto Handling | No skonto when not configured | test/features/documents/test_no_skonto_when_not_configured.dart | test_no_skonto_when_not_configured | 🔴 red |
| specs/documents/spec.md → Eingabemodus — Netto/Brutto | Netto mode calculation | test/features/documents/test_netto_mode_calculation.dart | test_netto_mode_calculation | 🔴 red |
| specs/documents/spec.md → Eingabemodus — Netto/Brutto | Brutto mode calculation | test/features/documents/test_brutto_mode_calculation.dart | test_brutto_mode_calculation | 🔴 red |
| specs/documents/spec.md → Rabatt — Position and Document Level | Position Rabatt | test/features/documents/test_position_rabatt.dart | test_position_rabatt | 🔴 red |
| specs/documents/spec.md → Rabatt — Position and Document Level | Document-level fixed Rabatt | test/features/documents/test_document_level_fixed_rabatt.dart | test_document_level_fixed_rabatt | 🔴 red |
| specs/documents/spec.md → Rabatt — Position and Document Level | Conflicting document-level Rabatt rejected | test/features/documents/test_conflicting_document_level_rabatt_rejected.dart | test_conflicting_document_level_rabatt_rejected | 🔴 red |
| specs/documents/spec.md → Einleitungstext und Schlusstext | Document overrides company default | test/features/documents/test_document_overrides_company_default.dart | test_document_overrides_company_default | 🔴 red |
| specs/documents/spec.md → Einleitungstext und Schlusstext | Empty document text falls back to default | test/features/documents/test_empty_document_text_falls_back_to_default.dart | test_empty_document_text_falls_back_to_default | 🔴 red |
| specs/documents/spec.md → Lagerführung — Stock auf Finalisierung | Multi-position stock update | test/features/documents/test_multi_position_stock_update.dart | test_multi_position_stock_update | 🔴 red |
| specs/documents/spec.md → Lagerführung — Stock auf Finalisierung | Stock change logged with reference | test/features/documents/test_stock_change_logged_with_reference.dart | test_stock_change_logged_with_reference | 🔴 red |
| specs/documents/spec.md → Lageradresse | Lieferschein shows delivery address | test/features/documents/test_lieferschein_shows_delivery_address.dart | test_lieferschein_shows_delivery_address | 🔴 red |
| specs/documents/spec.md → Lageradresse | Delivery address propagated to Rechnung | test/features/documents/test_delivery_address_propagated_to_rechnung.dart | test_delivery_address_propagated_to_rechnung | 🔴 red |
| specs/documents/spec.md → Angebot — Status | Angebot expires automatically | test/features/documents/test_angebot_expires_automatically.dart | test_angebot_expires_automatically | 🔴 red |
| specs/documents/spec.md → Angebot — Status | Expired Angebot cannot be accepted | test/features/documents/test_expired_angebot_cannot_be_accepted.dart | test_expired_angebot_cannot_be_accepted | 🔴 red |
| specs/documents/spec.md → Auftrag — Status | Auftrag auto-completes on payment | test/features/documents/test_auftrag_auto_completes_on_payment.dart | test_auftrag_auto_completes_on_payment | 🔴 red |
| specs/documents/spec.md → Auftrag — Status | Manual status regression blocked | test/features/documents/test_manual_status_regression_blocked.dart | test_manual_status_regression_blocked | 🔴 red |
| specs/documents/spec.md → Lieferschein — Preise | Lieferschein PDF without prices | test/features/documents/test_lieferschein_pdf_without_prices.dart | test_lieferschein_pdf_without_prices | 🔴 red |
| specs/documents/spec.md → Lieferschein — Preise | Lieferschein → Rechnung adds prices | test/features/documents/test_lieferschein_rechnung_adds_prices.dart | test_lieferschein_rechnung_adds_prices | 🔴 red |
| specs/einkommen/spec.md → Forderungen table for open items | Forderung created on invoice finalization | test/features/einkommen/test_forderung_created_on_invoice_finalization.dart | test_forderung_created_on_invoice_finalization | 🔴 red |
| specs/einkommen/spec.md → Forderungen table for open items | Forderung updated on partial payment | test/features/einkommen/test_forderung_updated_on_partial_payment.dart | test_forderung_updated_on_partial_payment | 🔴 red |
| specs/einkommen/spec.md → Forderungen table for open items | Forderung closed on full payment | test/features/einkommen/test_forderung_closed_on_full_payment.dart | test_forderung_closed_on_full_payment | 🔴 red |
| specs/einkommen/spec.md → Forderungen table for open items | Duplicate Forderung prevented | test/features/einkommen/test_duplicate_forderung_prevented.dart | test_duplicate_forderung_prevented | 🔴 red |
| specs/einkommen/spec.md → Überzahlungs-Protokoll (overpayment tracking) | Overpayment detected | test/features/einkommen/test_overpayment_detected.dart | test_overpayment_detected | 🔴 red |
| specs/einkommen/spec.md → Überzahlungs-Protokoll (overpayment tracking) | Overpayment in Kontokorrent | test/features/einkommen/test_overpayment_in_kontokorrent.dart | test_overpayment_in_kontokorrent | 🔴 red |
| specs/einkommen/spec.md → Überzahlungs-Protokoll (overpayment tracking) | Exact payment does not trigger overpayment | test/features/einkommen/test_exact_payment_does_not_trigger_overpayment.dart | test_exact_payment_does_not_trigger_overpayment | 🔴 red |
| specs/einkommen/spec.md → Forderungsausfall (write-off) | Write off receivable | test/features/einkommen/test_write_off_receivable.dart | test_write_off_receivable | 🔴 red |
| specs/einkommen/spec.md → Forderungsausfall (write-off) | Write-off requires reason | test/features/einkommen/test_write_off_requires_reason.dart | test_write_off_requires_reason | 🔴 red |
| specs/einkommen/spec.md → Forderungsausfall (write-off) | Write-off of already-paid Forderung | test/features/einkommen/test_write_off_of_already_paid_forderung.dart | test_write_off_of_already_paid_forderung | 🔴 red |
| specs/einkommen/spec.md → Zufluss-Monitor (cash flow monitor) | Monthly view | test/features/einkommen/test_monthly_view.dart | test_monthly_view | 🔴 red |
| specs/einkommen/spec.md → Zufluss-Monitor (cash flow monitor) | Service period view | test/features/einkommen/test_service_period_view.dart | test_service_period_view | 🔴 red |
| specs/einkommen/spec.md → Zufluss-Monitor (cash flow monitor) | Period navigation | test/features/einkommen/test_period_navigation.dart | test_period_navigation | 🔴 red |
| specs/einkommen/spec.md → Zufluss-Monitor (cash flow monitor) | Empty period shows no data | test/features/einkommen/test_empty_period_shows_no_data.dart | test_empty_period_shows_no_data | 🔴 red |
| specs/einkommen/spec.md → Kontokorrent (customer statement) | Generate Kontokorrent | test/features/einkommen/test_generate_kontokorrent.dart | test_generate_kontokorrent | 🔴 red |
| specs/einkommen/spec.md → Kontokorrent (customer statement) | Kontokorrent date filter | test/features/einkommen/test_kontokorrent_date_filter.dart | test_kontokorrent_date_filter | 🔴 red |
| specs/einkommen/spec.md → Kontokorrent (customer statement) | Kontokorrent for customer with no transactions | test/features/einkommen/test_kontokorrent_for_customer_with_no_transactions.dart | test_kontokorrent_for_customer_with_no_transactions | 🔴 red |
| specs/einkommen/spec.md → Verbindlichkeiten (payables) | Payable created on incoming invoice | test/features/einkommen/test_payable_created_on_incoming_invoice.dart | test_payable_created_on_incoming_invoice | 🔴 red |
| specs/einkommen/spec.md → Verbindlichkeiten (payables) | Payable payment | test/features/einkommen/test_payable_payment.dart | test_payable_payment | 🔴 red |
| specs/einkommen/spec.md → Verbindlichkeiten (payables) | Supplier overpayment creates credit | test/features/einkommen/test_supplier_overpayment_creates_credit.dart | test_supplier_overpayment_creates_credit | 🔴 red |
| specs/einkommen/spec.md → Dashboard integration | Dashboard widget reflects current state | test/features/einkommen/test_dashboard_widget_reflects_current_state.dart | test_dashboard_widget_reflects_current_state | 🔴 red |
| specs/einkommen/spec.md → Dashboard integration | Dashboard widgets update after payment | test/features/einkommen/test_dashboard_widgets_update_after_payment.dart | test_dashboard_widgets_update_after_payment | 🔴 red |
| specs/inventory/spec.md → Per-article inventory activation | Article with inventory disabled | test/features/inventory/test_article_with_inventory_disabled.dart | test_article_with_inventory_disabled | 🔴 red |
| specs/inventory/spec.md → Per-article inventory activation | Article with inventory enabled | test/features/inventory/test_article_with_inventory_enabled.dart | test_article_with_inventory_enabled | 🔴 red |
| specs/inventory/spec.md → Stock fields on articles | Stock decrement blocked at zero | test/features/inventory/test_stock_decrement_blocked_at_zero.dart | test_stock_decrement_blocked_at_zero | 🔴 red |
| specs/inventory/spec.md → Stock fields on articles | Stock decrement allowed below zero | test/features/inventory/test_stock_decrement_allowed_below_zero.dart | test_stock_decrement_allowed_below_zero | 🔴 red |
| specs/inventory/spec.md → Stock fields on articles | Fractional stock quantities | test/features/inventory/test_fractional_stock_quantities.dart | test_fractional_stock_quantities | 🔴 red |
| specs/inventory/spec.md → Stock decrement on invoice finalization | Multiple line items | test/features/inventory/test_multiple_line_items.dart | test_multiple_line_items | 🔴 red |
| specs/inventory/spec.md → Stock decrement on invoice finalization | No stock fields on non-inventory articles | test/features/inventory/test_no_stock_fields_on_non_inventory_articles.dart | test_no_stock_fields_on_non_inventory_articles | 🔴 red |
| specs/inventory/spec.md → Stock decrement on invoice finalization | Partial stock decrement on finalization failure | test/features/inventory/test_partial_stock_decrement_on_finalization_failure.dart | test_partial_stock_decrement_on_finalization_failure | 🔴 red |
| specs/inventory/spec.md → Stock restore on storno | Storno restores stock | test/features/inventory/test_storno_restores_stock.dart | test_storno_restores_stock | 🔴 red |
| specs/inventory/spec.md → Stock restore on storno | Storno of already-reduced stock | test/features/inventory/test_storno_of_already_reduced_stock.dart | test_storno_of_already_reduced_stock | 🔴 red |
| specs/inventory/spec.md → Stock restore on storno | Storno of invoice with non-inventory articles | test/features/inventory/test_storno_of_invoice_with_non_inventory_articles.dart | test_storno_of_invoice_with_non_inventory_articles | 🔴 red |
| specs/inventory/spec.md → Dashboard stock warning widget | Low stock warning displayed | test/features/inventory/test_low_stock_warning_displayed.dart | test_low_stock_warning_displayed | 🔴 red |
| specs/inventory/spec.md → Dashboard stock warning widget | No warnings | test/features/inventory/test_no_warnings.dart | test_no_warnings | 🔴 red |
| specs/inventory/spec.md → Dashboard stock warning widget | Article at exactly minimum stock | test/features/inventory/test_article_at_exactly_minimum_stock.dart | test_article_at_exactly_minimum_stock | 🔴 red |
| specs/inventory/spec.md → Stock warning in invoice form | Warning on insufficient stock | test/features/inventory/test_warning_on_insufficient_stock.dart | test_warning_on_insufficient_stock | 🔴 red |
| specs/inventory/spec.md → Stock warning in invoice form | Finalization blocked | test/features/inventory/test_finalization_blocked.dart | test_finalization_blocked | 🔴 red |
| specs/inventory/spec.md → Stock warning in invoice form | Draft save not blocked by stock warning | test/features/inventory/test_draft_save_not_blocked_by_stock_warning.dart | test_draft_save_not_blocked_by_stock_warning | 🔴 red |
| specs/inventory/spec.md → Manual stock adjustment | Absolute stock set | test/features/inventory/test_absolute_stock_set.dart | test_absolute_stock_set | 🔴 red |
| specs/inventory/spec.md → Manual stock adjustment | Relative stock adjustment | test/features/inventory/test_relative_stock_adjustment.dart | test_relative_stock_adjustment | 🔴 red |
| specs/inventory/spec.md → Manual stock adjustment | Negative stock set via manual adjustment | test/features/inventory/test_negative_stock_set_via_manual_adjustment.dart | test_negative_stock_set_via_manual_adjustment | 🔴 red |
| specs/inventory/spec.md → Configurable inventory activation in settings | Inventory globally disabled | test/features/inventory/test_inventory_globally_disabled.dart | test_inventory_globally_disabled | 🔴 red |
| specs/inventory/spec.md → Configurable inventory activation in settings | Inventory globally enabled | test/features/inventory/test_inventory_globally_enabled.dart | test_inventory_globally_enabled | 🔴 red |
| specs/mahnwesen/spec.md → Four Dunning Levels | Standard levels exist | test/features/mahnwesen/test_standard_levels_exist.dart | test_standard_levels_exist | 🔴 red |
| specs/mahnwesen/spec.md → Four Dunning Levels | User cannot delete system level | test/features/mahnwesen/test_user_cannot_delete_system_level.dart | test_user_cannot_delete_system_level | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Level Configuration | Configure level with multiplier | test/features/mahnwesen/test_configure_level_with_multiplier.dart | test_configure_level_with_multiplier | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Level Configuration | Configure level without multiplier | test/features/mahnwesen/test_configure_level_without_multiplier.dart | test_configure_level_without_multiplier | 🔴 red |
| specs/mahnwesen/spec.md → System Level Protection | Edit system level amounts | test/features/mahnwesen/test_edit_system_level_amounts.dart | test_edit_system_level_amounts | 🔴 red |
| specs/mahnwesen/spec.md → System Level Protection | Attempt to delete system level | test/features/mahnwesen/test_attempt_to_delete_system_level.dart | test_attempt_to_delete_system_level | 🔴 red |
| specs/mahnwesen/spec.md → Mahnung Snapshot | Create dunning letter | test/features/mahnwesen/test_create_dunning_letter.dart | test_create_dunning_letter | 🔴 red |
| specs/mahnwesen/spec.md → Mahnung Snapshot | Rechnung changes after snapshot | test/features/mahnwesen/test_rechnung_changes_after_snapshot.dart | test_rechnung_changes_after_snapshot | 🔴 red |
| specs/mahnwesen/spec.md → Mahngebühr Tracking | Partial payment of fee | test/features/mahnwesen/test_partial_payment_of_fee.dart | test_partial_payment_of_fee | 🔴 red |
| specs/mahnwesen/spec.md → Mahngebühr Tracking | Full payment of fee | test/features/mahnwesen/test_full_payment_of_fee.dart | test_full_payment_of_fee | 🔴 red |
| specs/mahnwesen/spec.md → Verzugszinsen Tracking | Interest calculation | test/features/mahnwesen/test_interest_calculation.dart | test_interest_calculation | 🔴 red |
| specs/mahnwesen/spec.md → Verzugszinsen Tracking | Zero outstanding amount | test/features/mahnwesen/test_zero_outstanding_amount.dart | test_zero_outstanding_amount | 🔴 red |
| specs/mahnwesen/spec.md → Fee/Interest Carry-Over | Carry-over on new dunning | test/features/mahnwesen/test_carry_over_on_new_dunning.dart | test_carry_over_on_new_dunning | 🔴 red |
| specs/mahnwesen/spec.md → Fee/Interest Carry-Over | No carry-over when fully paid | test/features/mahnwesen/test_no_carry_over_when_fully_paid.dart | test_no_carry_over_when_fully_paid | 🔴 red |
| specs/mahnwesen/spec.md → Mail-Versand via SMTP | Send dunning letter | test/features/mahnwesen/test_send_dunning_letter.dart | test_send_dunning_letter | 🔴 red |
| specs/mahnwesen/spec.md → Mail-Versand via SMTP | SMTP not configured | test/features/mahnwesen/test_smtp_not_configured.dart | test_smtp_not_configured | 🔴 red |
| specs/mahnwesen/spec.md → Configurable Attachments Per Level | Configure attachments | test/features/mahnwesen/test_configure_attachments.dart | test_configure_attachments | 🔴 red |
| specs/mahnwesen/spec.md → Configurable Attachments Per Level | No attachments configured | test/features/mahnwesen/test_no_attachments_configured.dart | test_no_attachments_configured | 🔴 red |
| specs/mahnwesen/spec.md → Customer Blocking (Kundensperrung) | Warning threshold | test/features/mahnwesen/test_warning_threshold.dart | test_warning_threshold | 🔴 red |
| specs/mahnwesen/spec.md → Customer Blocking (Kundensperrung) | Blocking threshold | test/features/mahnwesen/test_blocking_threshold.dart | test_blocking_threshold | 🔴 red |
| specs/mahnwesen/spec.md → Manual Customer Block (Mahnsperre) | Set manual block | test/features/mahnwesen/test_set_manual_block.dart | test_set_manual_block | 🔴 red |
| specs/mahnwesen/spec.md → Manual Customer Block (Mahnsperre) | Manual block without date | test/features/mahnwesen/test_manual_block_without_date.dart | test_manual_block_without_date | 🔴 red |
| specs/mahnwesen/spec.md → Manual Customer Block (Mahnsperre) | Block expires automatically | test/features/mahnwesen/test_block_expires_automatically.dart | test_block_expires_automatically | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Audit Trail | View dunning history | test/features/mahnwesen/test_view_dunning_history.dart | test_view_dunning_history | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Audit Trail | Empty history | test/features/mahnwesen/test_empty_history.dart | test_empty_history | 🔴 red |
| specs/mahnwesen/spec.md → Invoice Dunning Level | Invoice at level 2 | test/features/mahnwesen/test_invoice_at_level_2.dart | test_invoice_at_level_2 | 🔴 red |
| specs/mahnwesen/spec.md → Invoice Dunning Level | Invoice payment resets level | test/features/mahnwesen/test_invoice_payment_resets_level.dart | test_invoice_payment_resets_level | 🔴 red |
| specs/mahnwesen/spec.md → Dashboard Overdue Widget | Overdue widget shows data | test/features/mahnwesen/test_overdue_widget_shows_data.dart | test_overdue_widget_shows_data | 🔴 red |
| specs/mahnwesen/spec.md → Dashboard Overdue Widget | No overdue invoices | test/features/mahnwesen/test_no_overdue_invoices.dart | test_no_overdue_invoices | 🔴 red |
| specs/mahnwesen/spec.md → Mahnwesen Settings Singleton | Configure grace period | test/features/mahnwesen/test_configure_grace_period.dart | test_configure_grace_period | 🔴 red |
| specs/mahnwesen/spec.md → Mahnwesen Settings Singleton | Default settings on fresh install | test/features/mahnwesen/test_default_settings_on_fresh_install.dart | test_default_settings_on_fresh_install | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Letter PDF Generation | Generate PDF | test/features/mahnwesen/test_generate_pdf.dart | test_generate_pdf | 🔴 red |
| specs/mahnwesen/spec.md → Dunning Letter PDF Generation | Missing company data | test/features/mahnwesen/test_missing_company_data.dart | test_missing_company_data | 🔴 red |
| specs/mahnwesen/spec.md → Custom Dunning Levels | Add custom level | test/features/mahnwesen/test_add_custom_level.dart | test_add_custom_level | 🔴 red |
| specs/mahnwesen/spec.md → Custom Dunning Levels | Custom level is deletable | test/features/mahnwesen/test_custom_level_is_deletable.dart | test_custom_level_is_deletable | 🔴 red |
| specs/pdf/spec.md → Document Type Coverage | Rechnung generation | test/features/pdf/test_rechnung_generation.dart | test_rechnung_generation | 🔴 red |
| specs/pdf/spec.md → Document Type Coverage | Unsupported document type | test/features/pdf/test_unsupported_document_type.dart | test_unsupported_document_type | 🔴 red |
| specs/pdf/spec.md → Storno PDF | Storno generation | test/features/pdf/test_storno_generation.dart | test_storno_generation | 🔴 red |
| specs/pdf/spec.md → Storno PDF | Missing storno_grund | test/features/pdf/test_missing_storno_grund.dart | test_missing_storno_grund | 🔴 red |
| specs/pdf/spec.md → Gutschrift PDF | Gutschrift generation | test/features/pdf/test_gutschrift_generation.dart | test_gutschrift_generation | 🔴 red |
| specs/pdf/spec.md → Gutschrift PDF | Gutschrift without reference Rechnung | test/features/pdf/test_gutschrift_without_reference_rechnung.dart | test_gutschrift_without_reference_rechnung | 🔴 red |
| specs/pdf/spec.md → Angebot PDF | Angebot generation | test/features/pdf/test_angebot_generation.dart | test_angebot_generation | 🔴 red |
| specs/pdf/spec.md → Angebot PDF | Angebot without gueltig_bis | test/features/pdf/test_angebot_without_gueltig_bis.dart | test_angebot_without_gueltig_bis | 🔴 red |
| specs/pdf/spec.md → Auftrag PDF | Auftrag generation | test/features/pdf/test_auftrag_generation.dart | test_auftrag_generation | 🔴 red |
| specs/pdf/spec.md → Auftrag PDF | Auftrag without linked documents | test/features/pdf/test_auftrag_without_linked_documents.dart | test_auftrag_without_linked_documents | 🔴 red |
| specs/pdf/spec.md → Proforma PDF | Proforma generation | test/features/pdf/test_proforma_generation.dart | test_proforma_generation | 🔴 red |
| specs/pdf/spec.md → Proforma PDF | Proforma without Leistungszeitraum | test/features/pdf/test_proforma_without_leistungszeitraum.dart | test_proforma_without_leistungszeitraum | 🔴 red |
| specs/pdf/spec.md → Lieferschein PDF | Lieferschein generation | test/features/pdf/test_lieferschein_generation.dart | test_lieferschein_generation | 🔴 red |
| specs/pdf/spec.md → Lieferschein PDF | Lieferschein with linked Rechnung | test/features/pdf/test_lieferschein_with_linked_rechnung.dart | test_lieferschein_with_linked_rechnung | 🔴 red |
| specs/pdf/spec.md → PDF Templates | Standard template rendering | test/features/pdf/test_standard_template_rendering.dart | test_standard_template_rendering | 🔴 red |
| specs/pdf/spec.md → PDF Templates | Grün/Kleinunternehmer template rendering | test/features/pdf/test_gr_n_kleinunternehmer_template_rendering.dart | test_gr_n_kleinunternehmer_template_rendering | 🔴 red |
| specs/pdf/spec.md → PDF Templates | Unknown template value | test/features/pdf/test_unknown_template_value.dart | test_unknown_template_value | 🔴 red |
| specs/pdf/spec.md → Company Header | Logo present | test/features/pdf/test_logo_present.dart | test_logo_present | 🔴 red |
| specs/pdf/spec.md → Company Header | No logo configured | test/features/pdf/test_no_logo_configured.dart | test_no_logo_configured | 🔴 red |
| specs/pdf/spec.md → Customer Address Block | Standard customer address | test/features/pdf/test_standard_customer_address.dart | test_standard_customer_address | 🔴 red |
| specs/pdf/spec.md → Customer Address Block | Einmalkunde address | test/features/pdf/test_einmalkunde_address.dart | test_einmalkunde_address | 🔴 red |
| specs/pdf/spec.md → Customer Address Block | Missing customer address fields | test/features/pdf/test_missing_customer_address_fields.dart | test_missing_customer_address_fields | 🔴 red |
| specs/pdf/spec.md → Position Table | Rechnung position table | test/features/pdf/test_rechnung_position_table.dart | test_rechnung_position_table | 🔴 red |
| specs/pdf/spec.md → Position Table | Differenzbesteuerung §25a display | test/features/pdf/test_differenzbesteuerung_25a_display.dart | test_differenzbesteuerung_25a_display | 🔴 red |
| specs/pdf/spec.md → Position Table | Position with zero quantity | test/features/pdf/test_position_with_zero_quantity.dart | test_position_with_zero_quantity | 🔴 red |
| specs/pdf/spec.md → Position Table | Position with negative menge (Storno) | test/features/pdf/test_position_with_negative_menge_storno.dart | test_position_with_negative_menge_storno | 🔴 red |
| specs/pdf/spec.md → Payment Block | Standard payment block | test/features/pdf/test_standard_payment_block.dart | test_standard_payment_block | 🔴 red |
| specs/pdf/spec.md → Payment Block | QR code payment | test/features/pdf/test_qr_code_payment.dart | test_qr_code_payment | 🔴 red |
| specs/pdf/spec.md → Payment Block | SEPA QR code | test/features/pdf/test_sepa_qr_code.dart | test_sepa_qr_code | 🔴 red |
| specs/pdf/spec.md → Payment Block | Missing IBAN | test/features/pdf/test_missing_iban.dart | test_missing_iban | 🔴 red |
| specs/pdf/spec.md → Einleitungstext and Schlusstext | Per-type text rendering | test/features/pdf/test_per_type_text_rendering.dart | test_per_type_text_rendering | 🔴 red |
| specs/pdf/spec.md → Einleitungstext and Schlusstext | Empty text field | test/features/pdf/test_empty_text_field.dart | test_empty_text_field | 🔴 red |
| specs/pdf/spec.md → Einleitungstext and Schlusstext | Markdown formatting | test/features/pdf/test_markdown_formatting.dart | test_markdown_formatting | 🔴 red |
| specs/pdf/spec.md → Einleitungstext and Schlusstext | Text with only whitespace | test/features/pdf/test_text_with_only_whitespace.dart | test_text_with_only_whitespace | 🔴 red |
| specs/pdf/spec.md → Unterschrift Image | Signature present | test/features/pdf/test_signature_present.dart | test_signature_present | 🔴 red |
| specs/pdf/spec.md → Unterschrift Image | Signature disabled | test/features/pdf/test_signature_disabled.dart | test_signature_disabled | 🔴 red |
| specs/pdf/spec.md → KOPIE Watermark | Copy generation | test/features/pdf/test_copy_generation.dart | test_copy_generation | 🔴 red |
| specs/pdf/spec.md → KOPIE Watermark | Original document | test/features/pdf/test_original_document.dart | test_original_document | 🔴 red |
| specs/pdf/spec.md → ZUGFeRD and XRechnung E-Invoicing | ZUGFeRD PDF generation | test/features/pdf/test_zugferd_pdf_generation.dart | test_zugferd_pdf_generation | 🔴 red |
| specs/pdf/spec.md → ZUGFeRD and XRechnung E-Invoicing | XRechnung generation | test/features/pdf/test_xrechnung_generation.dart | test_xrechnung_generation | 🔴 red |
| specs/pdf/spec.md → ZUGFeRD and XRechnung E-Invoicing | Invalid invoice data for e-invoicing | test/features/pdf/test_invalid_invoice_data_for_e_invoicing.dart | test_invalid_invoice_data_for_e_invoicing | 🔴 red |
| specs/pdf/spec.md → PDF/A-3 Archival | PDF/A-3 output | test/features/pdf/test_pdf_a_3_output.dart | test_pdf_a_3_output | 🔴 red |
| specs/pdf/spec.md → PDF/A-3 Archival | PDF/A-3 with attachments | test/features/pdf/test_pdf_a_3_with_attachments.dart | test_pdf_a_3_with_attachments | 🔴 red |
| specs/pdf/spec.md → GoBD Signatures | Document finalization signature | test/features/pdf/test_document_finalization_signature.dart | test_document_finalization_signature | 🔴 red |
| specs/pdf/spec.md → GoBD Signatures | Signature verification | test/features/pdf/test_signature_verification.dart | test_signature_verification | 🔴 red |
| specs/pdf/spec.md → GoBD Signatures | Tampered document detection | test/features/pdf/test_tampered_document_detection.dart | test_tampered_document_detection | 🔴 red |
| specs/pdf/spec.md → Mahnung PDF | Mahnung generation | test/features/pdf/test_mahnung_generation.dart | test_mahnung_generation | 🔴 red |
| specs/pdf/spec.md → Mahnung PDF | Mahnung with attachments | test/features/pdf/test_mahnung_with_attachments.dart | test_mahnung_with_attachments | 🔴 red |
| specs/pdf/spec.md → Mahnung PDF | Mahnung with Kontokorrent | test/features/pdf/test_mahnung_with_kontokorrent.dart | test_mahnung_with_kontokorrent | 🔴 red |
| specs/pdf/spec.md → Mahnung PDF | No outstanding invoices | test/features/pdf/test_no_outstanding_invoices.dart | test_no_outstanding_invoices | 🔴 red |
| specs/pdf/spec.md → Anlage EKS PDF | EKS generation | test/features/pdf/test_eks_generation.dart | test_eks_generation | 🔴 red |
| specs/pdf/spec.md → Anlage EKS PDF | EKS field population | test/features/pdf/test_eks_field_population.dart | test_eks_field_population | 🔴 red |
| specs/pdf/spec.md → Anlage EKS PDF | Missing EKS customer data | test/features/pdf/test_missing_eks_customer_data.dart | test_missing_eks_customer_data | 🔴 red |
| specs/pdf/spec.md → Tagesabschluss PDF | Tagesabschluss generation | test/features/pdf/test_tagesabschluss_generation.dart | test_tagesabschluss_generation | 🔴 red |
| specs/pdf/spec.md → Tagesabschluss PDF | Counting discrepancy | test/features/pdf/test_counting_discrepancy.dart | test_counting_discrepancy | 🔴 red |
| specs/pdf/spec.md → Content-Disposition Inline | PDF via webview | test/features/pdf/test_pdf_via_webview.dart | test_pdf_via_webview | 🔴 red |
| specs/pdf/spec.md → Content-Disposition Inline | Non-PDF download | test/features/pdf/test_non_pdf_download.dart | test_non_pdf_download | 🔴 red |
| specs/pdf/spec.md → Content-Disposition Inline | PDF with attachment disposition (forbidden) | test/features/pdf/test_pdf_with_attachment_disposition_forbidden.dart | test_pdf_with_attachment_disposition_forbidden | 🔴 red |
| specs/pdf/spec.md → Footer with Page Numbers | Multi-page document | test/features/pdf/test_multi_page_document.dart | test_multi_page_document | 🔴 red |
| specs/pdf/spec.md → Footer with Page Numbers | Single-page document | test/features/pdf/test_single_page_document.dart | test_single_page_document | 🔴 red |
| specs/pdf/spec.md → Nummernkreise for Document Numbers | Number generation | test/features/pdf/test_number_generation.dart | test_number_generation | 🔴 red |
| specs/pdf/spec.md → Nummernkreise for Document Numbers | Number uniqueness | test/features/pdf/test_number_uniqueness.dart | test_number_uniqueness | 🔴 red |
| specs/pdf/spec.md → Nummernkreise for Document Numbers | Nummernkreis exhausted | test/features/pdf/test_nummernkreis_exhausted.dart | test_nummernkreis_exhausted | 🔴 red |
| specs/pdf/spec.md → Differenzbesteuerung §25a Display | §25a position display | test/features/pdf/test_25a_position_display.dart | test_25a_position_display | 🔴 red |
| specs/pdf/spec.md → Differenzbesteuerung §25a Display | §25a summary | test/features/pdf/test_25a_summary.dart | test_25a_summary | 🔴 red |
| specs/pdf/spec.md → Differenzbesteuerung §25a Display | Mixed document with §25a and standard positions | test/features/pdf/test_mixed_document_with_25a_and_standard_positions.dart | test_mixed_document_with_25a_and_standard_positions | 🔴 red |
| specs/pdf/spec.md → Leistungszeitraum | Service period on Rechnung | test/features/pdf/test_service_period_on_rechnung.dart | test_service_period_on_rechnung | 🔴 red |
| specs/pdf/spec.md → Leistungszeitraum | No service period | test/features/pdf/test_no_service_period.dart | test_no_service_period | 🔴 red |
| specs/pdf/spec.md → Leistungszeitraum | Partial service period | test/features/pdf/test_partial_service_period.dart | test_partial_service_period | 🔴 red |
| specs/pdf/spec.md → Absender Snapshot | Finalized document PDF | test/features/pdf/test_finalized_document_pdf.dart | test_finalized_document_pdf | 🔴 red |
| specs/pdf/spec.md → Absender Snapshot | Draft document PDF | test/features/pdf/test_draft_document_pdf.dart | test_draft_document_pdf | 🔴 red |
| specs/pdf/spec.md → Absender Snapshot | Absender snapshot missing on finalized document | test/features/pdf/test_absender_snapshot_missing_on_finalized_document.dart | test_absender_snapshot_missing_on_finalized_document | 🔴 red |
| specs/pdf/spec.md → Rabatt Display | Percentage rabatt | test/features/pdf/test_percentage_rabatt.dart | test_percentage_rabatt | 🔴 red |
| specs/pdf/spec.md → Rabatt Display | Fixed amount rabatt | test/features/pdf/test_fixed_amount_rabatt.dart | test_fixed_amount_rabatt | 🔴 red |
| specs/pdf/spec.md → Rabatt Display | Rechnungsrabatt | test/features/pdf/test_rechnungsrabatt.dart | test_rechnungsrabatt | 🔴 red |
| specs/pdf/spec.md → Rabatt Display | No rabatt | test/features/pdf/test_no_rabatt.dart | test_no_rabatt | 🔴 red |
| specs/pdf/spec.md → Logo Embedding | PNG logo | test/features/pdf/test_png_logo.dart | test_png_logo | 🔴 red |
| specs/pdf/spec.md → Logo Embedding | Logo exceeds header area | test/features/pdf/test_logo_exceeds_header_area.dart | test_logo_exceeds_header_area | 🔴 red |
| specs/pdf/spec.md → Logo Embedding | Unsupported logo format | test/features/pdf/test_unsupported_logo_format.dart | test_unsupported_logo_format | 🔴 red |
| specs/profiles/spec.md → Separate databases per profile | New profile creates isolated database | test/features/profiles/test_new_profile_creates_isolated_database.dart | test_new_profile_creates_isolated_database | 🔴 red |
| specs/profiles/spec.md → Separate databases per profile | Profile isolation | test/db/profile_test.dart | keeps identical invoice numbers isolated between profile databases | 🟢 green |
| specs/profiles/spec.md → Separate databases per profile | Corrupted profile.json falls back to default | test/db/profile_test.dart | falls back to first profile when profile pointer is corrupted | 🟢 green |
| specs/profiles/spec.md → APP_DATA_DIR resolved per profile | Upload path uses active profile | test/features/profiles/test_upload_path_uses_active_profile.dart | test_upload_path_uses_active_profile | 🔴 red |
| specs/profiles/spec.md → APP_DATA_DIR resolved per profile | Backup path uses active profile | test/features/profiles/test_backup_path_uses_active_profile.dart | test_backup_path_uses_active_profile | 🔴 red |
| specs/profiles/spec.md → APP_DATA_DIR resolved per profile | Code outside APP_DATA_DIR is rejected | test/db/profile_test.dart | rejects paths outside active profile data directory | 🟢 green |
| specs/profiles/spec.md → Profile switching requires restart | Switch profile | test/features/profiles/test_switch_profile.dart | test_switch_profile | 🔴 red |
| specs/profiles/spec.md → Profile switching requires restart | Switch to non-existent profile | test/features/profiles/test_switch_to_non_existent_profile.dart | test_switch_to_non_existent_profile | 🔴 red |
| specs/profiles/spec.md → Profile switching requires restart | Switch to same profile is a no-op | test/features/profiles/test_switch_to_same_profile_is_a_no_op.dart | test_switch_to_same_profile_is_a_no_op | 🔴 red |
| specs/profiles/spec.md → Profile manager UI | Profile manager accessible with multiple profiles | test/features/profiles/test_profile_manager_accessible_with_multiple_profiles.dart | test_profile_manager_accessible_with_multiple_profiles | 🔴 red |
| specs/profiles/spec.md → Profile manager UI | Profile manager hidden with single profile | test/features/profiles/test_profile_manager_hidden_with_single_profile.dart | test_profile_manager_hidden_with_single_profile | 🔴 red |
| specs/profiles/spec.md → Profile manager UI | Profile manager shown when explicitly activated | test/features/profiles/test_profile_manager_shown_when_explicitly_activated.dart | test_profile_manager_shown_when_explicitly_activated | 🔴 red |
| specs/profiles/spec.md → Auto-show profile manager when multiple profiles exist | Multiple profiles on first start | test/features/profiles/test_multiple_profiles_on_first_start.dart | test_multiple_profiles_on_first_start | 🔴 red |
| specs/profiles/spec.md → Auto-show profile manager when multiple profiles exist | Single profile auto-load | test/features/profiles/test_single_profile_auto_load.dart | test_single_profile_auto_load | 🔴 red |
| specs/profiles/spec.md → Auto-show profile manager when multiple profiles exist | No profiles exist | test/features/profiles/test_no_profiles_exist.dart | test_no_profiles_exist | 🔴 red |
| specs/profiles/spec.md → Create new profile | Create profile with unique name | test/features/profiles/test_create_profile_with_unique_name.dart | test_create_profile_with_unique_name | 🔴 red |
| specs/profiles/spec.md → Create new profile | Create profile with duplicate name | test/features/profiles/test_create_profile_with_duplicate_name.dart | test_create_profile_with_duplicate_name | 🔴 red |
| specs/profiles/spec.md → Create new profile | Empty profile name rejected | test/features/profiles/test_empty_profile_name_rejected.dart | test_empty_profile_name_rejected | 🔴 red |
| specs/profiles/spec.md → Delete profile | Delete inactive profile | test/features/profiles/test_delete_inactive_profile.dart | test_delete_inactive_profile | 🔴 red |
| specs/profiles/spec.md → Delete profile | Cannot delete active profile | test/features/profiles/test_cannot_delete_active_profile.dart | test_cannot_delete_active_profile | 🔴 red |
| specs/profiles/spec.md → Delete profile | Delete last remaining profile | test/features/profiles/test_delete_last_remaining_profile.dart | test_delete_last_remaining_profile | 🔴 red |
| specs/profiles/spec.md → Rename profile | Rename profile | test/features/profiles/test_rename_profile.dart | test_rename_profile | 🔴 red |
| specs/profiles/spec.md → Rename profile | Rename to duplicate name rejected | test/features/profiles/test_rename_to_duplicate_name_rejected.dart | test_rename_to_duplicate_name_rejected | 🔴 red |
| specs/profiles/spec.md → Rename profile | Rename active profile triggers restart | test/features/profiles/test_rename_active_profile_triggers_restart.dart | test_rename_active_profile_triggers_restart | 🔴 red |
| specs/profiles/spec.md → Platform-specific data paths | Linux profile path | test/features/profiles/test_linux_profile_path.dart | test_linux_profile_path | 🔴 red |
| specs/profiles/spec.md → Platform-specific data paths | macOS profile path | test/features/profiles/test_macos_profile_path.dart | test_macos_profile_path | 🔴 red |
| specs/profiles/spec.md → Platform-specific data paths | Windows profile path | test/features/profiles/test_windows_profile_path.dart | test_windows_profile_path | 🔴 red |
| specs/recurring/spec.md → Rechnungsvorlagen Lifecycle | Activate template | test/features/recurring/test_activate_template.dart | test_activate_template | 🔴 red |
| specs/recurring/spec.md → Rechnungsvorlagen Lifecycle | Pause template | test/features/recurring/test_pause_template.dart | test_pause_template | 🔴 red |
| specs/recurring/spec.md → Rechnungsvorlagen Lifecycle | End template | test/features/recurring/test_end_template.dart | test_end_template | 🔴 red |
| specs/recurring/spec.md → Invoice Generation Interval | Monthly generation | test/features/recurring/test_monthly_generation.dart | test_monthly_generation | 🔴 red |
| specs/recurring/spec.md → Invoice Generation Interval | Quarterly generation | test/features/recurring/test_quarterly_generation.dart | test_quarterly_generation | 🔴 red |
| specs/recurring/spec.md → Invoice Generation Interval | Yearly generation | test/features/recurring/test_yearly_generation.dart | test_yearly_generation | 🔴 red |
| specs/recurring/spec.md → Invalid Interval Rejection | Invalid interval | test/features/recurring/test_invalid_interval.dart | test_invalid_interval | 🔴 red |
| specs/recurring/spec.md → Invalid Interval Rejection | Empty interval | test/features/recurring/test_empty_interval.dart | test_empty_interval | 🔴 red |
| specs/recurring/spec.md → Template Positionen as JSON | Save template with positions | test/features/recurring/test_save_template_with_positions.dart | test_save_template_with_positions | 🔴 red |
| specs/recurring/spec.md → Template Positionen as JSON | Save template with no positions | test/features/recurring/test_save_template_with_no_positions.dart | test_save_template_with_no_positions | 🔴 red |
| specs/recurring/spec.md → Price Comparison via Artikel | Price mismatch warning | test/features/recurring/test_price_mismatch_warning.dart | test_price_mismatch_warning | 🔴 red |
| specs/recurring/spec.md → Price Comparison via Artikel | Price matches | test/features/recurring/test_price_matches.dart | test_price_matches | 🔴 red |
| specs/recurring/spec.md → Auftrag-Verknüpfung | Template linked to order | test/features/recurring/test_template_linked_to_order.dart | test_template_linked_to_order | 🔴 red |
| specs/recurring/spec.md → Auftrag-Verknüpfung | Order completed clears template | test/features/recurring/test_order_completed_clears_template.dart | test_order_completed_clears_template | 🔴 red |
| specs/recurring/spec.md → Auto-Generation from Templates | Auto-generate on startup | test/features/recurring/test_auto_generate_on_startup.dart | test_auto_generate_on_startup | 🔴 red |
| specs/recurring/spec.md → Auto-Generation from Templates | Missed generation | test/features/recurring/test_missed_generation.dart | test_missed_generation | 🔴 red |
| specs/recurring/spec.md → Generated Invoice Tracking | View generated invoices | test/features/recurring/test_view_generated_invoices.dart | test_view_generated_invoices | 🔴 red |
| specs/recurring/spec.md → Generated Invoice Tracking | Template with no generated invoices | test/features/recurring/test_template_with_no_generated_invoices.dart | test_template_with_no_generated_invoices | 🔴 red |
| specs/recurring/spec.md → Buchungsvorlagen for Fixed Costs | Create booking template | test/features/recurring/test_create_booking_template.dart | test_create_booking_template | 🔴 red |
| specs/recurring/spec.md → Buchungsvorlagen for Fixed Costs | Delete booking template | test/features/recurring/test_delete_booking_template.dart | test_delete_booking_template | 🔴 red |
| specs/recurring/spec.md → Buchungsvorlage Modus | Direkt mode | test/features/recurring/test_direkt_mode.dart | test_direkt_mode | 🔴 red |
| specs/recurring/spec.md → Buchungsvorlage Modus | Beleg mode | test/features/recurring/test_beleg_mode.dart | test_beleg_mode | 🔴 red |
| specs/recurring/spec.md → Buchungsvorlage Art | Ausgabe direction | test/features/recurring/test_ausgabe_direction.dart | test_ausgabe_direction | 🔴 red |
| specs/recurring/spec.md → Buchungsvorlage Art | Einnahme direction | test/features/recurring/test_einnahme_direction.dart | test_einnahme_direction | 🔴 red |
| specs/recurring/spec.md → Buchungsvorlage Auto-Generation | Auto-generate journal entry | test/features/recurring/test_auto_generate_journal_entry.dart | test_auto_generate_journal_entry | 🔴 red |
| specs/recurring/spec.md → Buchungsvorlage Auto-Generation | Inactive template skipped | test/features/recurring/test_inactive_template_skipped.dart | test_inactive_template_skipped | 🔴 red |
| specs/recurring/spec.md → Supplier and Account Linking | Linked supplier | test/features/recurring/test_linked_supplier.dart | test_linked_supplier | 🔴 red |
| specs/recurring/spec.md → Supplier and Account Linking | Linked account | test/features/recurring/test_linked_account.dart | test_linked_account | 🔴 red |
| specs/recurring/spec.md → Template Edit Propagation | Edit template price | test/features/recurring/test_edit_template_price.dart | test_edit_template_price | 🔴 red |
| specs/recurring/spec.md → Template Edit Propagation | Edit template interval | test/features/recurring/test_edit_template_interval.dart | test_edit_template_interval | 🔴 red |
| specs/recurring/spec.md → Template Deletion Protection | Attempt delete with invoices | test/features/recurring/test_attempt_delete_with_invoices.dart | test_attempt_delete_with_invoices | 🔴 red |
| specs/recurring/spec.md → Template Deletion Protection | Delete template without invoices | test/features/recurring/test_delete_template_without_invoices.dart | test_delete_template_without_invoices | 🔴 red |
| specs/setup/spec.md → Empty database detection triggers wizard | First launch with empty database | test/features/setup/test_first_launch_with_empty_database.dart | test_first_launch_with_empty_database | 🔴 red |
| specs/setup/spec.md → Empty database detection triggers wizard | Existing database with data | test/features/setup/test_existing_database_with_data.dart | test_existing_database_with_data | 🔴 red |
| specs/setup/spec.md → Empty database detection triggers wizard | Corrupted unternehmen record | test/features/setup/test_corrupted_unternehmen_record.dart | test_corrupted_unternehmen_record | 🔴 red |
| specs/setup/spec.md → Four-step wizard flow | Complete wizard flow | test/features/setup/test_complete_wizard_flow.dart | test_complete_wizard_flow | 🔴 red |
| specs/setup/spec.md → Four-step wizard flow | Navigation between steps | test/features/setup/test_navigation_between_steps.dart | test_navigation_between_steps | 🔴 red |
| specs/setup/spec.md → Four-step wizard flow | Skip wizard | test/features/setup/test_skip_wizard.dart | test_skip_wizard | 🔴 red |
| specs/setup/spec.md → Required field validation per step | Step 1 validation failure | test/features/setup/test_step_1_validation_failure.dart | test_step_1_validation_failure | 🔴 red |
| specs/setup/spec.md → Required field validation per step | Step 2 validation failure | test/features/setup/test_step_2_validation_failure.dart | test_step_2_validation_failure | 🔴 red |
| specs/setup/spec.md → Required field validation per step | Step 3 validation failure | test/features/setup/test_step_3_validation_failure.dart | test_step_3_validation_failure | 🔴 red |
| specs/setup/spec.md → Kassenbestand initialization | Default cash balance | test/features/setup/test_default_cash_balance.dart | test_default_cash_balance | 🔴 red |
| specs/setup/spec.md → Kassenbestand initialization | Custom cash balance | test/features/setup/test_custom_cash_balance.dart | test_custom_cash_balance | 🔴 red |
| specs/setup/spec.md → Kassenbestand initialization | Negative cash balance rejected | test/features/setup/test_negative_cash_balance_rejected.dart | test_negative_cash_balance_rejected | 🔴 red |
| specs/setup/spec.md → Profile selection on startup | Multiple profiles exist | test/features/setup/test_multiple_profiles_exist.dart | test_multiple_profiles_exist | 🔴 red |
| specs/setup/spec.md → Profile selection on startup | Single profile exists | test/features/setup/test_single_profile_exists.dart | test_single_profile_exists | 🔴 red |
| specs/setup/spec.md → Profile selection on startup | Profile switching requires restart | test/features/setup/test_profile_switching_requires_restart.dart | test_profile_switching_requires_restart | 🔴 red |
| specs/setup/spec.md → Profile selection on startup | No profiles exist | test/features/setup/test_no_profiles_exist.dart | test_no_profiles_exist | 🔴 red |
| specs/setup/spec.md → Profile manager UI | Create new profile | test/features/setup/test_create_new_profile.dart | test_create_new_profile | 🔴 red |
| specs/setup/spec.md → Profile manager UI | Delete profile | test/features/setup/test_delete_profile.dart | test_delete_profile | 🔴 red |
| specs/setup/spec.md → Profile manager UI | Rename to duplicate name rejected | test/features/setup/test_rename_to_duplicate_name_rejected.dart | test_rename_to_duplicate_name_rejected | 🔴 red |
| specs/setup/spec.md → Platform-specific data paths | Linux data path | test/features/setup/test_linux_data_path.dart | test_linux_data_path | 🔴 red |
| specs/setup/spec.md → Platform-specific data paths | macOS data path | test/features/setup/test_macos_data_path.dart | test_macos_data_path | 🔴 red |
| specs/setup/spec.md → Platform-specific data paths | Windows data path | test/features/setup/test_windows_data_path.dart | test_windows_data_path | 🔴 red |
| specs/stammdaten/spec.md → Kunden — CRUD | Create customer with auto-assigned Debitor-Nr | test/features/stammdaten/test_create_customer_with_auto_assigned_debitor_nr.dart | test_create_customer_with_auto_assigned_debitor_nr | 🔴 red |
| specs/stammdaten/spec.md → Kunden — CRUD | Delete customer with active documents | test/features/stammdaten/test_delete_customer_with_active_documents.dart | test_delete_customer_with_active_documents | 🔴 red |
| specs/stammdaten/spec.md → Kunden — Kreditlimit | Invoice finalization exceeds credit limit | test/features/stammdaten/test_invoice_finalization_exceeds_credit_limit.dart | test_invoice_finalization_exceeds_credit_limit | 🔴 red |
| specs/stammdaten/spec.md → Kunden — Kreditlimit | Invoice within credit limit proceeds without warning | test/features/stammdaten/test_invoice_within_credit_limit_proceeds_without_warning.dart | test_invoice_within_credit_limit_proceeds_without_warning | 🔴 red |
| specs/stammdaten/spec.md → Kunden — Mahngesperrt | Dunning run skips blocked customer | test/features/stammdaten/test_dunning_run_skips_blocked_customer.dart | test_dunning_run_skips_blocked_customer | 🔴 red |
| specs/stammdaten/spec.md → Kunden — Mahngesperrt | Manual dunning blocked for Mahngesperrt customer | test/features/stammdaten/test_manual_dunning_blocked_for_mahngesperrt_customer.dart | test_manual_dunning_blocked_for_mahngesperrt_customer | 🔴 red |
| specs/stammdaten/spec.md → Kunden — Zugferd aktiv | ZUGFeRD invoice generation | test/features/stammdaten/test_zugferd_invoice_generation.dart | test_zugferd_invoice_generation | 🔴 red |
| specs/stammdaten/spec.md → Kunden — Zugferd aktiv | ZUGFeRD not generated when disabled | test/features/stammdaten/test_zugferd_not_generated_when_disabled.dart | test_zugferd_not_generated_when_disabled | 🔴 red |
| specs/stammdaten/spec.md → Kunden — USt-IdNr validation | Invalid DE USt-IdNr rejected | test/features/stammdaten/test_invalid_de_ust_idnr_rejected.dart | test_invalid_de_ust_idnr_rejected | 🔴 red |
| specs/stammdaten/spec.md → Kunden — USt-IdNr validation | Non-EU free text accepted | test/features/stammdaten/test_non_eu_free_text_accepted.dart | test_non_eu_free_text_accepted | 🔴 red |
| specs/stammdaten/spec.md → Kunden — Steuernummer Ausland | Drittland invoice shows foreign tax number | test/features/stammdaten/test_drittland_invoice_shows_foreign_tax_number.dart | test_drittland_invoice_shows_foreign_tax_number | 🔴 red |
| specs/stammdaten/spec.md → Kunden — Steuernummer Ausland | EU customer omits foreign tax number | test/features/stammdaten/test_eu_customer_omits_foreign_tax_number.dart | test_eu_customer_omits_foreign_tax_number | 🔴 red |
| specs/stammdaten/spec.md → Lieferanten — CRUD | Create supplier with auto-assigned Kreditor-Nr | test/features/stammdaten/test_create_supplier_with_auto_assigned_kreditor_nr.dart | test_create_supplier_with_auto_assigned_kreditor_nr | 🔴 red |
| specs/stammdaten/spec.md → Lieferanten — CRUD | Delete supplier with journal references | test/features/stammdaten/test_delete_supplier_with_journal_references.dart | test_delete_supplier_with_journal_references | 🔴 red |
| specs/stammdaten/spec.md → Lieferanten — USt-IdNr validation | Invalid AT USt-IdNr rejected | test/features/stammdaten/test_invalid_at_ust_idnr_rejected.dart | test_invalid_at_ust_idnr_rejected | 🔴 red |
| specs/stammdaten/spec.md → Lieferanten — USt-IdNr validation | Valid EU USt-IdNr accepted | test/features/stammdaten/test_valid_eu_ust_idnr_accepted.dart | test_valid_eu_ust_idnr_accepted | 🔴 red |
| specs/stammdaten/spec.md → Artikel — CRUD | Create article with all types | test/features/stammdaten/test_create_article_with_all_types.dart | test_create_article_with_all_types | 🔴 red |
| specs/stammdaten/spec.md → Artikel — CRUD | Delete article referenced by invoice position | test/features/stammdaten/test_delete_article_referenced_by_invoice_position.dart | test_delete_article_referenced_by_invoice_position | 🔴 red |
| specs/stammdaten/spec.md → Artikel — VK-Preise | Brutto input preserves exact netto | test/features/stammdaten/test_brutto_input_preserves_exact_netto.dart | test_brutto_input_preserves_exact_netto | 🔴 red |
| specs/stammdaten/spec.md → Artikel — VK-Preise | Netto input preserves exact brutto | test/features/stammdaten/test_netto_input_preserves_exact_brutto.dart | test_netto_input_preserves_exact_brutto | 🔴 red |
| specs/stammdaten/spec.md → Artikel — Differenzbesteuerung | Margin scheme invoice calculation | test/features/stammdaten/test_margin_scheme_invoice_calculation.dart | test_margin_scheme_invoice_calculation | 🔴 red |
| specs/stammdaten/spec.md → Artikel — Differenzbesteuerung | Margin scheme without EK price | test/features/stammdaten/test_margin_scheme_without_ek_price.dart | test_margin_scheme_without_ek_price | 🔴 red |
| specs/stammdaten/spec.md → Artikel — Lagerführung | Stock decrement on finalization | test/features/stammdaten/test_stock_decrement_on_finalization.dart | test_stock_decrement_on_finalization | 🔴 red |
| specs/stammdaten/spec.md → Artikel — Lagerführung | Negative stock blocked | test/features/stammdaten/test_negative_stock_blocked.dart | test_negative_stock_blocked | 🔴 red |
| specs/stammdaten/spec.md → Artikel — Lieferantenverknüpfung | Dienstleistung rejects supplier link | test/features/stammdaten/test_dienstleistung_rejects_supplier_link.dart | test_dienstleistung_rejects_supplier_link | 🔴 red |
| specs/stammdaten/spec.md → Artikel — Lieferantenverknüpfung | Fremdleistung preserves supplier link | test/features/stammdaten/test_fremdleistung_preserves_supplier_link.dart | test_fremdleistung_preserves_supplier_link | 🔴 red |
| specs/stammdaten/spec.md → Artikelgruppen | Inactive group hidden from selection | test/features/stammdaten/test_inactive_group_hidden_from_selection.dart | test_inactive_group_hidden_from_selection | 🔴 red |
| specs/stammdaten/spec.md → Artikelgruppen | Active group visible in selection | test/features/stammdaten/test_active_group_visible_in_selection.dart | test_active_group_visible_in_selection | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — CRUD | Update company logo | test/features/stammdaten/test_update_company_logo.dart | test_update_company_logo | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — CRUD | Update non-existent field rejected | test/features/stammdaten/test_update_non_existent_field_rejected.dart | test_update_non_existent_field_rejected | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — SMTP-Konfiguration | SMTP test connection with invalid host | test/features/stammdaten/test_smtp_test_connection_with_invalid_host.dart | test_smtp_test_connection_with_invalid_host | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — SMTP-Konfiguration | SMTP test connection succeeds | test/features/stammdaten/test_smtp_test_connection_succeeds.dart | test_smtp_test_connection_succeeds | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — PDF-Vorlage | Template selection affects PDF output | test/features/stammdaten/test_template_selection_affects_pdf_output.dart | test_template_selection_affects_pdf_output | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — PDF-Vorlage | Default template applied | test/features/stammdaten/test_default_template_applied.dart | test_default_template_applied | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — Unterschrift | Signature on invoice PDF | test/features/stammdaten/test_signature_on_invoice_pdf.dart | test_signature_on_invoice_pdf | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — Unterschrift | Signature omitted when disabled | test/features/stammdaten/test_signature_omitted_when_disabled.dart | test_signature_omitted_when_disabled | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — QR-Zahlung | QR code on invoice | test/features/stammdaten/test_qr_code_on_invoice.dart | test_qr_code_on_invoice | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — QR-Zahlung | QR code omitted when disabled | test/features/stammdaten/test_qr_code_omitted_when_disabled.dart | test_qr_code_omitted_when_disabled | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — Skonto | Company default skonto applied | test/features/stammdaten/test_company_default_skonto_applied.dart | test_company_default_skonto_applied | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — Skonto | Customer-level skonto overrides company default | test/features/stammdaten/test_customer_level_skonto_overrides_company_default.dart | test_customer_level_skonto_overrides_company_default | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — Zahlungsziel | Default payment term | test/features/stammdaten/test_default_payment_term.dart | test_default_payment_term | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — Zahlungsziel | Per-invoice override | test/features/stammdaten/test_per_invoice_override.dart | test_per_invoice_override | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — Steuer-Fristen | Tax calendar shows state-specific deadlines | test/features/stammdaten/test_tax_calendar_shows_state_specific_deadlines.dart | test_tax_calendar_shows_state_specific_deadlines | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — Steuer-Fristen | Tax deadlines hidden when features inactive | test/features/stammdaten/test_tax_deadlines_hidden_when_features_inactive.dart | test_tax_deadlines_hidden_when_features_inactive | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — Dashboard-Konfiguration | Custom dashboard layout | test/features/stammdaten/test_custom_dashboard_layout.dart | test_custom_dashboard_layout | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — Dashboard-Konfiguration | Missing config falls back to default | test/features/stammdaten/test_missing_config_falls_back_to_default.dart | test_missing_config_falls_back_to_default | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — Profilmanager | Single profile hides menu | test/features/stammdaten/test_single_profile_hides_menu.dart | test_single_profile_hides_menu | 🔴 red |
| specs/stammdaten/spec.md → Unternehmen — Profilmanager | Multiple profiles force menu visible | test/features/stammdaten/test_multiple_profiles_force_menu_visible.dart | test_multiple_profiles_force_menu_visible | 🔴 red |
| specs/stammdaten/spec.md → Kategorien — CRUD | Create custom category | test/features/stammdaten/test_create_custom_category.dart | test_create_custom_category | 🔴 red |
| specs/stammdaten/spec.md → Kategorien — CRUD | Delete system-seeded category with references | test/features/stammdaten/test_delete_system_seeded_category_with_references.dart | test_delete_system_seeded_category_with_references | 🔴 red |
| specs/stammdaten/spec.md → Kategorien — SKR-Kontonummern | SKR03 category used in DATEV export | test/features/stammdaten/test_skr03_category_used_in_datev_export.dart | test_skr03_category_used_in_datev_export | 🔴 red |
| specs/stammdaten/spec.md → Kategorien — SKR-Kontonummern | SKR04 category used in DATEV export | test/features/stammdaten/test_skr04_category_used_in_datev_export.dart | test_skr04_category_used_in_datev_export | 🔴 red |
| specs/stammdaten/spec.md → Kategorien — EÜR-Zeilenzuordnung | Category appears on correct EÜR line | test/features/stammdaten/test_category_appears_on_correct_e_r_line.dart | test_category_appears_on_correct_e_r_line | 🔴 red |
| specs/stammdaten/spec.md → Kategorien — EÜR-Zeilenzuordnung | Category with NULL euer_zeile excluded from EÜR | test/features/stammdaten/test_category_with_null_euer_zeile_excluded_from_e_r.dart | test_category_with_null_euer_zeile_excluded_from_e_r | 🔴 red |
| specs/stammdaten/spec.md → Kategorien — eks_kategorie | EKS section assignment | test/features/stammdaten/test_eks_section_assignment.dart | test_eks_section_assignment | 🔴 red |
| specs/stammdaten/spec.md → Kategorien — eks_kategorie | Category without eks_kategorie excluded from EKS | test/features/stammdaten/test_category_without_eks_kategorie_excluded_from_eks.dart | test_category_without_eks_kategorie_excluded_from_eks | 🔴 red |
| specs/stammdaten/spec.md → Konten — CRUD | PayPal account without IBAN | test/features/stammdaten/test_paypal_account_without_iban.dart | test_paypal_account_without_iban | 🔴 red |
| specs/stammdaten/spec.md → Konten — CRUD | Duplicate IBAN rejected | test/features/stammdaten/test_duplicate_iban_rejected.dart | test_duplicate_iban_rejected | 🔴 red |
| specs/stammdaten/spec.md → Nummernkreise — Format-based numbering | Year rollover resets counter | test/features/stammdaten/test_year_rollover_resets_counter.dart | test_year_rollover_resets_counter | 🔴 red |
| specs/stammdaten/spec.md → Nummernkreise — Format-based numbering | Format template applied correctly | test/features/stammdaten/test_format_template_applied_correctly.dart | test_format_template_applied_correctly | 🔴 red |
| specs/stammdaten/spec.md → Steuersätze | Create custom tax rate | test/features/stammdaten/test_create_custom_tax_rate.dart | test_create_custom_tax_rate | 🔴 red |
| specs/stammdaten/spec.md → Steuersätze | System-seeded rate deletion blocked | test/features/stammdaten/test_system_seeded_rate_deletion_blocked.dart | test_system_seeded_rate_deletion_blocked | 🔴 red |
| specs/stammdaten/spec.md → Kunden-Lieferadressen | Select non-standard delivery address | test/features/stammdaten/test_select_non_standard_delivery_address.dart | test_select_non_standard_delivery_address | 🔴 red |
| specs/stammdaten/spec.md → Kunden-Lieferadressen | Multiple standard addresses prevented | test/features/stammdaten/test_multiple_standard_addresses_prevented.dart | test_multiple_standard_addresses_prevented | 🔴 red |
| specs/stammdaten/spec.md → Kunden-Belege | DSGVO expiry warning | test/features/stammdaten/test_dsgvo_expiry_warning.dart | test_dsgvo_expiry_warning | 🔴 red |
| specs/stammdaten/spec.md → Kunden-Belege | DSGVO overdue flag | test/features/stammdaten/test_dsgvo_overdue_flag.dart | test_dsgvo_overdue_flag | 🔴 red |

**Total: 669 scenarios mapped**
