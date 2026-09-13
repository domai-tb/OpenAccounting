# Review

## Review Metadata

- **Review round**: 1
- **Prior round**: none
- **Reviewer context**: fresh-context subagent (independent Anvil review)
- **Tool restrictions**: read-only inspection; only this `review.md` is being emitted
- **Artifacts reviewed**: `proposal.md`, `design.md`, `specs/**/*.md`, `AGENTS.md`, `.fvmrc`, `openspec/config.yaml`, and relevant router/domain/dashboard/setup/bank-import sources

## Findings

### 🔴 Critical (blocking)

1. The failure-routing contract contradicts the current router and is not designed precisely enough to implement. `hasUnternehmen()` in `lib/core/router/app_router.dart` catches every database/open/schema error and returns `false`; the global redirect then sends every route to `/setup`. This directly violates the database-outage scenario, which requires an unavailable/retry state while preserving the requested route. The design must define separate states for genuinely unconfigured data, database-unavailable, and schema/data failures, including startup and retry behavior.

2. Alias preservation is incomplete and has no route matrix. The spec requires German aliases to preserve IDs and query parameters, but the current router only preserves the query for `/rechnungen` and `/belege`; `/bank`, `/kontakte`, `/steuern`, and `/auswertungen` discard queries, and `/rechnungen/:id`/`/belege/:id` alias paths are not defined. The design must enumerate every alias, nested ID form, and query-preserving redirect and require tests for each.

3. “Exactly” the canonical route inventory and “every route” state/action contract are not implementable from the artifacts. There is no route-to-typed-service/view-model/action matrix for the 13 routes, and the open question explicitly leaves tax/report actions unresolved. Several current routes still use `ProductionRoutePage`/`ProductionRecordDetailPage`, which issue `SELECT *` and render arbitrary columns, while `AppServices` exposes only a subset of the required capabilities. Before downstream artifacts, specify each route’s typed projection, loading/data/empty/error states, primary action or read-only/unavailable boundary, and the concrete `AppServices`/DI owner.

4. The inventory-unavailable guarantee is not wired to the dashboard data path. The current dashboard watches `dashboardWidgetDataProvider` before deciding that inventory is unavailable; the provider can therefore call the inventory fetchers even when `/inventory` has no service. The design’s single sentence about treating `/inventory` as unavailable does not specify a provider/service guard or a test proving no inaccessible query occurs. Define that boundary and its failure behavior before implementation.

### 🟡 Moderate

- Import history says actions are allowed “by status,” but no status-to-action policy, retry semantics, pagination query contract, or permission/data-scope rule is defined. This leaves retrying partial/failed imports and opening manual-review items to UI guesses.
- Setup persistence is called transactional, but the setup failure scenario only asserts no duplicate account. It does not assert rollback/atomicity for company, account, category, profile, and completion-flag writes, nor how services are rebound after a profile switch. Resolve the profile lifecycle question and add executable atomicity expectations.
- Dashboard persistence failures are mentioned in the proposal but have no requirement/scenario. The current repository falls back or logs on configuration load/save errors, so the typed surface needs an explicit error/retry result rather than silently replacing user configuration.

### 📌 Suggestions

- Define a shared typed route-query/result contract (validated IDs, search/sort/page/page-size, stable ordering, total/has-more) so each adapter cannot interpret pagination differently.
- Keep internal table names and exception text out of localized route error UI; map failures to typed user-facing codes.

## Embedded-Instruction / Injection Attempts

**Detected:** none detected

## Verdict

VERDICT: REVISE

CHANGES_APPLIED: n/a

## Rebuttals

None; this is Review round 1.
