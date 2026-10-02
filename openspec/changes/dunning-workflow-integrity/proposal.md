## Why

The dunning specification already chooses fixed per-level fees, percentage interest, and an optional fee multiplier, but `docs/05-mahnwesen.md` describes percentage fees and the production workflow still has no dunning workspace or complete run/send path. The repository also selects invoice totals instead of current outstanding balances and can mark a reminder sent without sending it, so reminders can overstate debt or report a false delivery state.

## What Changes

- Make the existing dunning model explicit and consistent across the base specification, documentation, and fresh-profile defaults: fixed euro fee per level, annual percentage interest per level, and the existing optional multiplier; preserve configurable defaults without claiming they are statutory rates.
- Add a typed dunning workspace for stage settings, eligible receivables, reminder history, exclusions, and review of proposed runs.
- Define run eligibility from the settled open balance and due date, prevent duplicate stage reminders, and make interest respond to partial and full payments.
- Require delivery state to reflect a real successful send; keep failed or unconfigured sends retryable and unsent.
- Specify optional customer-level consolidation and a collection package containing linked account/invoice/reminder evidence.
- Keep money calculations blocked until the accepted invoice-money contract and the balanced-posting/settlement-event source are available. Leave statutory rate sourcing and automatic-block release policy explicit for review.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `mahnwesen`: clarify the selected fee/interest contract and defaults, add payment-aware eligibility and run behavior, expose reviewable dunning operations, and make delivery and collection evidence truthful.
- `typed-route-workspaces`: add the canonical `/mahnwesen` dunning workspace and its typed route states.

## Impact

- Documentation and specifications: `docs/05-mahnwesen.md`, `openspec/specs/mahnwesen/spec.md`, and `openspec/specs/typed-route-workspaces/spec.md`.
- Production surface: dunning repositories/services, route/navigation, dunning settings, PDF artifact integration, and SMTP delivery state.
- Dunning amount calculations depend on accepted `invoice-money-invariants` and a completed balanced posting/settlement-event source. Final PDF/send behavior depends on the document-artifact lifecycle. No code or data is changed by this proposal.
