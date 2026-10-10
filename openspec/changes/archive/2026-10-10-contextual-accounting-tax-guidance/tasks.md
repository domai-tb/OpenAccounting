## 1. app: Help workspace

- [x] 1.1 Write failing test `test_help_opens_with_reviewed_contextual_entries` in `test/app/contextual_accounting_tax_guidance_test.dart` for scenario "Help opens with reviewed contextual entries"; assert it fails for the right reason.
- [x] 1.2 Implement the specified behavior for "Help opens with reviewed contextual entries" to pass 1.1.
- [x] 1.3 Refactor the affected code; keep the focused and full suites green.
- [x] 1.4 Write failing test `test_search_finds_no_reviewed_entry` in `test/app/contextual_accounting_tax_guidance_test.dart` for scenario "Search finds no reviewed entry"; assert it fails for the right reason.
- [x] 1.5 Implement the specified behavior for "Search finds no reviewed entry" to pass 1.4.
- [x] 1.6 Refactor the affected code; keep the focused and full suites green.

## 2. contextual-accounting-tax-guidance: Supported accounting and tax controls have reviewed context guidance

- [x] 2.1 Write failing test `test_user_opens_guidance_for_a_supported_field` in `test/features/contextual_accounting_tax_guidance/contextual_accounting_tax_guidance_test.dart` for scenario "User opens guidance for a supported field"; assert it fails for the right reason.
- [x] 2.2 Implement the specified behavior for "User opens guidance for a supported field" to pass 2.1.
- [x] 2.3 Refactor the affected code; keep the focused and full suites green.
- [x] 2.4 Write failing test `test_field_has_no_approved_explanation` in `test/features/contextual_accounting_tax_guidance/contextual_accounting_tax_guidance_test.dart` for scenario "Field has no approved explanation"; assert it fails for the right reason.
- [x] 2.5 Implement the specified behavior for "Field has no approved explanation" to pass 2.4.
- [x] 2.6 Refactor the affected code; keep the focused and full suites green.
- [x] 2.7 Write failing test `test_unsupported_tax_behavior_is_discussed` in `test/features/contextual_accounting_tax_guidance/contextual_accounting_tax_guidance_test.dart` for scenario "Unsupported tax behavior is discussed"; assert it fails for the right reason.
- [x] 2.8 Implement the specified behavior for "Unsupported tax behavior is discussed" to pass 2.7.
- [x] 2.9 Refactor the affected code; keep the focused and full suites green.

## 3. contextual-accounting-tax-guidance: Help provides a searchable glossary for contextual entries

- [x] 3.1 Write failing test `test_search_and_open_a_help_entry` in `test/features/contextual_accounting_tax_guidance/contextual_accounting_tax_guidance_test.dart` for scenario "Search and open a help entry"; assert it fails for the right reason.
- [x] 3.2 Implement the specified behavior for "Search and open a help entry" to pass 3.1.
- [x] 3.3 Refactor the affected code; keep the focused and full suites green.
- [x] 3.4 Write failing test `test_no_glossary_result_is_available` in `test/features/contextual_accounting_tax_guidance/contextual_accounting_tax_guidance_test.dart` for scenario "No glossary result is available"; assert it fails for the right reason.
- [x] 3.5 Implement the specified behavior for "No glossary result is available" to pass 3.4.
- [x] 3.6 Refactor the affected code; keep the focused and full suites green.

## 4. contextual-accounting-tax-guidance: Context guidance follows the desktop design schema

- [x] 4.1 Write failing test `test_guidance_is_reachable_without_a_pointer` in `test/features/contextual_accounting_tax_guidance/contextual_accounting_tax_guidance_test.dart` for scenario "Guidance is reachable without a pointer"; assert it fails for the right reason.
- [x] 4.2 Implement the specified behavior for "Guidance is reachable without a pointer" to pass 4.1.
- [x] 4.3 Refactor the affected code; keep the focused and full suites green.

## Implementation Notes

- Follow `design.md` for implementation decisions and dependency order.
- Keep each scenario in red-green-refactor order; do not implement behavior before its failing test.
- Keep `test-plan.md` red until its named test passes.
