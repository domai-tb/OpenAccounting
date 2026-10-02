## Context

The existing `mahnwesen` specification defines a fixed per-level fee, a per-level percentage interest rate, a multiplier, snapshots, payment tracking, SMTP, and four standard levels. The reference guide instead calls the fee a percentage, its record shape differs from the database, and it claims statutory compliance. The source seeds fixed fees of €5/€10/€15/€25, annual rates of 0%/5%/8%/8%, delays of 7/21/35/49 days, and multiplier off; the settings singleton defaults its fallback rate to 0%. The current dunning entry points do not create a run or letter, `MahnungenRepository.create` uses invoice gross/net totals instead of the settled open balance, `sendMail` only updates a status, and `generatePdf` can write a minimal placeholder PDF. No `/mahnwesen` route or SMTP transport is currently exposed.

The feature map's dunning sections require configurable stages, manual/assisted/automatic evaluation, invoice and customer exclusions, optional customer consolidation, payment-sensitive interest, and collection preparation. The change adds those dunning behaviors while reusing the existing repository and application service composition.

## Goals / Non-Goals

**Goals:**

- Preserve the user-selected model: each stage has a fixed currency fee and a configurable annual percentage rate; the optional multiplier carries the immediately preceding configured fixed fee into the current stage.
- Make the current fresh-profile values explicit and keep them consistent across OpenSpec, `docs/05-mahnwesen.md`, and the seed. Initialization must not replace user-edited settings.
- Expose typed `/mahnwesen` list, preview, settings, exclusion, and history states using the existing desktop shell and service registration.
- Evaluate dunning from the settled open receivable balance, apply all modes to one eligibility policy, avoid duplicate stage records, and keep partial/full payment effects visible.
- Report a Mahnung as sent only after an actual configured transport accepts the message with its readable PDF attachment.
- Assemble a collection package from selected customer-linked invoices, statements, prior reminders, and readable stored artifacts.

**Non-Goals:**

- No automatic statutory-rate source, consumer/business spread, business surcharge, or legal-compliance claim is introduced by this proposal. Configured rates remain product values until a legal policy is approved.
- No dunning amount, interest, or settlement code may be implemented before the blocked `invoice-money-invariants` contract is accepted and the balanced-posting/settlement-event source is available and verified.
- This change does not reimplement PDF rendering or file lifecycle; it consumes the accepted document-artifact capability. It also does not invent SMTP credentials or claim that a transport exists; sending stays unavailable and visibly retryable until a separately configured transport is wired.
- No new dependency, accounting posting, or automatic customer-block release policy is selected here.

## Decisions

### Keep one dunning contract across spec, docs, and fresh seeds

Use `gebuehr` as a fixed euro amount, `zinssatz` as the annual percentage, and `multiplier` as a fixed-fee carry flag. Fresh-profile defaults match the existing seed: 7/21/35/49 days, €5/€10/€15/€25, 0%/5%/8%/8%, and multiplier disabled for the four standard levels. The 0% singleton fallback remains a fallback and does not overwrite a level's configured rate. Existing profile values are never reseeded. The docs must remove the percentage-fee examples and the unqualified statement that the defaults meet German law.

Rejected alternatives:

- Making fees a percentage would contradict the selected OpenSpec capability and change persisted values' units.
- Replacing the configurable rates with a hard-coded statutory formula would choose unresolved legal behavior and make the existing per-stage contract misleading.
- Updating standard-level records on every startup would silently overwrite user configuration.

### Evaluate one settled receivable projection

The dunning use case reads the authoritative open balance and dated settlement events from the accepted settlement capability. It does not join bank transactions directly or fall back to invoice gross/net fields when that projection is unavailable. Manual, assisted, and automatic modes share the same due-date, grace-period, next-stage, exclusion, and Mahnsperre checks. Assisted mode previews before creating drafts; an existing unsent draft for the same receivable and stage is reused. Consolidation is an explicit user choice, and every included invoice retains its own amount and source link.

This boundary depends on two upstream gates: accept the unresolved archived `invoice-money-invariants` review and make the `balanced-journal-postings-and-settlement-events` capability available before enabling dunning money calculations. If either source is missing or inconsistent, the operation returns an actionable unavailable result and creates no reminder.

Rejected alternatives:

- Calculating from `brutto_betrag` overstates partially paid invoices and ignores later payment dates.
- Treating any overdue `Forderung` row as the full balance can diverge from the canonical settlement history.
- Creating a new reminder on every run causes duplicate letters and repeated collection actions.

### Preserve historical calculations and delivery state

