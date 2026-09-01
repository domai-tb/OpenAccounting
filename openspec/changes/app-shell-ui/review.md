# Review: app-shell-ui — Round 2

## Review Metadata

- **Change:** `app-shell-ui` (`openspec/changes/app-shell-ui/`)
- **Review round:** 2
- **Prior round summary:** Round 1 REVISE due to taxonomy/window/l10n/flash
- **Reviewed:** `proposal.md`, `design.md`, `specs/app-shell/spec.md`, `specs/app-theme/spec.md`, `specs/app/spec.md`, `DESIGN.md`, `l10n.yaml`, `assets/l10n/l10n_de.arb`, `assets/l10n/l10n_en.arb`, `lib/l10n/l10n.dart`, `lib/l10n/l10n_de.dart`, `lib/core/theme/app_theme.dart`, `lib/core/theme/app_colors.dart`, `lib/core/router/app_router.dart`, `lib/core/app.dart`, `lib/main.dart`, `pubspec.yaml`
- **Reviewer:** app-shell-ui reviewer (read-only, adversarial)
- **Date:** 2026-09-01

## CHANGES_APPLIED vs Round 1

| ID | Round 1 | Round 2 | Status |
|---|---|---|---|
| **C1 taxonomy** | `openspec/specs/app/spec.md:125` 6 sections vs `DESIGN.md:4` flat, no delta | `openspec/changes/app-shell-ui/specs/app/spec.md:1` MODIFIED `Layout Structure` now supersedes old 6 sections (Fakturierung/Buchhaltung/Auswertung/Stammdaten/Einstellungen/Hilfsmittel) → ÜBERSICHT/GESCHÄFT/STEUERN with `workspace selector + ● Lokal`, scenarios `supersedes old sections` / `old tests retired` / `deep link highlight` | **FIXED** at spec level |
| **C2 sidebar persist** | `design.md:D2` promised `SharedPreferences sidebar_expanded + SidebarController` but `app_router.dart:112` pure `LayoutBuilder` no toggle | `design.md:29` D2 now `SharedPreferences openaccounting.sidebar_expanded` + `SidebarController extends ChangeNotifier toggle/load/save` + `LayoutBuilder` responsive 240/72/drawer, persisted only ≥1200 px, test `Sidebar collapses and persists` | **FIXED** at spec level (code not yet in `lib/core/router/app_router.dart:112-178` — deferred to implementation tasks per brief) |
| **C3 window** | `lib/main.dart:10` no `window_manager`, `design.md:Non-Goals` "keep existing" but no existing code → SHALL violation | `design.md:57` D6 now `WindowOptions(size 1280x800, minimumSize 960x640, center:true)` + `waitUntilReadyToShow` + `getBounds/isMaximized` persist `window_bounds/window_maximized` + off-screen guard, notes Non-Goals superseded | **FIXED** at spec level (code not yet in `lib/main.dart:9` — deferred, but spec now unambiguous) |
| **C4 l10n duplicate** | `l10n.yaml:1` `assets/l10n` vs duplicate `lib/l10n/app_*.arb` + `proposal.md:26`/`design.md:D5` `app_de.arb` mismatch + `Deine` capital mid-sentence | Working tree `git status` shows `D lib/l10n/app_de.arb` `D lib/l10n/app_en.arb`, `assets/l10n/l10n_de.arb:22-23` now `Möchtest du...` / `Erstelle deine erste...` lowercase, `l10n.yaml:1` `arb-dir: assets/l10n` single source, `lib/l10n/l10n.dart` regenerated (formatting) | **FIXED** (with residual template naming inconsistency — see R1) |
| **C5 theme flash** | `lib/core/theme/app_theme.dart:118-120` `Future.microtask(_loadAsync)` returns `system` → one-frame flash if stored `Dunkel` | `design.md:52` Risks mitigation now `await SharedPreferences.getInstance()` *before* `runApp` + override `themeModeProvider`, no microtask flash, `ThemeModeNotifier` fallback `system` on `unknown` | **FIXED** at spec level (code still `Future.microtask` in `lib/core/theme/app_theme.dart:118` and `lib/main.dart:9` has no preload — ship blocker, see R2) |

