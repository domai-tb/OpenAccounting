## Context

The root app already watches `appLocaleProvider` and passes the selected locale to `MaterialApp.router`. The generated catalogs are only a small seed set, while `app_router.dart`, dashboard, setup, inventory, bank import, invoice/document views, and shared components still contain production German literals. `formatMoney`, `formatDate`, `formatDateLong`, `MoneyText`, and the parallel `AppTypography.formatMoney`/`formatDate`/`formatDateLong` helpers also carry `de_DE` defaults, so a root locale change does not reach accounting values or semantic amount labels. Shared/page paths such as `finance_list_surface.dart`, bank-import date helpers, invoice document formatting, and PDF document dates need the same audit. The existing localization tests exercise helpers or temporary JSON rather than the production app/router composition.

The implementation must preserve the approved German-primary/English-secondary scope, current route/bank/receivable behavior, and the repository's FVM 3.47.2 workflow. No persistence schema or new package dependency is needed.

## Goals / Non-Goals

**Goals:**

- Make generated German and English ARB catalogs the source for all visible copy on the documented production routes, including the setup wizard and the inventory unavailable boundary.
- Carry the active `Locale` into money, decimal, short-date, long-date, and accessibility formatting.
- Carry the active `Locale` through invoice finalization so generated PDF labels and visible financial/date formatting use the selected locale.
- Switch locale live through the existing settings control while keeping GoRouter location, query, search, selected tab, and filters intact.
- Cover loading, data, empty, error, dialog, action, tooltip, focus, and semantics states with production-mounted tests.
- Reconcile the stale German-only app requirement and add mechanical ARB parity/required-key validation.

**Non-Goals:**

- No accounting, tax, payment, dunning, persistence, routing-policy, or native capability changes. PDF localization and active-locale labels/formatting are in scope; document/accounting semantics remain unchanged.
- No new localization framework, runtime translation service, dependency, or locale beyond German and English.
- No redesign of layouts or accessibility behavior beyond replacing labels and preserving the documented keyboard/focus contract.
- No product decision about wording, formal address, or additional locales; German wording keeps the approved informal `Du` form.

## Decisions

### Use generated ARB catalogs and existing Flutter localization wiring

Add the required keys to `assets/l10n/l10n_en.arb` and `assets/l10n/l10n_de.arb`, regenerate `lib/l10n/`, and obtain copy through `AppLocalizations` at production widget boundaries. Keep the existing `MaterialApp` delegates and supported locales. A small required-key/parity check may parse the two ARB files, but it must not become a second translation source.

Rejected alternatives:

- A runtime translation service would add a dependency and make local-first startup and deterministic tests worse.
- A second hand-written map would duplicate ARB ownership and allow catalogs to drift.
- Keeping literals with English-only exceptions would leave the selected locale partial and violate the base spec.

### Pass an explicit active locale to pure formatters

Keep pure helpers pure, but remove the production-only German default from both `app_money.dart` and `AppTypography`: derive a normalized `de_DE` or `en_US` formatter locale from `Localizations.localeOf(context)` at widget boundaries and pass it into money/date helpers. `MoneyText` must derive the same locale when its caller does not provide one. `AppTypography.formatMoney`, `AppTypography.formatDate`, and `AppTypography.formatDateLong` must either require an explicit locale or delegate to the same explicit-locale implementation; no production caller may rely on a German default. Short dates should use an Intl locale pattern rather than a German-only literal pattern; long dates should use the locale's month/order rules. The hidden-amount semantic label must come from `AppLocalizations`.

The implementation audit covers the shared/page paths `lib/design_system/components/finance_list_surface.dart`, `lib/features/bank_import/bank_import_page.dart`, `lib/features/bank_import/bank_import_service.dart`, `lib/pages/rechnungen/invoice_document_page.dart`, and `lib/features/pdf/pdf_generator.dart`, in addition to `app_money.dart` and `app_typography.dart`. Machine-readable ISO/DATEV persistence formatters remain unchanged; only user-visible formatting paths cross this locale boundary. The active-locale source guard must inspect these symbols and call sites and reject implicit `de_DE` defaults or omitted locale propagation.

### Define the PDF locale boundary

`PdfGenerator.generate` must receive a required render-locale input; it must not infer German from a default. The UI boundary derives the normalized `de_DE`/`en_US` tag and the generated ARB-backed PDF label catalog from `Localizations.localeOf(context)`, then passes that immutable render context through the invoice use case/repository/data source to `PdfGenerator`. The generator uses that context for document labels, date order/month names, decimal separators, currency values, and accessibility-relevant PDF text. The locale is render input only and is not persisted in the accounting snapshot. A missing or unsupported render locale is rejected before PDF bytes are written.

