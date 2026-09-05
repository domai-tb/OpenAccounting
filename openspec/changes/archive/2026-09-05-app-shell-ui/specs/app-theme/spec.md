## ADDED Requirements

### Requirement: Material 3 Theming

The system SHALL provide Material 3 `ThemeData(useMaterial3: true)` with `ColorScheme.fromSeed(seedColor: #4F46E5)` for both light and dark, per DESIGN.md §7–§8. Three appearance options System/Hell/Dunkel SHALL be exposed, default System, persisted across launches, and applied via `MaterialApp(theme/darkTheme/themeMode)`.

#### Scenario: Light theme uses seed and correct surfaces
- **GIVEN** the app is in Hell mode
- **WHEN** the theme resolves
- **THEN** `colorScheme.primary` SHALL be `#4F46E5`, `scaffoldBackgroundColor` SHALL be `#F7F8FA`, and `cardColor` SHALL be `#FFFFFF`

#### Scenario: Dark theme avoids pure black
- **GIVEN** the app is in Dunkel mode
- **WHEN** the theme resolves
- **THEN** `scaffoldBackgroundColor` SHALL be `#101217` (not `#000000`) and `cardColor` SHALL be `#171A21`

#### Scenario: System mode follows platform
- **GIVEN** the user selects System and the OS is in dark mode
- **WHEN** the theme resolves
- **THEN** `ThemeMode.system` SHALL be used and dark colors SHALL be active

#### Scenario: Theme toggle persists
- **GIVEN** the user switches from Hell to Dunkel
- **WHEN** the app restarts
- **THEN** the stored preference SHALL be Dunkel and the UI SHALL not flash Hell before applying

#### Scenario: Invalid stored theme falls back to system
- **GIVEN** the persisted theme value is corrupted to "unknown"
- **WHEN** the app loads the preference
- **THEN** it SHALL fall back to `ThemeMode.system` and not crash

### Requirement: Typography and Locale

The system SHALL use Inter fallback sans-serif, type scale per DESIGN.md §9, tabular financial numbers right-aligned, and locale-aware formatting via `flutter_localizations` + `intl` for `de-DE` (decimal comma, thousands dot, DD.MM.YYYY) without encoding locale assumptions into business logic.

#### Scenario: Financial number formatted for de-DE
- **GIVEN** the amount is 1284.32
- **WHEN** it renders in a MoneyText widget with `de-DE`
- **THEN** it SHALL display `1.284,32 €` right-aligned with tabular figures

#### Scenario: Date formatted for de-DE
- **GIVEN** the date is 2026-08-30
- **WHEN** it renders with `de-DE`
- **THEN** it SHALL display `30.08.2026` and long form `30. August 2026` where used

#### Scenario: Language switch without restart
- **GIVEN** the user switches language from Deutsch to English while on `/rechnungen?status=offen`
- **WHEN** the locale changes
- **THEN** the current page, selected record, and filters SHALL be preserved and strings SHALL update without restart

### Requirement: Design Tokens

The system SHALL define tokens `AppSpacing` (xs 4/sm 8/md 12/lg 16/xl 24/xxl 32/xxxl 48), `AppRadius` (control 8/card 12/dialog 14), `AppDuration` (fast 120ms/normal 200ms/slow 240ms) per DESIGN.md §42 and consume them in all shell/components instead of scattering raw values.

#### Scenario: Shell uses tokens not raw values
- **GIVEN** the sidebar, card, and dialog are inspected
- **WHEN** their spacing/radius/duration are checked
- **THEN** they SHALL reference `AppSpacing.lg`/`AppRadius.card`/`AppDuration.normal` not literal 16/12/200 scattered

#### Scenario: Tokens lint
- **GIVEN** a new component is added with hard-coded `EdgeInsets.all(17)` or `BorderRadius.circular(13)` not from tokens
- **WHEN** review or lint runs
- **THEN** the deviation SHALL be flagged as a review finding

### Requirement: Semantic Accounting Colors

The system SHALL provide a `ThemeExtension<AccountingColors>` with distinct light/dark values for paid/overdue/draft/warning/income/expense per DESIGN.md §43, never overloading `primary`/`secondary`/`error` for every financial state, and every custom component SHALL define default/hover/pressed/focused/selected/disabled in both themes per §44.

#### Scenario: Status chip uses semantic colors with icon+text
- **GIVEN** a chip for “Überfällig” is rendered in light theme
- **WHEN** it resolves its color
- **THEN** it SHALL use `AccountingColors.overdue` (light red) with icon `!` and text, not `colorScheme.error` alone, and not rely on color alone per §7

#### Scenario: Hover state differs in dark theme
- **GIVEN** a sidebar item is hovered in dark theme
- **WHEN** its background is checked
- **THEN** it SHALL use the dark hover token (e.g., `#1D2129`) distinct from light hover `#F1F3F6`

#### Scenario: Missing ThemeExtension falls back safely
- **GIVEN** a widget requests `AccountingColors` but the extension is not provided
- **WHEN** it builds
- **THEN** it SHALL fall back to a default neutral color and not throw

### Requirement: Elevation, Borders and Radius Consistency

The system SHALL apply DESIGN.md §10: buttons/inputs 8 px, cards 12 px, menus 10 px, dialogs 14 px radius; 1 px subtle borders for tables/grouped forms; shadows only for menus/dialogs/command palette/inspector, not static dashboard cards.

#### Scenario: Card radius correct
- **GIVEN** a dashboard card renders
- **WHEN** its decoration is inspected
- **THEN** `borderRadius` SHALL be 12 px and shadow SHALL be null, using border + surface contrast

#### Scenario: Dialog radius and shadow
- **GIVEN** a dialog is shown
- **WHEN** its decoration is inspected
- **THEN** `borderRadius` SHALL be 14 px and a shadow SHALL be present
