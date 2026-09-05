## Context

OpenAccounting currently builds but shows only a black `Container` with "Setup Wizard" because `lib/app/` and `lib/design_system/` from DESIGN.md §40 are missing. Existing `openinvoices` change already adds `AppTheme`, `AppColors`, `GoRouter` shell and database, but the shell in `lib/core/router/app_router.dart` is a minimal placeholder with a dummy drawer and no `AppShell` decomposition. `lib/core/theme` exists with seed `#4F46E5` but is not wired to `MaterialApp(theme/darkTheme/themeMode)` with persisted `ThemeMode` and not consumed via design tokens. `lib/main.dart` still contains legacy counter or a thin `ProviderScope` without the three-area shell. This change extracts the useful layout from `openinvoices/specs/app` (shell, guard, breakpoints, German locale) and aligns it fully to DESIGN.md §3–§10, §34–§35, §40–§44. It explicitly supersedes the previous 6-section taxonomy `Fakturierung/Buchhaltung/...` via delta `specs/app/spec.md` (MODIFIED Layout Structure) to resolve reviewer C1.

Current constraints: Flutter 3.47.2 via FVM, `flutter_localizations` + `intl` already in `pubspec.yaml`, strict `analysis_options.yaml` (package imports, `prefer_single_quotes`, `require_trailing_commas`, 120 chars), desktop-only (Windows/macOS/Linux), no mobile, no new backend.

## Goals / Non-Goals

**Goals:**
- Replace black fallback with a real left-panel shell: `AppShell(shell) + AppSidebar + AppPageHeader + AppPage + AppInspector` per §3, §40, §41.
- Implement responsive breakpoints exactly as DESIGN.md §4/§34: 240 px expanded ≥1200, 72 px rail 900–1199, drawer <900, with manual collapse persisted in `SharedPreferences`.
- Provide Material 3 theming with `ColorScheme.fromSeed(#4F46E5)` light/dark, `useMaterial3: true`, `ThemeMode` System/Hell/Dunkel persisted, `AccountingColors` `ThemeExtension`, tokens `AppSpacing`/`AppRadius`/`AppDuration`.
- Host existing setup wizard content inside the shell's constrained width instead of full-screen, preserving `hasUnternehmen` guard.
- Make layout auditable: every shell scenario from specs is assertable in widget tests (`pumpWidget` + size).

**Non-Goals:**
- No feature pages beyond shell placeholders for `Übersicht`, `Rechnungen`, `Belege`, `Bank`, `Kontakte`, `Steuern`, `Auswertungen`, `Einstellungen`, `Hilfe` — they stay as `AppPage` stubs with correct header.
- No chart library or data fetching — dashboard stays numbers-first.
- Window persistence beyond minimumSize is where practical per D6 (off-screen guard), but minimumSize 960×640 SHALL be enforced.
- No Riverpod vs GetIt migration — keep existing `AppDatabase` + `Riverpod` providers already in `lib/core`.

## Decisions

### D1: Shell location — `lib/app/app_shell.dart` + `lib/design_system/components/`
**Decision:** `lib/app/app_shell.dart` composes `AppSidebar`, `AppPage`, `AppPageHeader`, `AppInspector`. Reusable primitives live in `lib/design_system/components/` (`app_sidebar.dart`, `app_page_header.dart`, `app_page.dart`, `app_inspector.dart`) and tokens in `lib/design_system/tokens/(spacing,radius,duration).dart`. `lib/app/app.dart` only wires `MaterialApp.router` with `theme/darkTheme/themeMode` and `routerConfig`.
**Alternatives:** Keep everything in `lib/core/router/app_router.dart` (current placeholder). Rejected: mixes routing with layout, not reusable, violates §40.
**Rationale:** Matches DESIGN.md §40 structure, keeps feature code consuming the design system per §40, enables `AppPage` to be used by every feature without copy-paste.

### D2: Sidebar state — `SharedPreferences` + `ChangeNotifier` + `LayoutBuilder`
**Decision:** Persist `sidebarExpanded` bool via `SharedPreferences` (`openaccounting.sidebar_expanded` namespaced key) and expose via `SidebarController extends ChangeNotifier` with `toggle()` and `load()`/`save()` methods. Manual collapse toggle is implemented in `AppSidebar` header and persists. Width for responsive 240/72/drawer is STILL derived from `LayoutBuilder` constraints, not `window_manager` events, but the persisted expanded state is respected only at ≥1200 px (at <1200 px responsive rail/drawer overrides). Test `Sidebar collapses and persists` asserts round-trip via `SharedPreferences`.
**Alternatives:** `window_manager` `onWindowResize` + `getSize`. Rejected: overkill, adds native window dependency for a pure layout decision.
**Rationale:** DESIGN.md sidebar behavior is purely window-width driven; `LayoutBuilder` is synchronous, testable with `tester.view.physicalSize`, no platform channel flakiness.

### D3: Theme — `AppTheme` + `AccountingColors` already exists, wire correctly
**Decision:** Keep existing `lib/core/theme/app_theme.dart` and `app_colors.dart` but fix `AppTheme.light/dark` to use exact DESIGN.md §7 surfaces (`#F7F8FA`/`#FFFFFF` vs `#101217`/`#171A21`) and ensure `ThemeData` sets `scaffoldBackgroundColor`, `cardColor`, `dividerColor` from scheme, not defaults. Add `lib/design_system/tokens/` re-exporting the same values as `AppSpacing`/`AppRadius`/`AppDuration` so both import paths work. `ThemeMode` persisted via `SharedPreferences` (`theme_mode` string) with `ThemeModeNotifier extends StateNotifier<ThemeMode>`.
**Alternatives:** Introduce `flex_color_scheme` or `dynamic_color`. Rejected: DESIGN.md mandates manual `ColorScheme.fromSeed`, not generated.
**Rationale:** Minimal diff, reuses already-tested `AppTheme`, aligns to §7–§8 without new deps.

