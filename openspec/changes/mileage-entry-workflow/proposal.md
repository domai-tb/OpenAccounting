## Why

Business mileage currently has no entry workflow. The accounting data model and EKS calculator contain a distance field, but users cannot record and trace a business trip or have it safely considered for accounting.

## What Changes

- Add a routed mileage workspace to record, review, and find business trips by date, purpose, distance, and business context.
- Keep captured trip facts separate from the deductible amount. Calculate or post an amount only when an approved, date-effective policy and required accounting mapping exist; otherwise keep the trip visibly unresolved and out of accounting totals.
- Connect eligible, policy-resolved trips to accounting and reports through the accepted posting boundary, preserving a source link and preventing duplicate posting.
- Keep the existing EKS travel allowance rule scoped to EKS. Do not reuse its €0.10/km calculation as the general tax-deductible mileage rate.

## Capabilities

### New Capabilities

- `mileage-entry`: Traceable capture and controlled accounting of business mileage.

### Modified Capabilities

None. The new workflow consumes the existing EKS contract and the accounting posting boundary without changing their requirements.

## Impact

Adds a mileage route and form, a mileage entity/repository/use case and local persistence, plus an integration with accounting/reporting after the deduction policy and posting contract are approved. Design follows `DESIGN.md` page headers, searchable/filterable accounting tables, numeric alignment, keyboard access, and visible unresolved states. No policy rate, deductible percentage, account mapping, or rounding rule is selected by this proposal.
