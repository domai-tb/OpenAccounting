## Why

The dunning specification already chooses fixed per-level fees, percentage interest, and an optional fee multiplier, but `docs/05-mahnwesen.md` describes percentage fees and the production workflow still has no dunning workspace or complete run/send path. The repository also selects invoice totals instead of current outstanding balances and can mark a reminder sent without sending it, so reminders can overstate debt or report a false delivery state.

## What Changes

- Make the existing dunning model explicit and consistent across the base specification, documentation, and fresh-profile defaults: fixed euro fee per level, annual percentage interest per level, and the existing optional multiplier; preserve configurable defaults without claiming they are statutory rates.
- Add a typed dunning workspace for stage settings, eligible receivables, reminder history, exclusions, and review of manual or assisted runs.
- Define exact stage dates and payment-aware interest from the accepted settled-receivable source; fail closed without writes or side effects when that source is missing or invalid.
- Require delivery state to reflect actual transport acceptance; keep failed or unconfigured sends retryable and unsent.
- Keep each reminder linked to one invoice with its own immutable balance snapshot. A run may group separate invoice letters for review but SHALL NOT create a consolidated letter.
- Specify a collection package containing linked account, invoice, and reminder evidence, gated on the accepted balance source.
- Remove or mark unsupported documentation claims about automatic runs, automatic customer blocking, and statutory rate behavior until each behavior has an accepted contract and working runtime path.
- Keep the monetary path blocked until both the accepted invoice-money contract and the balanced-posting/settlement-event source are available.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `mahnwesen`: clarify the selected fee/interest contract and defaults, exact stage and payment-aware interest rules, fail-closed source behavior, reviewable manual/assisted operations, and truthful delivery and collection evidence.
- `typed-route-workspaces`: add the canonical `/mahnwesen` dunning workspace and its typed route states.

## Impact

- Documentation and specifications: `docs/05-mahnwesen.md`, `openspec/specs/mahnwesen/spec.md`, and `openspec/specs/typed-route-workspaces/spec.md`.
- Production surface: dunning repositories/services, route/navigation, dunning settings, PDF artifact integration, and SMTP delivery state.
- Dunning amount calculations depend on accepted `invoice-money-invariants` and a completed balanced posting/settlement-event source. Final PDF/send behavior depends on the document-artifact lifecycle. No code or data is changed by this proposal.
