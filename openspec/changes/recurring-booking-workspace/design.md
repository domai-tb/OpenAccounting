## Context

`BuchungsVorlagenRepository` already stores recurring templates, validates the current interval/mode/type values, and creates an occurrence table with a unique `(vorlage_id, faelligkeit)` key. Its `generateFaellig` method currently advances the stored due date while generating results; direct mode writes a journal row and input-tax claim, while Beleg mode inserts an incoming-invoice draft directly. `AppServices` exposes this repository, but the production app has no routed booking-template page or use case that calls due generation.

The maintained `recurring` and `accounting` specs currently describe automatic journal/invoice generation and tax-direction effects. The active `balanced-journal-postings-and-settlement-events` change is still under `REVISE`; its review identifies recurring direct SQL writes among the writers that must be reconciled. The archived `recurring-accounting-postings` change addresses tax calculations, not a user review workspace or an accepted shared posting boundary. This change therefore defines a review-first workspace and keeps financial execution closed until the shared contract is accepted.

## Goals / Non-Goals

**Goals:**

- Add a routed workspace for creating and inspecting booking templates and reviewing due occurrences.
- Keep the page → use case → repository → data source dependency direction. Expose the feature through `AppServices`; do not construct repositories in widgets.
- Persist and reuse each occurrence by template ID and its stored due date, and show pending or blocked state with an actionable explanation.
- Send direct-mode financial effects only through an accepted shared posting contract. Send Beleg-mode draft creation through the existing incoming-invoice use case.
- Follow `DESIGN.md` page-header, table/list, keyboard-navigation, visible-focus, empty-state, and error-state guidance.

**Non-Goals:**

- Defining debit/credit legs, account selection, tax/VAT interpretation, input-tax eligibility, or accounting recognition dates.
- Adding a recurring-specific journal writer or direct SQL invoice-draft writer.
- Choosing date advancement, month-end, catch-up, retry, template-edit propagation, or occurrence snapshot policy.
- Replacing incoming-invoice finalization or changing financial effects already linked to existing occurrences.

## Decisions

1. **Add an application use-case seam and canonical `/recurring` route.** Add a booking-template use case that coordinates template storage, due-instance review state, and explicitly requested handoffs. Register it in `AppServices` and make `/recurring` resolve it through the app's service scope. The current repository stays behind this seam. A dedicated page uses one primary `Neue Vorlage` action and a table/list for templates and due occurrences, with clear status and detail review. `DESIGN.md` places recurring work under the invoice navigation family and calls for a consistent primary page header and keyboard-accessible tables.

2. **Separate schedule detection from occurrence execution.** Due detection uses the template's stored next due date and persists or reuses the existing unique `(vorlage_id, faelligkeit)` occurrence identity. Detection and review do not create financial records. The current `generateFaellig` loop combines detection, date advancement, and record creation; the new flow must split those responsibilities. It must not invent advancement or catch-up semantics. Until those are decided, do not advance a template's stored date merely because a scan or review occurred.

3. **Gate all financial effects at their owning boundary.** A confirmed direct occurrence can call the accepted shared posting contract only when it exists and defines all required inputs. The current active posting change has not passed review, so direct execution remains blocked and visible as pending with its reason. Beleg mode hands data to `RechnungenUseCases.createDraftRechnung`; the workspace does not insert into `rechnungen` or `rechnungspositionen`. Finalization remains owned by the invoice workflow.

4. **Keep occurrence state separate from accounting policy.** Reuse the current occurrence key and linked journal/invoice references. Add only the persistence needed to represent review state and a durable blocking or handoff reason. The shared posting boundary owns posting status and idempotency; the workspace supplies the occurrence identity as its source key. Do not infer posting fields from `art`, category, account, amount, or tax input.

5. **Keep unresolved template changes out of this scope.** The page supports creating and inspecting templates and due occurrences. It does not offer edits that alter financial inputs or schedule state until the existing template-edit and occurrence-value snapshot behavior is defined. Pausing and resuming may use the existing lifecycle methods, but do not change already-created occurrences as a side effect.

## Risks / Trade-offs

- [The shared posting contract remains under review, so direct-mode occurrences cannot complete financially.] → Keep the action disabled or return a clear pending/block reason; enable it only against the accepted contract.
- [The current schedule generator mutates dates and catches up overdue periods during its scan.] → Split scanning from execution and leave pointer advancement/catch-up open; do not silently preserve the current automatic behavior.
- [Existing occurrence rows may already link to journal rows or invoice drafts created by the legacy generator.] → Preserve those links and present them as existing results; do not recreate or rewrite their financial records as part of workspace rollout.
- [Template values may change while an occurrence awaits review, but propagation/snapshot rules are unspecified.] → Keep financial-input edits out of the initial workspace until that behavior is resolved.

## Migration Plan

1. Add the use case, service registration, and workspace route with template listing/creation and review-only due occurrences.
2. Evolve occurrence persistence without changing the existing `(vorlage_id, faelligkeit)` uniqueness or linked-result references. Preserve existing rows and make their already-linked results visible.
3. Route Beleg draft requests through the incoming-invoice use case. Keep direct mode pending until the accepted shared posting contract and its required mappings are available.
4. Roll back by removing the route/use-case wiring while retaining template and occurrence data. Do not delete linked journal or invoice records during rollback.

## Open Questions

- What accepted shared posting contract defines recurring direct-booking lines, tax interpretation, required mappings, date, source identity, and retry behavior?
- When does a reviewed or handed-off occurrence advance `naechste_faelligkeit`, and how are overdue periods and month-end dates handled?
- Should due occurrences snapshot template values at detection time or use current values at review time? What happens when a template is edited after an occurrence exists?
- What lifecycle states and recovery action should represent a failed incoming-invoice draft handoff?
