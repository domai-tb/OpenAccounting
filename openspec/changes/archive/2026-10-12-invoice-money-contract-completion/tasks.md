# Implementation Tasks

> Planning only: all tests are to be added red before implementation. Do not mark tasks complete until evidence is recorded.

## 1. SQLite persistence and application precision

- [x] 1.1 Write failing test `test/db/invoice_money_contract_sqlite_test.dart::test_invoice_price_and_quantity_retain_precision_in_sqlite` for scenario "Invoice price and quantity retain application precision in SQLite" in `specs/db/spec.md`; confirm it fails for the expected reason.
- [x] 1.2 Implement the specified behavior to round-trip accepted 4-place unit prices and 3-place quantities unchanged and pass 1.1.
- [x] 1.3 Review this SQLite precision path for a useful refactor; keep the current form if no smaller correct implementation improves clarity, then rerun the focused test.
- [x] 1.4 Write failing test `test/db/invoice_money_contract_sqlite_test.dart::test_money_column_precision_round_trips_exact_cents` for scenario "Money Column Precision" in `specs/db/spec.md`; confirm it fails for the expected reason.
- [x] 1.5 Implement the specified behavior to round-trip the supported currency maximum exactly to cents and pass 1.4.
- [x] 1.6 Review this SQLite precision path for a useful refactor; keep the current form if no smaller correct implementation improves clarity, then rerun the focused test.
- [x] 1.7 Write failing test `test/db/invoice_money_contract_sqlite_test.dart::test_money_overflow_is_rejected_before_sqlite_write` for scenario "Money Column Overflow" in `specs/db/spec.md`; confirm it fails for the expected reason.
- [x] 1.8 Implement the specified behavior to reject currency overflow before SQLite receives a value and pass 1.7.
- [x] 1.9 Review this SQLite precision path for a useful refactor; keep the current form if no smaller correct implementation improves clarity, then rerun the focused test.
- [x] 1.10 Write failing test `test/db/invoice_money_contract_sqlite_test.dart::test_article_price_product_calculates_exact_cents` for scenario "Article Price Precision" in `specs/db/spec.md`; confirm it fails for the expected reason.
- [x] 1.11 Implement the specified behavior to calculate article price multiplied by quantity in exact cents and pass 1.10.
- [x] 1.12 Review this article-price path for a useful refactor; keep the current form if no smaller correct implementation improves clarity, then rerun the focused test.
- [x] 1.13 Write failing test `test/db/invoice_money_contract_sqlite_test.dart::test_zero_article_price_round_trips_without_artifact` for scenario "Article Price Zero" in `specs/db/spec.md`; confirm it fails for the expected reason.
- [x] 1.14 Implement the specified behavior to preserve zero article prices without a floating-point artifact and pass 1.13.
- [x] 1.15 Review this zero-price path for a useful refactor; keep the current form if no smaller correct implementation improves clarity, then rerun the focused test.
- [x] 1.16 Write failing test `test/db/invoice_money_contract_sqlite_test.dart::test_excess_price_or_quantity_scale_is_rejected_before_sqlite_write` for scenario "Excess scale is rejected by the application" in `specs/db/spec.md`; confirm it fails for the expected reason.
- [x] 1.17 Implement the specified behavior to reject excess price or quantity scale before the database write and pass 1.16.
- [x] 1.18 Review this application scale-validation path for a useful refactor; keep the current form if no smaller correct implementation improves clarity, then rerun the focused test.
- [x] 1.19 Write failing test `test/db/invoice_money_contract_sqlite_test.dart::test_invoice_values_beyond_supported_range_are_rejected_before_sqlite_write` for scenario "Values beyond the supported range are rejected" in `specs/db/spec.md`; confirm it fails for the expected reason.
- [x] 1.20 Implement the specified behavior to reject supported-input overflow before the database write and pass 1.19.
- [x] 1.21 Review this application range-validation path for a useful refactor; keep the current form if no smaller correct implementation improves clarity, then rerun the focused test.
- [x] 1.22 Write failing test `test/db/invoice_money_contract_sqlite_test.dart::test_sqlite_numeric_declaration_does_not_round_overflow` for scenario "SQLite declaration does not promise overflow rounding" in `specs/db/spec.md`; confirm it fails for the expected reason.
- [x] 1.23 Implement the specified behavior to keep SQLite affinity declarative and make application validation reject overflow and pass 1.22.
- [x] 1.24 Review the SQLite/app validation boundary for a useful refactor; keep the current form if no smaller correct implementation improves clarity, then rerun the focused test.