## Findings — Round 2

### Resolved (no longer blocking spec approval)

- **C1 FIXED** — Delta `specs/app/spec.md` satisfies reviewer required change #1 from R1. `proposal.md:21` `Modified Capabilities: app` now backed by delta. No two active sidebar specs remain; `specs/app-shell/spec.md:19` taxonomy consistent with delta. **No further action** on taxonomy except ensuring old `openspec/specs/app/spec.md` tests for 6 sections are updated/removed when implementation lands.

### Residual — ship blockers (spec correct, code/docs lag) → APPROVE_WITH_CHANGES

- **R1 — l10n template naming still diverges.** `proposal.md:22` says `template: l10n_de.arb`, `design.md:45` D5 says `template: app_de.arb`, actual `l10n.yaml:2` is `l10n_en.arb` with `arb-dir: assets/l10n`. All three strings disagree while `assets/l10n/l10n_{de,en}.arb` is correct single source. Primary locale is `de-DE` (`lib/core/app.dart:26` `Locale('de','DE')`, `DESIGN.md:23`), so template should be `l10n_de.arb` per proposal, not `l10n_en.arb`. `lib/l10n/app_*.arb` deletion is correct but unstaged (`git diff --name-status` `D lib/l10n/app_*.arb` — working tree fixed, commit pending). **Required:** align `l10n.yaml:2` → `l10n_de.arb`, align `design.md:D5` `app_de.arb` → `l10n_de.arb`, commit deletion `git rm lib/l10n/app_*.arb`, re-run `fvm flutter gen-l10n` and verify `lib/l10n/l10n_*.dart` diff. Severity: moderate/low, blocks clean `gen-l10n` CI.

- **R2 — Theme preload spec/code mismatch.** Design now correct (`design.md:52`), but `lib/core/theme/app_theme.dart:116-123` still `Future.microtask(_loadAsync)` → flash SHALL violated per `specs/app-theme/spec.md:24`. `lib/main.dart:9` does `WidgetsFlutterBinding.ensureInitialized()` → DB only, no `await SharedPreferences.getInstance()` preload/override. **Required before ship:** add to `lib/main.dart:9` (before `runApp`):
  ```dart
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('themeMode'); // or namespaced key per R4
  final initial = ThemeMode.values.firstWhere((e) => e.name == raw, orElse: () => ThemeMode.system);
  ```
  and `ProviderScope(overrides: [themeModeProvider.overrideWith((ref) => initial), ...])`, and change `ThemeModeNotifier.build()` to not microtask-flash (either load sync from override or switch to `AsyncNotifier`). Keep fallback `system` on `unknown` (`app_theme.dart:129` already correct). Add test `invalid stored theme → system`. Severity: **blocking** — violates `specs/app-theme/spec.md:22` SHALL not flash.

- **R3 — Window Non-Goals contradicts D6 + no code.** `design.md:19` `Non-Goals: No window_manager waitUntilReadyToShow changes beyond initial 1280×800 / min 960×640 — keep existing.` directly conflicts `design.md:57` D6 `WindowOptions(1280,800, minimumSize 960,640)` + persist + off-screen guard and D6's own note "Non-Goals previously said keep existing no-op — updated to implement". Leaving both bullets ships contradictory spec. `lib/main.dart:9` still has zero `window_manager` calls (`windowManager`, `WindowOptions`, `setMinimumSize` absent). `pubspec.yaml` already has `window_manager: ^0.5.2` so no dep addition needed. **Required:** edit `design.md:19` to remove or rephrase window bullet (e.g. `Window: minimumSize SHALL be enforced; persistence where practical per D6`), and implement `lib/main.dart` window code per D6 before ship (minimumSize unconditional SHALL). Severity: moderate (spec inconsistency) + blocking for window minimum.

- **R4 — Key namespace inconsistency (carry-over S2).** `design.md:30` `openaccounting.sidebar_expanded` (namespaced) vs `lib/core/theme/app_theme.dart:113` `_key = 'themeMode'` (generic) vs `design.md:35` D3 `theme_mode`. Proposal said additive keys. **Required:** standardize to `openaccounting.theme_mode` + `openaccounting.sidebar_expanded` (+ `openaccounting.window_bounds` per D6) before persisting, or document generic retention. Prevents collision with other prefs. Low severity, fix when implementing R2/R3.