Persist the applied stage fee, rate, open principal, date interval, and carried amounts in the Mahnung snapshot. A partial settlement changes only future daily interest principal; it does not rewrite an already created letter. Stage progression follows a successful send, matching the existing OpenSpec rule. A missing transport, missing artifact, or rejected send leaves the same record unsent and retryable. The mail adapter reports transport acceptance rather than claiming final recipient delivery.

Use the document-artifact lifecycle proposal as the sole owner of PDF bytes, profile-local paths, and atomic persistence. The dunning use case requests a readable finalized artifact and blocks sending if it is unavailable; it does not keep the minimal-PDF fallback. SMTP credentials and transport selection remain a prerequisite owned by the settings/integrations work, so the page exposes a configuration boundary rather than a fake success.

Rejected alternatives:

- Marking `versendet` before the transport completes hides failures and advances stages without contacting the customer.
- Generating a second dunning-specific PDF writer duplicates the existing document renderer and artifact lifecycle.
- Updating prior Mahnung amounts after a payment would rewrite the historical notice instead of recording the payment against its snapshot.

### Keep the dunning workspace native to the desktop design

Add `/mahnwesen` as a shallow business destination in the existing sidebar. Use the existing page header, one primary action for run preview, searchable/filterable typed rows, right-aligned money values, and a detail inspector for invoice links and history. Follow `DESIGN.md` spacing, theme, status, focus, keyboard, and responsive rules; use the documented window-width breakpoints, with a list/detail fallback below 900 logical pixels. Loading, empty, failure, excluded, draft, sent, and unavailable states must be explicit and localized. Dunning must not use a generic table or expose raw schema columns.

Rejected alternatives:

- Hiding dunning under an unrelated customer detail leaves users without a reviewable run and stage-management entry point.
- A separate visual system would make a risk-sensitive workflow inconsistent with the rest of the app.

### Keep collection preparation read-only and source-linked

Build the package as a manifest of selected, readable artifacts and an as-of balance snapshot. The package does not post money, alter invoice status, or silently include every historical document. If a required prior reminder artifact is absent, show the missing item and keep the package incomplete.

## Risks / Trade-offs

- **[Risk]** The selected configurable rate model is not enough to claim statutory correctness. → Keep legal rate-source, party class, effective-date, and business surcharge policy as a blocking open question for automatic statutory interest; label current rates as configured values.
- **[Risk]** Settlement data or monetary rounding may differ before upstream changes are accepted. → Block all dunning amount work behind the named money and settlement gates; never fall back to invoice totals.
- **[Risk]** A mail server can accept a message even when delivery to the recipient later fails. → Persist only the transport's acceptance result and describe the state as sent/accepted, not delivered/read.
- **[Risk]** SMTP may remain unconfigured. → Keep sending disabled with a settings action and retry path; do not mark the Mahnung sent.
- **[Risk]** Consolidated letters can obscure per-invoice amounts. → Keep each invoice and snapshot separately linked and show the combined total only as a derived display value.
- **[Risk]** A missing historical PDF can make a collection package incomplete. → Report the exact missing artifact and never substitute an empty or placeholder PDF.

## Migration Plan

1. Resolve and accept the invoice money contract and complete the balanced journal/settlement event prerequisite; do not implement interest or balance calculations before both gates pass.
2. Approve the legal policy for any statutory-rate automation and the customer-block release rule before enabling those behaviors; configured percentages alone remain non-certified product inputs.
3. Sync the accepted dunning contract and update `docs/05-mahnwesen.md`; validate that fresh-profile seeds match the spec without overwriting existing customized levels.
4. Implement the typed dunning use case and `/mahnwesen` workspace against the accepted receivable source, then add exclusions and optional consolidation.
5. Wire PDF generation through the accepted document-artifact lifecycle and connect an actually configured SMTP transport. Keep those actions visibly unavailable until their prerequisites are present.
6. Add the collection-package manifest and verify every referenced artifact is readable and linked to the selected customer.
7. Rollback removes the route/use-case wiring and additive dunning metadata only after backing up profiles; it must preserve prior Mahnung snapshots, sent timestamps, and user-edited stage configuration.

## Open Questions

- What legal rate-source and consumer/business policy, if any, should replace user-configured stage percentages for statutory interest? The selected fee/rate data model does not decide the applicable statutory value, effective-date rule, or surcharge.
- Should fully paid receivables automatically clear only the invoice stage, or also clear automatic customer blocking? The existing docs and audit evidence conflict; manual Mahnsperre remains a separate control.
- Which existing or future settings capability owns SMTP credentials, and what transport acceptance result can it reliably expose? Until answered and implemented, send remains unavailable.
- Is consolidation an optional per-run action or a persisted mode preference? The proposal requires optional consolidation but deliberately does not choose the preference's storage location.
- The archived `invoice-money-invariants` change remains `REVISE`; its amount and correction-sign contract must be accepted before any implementation of the dunning monetary path.
