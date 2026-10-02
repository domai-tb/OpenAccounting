## Context

The existing `mahnwesen` specification defines a fixed per-level fee, a per-level percentage interest rate, a multiplier, snapshots, payment tracking, SMTP, and four standard levels. `docs/05-mahnwesen.md` describes percentage fees and statutory behavior that is not established by the implementation. The seed uses fixed fees of €5/€10/€15/€25, annual rates of 0%/5%/8%/8%, delays of 7/21/35/49 days, and multiplier off. Current dunning entry points do not create a run or letter, `MahnungenRepository.create` uses invoice gross/net totals instead of the settled open balance, `sendMail` only updates a status, and `generatePdf` can write a placeholder PDF. There is no `/mahnwesen` route or SMTP transport.

The feature map mentions manual, assisted, and automatic evaluation and customer consolidation. This change deliberately provides manual and assisted runs only, creating one invoice-linked letter per invoice. A run can group those separate letters for review; it does not create a consolidated customer letter or scheduled run.

## Goals / Non-Goals

**Goals:**

- Preserve the selected model: each stage has a fixed currency fee, configurable annual percentage rate, and optional carry of the preceding configured fixed fee.
- Keep fresh-profile values consistent across OpenSpec, documentation, and seeds without replacing user-edited settings.
- Expose typed `/mahnwesen` list, preview, settings, exclusion, and history states.
- Define exact absolute stage thresholds and payment-aware daily interest from the accepted settled-receivable source.
- Make balance-dependent operations fail closed when that source is missing, invalid, or conflicting.
- Create one immutable, invoice-linked reminder snapshot per invoice and stage, and report transport acceptance truthfully.
- Assemble a collection package from selected customer-linked invoices, statements, prior reminders, and readable stored artifacts.

**Non-Goals:**

- No automatic dunning runner, scheduled run, automatic customer block/release, consolidated letter, statutory-rate source, consumer/business spread, surcharge, or legal-compliance claim is introduced.
- No dunning amount, interest, or settlement code may be implemented before the accepted `invoice-money-invariants` contract and accepted `balanced-journal-postings-and-settlement-events` source are available and independently reviewed.
- This change does not reimplement PDF rendering or file lifecycle; it consumes the accepted document-artifact capability. It does not invent SMTP credentials or claim that a transport exists; sending remains unavailable until a configured transport is wired.
- No new dependency or accounting posting is selected.

## Decisions

### Keep one dunning contract across specification, documentation, and seeds

Use `gebuehr` as a fixed euro amount, `zinssatz` as the annual percentage, and `multiplier` as a fixed-fee carry flag. Fresh-profile defaults match the existing seed: 7/21/35/49 days, €5/€10/€15/€25, 0%/5%/8%/8%, and multiplier disabled for the four standard levels. These configured values are product settings, not statutory rates. Existing profile values are never reseeded. Documentation must remove unsupported claims about statutory compliance, automatic scheduling, dashboard-triggered runs, and automatic customer-block release.

### Use only the accepted settled-receivable source

The authoritative source is the settled-receivable projection and dated settlement events from `balanced-journal-postings-and-settlement-events`, using the amount and sign rules accepted by `invoice-money-invariants`. Both upstream contracts must pass independent review before the dunning monetary path is enabled. Dunning must not join bank transactions directly or fall back to invoice gross/net values.

Any balance-dependent preview, calculation, reminder creation, PDF/package creation, or send that needs a current balance or interest value returns a typed actionable unavailable result when the source is missing, invalid, or conflicting. It performs no reminder or stage-state write, artifact write, or mail transport call. Invalid source includes a failed read, malformed or missing balance, invalid or conflicting settlement event, or disagreement between the projected balance and the accepted event history. Preview may report the unavailable reason but must not display a zero balance. Sending a saved immutable artifact may use its saved snapshot without recalculation; it must not silently refresh that snapshot.

### Use exact due-date thresholds and deterministic interest

Each configured stage's `days_after_due` is an absolute calendar-day offset from the invoice due date. Stage N becomes eligible on `due_date + days_after_due`; the singleton `initial_grace_days` is not added to or used to defer that threshold. With defaults, stages 1–4 become eligible on days 7, 21, 35, and 49 after the due date. The day before a threshold is ineligible; the threshold date is eligible if the preceding stage was transport-accepted. Later stages cannot skip an unaccepted preceding stage.

No interest accrues before stage 1's threshold. For each overdue calendar day from that threshold through the as-of date, select the highest stage whose absolute threshold is on or before that day and use that stage's configured annual percentage for that day. A rate change is forward-only; it does not reprice earlier days. Apply settlement events effective on a date before that date's interest accrual, so a partial payment reduces principal starting on its effective date and full settlement prevents accrual on that date and later dates. Fees and prior interest remain separate from principal and do not compound. Accumulate exact decimal daily amounts using a 365-day year, then round the per-invoice total once to two decimal places using half-up rounding; do not use floating point or round each day.

