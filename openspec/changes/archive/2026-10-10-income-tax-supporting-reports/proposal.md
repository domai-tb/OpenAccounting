## Why

Feature-map item 54 asks for accounting evaluations for Anlage S and Anlage G, but this project has no accepted form-year field list, calculation mapping, classification contract, or complete accounting source for those schedules. EÜR and EKS are separate reports and cannot safely be presented as completed S/G workpapers. This change specifies only a truthful S/G availability surface; it does not fabricate tax-report values.

## What Changes

- Add a typed `/taxes` view for users to select Anlage S or Anlage G and see whether a supporting-report contract is available.
- Keep both schedules explicitly unavailable until a separate accepted contract defines a form-year field inventory, tax period, classification evidence, accounting source, formulas, and completeness rules.
- Do not show a period selector, numeric S/G fields, guessed totals, copied EÜR/EKS values, source coverage counts, exports, or submission status while that contract is absent.
- Preserve the selection in the route and show localized blockers with links to the relevant contract/unavailable state.
- Follow `DESIGN.md` localization, keyboard, focus, text-scaling, and responsive rules.

## Capabilities

### New Capabilities

- `income-tax-supporting-reports`: Defines a typed availability-only surface for future Anlage S/G supporting reports.

### Modified Capabilities

- `accounting`: Establish the fail-closed prerequisite for any future S/G field value.
- `typed-route-workspaces`: Add typed S/G selection and deep-link behavior to the existing Taxes route.

## Impact

The `/taxes` route, typed availability use case, and German/English status copy. This proposal adds no accounting projection, tax formula, report artifact, database migration, or business-data write. Any future S/G values require a separately reviewed form-year, period, classification, accounting-source, and completeness contract.
