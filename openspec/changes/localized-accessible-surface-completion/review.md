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
