## Why

Recurring booking templates have a repository and due-generation code, but no user-facing workspace or production caller. The current requirements and direct-mode implementation can create journal effects on a schedule before a user reviews the due item, while the shared posting contract remains unresolved.

## What Changes

- Add a recurring-booking workspace for creating and inspecting templates, their schedules, and due instances.
- Make due instances durable and reviewable before execution; show blocked items and the reason they cannot proceed.
- Route any confirmed financial effect through the accepted shared accounting posting contract. Until it is available, due instances remain pending and the workflow creates no journal posting.
- Preserve document mode as a handoff to the existing incoming-invoice draft workflow; do not add another invoice editor or journal writer.
- Reconcile the existing recurring/accounting requirements so interval, tax, date, account, and template-edit behavior are not newly inferred by this workspace.

## Capabilities

### New Capabilities

- `recurring-booking-workspace`: User-facing management and review of recurring booking templates and due instances.

### Modified Capabilities

- `recurring`: Replace automatic financial generation with review-first due instances and shared-boundary execution; treat booking type as configured template data until the accounting contract defines its effect.
- `accounting`: Require recurring template execution to use the accepted shared posting boundary and fail closed when it is unavailable.
- `typed-route-workspaces`: Add `/recurring` to the canonical route inventory and require its typed route states.

## Impact

Adds a routed workspace and application use case over the existing `BuchungsVorlagenRepository`, due-instance persistence/state, and service composition. Direct journal writes in recurring execution must be replaced by shared-boundary calls before any financial effect is enabled. Beleg mode connects to incoming-invoice draft creation through its owning use case. The design follows `DESIGN.md` page-header, table, empty/error-state, keyboard, and visible-focus guidance. No debit/credit, VAT, recognition-date, schedule catch-up, or template-edit policy is selected here.