## 2. Accepted decimal inputs and range checks

- [x] 2.1 Write failing test `test/features/rechnungen/invoice_money_contract_test.dart::test_price_and_quantity_scales_round_trip_through_draft_conversion` for scenario "Four-place price and three-place quantity round-trip" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 2.2 Implement the specified behavior to preserve accepted scales through save, reload, and supported draft conversion and pass 2.1.
- [x] 2.3 Refactor this accepted decimal inputs and range checks behavior; rerun `test/features/rechnungen/invoice_money_contract_test.dart::test_price_and_quantity_scales_round_trip_through_draft_conversion` and keep the full VM suite green.
- [x] 2.4 Write failing test `test/features/rechnungen/invoice_money_contract_test.dart::test_excess_scale_and_negative_inputs_return_typed_validation_error` for scenario "Excess scale and negative caller values are rejected" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 2.5 Implement the specified behavior to return typed field validation before creating documents, positions, or numbers and pass 2.4.
- [x] 2.6 Refactor this accepted decimal inputs and range checks behavior; rerun `test/features/rechnungen/invoice_money_contract_test.dart::test_excess_scale_and_negative_inputs_return_typed_validation_error` and keep the full VM suite green.
- [x] 2.7 Write failing test `test/features/rechnungen/invoice_money_contract_test.dart::test_values_beyond_supported_range_return_value_out_of_range` for scenario "Values beyond the supported range are rejected" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 2.8 Implement the specified behavior to reject supported-input overflow before the database write and pass 2.7.
- [x] 2.9 Refactor this accepted decimal inputs and range checks behavior; rerun `test/features/rechnungen/invoice_money_contract_test.dart::test_values_beyond_supported_range_return_value_out_of_range` and keep the full VM suite green.
- [x] 2.10 Write failing test `test/features/rechnungen/invoice_money_contract_test.dart::test_derived_currency_overflow_is_rejected_without_integer_overflow` for scenario "A derived amount beyond the currency range is rejected safely" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 2.11 Implement the specified behavior to guard exact intermediate arithmetic and reject the derived amount with valueOutOfRange before persistence and pass 2.10.
- [x] 2.12 Refactor this accepted decimal inputs and range checks behavior; rerun `test/features/rechnungen/invoice_money_contract_test.dart::test_derived_currency_overflow_is_rejected_without_integer_overflow` and keep the full VM suite green.
- [x] 2.13 Write failing test `test/features/rechnungen/invoice_money_contract_lifecycle_test.dart::test_supported_conversions_preserve_discounted_headers` for scenario "Converted drafts preserve discounted calculated headers"; confirm it fails for the expected reason.
- [x] 2.14 Recalculate and persist all header totals and document discounts when converting a supported draft, then pass 2.13.
- [x] 2.15 Refactor supported document conversion; rerun the focused regression and keep the full VM suite green.

## 3. Line, tax, and document discount arithmetic

