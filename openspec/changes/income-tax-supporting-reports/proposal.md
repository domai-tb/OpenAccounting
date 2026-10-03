## Why

Feature-map item 54 requires accounting evaluations for Anlage S and Anlage G that derive their values from accounting records and explain the tax-return fields. No production workflow or maintained capability currently owns these schedules. EÜR and EKS are separate reports and cannot be presented as a completed S/G workpaper without a reviewed line mapping and source contract.

## What Changes

- Add read-only, traceable supporting reports for Anlage S and Anlage G under the Taxes workspace.
- Show each supported schedule field with its official form version, value, source record coverage, and calculation/mapping explanation.
- Require an explicit supported schedule and period selection; never infer professional/commercial classification from names or transaction text.
- Keep each field unavailable when its tax-year mapping, accounting source, or classification is unapproved or incomplete; do not substitute EÜR totals blindly.
- Do not submit returns or claim tax compliance. Follow `DESIGN.md` period filters, accessible data tables, localization, and responsive behavior.

## Capabilities

### New Capabilities

- `income-tax-supporting-reports`: Defines versioned, source-traceable supporting reports for Anlage S and Anlage G.

### Modified Capabilities

- `accounting`: Add the S/G workpaper source, period, line-mapping, and unavailable boundaries.
- `typed-route-workspaces`: Add the S/G view to the existing Taxes route.

## Impact

The Taxes workspace, read-only accounting projection and form-line mapping service, German/English report labels, and the documentation for tax-report scope. Exact field mappings and calculations require an accepted tax-year source contract; until then the report must remain unavailable rather than inventing values. No journal, invoice, EÜR, or EKS record is changed.
