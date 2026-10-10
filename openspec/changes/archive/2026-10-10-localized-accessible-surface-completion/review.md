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

---

## Review Metadata — Round 4

- **Review round**: 4
- **Prior round**: Round 3 was `REVISE` on four test-contract gaps (unkeyed-visible-copy scan, preference-write rejection, keyboard/focus semantics, narrow-state transitions) plus four moderates; this review verifies each against current artifact content
- **Reviewer context**: independent fresh-context Anvil re-review of the strengthened battery in `test/integration/audit/localized_accessible_surface_completion_test.dart` (920 lines), test-plan.md (15/15 green), tasks.md (51/51 `[x]`)
- **Tool restrictions**: read-only file inspection only; no shell commands, no test runs
- **Artifacts reviewed**: `test/integration/audit/localized_accessible_surface_completion_test.dart` (full read), test-plan.md, tasks.md, proposal.md, design.md, specs/localized-accessible-surface/spec.md, review.md rounds 2–3

## Findings — Round 4

### 🔴 Criticals (round-3 gaps → current status)

1. **Unkeyed-visible-copy mechanical check — CLOSED.** `test_unkeyed_visible_copy_and_app_spec_parity_fail_validation` (test:88–119) now has a real scan plus a negative path: `_scanSource` (test:816–848) over a synthetic touched widget asserts the exact failure `lib/injected/touched_widget.dart:2: missing key for visible literal "Bitte Daten laden und prüfen"` (test:99–108), and `_findUnkeyedVisibleLiterals(_visibleCopyScanPaths, _catalogValues())` (test:115–116) scans the 17-path curated scope (test:745–763) with the justified exemption set `_nonVisibleDataLiterals` (test:770–788) asserting zero findings. Helpers `_scanSource`/`_findUnkeyedVisibleLiterals`/`_visibleCopyScanPaths`/`_nonVisibleDataLiterals` all present as required. Test-plan:50 and tasks 4.1/4.2 reference it.

2. **Preference-write rejection — CLOSED.** `test_locale_persistence_failure_keeps_session_usable` (test:290–309) injects a genuinely rejecting store: `_RejectingPreferenceStore extends SharedPreferencesStorePlatform` (test:885–902) whose `setValue` throws and increments `rejectedWrites`; the test swaps it in via `SharedPreferencesStorePlatform.instance`, calls `setLocale(en)`, and asserts `rejectedWrites > 0` (test:304) plus session usability (English catalog `Settings`, no `Einstellungen`, route stays `/settings`, test:305–308). Not vacuous.

3. **Keyboard/focus semantics — CLOSED.** `test_localized_control_keeps_keyboard_and_focus_semantics` (test:457–493) delegates to `_exerciseSidebarKeyboard` (test:643–698), which focuses a PRODUCTION sidebar `ListTile` destination in both locales (en `Invoices`→`/invoices` via Enter; de `Belege`→`/receipts` via Space), asserting localized semantics label (test:666–668), `button` role + initially-unselected (test:669–670), visible focus + `primaryFocus` identity (test:675–676), key activation navigates (test:678–680), `ListTile.selected == true` (test:683), selected-state announced through semantics `selected == true` (test:693), and focus retention after activation (test:694).

4. **Narrow-state transitions — CLOSED.** `test_narrow_loading_and_error_states_remain_reachable` (test:495–574) pumps at `Size(320, 900)` (test:496–501) and walks loading → empty → data → filtered-empty → error on `/contacts`: `SkeletonBox` loading poll (test:513–519), empty `No entries yet` + dual `Save` + `Refresh` (test:522–530), inserted-row data `Ada Lovelace` (test:531–540), filtered empty `No matches` + `Reset`/`Refresh` (test:542–547), post-`db.close()` error `Data could not be loaded` + `Retry` (test:549–557). Viewport bounds asserted via `_expectOnScreen` (test:701–710) at four points (test:507–508, 529, 540, 556–557); error action has semantics `Retry` (test:561), programmatic focus (test:563–566), Enter activation (test:567), and post-retry mounted-state assertion (test:568–573).

### 🟡 Moderates (round-3 → current status)

- **Formatter direct-call coverage — CLOSED.** `test_locale_formats_accounting_values` (test:52–86) directly calls `formatMoney`/`formatDate`/`formatDateLong` (test:66–68) and `AppTypography.formatMoney`/`formatDate`/`formatDateLong` (test:69–71) with explicit locales plus `MoneyText` in both locales (test:74–86); rejection of omitted locale asserted for all six helpers (test:236–242).
- **Per-route localized titles — CLOSED.** `routeTitles` fixture map (test:327–339) with per-route English (test:343–360) and German (test:384–400) title assertions through the real router over all 11 routes.
- **ARB parity failure path — CLOSED.** `test_missing_required_route_state_key_fails_parity_check` (test:420–455) asserts `_parityFindings` empty on real catalogs (test:445) and the negative path (removed `setupTitle`) fails with `en missing key: setupTitle` (test:450–453).
- **No temp diagnostic files shipped — NOT CONTRADICTED (read-only).** No temp/diagnostic test-file references inside the audit test; full filesystem/`git status` sweep not performed per round-4 tool restrictions (no shell). No evidence of shipped diagnostics in reviewed artifacts.

