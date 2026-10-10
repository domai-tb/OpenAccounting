## Context

Feature-map item 37 asks for reusable transaction presets with description, category, payment type, tax treatment, and an optional default amount (`pasted-text-1.txt:731-745`). The main accounting spec already requires one-action execution, but production `schnellbuchungen` stores only name, category, account, required amount, and description. It has no CRUD/execution caller in the application graph; the only production query reads a few rows in `EksService` without using them. Generic journal creation is not a balanced posting service. The active `cashbook-and-daily-close-workspace` owns the separate cashbook forms and explicitly excludes quick-booking templates; it requires an accepted typed direct-cash posting contract.

## Goals / Non-Goals

**Goals:**

- Manage reusable presets from the Banking workspace without introducing another transaction ledger.
- Preserve all inputs needed to execute a complete preset through an approved typed posting service.
- Keep existing presets readable while requiring review for direction or tax values the current schema does not persist.
- Make an executed preset traceable to the returned posting-group identity.

**Non-Goals:**

- Defining debit/credit legs, tax calculations, gross/net accounting policy, category/account defaults, settlement behavior, or correction posting rules.
- Posting by SQL, `JournalRepository.create`, or a separate quick-booking-specific journal writer.
- Replacing the cashbook composer, recurring booking, bank import, or bank reconciliation.
- Executing an incomplete legacy preset by guessing its direction, tax treatment, or amount basis.

## Decisions

1. **Add a sibling Banking view.** Use `/banking?view=quick-bookings` and preserve all bank import, history, cashbook, and daily-close query state. Quick-booking management does not add a top-level navigation destination or a competing ledger.
2. **Store explicit preset semantics.** Add `art` (income/expense), `ust_satz_id` (selected configured tax rate), and `eingabemodus` (net/gross amount basis), while allowing the default amount to be absent. Keep the current stable preset ID, name, account, category, and description. Existing rows retain their current values but receive no inferred direction, tax rate, or amount mode; they are marked “review required” until a user supplies valid values. Special tax cases are executable only if the accepted posting contract supports and the preset stores them; otherwise the preset stays unavailable.
3. **Use one accepted posting boundary.** One user activation submits the preset's exact values and an explicit business date to the typed posting use case. The UI does not calculate VAT, choose an account/category fallback, compose journal legs, or retry an ambiguous posting result. If the posting service requires values the preset lacks, execution is disabled with the specific missing fields. The current balanced-posting proposal does not accept direct cash events yet, so the Quick Bookings execution action remains unavailable until that contract is independently accepted and implemented.
4. **Validate references at save and execution.** A new or edited preset must reference an active category, a valid account/payment type, and a configured tax rate accepted by the posting owner for the explicit business date. `ust_saetze` has no `aktiv` column, so the preset layer SHALL NOT infer an active/inactive flag or add one. The posting owner must resolve whether the selected tax-rate ID is configured and applicable for that date; if it cannot prove that, it returns an unsupported/review state. Stale/deleted references produce a localized review state. They are not silently replaced or used to post with a warning.
5. **Keep the persisted history with the accounting owner.** A successful execution displays the committed posting-group identity returned by the posting service. The preset itself does not claim a posting succeeded until the service confirms it. Any source snapshot and idempotency behavior follow that service; the preset layer does not deduplicate separate intentional transactions by amount/text.
6. **Handle optional default amounts explicitly.** A null default amount means the activation form asks for an amount through the typed cash-event composer; a stored amount is a prefill. In both cases, the accepted posting contract determines the required input basis. No zero or default tax/account value is invented.
7. **Follow the design schema.** Use the existing Banking page header and page-level tabs, one primary create action, labeled form sections, visible focus, keyboard-accessible preset activation, active-locale number/date formatting, German and English strings, and narrow-window layouts defined by `DESIGN.md`.

## Risks / Trade-offs

- [Risk] Legacy presets appear usable although their direction/tax basis is absent. → Mitigation: show an explicit review state and keep execution disabled until edited.
- [Risk] One-action execution bypasses required accounting inputs. → Mitigation: submit only through the accepted posting service and block any preset missing a required field.
- [Risk] An inactive category, missing/unsupported account, or tax rate the posting owner cannot resolve for the business date leads to an incorrect posting. → Mitigation: revalidate at execution and fail closed with a localized field-specific reason.
- [Risk] Quick-booking forms duplicate cashbook entry behavior. → Mitigation: share the same typed posting use case and keep Quick Bookings limited to preset management and activation.

## Migration Plan

1. Add nullable migration fields for `art`, `ust_satz_id`, and `eingabemodus`; permit an absent default amount for newly edited presets while retaining old stored values and stable IDs.
2. Add typed preset projections, CRUD use cases, validation, and a Banking query view. Do not wire `EksService`'s schema probe as a functional caller.
3. Add execution only after the accepted posting service supports the preset's direction, payment account, category, tax selection, date, and amount basis. Until then, show the truthful unavailable state and create no journal rows.
4. Rollback may hide the view but must not delete existing preset rows or committed posting history.

## Open Questions

- Does the balanced-posting owner contract support one-action direct cash and bank transaction posting, including the explicit tax-rate/amount-mode fields proposed here?
- Should a preset with a missing default amount open the shared cashbook composer or a compact inline amount step? It must collect the same typed inputs in either case.
- Which special tax cases can a preset represent without becoming an unsafe shortcut? Unsupported cases remain unavailable until explicitly contracted.