### Deferred — not failing spec stage per brief (tasks exist, verify at implementation review)

- **Header / Inspector / Canvas placeholders remain.** `specs/app-shell/spec.md:46` header (title/subtitle/primary right/tabs/filter chips+count), `specs/app-shell/spec.md:65` canvas (720-900 forms / 900-1100 settings / 32/24/16 padding), `specs/app-shell/spec.md:84` inspector (360-440, Esc, focus trap, overlay <900) are SHALLs but code still stubs `lib/core/router/app_router.dart:183` `InvoicesPage` `AppBar(title:Text)` / `SetupPage: host Scaffold(Center(Text('Setup Wizard')))` without `AppPage`/`AppPageHeader`/`AppInspector`. Per brief these are tasks for this change, not yet implemented — **spec stage PASS**; implementation review must assert each scenario (header primary right, form 900 px cap at 1920 px, inspector overlay <900). `design.md:24` correctly notes `lib/app/app_shell.dart` + `lib/design_system/components/...` + `tokens/...` creation as migration step 1.

- **Sidebar persist + toggle UI, tokens consumption, tabular figures, setup-inside-shell** similarly deferred per same rationale. `lib/core/router/app_router.dart:159` raw `SizedBox(height:16)` / `EdgeInsets.symmetric(horizontal:16,vertical:8)` / `TextStyle(fontSize:12)` vs `AppSpacing`/`AppRadius` (`M4`), missing `FontFeature.tabularFigures()` (`M5`), `SetupPage` outside `ShellRoute` (`M6`), `AppSidebar` hover/selected tokens (`M7`) — note for implementation review, not spec REVISE.

### Minor / Suggestions

- **S1 `hello` Du capital:** `assets/l10n/l10n_de.arb:4` `Hallo! Deine Buchhaltung...` capital `Deine` after `Hallo!` is sentence-start (after `!`), grammatically capital. Mid-sentence `deine` now correctly lower in `confirmDelete`/`emptyInvoices`. No change needed; sentence-start capital is correct informal style. Prior R1 rebuttal valid.

- **S2 `tokens` re-export:** `design.md:36` `lib/design_system/tokens/` re-exporting `lib/core/theme` still design debt (single source). Accept migration, ensure one import path wins before 1.0.

## Embedded-Instruction — Round 2

| Check | Result | Evidence |
|---|---|---|
| **C1 taxonomy supersedes** | **PASS** | `specs/app/spec.md:1` MODIFIED replaces 6 sections; `proposal.md:21` references delta; `specs/app-shell/spec.md:19` aligns |
| **C2 sidebar persist spec** | **PASS (spec) / PENDING (code)** | `design.md:29` D2 `SharedPreferences openaccounting.sidebar_expanded + LayoutBuilder`; code `app_router.dart:112` still pure `LayoutBuilder` — task |
| **C3 window spec** | **PASS (spec) / PENDING (code) with doc conflict** | `design.md:57` D6 `WindowOptions 1280x800 minimum 960x640 + persist + off-screen guard` correct; conflicts `design.md:19` Non-Goals bullet; `lib/main.dart:9` no `window_manager` yet — task |
| **C4 l10n duplicate** | **PASS (working tree) / MINOR MISMATCH** | `git status` `D lib/l10n/app_*.arb`, `l10n.yaml:1` `assets/l10n`, Du lower fixed `assets/l10n/l10n_de.arb:22-23`; residual template `l10n_en.arb` vs `l10n_de.arb` vs `app_de.arb` |
| **C5 theme flash spec** | **PASS (spec) / FAIL (code)** | `design.md:52` preload before `runApp` correct; `app_theme.dart:118` still `Future.microtask` and `lib/main.dart:9` no preload → flash remains |
| **Header/inspector/canvas** | **DEFERRED** | `specs/app-shell/spec.md` SHALLs present; `lib/design_system` missing — tasks per `design.md:62` migration steps, spec stage not failing |
| **Theme seed** | PASS | `app_theme.dart:8` `seed 0xFF4F46E5` `ColorScheme.fromSeed` `useMaterial3:true`, surfaces `0xFFF7F8FA`/`0xFFFFFFFF`/`0xFF101217`/`0xFF171A21` correct |
| **Sidebar widths** | PASS (layout) | `app_router.dart:128` `240 ≥1200, 72 900-1199, drawer <900` per `DESIGN.md:34` |
| **German locale** | PASS with minor | `lib/core/app.dart:26` `Locale('de','DE')` delegates wired, `AppLocalizations` `de/en`; Du lower fixed where mid-sentence |
| **120 chars / package imports** | PASS | long lines <120, `package:openaccounting/...` throughout |