- [x] 3.1 Write failing test `test/features/rechnungen/invoice_money_contract_test.dart::test_half_cent_line_product_rounds_once_before_vat` for scenario "A half-cent line product rounds once before VAT" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 3.2 Implement the specified behavior to round the exact line product once at the entered-mode cents boundary before tax and pass 3.1.
- [x] 3.3 Refactor this line, tax, and document discount arithmetic behavior; rerun `test/features/rechnungen/invoice_money_contract_test.dart::test_half_cent_line_product_rounds_once_before_vat` and keep the full VM suite green.
- [x] 3.4 Write failing test `test/features/rechnungen/invoice_money_contract_test.dart::test_line_discount_precedes_single_cent_rounding` for scenario "Line discount is applied before the single cent rounding" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 3.5 Implement the specified behavior to apply the position discount to the exact product before its single half-up cent rounding and pass 3.4.
- [x] 3.6 Refactor this line, tax, and document discount arithmetic behavior; rerun `test/features/rechnungen/invoice_money_contract_test.dart::test_line_discount_precedes_single_cent_rounding` and keep the full VM suite green.
- [x] 3.7 Write failing test `test/features/rechnungen/invoice_money_contract_test.dart::test_mismatched_asserted_line_amount_fails_before_insert` for scenario "Mismatched asserted line amount is rejected" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 3.8 Implement the specified behavior to compare the asserted amount with the calculator result before inserting document or position rows and pass 3.7.
- [x] 3.9 Refactor this line, tax, and document discount arithmetic behavior; rerun `test/features/rechnungen/invoice_money_contract_test.dart::test_mismatched_asserted_line_amount_fails_before_insert` and keep the full VM suite green.
- [x] 3.10 Write failing test `test/features/rechnungen/invoice_money_contract_test.dart::test_mixed_rate_percentage_discount_allocates_deterministically` for scenario "A mixed-rate percentage discount is allocated deterministically" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 3.11 Implement the specified behavior to round the percentage on the whole net subtotal, allocate cents by largest remainder, and recalculate VAT per position; pass 3.10.
- [x] 3.12 Refactor this line, tax, and document discount arithmetic behavior; rerun `test/features/rechnungen/invoice_money_contract_test.dart::test_mixed_rate_percentage_discount_allocates_deterministically` and keep the full VM suite green.
- [x] 3.13 Write failing test `test/features/rechnungen/invoice_money_contract_test.dart::test_percentage_discount_rounds_once_before_bucket_allocation` for scenario "Percentage discount rounds once before mixed-rate allocation" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 3.14 Implement the specified behavior to round the aggregate percentage discount once, then assign equal remainders by lower VAT rate and persisted position; pass 3.13.
- [x] 3.15 Refactor this line, tax, and document discount arithmetic behavior; rerun `test/features/rechnungen/invoice_money_contract_test.dart::test_percentage_discount_rounds_once_before_bucket_allocation` and keep the full VM suite green.
- [x] 3.16 Write failing test `test/features/rechnungen/invoice_money_contract_test.dart::test_discounted_draft_headers_match_after_reload` for scenario "Discounted draft headers survive reload" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 3.17 Implement the specified behavior to persist and reload net, VAT, and gross headers from the discounted calculator result and pass 3.16.
- [x] 3.18 Refactor this line, tax, and document discount arithmetic behavior; rerun `test/features/rechnungen/invoice_money_contract_test.dart::test_discounted_draft_headers_match_after_reload` and keep the full VM suite green.
- [x] 3.19 Write failing test `test/features/rechnungen/invoice_money_contract_test.dart::test_discount_cannot_exceed_subtotal_or_combine_with_another` for scenario "A discount cannot exceed subtotal or combine with another discount" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 3.20 Implement the specified behavior to reject over-subtotal and simultaneous document discounts with typed validation before persistence and pass 3.19.
- [x] 3.21 Refactor this line, tax, and document discount arithmetic behavior; rerun `test/features/rechnungen/invoice_money_contract_test.dart::test_discount_cannot_exceed_subtotal_or_combine_with_another` and keep the full VM suite green.
- [x] 3.22 Add a gross-mode discount regression covering multiple VAT buckets; retain the existing calculator path if it matches per-position rounding.
- [x] 3.23 Write failing test `test/features/rechnungen/invoice_money_contract_test.dart::test_vat_rounds_per_position_before_summing` for scenario "VAT rounds per position before summing"; confirm it fails for the expected reason.
- [x] 3.24 Calculate VAT per discounted invoice position and sum rounded line VAT, then pass 3.23.
- [x] 3.25 Refactor per-position VAT calculation; rerun the focused regression and keep the full VM suite green.
- [x] 3.26 Write failing test `test/features/rechnungen/invoice_money_contract_test.dart::test_same_rate_discount_tie_uses_persisted_position` for scenario "Same-rate discount ties use persisted position order"; confirm it fails for the expected reason.
- [x] 3.27 Allocate each rate bucket's document discount across persisted positions by largest remainder and persisted-position tie-break; pass 3.26.
- [x] 3.28 Refactor per-position discount allocation; rerun the focused regression and keep the full VM suite green.
- [x] 3.29 Write failing test `test/features/rechnungen/invoice_money_contract_test.dart::test_gross_mode_rounds_net_per_position_before_summing` for scenario "Gross-mode tax bases round per position"; confirm it fails for the expected reason.
- [x] 3.30 Derive gross-mode net and VAT per position before summing and pass 3.29.
- [x] 3.31 Refactor gross-mode per-position rounding; rerun the focused regression and keep the full VM suite green.

## 4. Shared proportional cent allocation

