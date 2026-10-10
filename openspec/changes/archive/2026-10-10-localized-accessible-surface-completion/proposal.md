## Why

The app persists and applies a German/English locale choice, but most production routes still render German literals and the money/date helpers default to `de_DE`. This leaves the approved German-primary/English-secondary product scope incomplete and makes the selected English locale unreliable for visible copy, formatting, and accessibility semantics.

## What Changes

- Complete German and English ARB coverage for every production-visible label, action, tooltip, heading, loading state, empty state, error, dialog, and accessibility label on the documented routes, including the `/setup` wizard and `/inventory` unavailable boundary.
- Replace route and state literals in the dashboard, settings/profile surface, bank import, invoice/document views, and shared UI with generated localization keys.
- Make money, decimal, date, long-date, and semantic amount labels derive from the active app locale.
- Pass the active locale through invoice finalization into `PdfGenerator` so generated PDF labels, dates, numbers, and currency formatting are localized in German and English.
- Add a production-mounted locale-switch smoke path that updates visible copy without restarting and preserves the current route, query, and filter state.
- Add ARB key parity and required route-state key validation, plus Linux runtime coverage; record macOS and Windows as static acceptance checks on Linux.
- Reconcile the stale German-only requirement in `openspec/specs/app/spec.md` with the already approved German and English scope.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `localized-accessible-surface`: require complete German/English visible copy, active-locale formatting and semantics, production route/state coverage, and live locale switching that preserves navigation context.

## Impact

- Production UI and localization: `assets/l10n/`, generated `lib/l10n/`, `lib/core/app_locale.dart`, `lib/core/app.dart`, router/settings, dashboard, bank import, invoice/document views, and shared money/date components.
- Tests: production-mounted widget/integration coverage, ARB parity/required-key checks, and Linux route smoke. Existing route, bank, and receivable changes remain untouched.
- No new dependency, persistence schema, accounting semantics, dunning behavior, or platform-native runtime behavior changes are required; PDF localization is an explicit part of this surface change.