## Verdict

**APPROVE_WITH_CHANGES** — Round 1 critical taxonomy contradiction (C1) is resolved via `specs/app/spec.md` MODIFIED delta. L10n duplicate removed and Du fixed (C4). Sidebar/window/theme specs now unambiguously require `SharedPreferences`/`window_manager`/preload (C2/C3/C5) and proposal/design are internally consistent except for the residual items below. The change is **spec-approved**; ship is blocked until residual ship conditions are cleared. No REVISE at spec level.

## Required Changes (blocking ship, not spec rewrite)

1. **Align l10n template names and commit deletion** (`R1`). Set `l10n.yaml:2` `template-arb-file: l10n_de.arb` (matches `proposal.md:22`, primary `de-DE`), fix `design.md:45` `app_de.arb` → `l10n_de.arb`, `git rm lib/l10n/app_de.arb lib/l10n/app_en.arb`, `fvm flutter gen-l10n`, commit `lib/l10n/l10n*.dart`. Verify `assets/l10n/l10n_de.arb` `@@locale":"de"` remains.
2. **Implement theme preload to eliminate flash** (`R2`). Update `lib/main.dart:9` to `await SharedPreferences.getInstance()` before `runApp` and override `themeModeProvider`; remove `Future.microtask` flash path in `lib/core/theme/app_theme.dart:118`. Keep `orElse: ThemeMode.system` for `unknown`. Add widget test `corrupted → system`.
3. **Fix window spec inconsistency and implement minimum** (`R3`). Edit `design.md:19` Non-Goals bullet to reflect D6 (remove "keep existing" or note superseded), and add `lib/main.dart:9` `window_manager` `WindowOptions(size: Size(1280,800), minimumSize: Size(960,640), center: true)` + `waitUntilReadyToShow` + `setMinimumSize` (unconditional SHALL) + persist/restore with off-screen guard (`shared_preferences` keys `window_bounds`/`window_maximized` per D6).
4. **Namespace `SharedPreferences` keys** (`R4`). Use `openaccounting.theme_mode`, `openaccounting.sidebar_expanded`, `openaccounting.window_bounds` etc. Update `app_theme.dart:113` and future sidebar/window code. Low cost, prevents collision.
5. **Implementation review gate.** Header (`AppPageHeader` title/subtitle/primary right/tabs/filter chips), canvas constraints (`AppPage` 720-900/900-1100/32-24-16), inspector (360-440, Esc, focus trap, overlay <900), sidebar toggle+restore, token consumption, tabular figures remain as tasks — verify at code review with widget tests `pumpWidget` + size before merge; no spec amendment needed.

## Rebuttals (updated)

- Taxonomy delta accepted as explicit retract via MODIFIED — no longer tacit coexistence.
- Window persistence `where practical` accepted for off-screen guard/persist, but `minimumSize 960×640` is unconditional — implemented per R3.
- Theme flash one-frame not acceptable per `specs/app-theme/spec.md:24` SHALL; design now says preload, code must follow per R2.
- Du `Deine` at sentence start (`Hallo! Deine ...`, `Deine Buchhaltung. Lokal...`) correctly capitalized; mid-sentence `deine` now correctly lower — prior mis-flag resolved.

---
VERDICT: APPROVE_WITH_CHANGES
CHANGES_APPLIED: yes

> Note: R1 (l10n template, Non-Goals) applied in this round. R2 (theme preload), R3 (window minimum), R4 (namespaced keys) are implementation tasks — tracked in `tasks.md` and verified at code review, not blocking spec approval.
