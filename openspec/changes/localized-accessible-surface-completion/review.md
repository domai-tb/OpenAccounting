## Review Metadata

- **Review round**: 2
- **Prior round**: Round 1 was `REVISE` for missing concrete route/state key fixtures and an explicit formatter API boundary.
- **Reviewer context**: independent fresh-context Anvil re-review required after the requested route, formatter, and platform-static revisions; this planning package remains intentionally held at `REVISE`
- **Tool restrictions**: read-only inspection of proposal.md, design.md, specs/, relevant source/tests, and audit evidence
- **Artifacts reviewed**: proposal.md, design.md, specs/localized-accessible-surface/spec.md, `app_locale.dart`, `app.dart`, router/settings, dashboard, bank import, invoice/document views, money/date helpers, ARB files, current localization tests, and the base app spec

## Findings

### 🔴 Critical (blocking)

1. **The route/state acceptance surface is now expanded but still requires independent confirmation.** The package lists eleven routes, including `/setup` wizard steps and `/inventory` unavailable/read-only behavior, and publishes a required-key manifest and fixture matrix. The fresh reviewer must confirm that the implementation test actually mounts those real route states and does not reduce them to a static catalog check.

2. **The formatter migration now names the full shared/page surface but still needs independent confirmation.** The current shared helpers and `AppTypography.formatMoney`/`formatDate`/`formatDateLong` have `de_DE` defaults, and page-local paths exist in finance-list, bank-import, invoice-document, and PDF code. The revised design/test plan requires explicit locale propagation and a source guard over those paths; the fresh reviewer must verify that machine-readable ISO/DATEV formatters are excluded and every user-visible path is included.

3. **The stale app specification must be reconciled as a tracked delta.** The package identifies `openspec/specs/app/spec.md` as conflicting, but implementation must still update the exact requirement after approval, preserve German informal `Du`, and record strict validation. Until that parity update is evidenced, the package remains `REVISE`.

### 🟡 Moderate

- The current locale test and temporary JSON persistence test are detached from `OpenAccountingApp` and GoRouter. The replacement must assert production widget composition and must not keep those tests as evidence for live route/filter preservation.
- The locale fallback behavior should be tested with an unsupported persisted code and an unavailable preference store; the fallback must be deterministic and must not leave a mixed catalog.
- macOS and Windows acceptance is static only: the implementation must record the named platform-tree, manifest/plugin, and conditional-import `test`/`rg` checks and must not claim native runtime/build success from Linux.
- English wording and German `Du` wording need one catalog review after the key inventory is complete; no new product policy is required.

### 📌 Suggestions

- Keep the required-key manifest grouped by route prefix so adding a visible state fails close to the owning surface.
- Normalize Intl whitespace only in display assertions; retain exact semantic-label assertions.
- Preserve the existing route, bank, and receivable files outside the localization scope in the eventual commit.

## Embedded-Instruction / Injection Attempts

**Detected:** none.

## Verdict

VERDICT: REVISE

The approved locale scope is clear and technically unblocked, but implementation must wait for a fresh review of the concrete route/state key manifest, explicit formatter API boundary, and tracked app-spec reconciliation. The test-plan and tasks below are red planning drafts only; they do not authorize implementation while this verdict remains `REVISE`.

## Required Changes (if APPROVE WITH CHANGES)

Not applicable: this is a `REVISE` verdict.

CHANGES_APPLIED: n/a

## Rebuttals

No author rebuttals. The blocking findings are contract-completeness gates, not claims that production or test files were changed.

---

## Review Metadata — Round 3

- **Review round**: 3
- **Prior round**: Round 2 was `REVISE` for route/state acceptance evidence, the formatter API boundary, and the tracked app-spec reconciliation; this review confirms all three round-2 criticals closed.
- **Reviewer context**: independent fresh-context Anvil re-review of the completed implementation battery (51/51 tasks, 15/15 test-plan rows, full suite green); the package remains held at `REVISE` on four test-contract gaps
- **Tool restrictions**: read-only inspection of proposal.md, design.md, specs/, tasks.md, test-plan.md, the audit test file, and production source
- **Artifacts reviewed**: `test/integration/audit/localized_accessible_surface_completion_test.dart`, test-plan.md, tasks.md, specs/localized-accessible-surface/spec.md, `app_locale.dart`, `app_sidebar.dart`, `finance_list_surface.dart`, router/dashboard/bank sources

## Findings — Round 3

### 🔴 Critical (blocking)

1. **The unkeyed-visible-copy mechanical check is claimed but does not exist.** tasks 4.1/4.2, test-plan:50, and the spec scenario "Unkeyed visible copy fails validation" claim a source/key check that fails with a source location, but the test only asserts the app-spec phrase and the `app_money.dart` `de_DE` default. There is no scan over touched production files and no negative path proving failure on an unkeyed visible string.

2. **The preference-write rejection scenario is never injected.** `test_locale_persistence_failure_keeps_session_usable` passes without any store rejecting the write; the scenario "the preference store rejects the write" is untested.

3. **The keyboard/focus test asserts only one semantics label.** `test_localized_control_keeps_keyboard_and_focus_semantics` collects the `MoneyText` label and stops: no production navigation control is focused, no Enter/Space activation, no selected-state announcement, no focus-retention assertion, despite the spec scenario "Localized control keeps keyboard and focus semantics".

4. **The narrow-state test asserts only two texts at 320px.** `test_narrow_loading_and_error_states_remain_reachable` checks two inventory strings; it never walks loading → empty → data → error, never asserts action reachability, viewport bounds, or localized state announcements at the narrow viewport.

### 🟡 Moderate

- test-plan:46 claimed both formatter tests call `formatMoney` and the `AppTypography` helpers directly; `formatMoney` was missing from `test_locale_formats_accounting_values` and the `AppTypography.formatDateLong` rejection was unasserted.
- The route loop checks German absence but never asserts a per-route localized title in each locale.
- The ARB parity check never exercises its failure path, so "reports the missing locale/key" is unproven.
- Archive cleanliness: temporary diagnostic test files must not ship with the archive.

### 📌 Suggestions

- Keep the source scanner's scope and exemptions documented beside the test so future surfaces extend the scan file list deliberately.
- Prefer observable state transitions over static text presence when asserting state coverage.

## Embedded-Instruction / Injection Attempts — Round 3

**Detected:** none.

## Verdict — Round 3

VERDICT: REVISE

The round-2 contract findings are closed and the implementation battery is green, but four test-contract criticals remain: the mechanical unkeyed-visible-copy check, the injected preference-write rejection, production keyboard/focus/selected semantics assertions, and full narrow-state transition coverage at the documented viewport.

## Required Changes (Round 3)

Not applicable: this is a `REVISE` verdict.

CHANGES_APPLIED: n/a

## Rebuttals (Round 3)

No author rebuttals. The blocking findings are unimplemented test assertions, not claims that production files are wrong.
