## Why

`/reports` and `/taxes` currently show generic records rather than report-specific workflows. The app also lacks a shared period-result contract. These workspaces must expose only calculations and files whose legal, form, period, and accounting-source contracts are explicit; unsupported or unapproved reports must remain unavailable.

## What Changes

- Replace generic report routes with localized typed workspaces for EÜR, EKS, GuV, ZM, UStVA, DATEV, and export history; define deep-link query selections, route ownership, typed report service APIs, periods, and unavailable/result boundaries. A report service or source contract that is unavailable SHALL produce an unavailable state, never a raw-table substitute.
- Correct the maintained ZM, GuV, EÜR, and DATEV accounting contracts. Pin ZM transaction direction and reporting dates to §18a UStG; distinguish optional management GuV from the evidence-based §141 AO duty; version EÜR by tax year; and pin DATEV to EXTF Buchungsstapel header 700/category 21/format 13 with explicit field mappings.
- Define `AccountingPeriodSummary` for supported annual calendar years only. Keep financial summary and report results unavailable until the balanced-posting/settlement and invoice-money prerequisites have each passed independent review and approval.
- Limit this change's file output to DATEV CSV. EÜR, EKS, GuV, UStVA, and ZM are on-screen previews only; this change adds no PDF, CSV, or official filing output for them. A local preview or DATEV file SHALL NOT imply submission.
- Require report period, source-contract version, form/interface version, source record references, and unresolved-input status on every result.

## Capabilities

### New Capabilities

- `accounting-reporting-workspaces`: User-facing, period-based reporting workspaces, source/version provenance, and truthful availability and result states.

### Modified Capabilities

- `accounting`: Correct and version the EÜR, GuV, ZM, and DATEV calculation/report contracts.
- `dashboard`: Consume the annual `AccountingPeriodSummary` and show unavailable state while its required sources are blocked.
- `tax-reporting-and-export-integrity`: Keep artifact lifecycle rules in the maintained capability and limit this change's report files to the specified DATEV CSV.
- `typed-route-workspaces`: Define typed report selections and deep-link ownership for `/reports` and `/taxes`.

## Impact

The report and tax routes and their typed deep-link selections, composed report use cases, dashboard summary provider, DATEV export workflow, and maintained route-ownership contract. Normative report calculations and file lifecycle remain in the maintained `accounting` and `tax-reporting-and-export-integrity` capabilities. Legal/form and DATEV version references are pinned in the design and delta specs; implementation remains gated on the named accounting prerequisites.