### D4: Router — keep `GoRouter` shell, move shell widget out
**Decision:** Keep `GoRouter` with `ShellRoute` and `hasUnternehmen` guard from `openinvoices`. Extract the current inline `AppShell` widget from `app_router.dart` into `lib/app/app_shell.dart` and keep `app_router.dart` only for route table (`/`, `/rechnungen`, `/belege`, `/bank`, `/kontakte`, `/steuern`, `/auswertungen`, `/einstellungen`, `/hilfe`, `/setup`). Add `GoRouter` `navigatorKey` and `refreshListenable` for sidebar highlight via `GoRouterState.matchedLocation`.
**Alternatives:** `auto_route` or `Navigator 2.0` custom. Rejected: already have 40+ routes planned in `openinvoices`; migration cost high.
**Rationale:** Reuse, keep deep linking and guard, fix only layout.

### D5: Localization — `gen_l10n` with `app_de.arb` Du-Ansprache
**Decision:** Keep `l10n.yaml` (`arb-dir: assets/l10n`, `template: l10n_de.arb`). Add `l10n_de.arb`/`l10n_en.arb` with `sidebarOverview`, `sidebarInvoices` etc Du-Ansprache (`Übersicht`, `Rechnungen`, `Neue Rechnung`). Use `AppLocalizations` in shell labels, not hard-coded. `MaterialApp.router` sets `localizationsDelegates` + `supportedLocales` + `locale: Locale('de','DE')`.
**Alternatives:** `easy_localization` with JSON. Rejected: DESIGN.md §23 mandates `gen_l10n` ARB.
**Rationale:** No new dep, aligns to §23.

## Risks / Trade-offs

- **[Risk] Shell refactor touches `app_router.dart` used by `openinvoices` → break 40+ routes** → **[Mitigation]** Keep route table identical, only extract widget, add widget tests for shell routes before moving.
- **[Risk] `SharedPreferences` async load causes flash (System → Hell)** → **[Mitigation]** Preload `ThemeMode` *before* `runApp` via `await SharedPreferences.getInstance()` in `main()` and override `themeModeProvider` with stored value. No `Future.microtask` flash; `ThemeModeNotifier` still handles fallback `system` on `unknown` and `await prefs.setString` non-blocking. Alternative `FutureBuilder` splash rejected as heavier.
- **[Risk] Drawer overlay at <900 px conflicts with inspector 360–440 px → content <960 min** → **[Mitigation]** At <900 px, inspector is overlay as well, not side-by-side; main content always full width.
- **[Risk] Token duplication `lib/core/theme` vs `lib/design_system/tokens`** → **[Mitigation]** `tokens` files re-export `AppSpacing` etc from `core/theme` or vice versa, single source of truth, both import paths work during migration.
- **[Risk] Hotkey `Ctrl+K` global search palette not yet implemented** → **[Mitigation]** Leave `RawKeyboardListener` stub in `AppShell`, no feature yet.

### D6: Window — `window_manager` for minimum and persistence
**Decision:** Use `window_manager` `WindowOptions(size: Size(1280,800), minimumSize: Size(960,640), center: true)` and `windowManager.waitUntilReadyToShow` at startup. Persist size/position/maximized via `windowManager.getBounds()` + `isMaximized()` on close to `SharedPreferences` (`window_bounds`/`window_maximized`), restore via `setBounds`/`maximize` if on-screen (off-screen guard per DESIGN.md §35). `Non-Goals` previously said keep existing no-op — updated to implement minimumSize unconditionally (SHALL), persistence where practical.
**Alternatives:** `bitsdojo_window` or no window code. Rejected: `window_manager` already in `pubspec.yaml` via `openinvoices`.

## Migration Plan

1. Create `lib/design_system/tokens/{spacing,radius,duration}.dart` and `components/{app_sidebar,app_page_header,app_page,app_inspector}.dart` with pure widgets, no `AppDatabase` dependency.
2. Create `lib/app/app_shell.dart` composing the components and `lib/app/app.dart` wiring `MaterialApp.router`.
3. Update `lib/core/router/app_router.dart` to import `AppShell` from `lib/app/`, keep route table and guard.
4. Update `lib/main.dart` to use `App` from `lib/app/app.dart`.
5. Add `assets/l10n/l10n_de.arb` with Du-Ansprache, run `fvm flutter gen-l10n`.
6. Replace black fallback: verify `/setup` renders inside shell with constrained width.
7. Run `fvm flutter analyze`, `fvm flutter test`, `fvm flutter build linux --debug` (clean `build/` first to avoid CMakeCache path issue from LXC).
8. No DB migration, no rollback beyond `git revert`. `SharedPreferences` keys are additive.

## Open Questions

- Should the “● Lokal” indicator at sidebar bottom be a `tooltip` + popover per §39 or a simple `Text` for v1? Proposal: simple `Text` + `onTap` popover stub.
- Should `AppInspector` be `NavigationRail` + `AnimatedSwitcher` or `LayoutBuilder` with `AnimatedContainer` 180–240 ms per §32? Proposal: `AnimatedContainer` 200 ms.
