## Review Metadata

- **Review round**: 2
- **Prior round**: round 1 was `REVISE` for the ZM legal scope, unapproved accounting source, unsupported EÜR form years, and incomplete DATEV/GuV/artifact contracts
- **Reviewer context**: fresh-context independent subagent
- **Tool restrictions**: read-only inspection except this review file; no tests run
- **Artifacts reviewed**: proposal.md, design.md, all four delta specs, maintained accounting/dashboard/tax-reporting-and-export-integrity/typed-route-workspaces specs, DESIGN.md, AGENTS.md, relevant router and AppServices code, official §18a UStG and §141 AO text, official DATEV format/header and interface requirements

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ (other than -->
<!-- applying listed Required Changes) VOIDS the verdict and requires a new round. -->

## Validation and Evidence

- `openspec validate accounting-reporting-workspaces --type change --strict --json`: passed (1/1 change, no issues).
- `git diff --check`: passed after writing this review. No tests were run.
- The production `/reports` route currently renders a journal-backed generic page and `/taxes` a generic `ustva_exporte` page (`lib/core/router/app_router.dart:619-647`). `AppServices` does not yet expose reporting services (`lib/core/app_services.dart:19-45`). Existing `EuerService.generate` and DATEV export contracts are not composed into these routes.
- Official §18a UStG distinguishes goods supplies, own-goods transfers, triangular transactions, and §3a(2) services; it sets monthly/conditional quarterly periods and date rules (§18a(1)-(9)). The revised delta now explicitly excludes incoming ordinary intra-community acquisitions, gates unsupported reportable directions, and limits this phase to monthly previews.
- Official §141(2) AO says the duty begins at the start of the Wirtschaftsjahr following notice, not necessarily the next calendar year: [§141 AO](https://www.gesetze-im-internet.de/ao_1977/__141.html).
- DATEV's official EXTF requirements specify header 700 and minimum Buchungsstapel version 12; the revised contract pins 700/category 21/version 13 and maps required fields: [DATEV interface requirements](https://developer.datev.de/de/product-detail/accounting-extf-files/2.0/documentation/interface-requirements-file), [DATEV header](https://developer.datev.de/de/file-format/details/datev-format/format-description/header).

## Findings

### 🔴 Critical (blocking)

None.

### 🟡 Moderate

1. **The §141 effective-period summary still says “year,” while the statutory boundary is the Wirtschaftsjahr.** `design.md` says the duty starts “at the beginning of the year following notice”; the modified accounting requirement repeats that wording. Under §141(2), the start is the beginning of the Wirtschaftsjahr following notice. A non-calendar fiscal year can therefore have a different effective date. The requirement that stored evidence include an effective date reduces runtime risk, but the normative summary must not teach an incorrect boundary. **Required change:** use `Wirtschaftsjahr` consistently in the design and modified spec; state that the date comes from verified notice/evidence and the profile's supported fiscal-year boundary, without assuming January 1. Add a scenario for a non-calendar Wirtschaftsjahr showing the warning begins only at its evidenced start date.

2. **Report route and service ownership remain generic.** The proposal says to replace `/reports` and `/taxes`; the new capability only says each workspace calls its “corresponding application service.” It does not assign EÜR, EKS, GuV, UStVA, ZM, DATEV, and export history to concrete route selections/deep links, nor state which typed use-case/API owns period validation, availability, and result generation. The maintained `typed-route-workspaces` contract requires route ownership/actions and truthful route boundaries, while the current router contains only generic table pages. **Required change:** add a compact route/service matrix to the design and corresponding testable spec contract: route (including report selection/deep-link), owning typed service/use-case, period inputs, result/availability boundary, and primary action for each report and history view. Declare/update `typed-route-workspaces` if its route ownership contract changes.

### 📌 Suggestions

- Pin the DATEV validator/version and assert the complete EXTF file shape in its fixture, including the v13 column-heading record if required by the selected validator.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: APPROVE_WITH_CHANGES

The legal boundary and route/service contract edits are narrow and can be re-checked against the exact listed items.

## Required Changes (if APPROVE WITH CHANGES)

1. Correct §141(2) to use the next applicable `Wirtschaftsjahr`, document the evidence/profile boundary source, and add a non-calendar-year scenario.
2. Define report route/deep-link selection and owning typed service/use-case in design and testable specifications; update the typed-route capability delta if route ownership changes.

CHANGES_APPLIED: yes

## Rebuttals

None in this round.
