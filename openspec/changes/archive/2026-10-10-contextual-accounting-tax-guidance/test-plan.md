## Test Plan

<!-- Every scenario in specs/ maps to a named test. -->
<!-- During implementation, flip 🟢 green to 🟢 green when its test passes. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/specs/app/spec.md → Help workspace | Help opens with reviewed contextual entries | test/app/contextual_accounting_tax_guidance_test.dart | test_help_opens_with_reviewed_contextual_entries | 🟢 green |
| specs/specs/app/spec.md → Help workspace | Search finds no reviewed entry | test/app/contextual_accounting_tax_guidance_test.dart | test_search_finds_no_reviewed_entry | 🟢 green |
| specs/specs/contextual-accounting-tax-guidance/spec.md → Supported accounting and tax controls have reviewed context guidance | User opens guidance for a supported field | test/features/contextual_accounting_tax_guidance/contextual_accounting_tax_guidance_test.dart | test_user_opens_guidance_for_a_supported_field | 🟢 green |
| specs/specs/contextual-accounting-tax-guidance/spec.md → Supported accounting and tax controls have reviewed context guidance | Field has no approved explanation | test/features/contextual_accounting_tax_guidance/contextual_accounting_tax_guidance_test.dart | test_field_has_no_approved_explanation | 🟢 green |
| specs/specs/contextual-accounting-tax-guidance/spec.md → Supported accounting and tax controls have reviewed context guidance | Unsupported tax behavior is discussed | test/features/contextual_accounting_tax_guidance/contextual_accounting_tax_guidance_test.dart | test_unsupported_tax_behavior_is_discussed | 🟢 green |
| specs/specs/contextual-accounting-tax-guidance/spec.md → Help provides a searchable glossary for contextual entries | Search and open a help entry | test/features/contextual_accounting_tax_guidance/contextual_accounting_tax_guidance_test.dart | test_search_and_open_a_help_entry | 🟢 green |
| specs/specs/contextual-accounting-tax-guidance/spec.md → Help provides a searchable glossary for contextual entries | No glossary result is available | test/features/contextual_accounting_tax_guidance/contextual_accounting_tax_guidance_test.dart | test_no_glossary_result_is_available | 🟢 green |
| specs/specs/contextual-accounting-tax-guidance/spec.md → Context guidance follows the desktop design schema | Guidance is reachable without a pointer | test/features/contextual_accounting_tax_guidance/contextual_accounting_tax_guidance_test.dart | test_guidance_is_reachable_without_a_pointer | 🟢 green |

## Coverage Notes

- Every scenario is mapped once to a named executable test; all rows start red.
- Tests use the repository’s Flutter test infrastructure and focused fixtures for the affected feature and persistence boundaries.
- These are planned tests; this artifact does not claim that the tests already exist or have passed.