- [x] 4.1 Write failing tests `test/features/accounting/euer_test.dart::test_proportional_cent_equal_remainders_use_stable_key` and `test/features/accounting/euer_test.dart::test_proportional_cent_largest_remainder_precedes_stable_key` for their mapped scenarios in `specs/invoice-money-contract/spec.md`; confirm each fails for the expected reason.
- [x] 4.2 Implement the specified behavior to assign leftover cents by descending remainder and ascending caller key and pass both tests in 4.1.
- [x] 4.3 Review this shared allocator for a useful refactor; keep its current form if no smaller correct form improves clarity, then rerun both tests in 4.1.
- [x] 4.4 Write failing test `test/features/accounting/euer_test.dart::test_proportional_cent_allocation_rejects_positive_amount_with_zero_weights` for scenario "Zero weights cannot receive a positive allocation" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 4.5 Implement the specified behavior to return typed validation for positive allocations with zero total weight and pass 4.4.
- [x] 4.6 Remove the redundant nested zero-weight validation after amount-versus-total validation; rerun `test/features/accounting/euer_test.dart::test_proportional_cent_allocation_rejects_positive_amount_with_zero_weights`.

## 5. Document discount behavior

- [x] 5.1 Write failing test `test/features/rechnungen/erstellung_test.dart::test_fixed_discount_tie_across_vat_rates_goes_to_lower_rate` for scenario "Document fixed discount spans two VAT rates" in `specs/documents/spec.md`; confirm it fails for the expected reason.
- [x] 5.2 Implement the specified behavior to allocate the equal-remainder cent to the lower VAT rate and reconcile the buckets and pass 5.1.
- [x] 5.3 Refactor this document discount behavior behavior; rerun `test/features/rechnungen/erstellung_test.dart::test_fixed_discount_tie_across_vat_rates_goes_to_lower_rate` and keep the full VM suite green.
- [x] 5.4 Write failing test `test/features/rechnungen/erstellung_test.dart::test_position_discount_applies_before_single_cent_rounding` for scenario "Position Rabatt" in `specs/documents/spec.md`; confirm it fails for the expected reason.
- [x] 5.5 Implement the specified behavior to calculate the discounted position from the exact price-times-quantity product before rounding once and pass 5.4.
- [x] 5.6 Refactor this document discount behavior behavior; rerun `test/features/rechnungen/erstellung_test.dart::test_position_discount_applies_before_single_cent_rounding` and keep the full VM suite green.
- [x] 5.7 Write failing test `test/features/rechnungen/erstellung_test.dart::test_document_fixed_discount_reduces_pre_tax_subtotal` for scenario "Document-level fixed Rabatt" in `specs/documents/spec.md`; confirm it fails for the expected reason.
- [x] 5.8 Implement the specified behavior to reduce the net subtotal by the fixed discount before recalculating VAT and pass 5.7.
- [x] 5.9 Refactor this document discount behavior behavior; rerun `test/features/rechnungen/erstellung_test.dart::test_document_fixed_discount_reduces_pre_tax_subtotal` and keep the full VM suite green.
- [x] 5.10 Write failing test `test/features/rechnungen/erstellung_test.dart::test_document_discount_fields_cannot_both_be_nonzero` for scenario "Conflicting document-level Rabatt rejected" in `specs/documents/spec.md`; confirm it fails for the expected reason.
- [x] 5.11 Implement the specified behavior to reject two non-zero document discount fields before persisting amounts and pass 5.10.
- [x] 5.12 Refactor this document discount behavior behavior; rerun `test/features/rechnungen/erstellung_test.dart::test_document_discount_fields_cannot_both_be_nonzero` and keep the full VM suite green.
- [x] 5.13 Write failing test `test/features/rechnungen/erstellung_test.dart::test_excessive_or_conflicting_document_discount_is_rejected` for scenario "Excessive or conflicting document discount is rejected" in `specs/documents/spec.md`; confirm it fails for the expected reason.
- [x] 5.14 Implement the specified behavior to reject over-subtotal or conflicting discounts with the corresponding stable error code and pass 5.13.
- [x] 5.15 Refactor this document discount behavior behavior; rerun `test/features/rechnungen/erstellung_test.dart::test_excessive_or_conflicting_document_discount_is_rejected` and keep the full VM suite green.

## 6. Invoice lifecycle and header integrity

