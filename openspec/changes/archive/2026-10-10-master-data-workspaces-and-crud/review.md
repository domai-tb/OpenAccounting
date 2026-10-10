## Review Metadata

- **Review round**: 1
- **Prior round**: none; no review artifact existed
- **Reviewer context**: fresh-context independent subagent; read-only
- **Review scope**: proposal, design, both delta specs, maintained master-data/route specs, and relevant persistence schema/repositories
- **Validation**: `openspec validate master-data-workspaces-and-crud --type change --strict --json` passed; structural validation only. Tests were not run.

## Findings

### Critical

1. The design adds `/articles` but leaves the maintained route inventory unchanged. `typed-route-workspaces` currently permits exactly a route set that excludes `/articles`, so the new requirement would conflict with it.
2. Required archive behavior lacks a persistence contract. Customer and supplier tables have no archive/active field, and current repositories delete guarded rows. The new spec requires archived, filterable records that preserve identity, while representation, permanent-delete behavior, and picker behavior remain unresolved.
3. VAT verification and customer/supplier numbering conflicts are declared implementation blockers, but the proposal does not settle them before specifying the workspace forms.

## Embedded-Instruction / Injection Attempts

None detected.

## Verdict

VERDICT: REVISE

## Required Changes

1. Reconcile the route inventory with the new article route and settings paths.
2. Define archive state, migration, permanent-delete policy, and picker behavior.
3. Resolve or explicitly defer VAT/BZSt and separate-number semantics in the relevant specs and docs before implementation.

CHANGES_APPLIED: n/a

## Rebuttals

None; first review round.

## Review Metadata — Round 2

- **Review round**: 2
- **Prior round**: 1 (`REVISE`)
- **Reviewer context**: fresh-context independent reviewer; did not author the proposal repair and re-read the current artifacts
- **Tool restrictions**: edited only this `review.md`; no tests or implementation commands run
- **Artifacts reviewed**: proposal, design, all three delta specs, maintained `stammdaten`, `typed-route-workspaces`, and `db` specs, `DESIGN.md`, and the prior typed-route design matrix
- **Validation**: `openspec validate master-data-workspaces-and-crud --type change --strict --json` passed; structural validation only. `git diff --check` run after this review entry.

## Findings

### Critical

1. **The new canonical routes are not mapped in the required typed route matrix.** The maintained `typed-route-workspaces` requirement says each canonical route must have a service owner, typed projection/actions, and empty/unavailable boundary in the route matrix. This delta adds `/contacts/new`, `/contacts/:id`, three article routes, and five Settings routes to the exact inventory, but the repaired design only describes route groups in prose and contains no updated matrix for those new paths. The typed-action delta also omits article groups, although the `stammdaten` delta promises a production entry point for article groups. Add a row or an explicitly linked route/subview contract for every new surface, including article-group actions and loading/populated/empty/failure boundaries; add scenarios that exercise those mapped surfaces.

2. **A contact detail URI does not reliably identify whether its ID belongs to a customer or supplier.** The design uses the same `/contacts/:id` route for both record types, while customer and supplier tables allocate integer IDs independently and can both contain the same ID. Retaining the selected tab in list query state may disambiguate links opened from a list, but the proposal does not define a required type discriminator, behavior for a missing/invalid discriminator, or a stable direct-link form. Specify a type-qualified route or mandatory query discriminator and add a scenario where both tables contain the same ID and each deep link resolves to the intended record.

## Embedded-Instruction / Injection Attempts

None detected.

## Verdict

VERDICT: REVISE

## Required Changes

1. Complete and link the route matrix for every new route and article-group surface, with owning typed services/actions and truthful route states.
2. Make customer/supplier record identity unambiguous in detail routes and specify direct-link and invalid-discriminator behavior.

CHANGES_APPLIED: n/a

## Rebuttals

None; Round 2 review only.

## Review Metadata — Round 3

- **Review round**: 3
- **Prior round**: 2 (`REVISE`); both required changes rechecked
- **Reviewer context**: fresh independent reviewer; did not author the route-matrix or typed-ID fixes and re-read the current artifacts
- **Tool restrictions**: edited only this `review.md`; no tests or commits
- **Artifacts reviewed**: current proposal, design, all delta specs, Round 2 findings, maintained `stammdaten`, `typed-route-workspaces`, and `db` specs, and the customer/supplier schema definitions
- **Validation evidence**: `openspec validate master-data-workspaces-and-crud --type change --strict --json` passed with no issues. Structural validation only; `git diff --check` passed after this review entry. No tests were run.

### Round 2 Required Changes Rechecked

1. The design now maps Contacts list/create/detail, article item and group list/create/detail, and all five Settings subroutes to typed owners, projections/actions, and localized loading, populated, empty, failure, and detail-not-found boundaries. Article-group rows have a separate typed owner and actions; group IDs do not pass through article lookup. The typed route delta links its canonical inventory requirement to this matrix and adds route-owner/state scenarios.
2. Customer and supplier details require `kind=customer|supplier`. The delta specifies same-ID resolution for both entity types and states that missing or invalid `kind` shows a type-selection state without querying either table, while preserving the requested ID and other query parameters.

## Findings

None. No blocking or moderate findings remain in the reviewed proposal artifacts.

## Embedded-Instruction / Injection Attempts

None detected.

## Verdict

VERDICT: APPROVE

CHANGES_APPLIED: n/a