PDF acceptance generates the same immutable snapshot in both locales, extracts text from the resulting bytes, and asserts localized headings/labels, dates, decimal/currency formatting, and no German-only labels in English output. The finalize path must prove that the active widget locale reaches the generator; a direct generator test with a manually supplied locale is insufficient. Existing PDF document-type/accounting semantics remain unchanged.

Rejected alternatives:

- A process-global `Intl.defaultLocale` would be order-dependent and unsafe for tests or multiple widget trees.
- Leaving optional `de_DE` defaults would make direct production callers silently violate English mode.
- Reimplementing number/date formatting per route would duplicate locale rules and drift.

### Keep locale state above the router and preserve URL state

Retain `appLocaleProvider` as the state owner and keep `appRouterProvider` stable while the root rebuilds for locale changes. The settings selector calls the existing notifier; route pages read localized strings from context. Search/filter/tab state must stay in the existing route/query/page state rather than being recreated during a locale rebuild. Tests will inspect the real `GoRouter` location and visible controls before and after switching.

Rejected alternatives:

- Recreating the router on every locale change risks losing navigation and query state.
- A route-local locale flag would diverge from the persisted root preference.
- Restarting the app would fail the live-switch requirement and make the desktop workflow needlessly disruptive.

### Inventory production-visible strings by route and state

Use the existing production route composition as the boundary. The implementation inventory covers `/`, `/settings`, `/banking`, `/invoices`, `/receipts`, `/contacts`, `/taxes`, `/reports`, `/help`, `/setup`, and `/inventory`, including each route's actual loading, data, empty, error, dialog, action, and tooltip paths. `/setup` uses wizard-step, validation, persistence-failure, and completion fixtures; `/inventory` uses its unavailable/read-only/retry fixture and must not query a generic fallback. Each replacement is a generated key with placeholders for dynamic values; user data itself is never translated.

### Test the real composition and keep platform claims honest

The focused test file mounts `OpenAccountingApp`/`MaterialApp.router` with real localization delegates, GoRouter, and test service overrides. It must not replace the production app with a standalone `MaterialApp` for the acceptance cases. ARB parity, required-key checks, and the active-locale formatter source guard are mechanical checks. Linux runs the production route smoke and debug build. macOS and Windows have concrete static checks only: verify conditional imports/platform branches, generated plugin/dependency manifests, and required platform tree files (`macos/Runner/Info.plist`, `macos/Runner/AppDelegate.swift`, `macos/Podfile`, `windows/CMakeLists.txt`, `windows/runner/Runner.rc`, and `windows/runner/main.cpp`) with `test`/`rg`; no native runtime or build result is claimed on Linux.

## Risks / Trade-offs

- **[Risk]** A literal may survive in a rarely visited dialog or error branch. → **Mitigation:** maintain the route/state inventory, add English and German production smoke assertions, and run a scoped source scan for visible literals before review.
- **[Risk]** Intl output contains non-breaking or narrow spaces that make exact string assertions brittle. → **Mitigation:** assert normalized display strings plus locale-specific separators/order, while retaining one exact semantic assertion per locale.
- **[Risk]** Replacing format defaults touches many callers, including AppTypography and page-local helpers. → **Mitigation:** make the locale boundary explicit in the shared formatter/MoneyText path, use the active-locale source guard across the named shared/page paths, and do not introduce a parallel formatter.
- **[Risk]** Locale rebuilds could reset page-local state. → **Mitigation:** assert route URI, query, filter, and selected tab around a real settings switch; keep router provider identity stable.
- **[Risk]** English translations could accidentally use German formal/informal wording or inconsistent accounting terms. → **Mitigation:** review ARB values as a catalog pair and retain the documented German `Du` wording; no new product vocabulary is invented in this change.

## Migration Plan

1. Add the required ARB keys in both locales and run `fvm flutter gen-l10n`.
2. Add the failing production-mounted locale, route/state, formatter, semantics, parity, source-guard, and platform-static checks before changing production widgets.
3. Replace literals and route-local formatting in small route groups, keeping the router and locale provider wiring stable.
4. Run focused tests, `fvm flutter analyze`, the full VM suite, strict OpenSpec validation, `fvm flutter build linux --debug`, the macOS/Windows static `test`/`rg` checks against the actual platform trees, formatting, and `git diff --check`.
5. If the change is reverted, generated l10n and ARB files revert with the route changes; there is no data migration or persisted-value conversion.

## Open Questions

No product or policy decision is open. The implementation review must confirm the final key inventory and English wording against the existing approved German/English scope before approval; a missing route/state key or unresolved literal is a blocking review finding.