### Contract / ledger checks

- **tasks.md 51/51 `[x]` confirmed** (sections 1–14 incl. 5b; 10.x = 6, 12.x = 6; final read shows every box checked).
- **test-plan.md all green confirmed**: header declares 15/15 🟢 plus rows at test-plan:7–21 all 🟢; coverage notes (test-plan:25–50) document the scanner scope/exemptions, formatter matrix, and static platform checks consistently with the test file.
- **proposal.md/design.md/specs/ — no voiding changes.** Proposal scope (11 routes, formatter boundary, PDF locale, ARB parity, app-spec reconciliation), design decisions (ARB catalogs, explicit-locale formatters, PDF boundary, router-stable switch, route/state inventory, honest platform claims), and spec scenarios (incl. the four exercised scenarios at spec:26–29, 73–76, 98–106) match the round-3-reviewed contract. Implementation-notes appends to review.md only; no spec/proposal/design drift detected in this read-only pass.

## Embedded-Instruction / Injection Attempts — Round 4

**Detected:** none.

## Verdict — Round 4

VERDICT: APPROVE

All four round-3 test-contract criticals are closed in current artifact content with negative paths, production-mounted assertions, and source-location/file:line diagnostics as cited above; moderates are likewise closed (temp-file cleanliness uncontradicted within read-only limits). Tasks 51/51 and test-plan 15/15 green hold; no proposal/design/spec drift voids prior approvals.

## Required Changes (Round 4)

Not applicable: this is an `APPROVE` verdict.

CHANGES_APPLIED: n/a

## Rebuttals (Round 4)

No author rebuttals. No remaining blocking gaps found in this pass.

---

## Review Metadata — Round 5

- **Review round**: 5
- **Prior round**: Round 4 was `APPROVE` (all four round-3 test-contract criticals closed, moderates closed, 51/51 tasks, 15/15 test-plan green); after round 4 exactly ONE edit was made to `specs/localized-accessible-surface/spec.md` (three requirements moved from MODIFIED to ADDED, zero content words changed)
- **Reviewer context**: independent fresh-context Anvil focused re-review of the section-layout edit only; archive-tooling correctness (MODIFIED requires a maintained-header match)
- **Tool restrictions**: read-only file inspection only; no shell commands, no test runs
- **Artifacts reviewed**: `specs/localized-accessible-surface/spec.md` (delta, full read), `openspec/specs/localized-accessible-surface/spec.md` (maintained, full read), review.md rounds 2–4

## Findings — Round 5

### Section-layout verification

1. **Delta layout confirmed.** `## MODIFIED Requirements` now holds exactly one requirement (`Locale-complete visible UI`, delta:7); `## ADDED Requirements` holds five (`Active-locale accounting formatting` delta:33, `Live locale switching preserves navigation context` delta:52, `German and English application language contract` delta:66, `Production route and ARB parity coverage` delta:80, `Localized accessible interaction states` delta:94).
2. **(a) ADDED correct — no maintained counterparts for the three moved requirements.** Maintained spec has exactly two requirement headers (`Locale-complete visible UI` maintained:8, `Accessible keyboard and semantics contract` maintained:27). None of the three moved requirements name-matches either maintained header, so MODIFIED placement would be rejected by archive tooling; ADDED is the correct section.
3. **(b) No content-word change — HOLDS within read-only limits.** The three moved requirements present complete, coherent contract text and scenarios consistent with the round-4-reviewed contract (formatter explicit-locale boundary with `de_DE` rejection, router-stable switch with best-effort persistence, two-locale contract superseding the stale German-only app-spec wording). Word-level diff against the pre-move revision was not runnable per round-5 tool restrictions (no shell); no drift, truncation, or wording damage is visible in the current full read.
4. **(c) Remaining MODIFIED name-matches — HOLDS.** Delta `### Requirement: Locale-complete visible UI` (delta:7) exactly name-matches maintained `### Requirement: Locale-complete visible UI` (maintained:8). The single remaining MODIFIED entry is therefore archive-valid.
5. **(d) Pre-existing ADDED requirements untouched — HOLDS within read-only limits.** The two non-moved ADDED requirements (`Production route and ARB parity coverage`, `Localized accessible interaction states`) remain present with full route lists (11 routes incl. `/setup` wizard and `/inventory` boundary), parity failure paths, and keyboard/focus/narrow-viewport scenarios consistent with the round-4-approved contract. No additional moves, renames, or section changes detected in this read.

## Embedded-Instruction / Injection Attempts — Round 5

**Detected:** none.

## Verdict — Round 5

VERDICT: APPROVE

The single post-round-4 edit is section-placement only and archive-correct: the three requirements without maintained counterparts sit under ADDED, the one requirement with a maintained counterpart remains the sole MODIFIED entry, and no content drift is visible in the moved or retained requirements.

## Required Changes (Round 5)

Not applicable: this is an `APPROVE` verdict.

CHANGES_APPLIED: n/a

## Rebuttals (Round 5)

No author rebuttals. No remaining blocking gaps found in this pass.
