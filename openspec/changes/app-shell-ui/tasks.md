## 1. Desktop Shell Layout

- [x] 1.1 Write failing test: `test/app/app_shell_test.dart` — shell renders on every primary route + not black fallback (assert fails for right reason, not import error)
- [x] 1.2 Implement: `lib/app/app_shell.dart` + `lib/design_system/components/app_sidebar.dart` + `lib/design_system/components/app_page.dart` to pass 1.1 (three-area shell with sidebar/header/canvas, not black Container)
- [x] 1.3 Refactor; full suite stays green

## 2. Sidebar Navigation (240/72/drawer + persist)

- [x] 2.1 Write failing test: `test/app/app_shell_test.dart` — expanded at 1280, compact rail at 1024, drawer at 800, collapses and persists, highlights correctly (assert fails)
- [x] 2.2 Implement: `lib/design_system/components/app_sidebar.dart` with `LayoutBuilder` 240/72/drawer, `SidebarController` `SharedPreferences` `openaccounting.sidebar_expanded`, workspace selector, `● Lokal` indicator, tooltip, temporary expand, selected highlight
- [x] 2.3 Refactor; full suite stays green

## 3. Page Header

- [x] 3.1 Write failing test: `test/design_system/app_page_header_test.dart` — header shows title+primary, filter toolbar with chips+count, subtitle without primary (assert fails)
- [x] 3.2 Implement: `lib/design_system/components/app_page_header.dart` with title/subtitle/primary action right, tabs, filter/search toolbar per §5
- [x] 3.3 Refactor; full suite stays green

## 4. Content Canvas and Layout Constraints

- [ ] 4.1 Write failing test: `test/design_system/app_page_test.dart` — form width 720–900 cap at 1920, padding 32/24/16, table full width (assert fails)
- [ ] 4.2 Implement: `lib/design_system/components/app_page.dart` with `ConstrainedBox` + `LayoutBuilder` + `AppSpacing` tokens, 4px grid, responsive padding
- [ ] 4.3 Refactor; full suite stays green

## 5. Optional Inspector

- [ ] 5.1 Write failing test: `test/design_system/app_inspector_test.dart` — inspector opens on selection 400px, adapts to overlay at 900, closes on Esc (assert fails)
- [ ] 5.2 Implement: `lib/design_system/components/app_inspector.dart` 360–440 px, `AnimatedContainer` 200ms, focus trap, overlay <900
- [ ] 5.3 Refactor; full suite stays green

## 6. Window Behavior

- [ ] 6.1 Write failing test: `test/app/window_test.dart` — window respects minimum 960×640 and state persists (assert fails)
- [ ] 6.2 Implement: `lib/main.dart` `window_manager` `WindowOptions(1280x800, minimumSize 960x640, center:true)` + `waitUntilReadyToShow` + persist `window_bounds`/`window_maximized` with off-screen guard
- [ ] 6.3 Refactor; full suite stays green

## 7. Material 3 Theming (seed #4F46E5)

- [ ] 7.1 Write failing test: `test/app/app_theme_test.dart` — light seed surfaces #F7F8FA/#FFFFFF, dark #101217/#171A21, system follows platform, toggle persists, invalid falls back to system (assert fails)
- [ ] 7.2 Implement: `lib/core/theme/app_theme.dart` `ColorScheme.fromSeed(seedColor: #4F46E5, brightness: light/dark)` + `useMaterial3:true` + `lib/app/app.dart` `MaterialApp(theme/darkTheme/themeMode)` + `lib/main.dart` preload `await SharedPreferences.getInstance()` before `runApp` and override `themeModeProvider` with namespaced key `openaccounting.theme_mode`
- [ ] 7.3 Refactor; full suite stays green

## 8. Typography and Locale (Inter + de-DE)

- [ ] 8.1 Write failing test: `test/l10n/format_test.dart` — financial 1.284,32 € right-aligned tabular, date 30.08.2026, language switch preserves route/filters (assert fails)
- [ ] 8.2 Implement: `lib/design_system/theme/app_typography.dart` Inter fallback + `FontFeature.tabularFigures()`, `MoneyText` widget, `NumberFormat`/`DateFormat` via `intl`, `lib/l10n/` with `assets/l10n/l10n_de.arb` Du-Ansprache, `MaterialApp` delegates
- [ ] 8.3 Refactor; full suite stays green

## 9. Design Tokens

- [ ] 9.1 Write failing test: `test/design_system/tokens_test.dart` — shell uses AppSpacing/AppRadius/AppDuration not raw 16/12/200 (assert fails)
- [ ] 9.2 Implement: `lib/design_system/tokens/spacing.dart` `AppSpacing` xs4/sm8/md12/lg16/xl24/xxl32/xxxl48, `radius.dart` control8/card12/dialog14, `duration.dart` fast120/normal200/slow240, consume in shell/components, add grep CI for raw values
- [ ] 9.3 Refactor; full suite stays green

## 10. Semantic Accounting Colors

- [ ] 10.1 Write failing test: `test/design_system/app_status_chip_test.dart` — status chip uses AccountingColors with icon+text not color alone, hover differs dark, missing extension falls back (assert fails)
- [ ] 10.2 Implement: `lib/core/theme/app_colors.dart` `ThemeExtension<AccountingColors>` paid/overdue/draft/warning/income/expense distinct light/dark, `AppStatusChip` with default/hover/pressed/focused/selected/disabled per §44
- [ ] 10.3 Refactor; full suite stays green

## 11. Elevation, Borders and Radius

- [ ] 11.1 Write failing test: `test/design_system/app_card_test.dart` + `test/design_system/app_dialog_test.dart` — card radius 12 no shadow, dialog radius 14 with shadow (assert fails)
- [ ] 11.2 Implement: `lib/design_system/components/app_card.dart` + `app_dialog.dart` with correct radius/border/shadow per §10
- [ ] 11.3 Refactor; full suite stays green

## 12. App Taxonomy Supersede

- [ ] 12.1 Write failing test: `test/app/app_shell_test.dart` — sidebar taxonomy supersedes old 6 sections, old tests retired, deep link highlights (assert fails)
- [ ] 12.2 Implement: `lib/design_system/components/app_sidebar.dart` taxonomy ÜBERSICHT/GESCHÄFT/STEUERN, update `openspec/changes/app-shell-ui/specs/app/spec.md` delta already applied, retire old splitter tests
- [ ] 12.3 Refactor; full suite stays green