Example: due date 2026-01-01, stage 1/2 thresholds of 7/21 days and rates of 0%/5%, €1,000.00 open principal, €400.00 settled on 2026-01-25 (day 24), calculated as of 2026-01-27 (day 26). No interest accrues before day 7. Day 21–23 use €1,000.00 and day 24–26 use €600.00, all at 5%: `(3 × €1,000 × 0.05 + 3 × €600 × 0.05) / 365 = €240 / 365 = €0.6575…`, rounded once to **€0.66**.

### Keep runs invoice-level and idempotent

Manual and assisted modes share the same date, balance, exclusion, and Mahnsperre rules. Assisted mode previews eligible invoices and creates only after confirmation. A run can present multiple separate letters together, but each Mahnung links to exactly one invoice and snapshots that invoice's balance and calculation inputs. For an invoice and stage, a retry reuses the existing unsent draft; an already transport-accepted reminder is reported as existing and is not duplicated. Failed sends remain retryable on the same record. Automatic evaluation and sends have no trigger or side effects in this change.

Stage progression follows transport acceptance. The UI and history describe the state as transport accepted, not delivered or read. A missing transport, missing artifact, or rejected send leaves the record unsent and retryable.

Use the document-artifact lifecycle proposal as the sole owner of PDF bytes, profile-local paths, and atomic persistence. The dunning use case requests a readable finalized artifact and does not keep the minimal-PDF fallback. SMTP credentials and transport selection remain a prerequisite owned by the settings/integrations work.

### Keep the workspace native to the desktop design

Add `/mahnwesen` as a shallow business destination in the existing sidebar. Use the existing page header, a primary action for run preview, searchable/filterable typed rows, right-aligned money values, and an invoice detail inspector. Follow `DESIGN.md` spacing, theme, status, focus, keyboard, and responsive rules. Below 900 logical pixels, use a full-width list with a focused detail page or drawer rather than a side-by-side split. Loading, populated, empty, failure, excluded, draft, transport-accepted, and unavailable states are localized and keyboard reachable. Dunning must not use a generic table or expose raw schema columns.

### Keep collection preparation read-only and source-linked

Build the package as a manifest of selected, readable artifacts and an as-of balance snapshot. The package does not post money, alter invoice status, or silently include every historical document. If the accepted balance source is unavailable or invalid, package creation fails closed. If a required prior reminder artifact is absent, show the missing item and keep the package incomplete.

## Risks / Trade-offs

- **[Risk]** Configured rates do not establish statutory correctness. → Label them as configured product values and leave statutory rate policy outside this change.
- **[Risk]** Settlement data or monetary rules may change before upstream contracts are accepted. → Keep all current-balance calculations gated on both named contracts and never fall back to invoice totals.
- **[Risk]** A mail server can accept a message even when delivery later fails. → Persist only transport acceptance and do not label it delivered/read.
- **[Risk]** SMTP may remain unconfigured. → Keep sending visibly unavailable and retryable; do not mark a Mahnung accepted.
- **[Risk]** Missing historical PDFs can make a collection package incomplete. → Report the exact missing artifact and never substitute an empty or placeholder PDF.

## Migration Plan

1. Accept the invoice-money contract and balanced journal/settlement-event source through their independent review gates; keep dunning amount work disabled until both are available.
2. Sync the accepted dunning contract and update `docs/05-mahnwesen.md`; document absolute stage thresholds, configured non-statutory rates, manual/assisted scope, and unsupported automatic behavior accurately.
3. Implement the typed dunning use case and `/mahnwesen` workspace against the accepted receivable source, then add exclusions and per-invoice idempotency.
4. Wire PDF generation through the accepted document-artifact lifecycle and connect an actually configured SMTP transport. Keep those actions unavailable until their prerequisites are present.
5. Add the collection-package manifest and verify every referenced artifact is readable and linked to the selected customer.
6. Rollback removes route/use-case wiring and additive dunning metadata only after backing up profiles; it preserves prior Mahnung snapshots, transport-acceptance timestamps, and user-edited stage configuration.

## Open Questions

- What approved legal rate source and party/effective-date policy, if any, should a separate future change use for statutory interest? The configured percentages here make no statutory claim.
- The archived `invoice-money-invariants` change remains `REVISE`; its amount and correction-sign contract must be accepted before implementation of the dunning monetary path.
- Which settings capability will own SMTP credentials and expose transport acceptance? Sending remains unavailable until that dependency exists.