- [x] 6.1 Write failing test `test/features/rechnungen/invoice_money_contract_lifecycle_test.dart::test_generic_correction_creation_fails_before_side_effects` for scenario "Generic correction creation is rejected before side effects" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 6.2 Implement the specified behavior to reject correction types from generic draft creation before document, counter, or source writes and pass 6.1.
- [x] 6.3 Refactor this invoice lifecycle and header integrity behavior; rerun `test/features/rechnungen/invoice_money_contract_lifecycle_test.dart::test_generic_correction_creation_fails_before_side_effects` and keep the full VM suite green.
- [x] 6.4 Write failing test `test/features/rechnungen/invoice_money_contract_lifecycle_test.dart::test_finalize_rejects_altered_headers_before_posting` for scenario "Finalization rejects altered stored totals before posting" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 6.5 Implement the specified behavior to recalculate all stored lines and discounts, then reject every mismatched header before numbering or posting and pass 6.4.
- [x] 6.6 Refactor this invoice lifecycle and header integrity behavior; rerun `test/features/rechnungen/invoice_money_contract_lifecycle_test.dart::test_finalize_rejects_altered_headers_before_posting` and keep the full VM suite green.

## 7. Correction sign and source validation

- [x] 7.1 Write failing test `test/features/rechnungen/gutschrift_test.dart::test_rechnung_correction_and_standalone_gutschrift_have_negative_totals` for scenario "Rechnung corrections and standalone Gutschrift have negative totals" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 7.2 Implement the specified behavior to apply the negative sign consistently to correction lines and net, VAT, and gross headers and pass 7.1.
- [x] 7.3 Refactor this correction sign and source validation behavior; rerun `test/features/rechnungen/gutschrift_test.dart::test_rechnung_correction_and_standalone_gutschrift_have_negative_totals` and keep the full VM suite green.
- [x] 7.4 Write failing test `test/features/rechnungen/storno_test.dart::test_gutschrift_storno_is_exact_positive_inverse` for scenario "Storno of a Gutschrift exactly reverses its negative totals" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 7.5 Implement the specified behavior to make the Gutschrift Storno a positive exact inverse of line and header balances and pass 7.4.
- [x] 7.6 Refactor this correction sign and source validation behavior; rerun `test/features/rechnungen/storno_test.dart::test_gutschrift_storno_is_exact_positive_inverse` and keep the full VM suite green.
- [x] 7.7 Write failing test `test/features/rechnungen/invoice_money_contract_lifecycle_test.dart::test_mismatched_or_unsupported_correction_source_fails_before_side_effects` for scenario "A mismatched source or unsupported source type is not corrected" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 7.8 Implement the specified behavior to reject unsupported or inconsistent source documents before counters or source state change and pass 7.7.
- [x] 7.9 Refactor this correction sign and source validation behavior; rerun `test/features/rechnungen/invoice_money_contract_lifecycle_test.dart::test_mismatched_or_unsupported_correction_source_fails_before_side_effects` and keep the full VM suite green.

## 8. Storno workflow

- [x] 8.1 Write failing test `test/features/rechnungen/storno_test.dart::test_rechnung_storno_reverses_positive_balances` for scenario "Storno of a Rechnung reverses its positive balances" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 8.2 Implement the specified behavior to invert all finalized Rechnung line, net, VAT, and gross balances exactly and pass 8.1.
- [x] 8.3 Refactor this storno workflow behavior; rerun `test/features/rechnungen/storno_test.dart::test_rechnung_storno_reverses_positive_balances` and keep the full VM suite green.
- [x] 8.4 Write failing test `test/features/rechnungen/storno_test.dart::test_gutschrift_storno_reverses_negative_balances` for scenario "Storno of a Gutschrift exactly reverses its negative totals" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 8.5 Implement the specified behavior to invert all finalized negative Gutschrift line and header balances exactly and pass 8.4.
- [x] 8.6 Refactor this storno workflow behavior; rerun `test/features/rechnungen/storno_test.dart::test_gutschrift_storno_reverses_negative_balances` and keep the full VM suite green.
- [x] 8.16 Confirm the existing incoming-invoice Storno test fails because its valid source type is rejected; map it to "Incoming Storno reverses line, header, and input-tax amounts" in `specs/invoice-money-contract/spec.md`.
- [x] 8.17 Allow the invoice types supported by generic finalization as Storno sources, preserve exact reversal and input-tax handling, and pass 8.16.
- [x] 8.18 Refactor the Storno source validation; rerun the focused regression and keep the full VM suite green.

## 9. Gutschrift workflow

