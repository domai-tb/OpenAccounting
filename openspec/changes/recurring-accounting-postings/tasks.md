## Implementation Tasks

## 1. Recurring invoices preserve position tax rates — Mixed-rate template generates correct totals

- [ ] 1.1 Write failing test test/integration/audit/recurring-accounting-postings_test.dart → test_recurring_accounting_postings_1_1_mixed_rate_template_generates_correct_totals (assert it fails for the right reason)
- [ ] 1.2 Implement the behavior required by Recurring invoices preserve position tax rates to pass 1.1
- [ ] 1.3 Refactor the implementation and fixtures; the full suite stays green

## 2. Recurring invoices preserve position tax rates — Invalid template rate is handled

- [ ] 2.1 Write failing test test/integration/audit/recurring-accounting-postings_test.dart → test_recurring_accounting_postings_1_2_invalid_template_rate_is_handled (assert it fails for the right reason)
- [ ] 2.2 Implement the behavior required by Recurring invoices preserve position tax rates to pass 2.1
- [ ] 2.3 Refactor the implementation and fixtures; the full suite stays green

## 3. Recurring bookings calculate input tax from tax semantics — Gross expense yields only its tax component

- [ ] 3.1 Write failing test test/integration/audit/recurring-accounting-postings_test.dart → test_recurring_accounting_postings_2_1_gross_expense_yields_only_its_tax_component (assert it fails for the right reason)
- [ ] 3.2 Implement the behavior required by Recurring bookings calculate input tax from tax semantics to pass 3.1
- [ ] 3.3 Refactor the implementation and fixtures; the full suite stays green

## 4. Recurring bookings calculate input tax from tax semantics — Retry is idempotent

- [ ] 4.1 Write failing test test/integration/audit/recurring-accounting-postings_test.dart → test_recurring_accounting_postings_2_2_retry_is_idempotent (assert it fails for the right reason)
- [ ] 4.2 Implement the behavior required by Recurring bookings calculate input tax from tax semantics to pass 4.1
- [ ] 4.3 Refactor the implementation and fixtures; the full suite stays green
