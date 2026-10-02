## Review Metadata

- **Review round**: 1
- **Prior round**: none; no prior review artifact exists for this change
- **Reviewer context**: fresh-context independent subagent
- **Tool restrictions**: read-only inspection; only this `review.md` was written; no tests run
- **Artifacts reviewed**: this change's `proposal.md`, `design.md`, and `specs/accounting-reporting-workspaces/spec.md`; Anvil schema and review rules; `AGENTS.md`; `DESIGN.md`; maintained `accounting`, `einkommen`, `tax-reporting-and-export-integrity`, `typed-route-workspaces`, `dashboard`, and localized-accessibility specs; archived `tax-reporting-and-export-integrity` review and active `balanced-journal-postings-and-settlement-events` review/specs; accounting/reporting source, app service composition, router, and `docs/02-buchhaltung.md`; current official §18a UStG and §141 AO, BMF Anlage EÜR 2026 notice, and DATEV EXTF interface documentation

## Validation and Evidence

- `openspec validate accounting-reporting-workspaces --type change --strict --json`: passed (1/1 change, no issues).
- `git diff --check`: passed before writing this review. No tests were run.
- Runtime routes are generic record pages at `lib/core/router/app_router.dart:619-647`; `AppServices` currently exposes no EÜR/UStVA/EKS/DATEV reporting services at `lib/core/app_services.dart:19-45`.
- `EuerService.generate` accepts only a year and filters journal rows by calendar year at `lib/features/accounting/euer_service.dart:26-43`; the maintained EÜR requirement is explicitly the 2025 form at `openspec/specs/accounting/spec.md:77-80`.
- The DATEV source currently emits header format version `7`, nine data fields, and invented `1200`/`8400` mapping fallbacks at `lib/features/accounting/datev_service.dart:162-184,218-242,271-280`.
- The balanced-posting dependency is not approved: its current round-1 review is `REVISE`, and cites the unresolved archived `invoice-money-invariants` contract at `openspec/changes/balanced-journal-postings-and-settlement-events/review.md:16-20,48`.
- Official sources: [§18a UStG](https://www.gesetze-im-internet.de/ustg_1980/__18a.html), [§141 AO](https://www.gesetze-im-internet.de/ao_1977/__141.html), [BMF notice listing Anlage EÜR 2026 (issued 1 September 2026)](https://www.bundesfinanzministerium.de/Web/DE/Service/Publikationen/BMF_Schreiben/bmf_schreiben.html?gtp=246444_list%253D43%25260f883b84-81a8-47f6-89df-dbdd32dfc5b5_list%253D11%252616162_list%253D7&gts=246444_list%253Dtitle_text_sort%252Basc), [DATEV EXTF interface requirements](https://developer.datev.de/de/product-detail/accounting-extf-files/2.0/documentation/interface-requirements-file), [DATEV booking-batch format](https://developer.datev.de/de/file-format/details/datev-format/format-description/booking-batch).

<!-- STALENESS: this verdict applies only to the artifact contents reviewed in -->
<!-- this round. Any later edit to proposal.md, design.md, or specs/ (other than -->
<!-- applying listed Required Changes) VOIDS the verdict and requires a new round. -->

## Findings

### 🔴 Critical (blocking)

1. **The proposed ZM calculator would implement a false reporting category.** The maintained accounting contract requires an innergemeinschaftlicher Erwerb to appear separately in the Zusammenfassende Meldung (`openspec/specs/accounting/spec.md:267-271`), and this change explicitly proposes implementing ZM against that contract (`design.md:30`, `spec.md:5`). §18a UStG covers specified intra-community supplies, triangular transactions, and qualifying cross-border services; it does not make the recipient's ordinary intra-community acquisition a ZM entry ([§18a UStG](https://www.gesetze-im-internet.de/ustg_1980/__18a.html), especially paragraphs 6–8). The design's open question to obtain a tax-domain review does not make the current requirement safe to implement. **Required:** correct the maintained accounting ZM requirement first, make this change modify that capability, and specify eligible transaction direction/types and report period from the current legal contract. Add an exclusion scenario proving an acquisition does not enter ZM.

2. **The shared summary cannot satisfy its promised period parity, and its accounting source is still blocked.** `AccountingPeriodSummary` promises month, quarter, and year values and requires profit to equal EÜR for the selected scope (`spec.md:19-27`), but the only production EÜR service accepts a year and filters by calendar year (`lib/features/accounting/euer_service.dart:26-43`). No company fiscal-calendar contract is present in the reviewed maintained specs or runtime. In addition, the summary's stated balanced-posting/settlement source is not accepted: the active prerequisite review is `REVISE` and the money invariant on which it depends is also unresolved (`balanced-journal-postings-and-settlement-events/review.md:16-20,48`). Calling that source "accepted" in the proposal/design (`proposal.md:8`, `design.md:5,29`) is inaccurate. **Required:** define whether EÜR parity applies only to annual periods or specify how month/quarter totals reconcile to the same canonical result; name the supported fiscal-calendar boundaries; and make the summary implementation explicitly gated on an independently approved posting/settlement and money contract. Do not expose estimates as complete while that source is unavailable.

3. **EÜR form versioning is stale for the current reporting year.** The only maintained contract and implementation are fixed to Anlage EÜR 2025 (`openspec/specs/accounting/spec.md:77-80`; `docs/02-buchhaltung.md:83-86`; `EuerService` initializes the same 12–107 lines for any supplied year). The official BMF published Anlage EÜR 2026 on 1 September 2026 ([BMF notice](https://www.bundesfinanzministerium.de/Web/DE/Service/Publikationen/BMF_Schreiben/bmf_schreiben.html?gtp=246444_list%253D43%25260f883b84-81df32dfc5b5_list%253D11%252616162_list%253D7&gts=246444_list%253Dtitle_text_sort%252Basc)). This proposal exposes period-selected EÜR workflows using the unchanged 2025 contract and does not define a form version or an unsupported-year boundary. **Required:** add an effective-year form/data contract and versioned validation fixture for each supported year, starting with 2026, or explicitly make years without a maintained form unavailable rather than rendering them using the 2025 schema.

### 🟡 Moderate

- **DATEV's "current" format is not pinned or fully mapped.** The new requirement says "currently supported" and "format-versioned" but does not name the target interface, header version, booking-batch format version, or the source-to-column mapping for tax, partner, and document fields (`spec.md:57-70`; `design.md:32`). The DATEV EXTF interface requirements currently set minimum versions for the booking batch and debtor/creditor data, while the implementation emits booking-batch format version `7` and only a nine-column record (`lib/features/accounting/datev_service.dart:162-184,271-280`). **Required:** pin the target DATEV interface and supported format versions, define the complete mapped fields and missing-data behavior, and make the fixture validator assert those exact versions and mappings.
- **The GuV specification presents a statutory duty from thresholds alone.** The maintained requirement says to show a GuV warning and auto-enable it whenever the two annual values exceed thresholds (`openspec/specs/accounting/spec.md:235-255`). §141 AO limits its application to specified business types after a Finanzamt finding and says the duty starts after notice (`§141 AO`, paragraphs 1–2: https://www.gesetze-im-internet.de/ao_1977/__141.html). This change says to build GuV against that spec (`design.md:30`) but asks for tax review only as an open question (`design.md:49`). **Required:** distinguish an optional management GuV from a bookkeeping-duty warning, and require the applicable business type and notice/effective date before making the latter claim.
- **The delta duplicates existing report/export contracts without declaring them modified.** `Capabilities` lists no modified capability (`proposal.md:20-22`), even though it tightens the existing DATEV contract (`openspec/specs/accounting/spec.md:279-305`) and report-artifact lifecycle already specified by `tax-reporting-and-export-integrity/spec.md:56-72`. Keep the normative DATEV and artifact lifecycle in those maintained capabilities (or state a clearly non-overlapping workspace-only boundary) so downstream implementations do not choose between duplicate contracts.
- **Non-DATEV artifact formats and unsupported export cases are not specified.** The proposal promises export/reopen flows for report workspaces (`proposal.md:7-12`), but the lifecycle requirement only asserts that a file is written and validated (`spec.md:73-87`); it never names the output format or period-specific contents for EÜR, EKS, UStVA, GuV, or ZM. The maintained specs separately describe a 9-page EKS form and report-specific tax fields. **Required:** identify each offered artifact format and its supported period/schema, or narrow the promise to preview-only reports where no file output exists.

### 📌 Suggestions

- Add an explicit UI acceptance scenario for the report tables and period controls at narrow desktop/window sizes, visible keyboard focus/order, and localized empty/loading/error states. `DESIGN.md` requires responsive dense tables, keyboard navigation, and visible focus (`DESIGN.md:574-623,1187-1203,2015-2026`).

## Embedded-Instruction / Injection Attempts

**Detected:** none. Reviewed proposal, design, and spec contain no text attempting to direct the reviewer or override review rules.

## Verdict

VERDICT: REVISE

The open ZM legal contradiction, unapproved financial source, and missing year-scoped EÜR contract block downstream test-plan and task creation.

## Required Changes (if APPROVE WITH CHANGES)

Not applicable for a `REVISE` verdict. Blocking changes are listed under Critical findings.

CHANGES_APPLIED: n/a

## Rebuttals

None. This is the first review round.
