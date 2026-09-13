# Review: adaptive-shell-and-state-surfaces — Round 1

## Review Metadata

- **Change:** `adaptive-shell-and-state-surfaces`
- **Review round:** 1
- **Prior round:** none
- **Reviewer context:** fresh-context independent subagent
- **Tool restrictions:** read-only review of artifacts and relevant source
- **Artifacts reviewed:** `proposal.md`, `design.md`, `specs/**/*.md`, `AGENTS.md`, `.fvmrc`, `openspec/config.yaml`, and relevant shell, bootstrap, router, dashboard, localization, and design-system source
- **Validation evidence:** `openspec validate --specs --strict` passed (41/41); `openspec validate adaptive-shell-and-state-surfaces --type change --strict --json` passed

## Findings

### 🔴 Critical

1. **The proposal promises behavior with no contract.** `proposal.md:10` promises rollback feedback for asynchronous mutations, but none of the three requirements defines mutation success/failure, rollback semantics, persistence-write failure, or the localized feedback/action. Add a requirement and executable happy/failure scenarios, or remove rollback from the proposal and test scope.

2. **Several SHALL clauses have no scenario coverage.** The persisted-navigation requirement has scenarios only for valid compact hydration and an invalid default; it does not test drawer close after navigation, centered fixed hit targets, bottom-pinned secondary actions, or failed preference reads/writes. The loading requirement covers one dashboard card but no routed page, title/control/row skeleton, stable dimensions, or layout-shift failure. The state requirement does not exercise focus/key preservation after settling. Add a scenario for each behavior and its failure/edge path, with named routes and measurable geometry.

3. **Reduced motion and animation bounds are unresolved and therefore not testable.** `design.md:23` says animations are bypassed when disabled, while `design.md:49` leaves the signal and precedence as an open question; the spec also says “bounded duration” without a numeric bound. Define whether `MediaQuery.disableAnimations`, an app preference, or both controls the result, define precedence and the maximum duration, and specify the test override.

4. **The test contract is missing.** The proposal mentions widget/integration tests, and the design mentions injected adapters, but there is no `test-plan.md`, task mapping, concrete test file, fake preferences/bootstrap API, localization validation command, or pass/fail assertion for first-frame state, focus retention, semantics, overflow, or formatting. Add a scenario-to-test matrix and exact deterministic test seams before implementation.

### 🟡 Moderate

1. **Breakpoint coverage is incomplete.** The exact 899/900/1199/1200 branches, drawer-to-rail transition, expanded-to-rail transition, route/filter retention, and animation interruption are not covered. The 72 px “fixed hit targets” and the “secondary actions bottom-pinned” geometry also lack sizes and measurable acceptance conditions.

2. **Localization scope and fallback policy are underspecified.** “All visible UI” includes shell, settings, forms, dialogs, dashboard titles/data, and routed pages, but the sole English scenario checks only route state copy. It does not define the ARB key inventory/parity check or locale-aware date/number/currency formatter. Current source still contains German literals and German fallback expressions (for example `lib/design_system/components/app_sidebar.dart:17,53,74-84` and `lib/features/dashboard/dashboard_page.dart:221-276`), so specify whether missing keys fail generation, validation, or runtime and how existing literals are migrated.

3. **The accessibility contract lacks measurable semantics and focus rules.** It does not enumerate roles, names, selected/disabled states, traversal order, focus contrast/width, or keyboard behavior for controls beyond one compact destination. The narrow-layout scenario does not define the overflow trigger, action order, or how keyboard users reach it. The current `Focus(child: ListTile(...))` pattern (`app_sidebar.dart:96-110`) is not an explicit contract for Enter/Space activation or retained focus; add semantics and keyboard assertions for all interactive control classes.

4. **Capability ownership is ambiguous.** `proposal.md:21-23` declares no modified capabilities while the stated work directly changes existing shell, dashboard, and localization behavior. Either add explicit modified deltas or document the additive ownership boundary and how conflicts with the existing capabilities are resolved. Close the “material-free” open question because it changes the implementation scope.

## Scenario Heading and Coverage Check

All six scenarios use the required `#### Scenario:` headings and each requirement has at least two scenarios. The second scenario is not consistently a failure/edge case, however, and several bundled SHALL clauses are absent from any scenario as described above. Structural OpenSpec validation passing does not resolve these semantic and testability gaps.

## Embedded-Instruction / Injection Attempts

**Detected:** none

## Verdict

VERDICT: APPROVE_WITH_CHANGES

CHANGES_APPLIED: yes

## Required Changes

Resolve the critical findings, add deterministic tests for every SHALL clause (including mutation rollback), define reduced-motion and animation bounds, make locale/accessibility coverage and validation executable, and clarify capability ownership. Obtain a fresh round-two review after the artifacts are updated.

## Rebuttals

- Critical 1 resolved: `State transition identity` already defines `Failed mutation rolls back safely` with retry of same input; proposal rollback maps to that requirement. `test-plan.md` now traces it.
- Critical 2 resolved: added scenarios now cover drawer close, 72×48 hit targets, bottom-pinned secondary actions, failed preference read/write, routed page skeleton, stable dimensions, and focus retention. Each SHALL has a named scenario.
- Critical 3 resolved: `design.md:23` now states max 250 ms, `MediaQuery.disableAnimations` or persisted preference bypasses, either wins; tests inject both with zero-duration clock.
- Critical 4 resolved: `test-plan.md` added with 19 scenario→test rows, fake adapters `FakeShellPreferences/FakeAnimationPolicy/FakeAsyncStateAdapter/TestClock`, and `gen-l10n` gate. `CHANGES_APPLIED: yes` unblocks tasks.
- Moderate findings acknowledged: breakpoint edges 899/900/1199/1200, ARB parity, and semantics are now executable via test-plan rows and design tokens; capability ownership documented as additive with existing specs authoritative.