- [x] 9.1 Write failing test `test/features/rechnungen/gutschrift_test.dart::test_invoice_gutschrift_reverses_discounted_totals` for scenario "Gutschrift reverses the source's discounted totals" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 9.2 Implement the specified behavior to copy and negate the source invoice discounted net, VAT, and gross totals and pass 9.1.
- [x] 9.3 Refactor this gutschrift workflow behavior; rerun `test/features/rechnungen/gutschrift_test.dart::test_invoice_gutschrift_reverses_discounted_totals` and keep the full VM suite green.
- [x] 9.4 Write failing test `test/features/rechnungen/gutschrift_test.dart::test_standalone_gutschrift_persists_negative_totals_without_source` for scenario "Invoice-derived and standalone Gutschrift amounts are negative" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 9.5 Implement the specified behavior to persist standalone line and header amounts as negative with no source link and pass 9.4.
- [x] 9.6 Refactor this gutschrift workflow behavior; rerun `test/features/rechnungen/gutschrift_test.dart::test_standalone_gutschrift_persists_negative_totals_without_source` and keep the full VM suite green.

## 10. Stable validation error metadata

- [x] 10.1 Write failing test `test/features/rechnungen/invoice_money_contract_test.dart::test_line_validation_error_includes_code_field_and_both_indexes` for scenario "Line validation reports code, field, and both line indexes" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 10.2 Implement the specified behavior to expose the stable error code, field, zero-based line index, and persisted position and pass 10.1.
- [x] 10.3 Refactor this stable validation error metadata behavior; rerun `test/features/rechnungen/invoice_money_contract_test.dart::test_line_validation_error_includes_code_field_and_both_indexes` and keep the full VM suite green.
- [x] 10.4 Write failing test `test/features/rechnungen/invoice_money_contract_test.dart::test_header_mismatch_reports_fields_without_line_metadata` for scenario "Document validation reports header fields without a line index" in `specs/invoice-money-contract/spec.md`; confirm it fails for the expected reason.
- [x] 10.5 Implement the specified behavior to report every mismatching header field and leave lineIndex and position null and pass 10.4.
- [x] 10.6 Refactor this stable validation error metadata behavior; rerun `test/features/rechnungen/invoice_money_contract_test.dart::test_header_mismatch_reports_fields_without_line_metadata` and keep the full VM suite green.

## 11. Discounted invoice PDF output

- [x] 11.1 Write failing test `test/features/pdf/rechnung_test.dart::test_discounted_invoice_pdf_shows_discount_and_subtotal` for the Rabatt requirement that active discounts and subtotal appear in the PDF; confirm it fails for the expected reason.
- [x] 11.2 Render discount and subtotal from the canonical calculated invoice totals in the PDF and pass 11.1.
- [x] 11.3 Refactor the invoice PDF totals path; rerun the focused PDF test and keep the full VM suite green.
- [x] 11.4 Write a failing integration regression for a discounted half-cent position and inspect the finalized PDF artifact; confirm the PDF shows net 0.50 and gross 0.60.
- [x] 11.5 Build PDF position amounts with the calculator's exact line discount and single cent rounding.
- [x] 11.6 Refactor the PDF position calculation path; rerun the focused integration regression.

## 12. Verify, synchronize, archive, and commit

- [x] 12.1 Run the focused invoice, database, EÜR, correction, and PDF VM tests; flip each passing test-plan row to 🟢 green and investigate any mismatch.
- [x] 12.2 Run `fvm flutter analyze`, the full VM test suite, pre-archive strict change validation, `openspec validate --specs --strict`, and `git diff --check`; record exact results in `verify.md` and confirm all 50 scenario rows are green across 49 unique tests.
- [x] 12.3 Synchronize accepted delta requirements and validate the completed archive after all tasks are checked.
- [x] 12.4 Commit only the completed change and its required synchronized specs. Include trailers `OpenSpec-Change: invoice-money-contract-completion`, `OpenSpec-Schema: anvil`, `OpenSpec-Status: complete`, and `OpenSpec-Tasks: 141/141`.


## 13. Corrective invoice lifecycle edge cases

- [x] 13.1 Add failing regressions for gross-mode Storno snapshot signs, fractional-cent headers, unsupported direct-datasource draft types, replacement discounts, negative stored source position values, and wrong-sign stored line totals; confirm each fails for the expected reason.
- [x] 13.2 Preserve source input mode for Storno, validate signed source values unchanged, use stable persisted position ordering in Storno and Gutschrift, reject non-cent headers and unsupported generic draft types, and recalculate discounted replacement drafts.
- [x] 13.3 Format scoped changes and rerun focused tests, analyzer, full VM suite, maintained and archived OpenSpec validation, and diff checks; record fresh evidence.
- [x] 13.4 Obtain a fresh full-scope review, reconcile verification records, and create the separate local invoice-money commit with the required trailers.
