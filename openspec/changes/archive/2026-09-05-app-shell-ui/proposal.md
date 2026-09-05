## Why

The current desktop build shows only a black canvas with "Setup Wizard" and the debug badge. There is no persistent navigation, no desktop shell, and no Material 3 theming. Freelancers need a calm, trustworthy desktop shell with a left navigation that stays visible, plus correct light/dark/System themes per DESIGN.md, before any feature work can be validated visually.

## What Changes

- **New**: Persistent desktop shell with left sidebar (240 px expanded at ≥1200 px, 72 px rail at 900–1199 px, overlay drawer <900 px), collapsible and persisted, with workspace selector at top and “● Lokal” trust indicator at bottom.
- **New**: Page header with title, subtitle/status, primary action on the right, tabs, and filter/search toolbar below, per DESIGN.md §5.
- **New**: Content canvas with max-width constraints (tables full width, forms 720–900 px, settings 900–1100 px), 4 px spacing scale, page padding 32/24/16, responsive grid, and optional 360–440 px inspector.
- **New**: Material 3 theming via `AppTheme` light/dark from seed `#4F46E5`, `ColorScheme.fromSeed`, `useMaterial3: true`, three modes System/Hell/Dunkel persisted, separate palettes for charts, explicit states for every custom component (default/hover/pressed/focused/selected/disabled).
- **New**: Typography Inter fallback, type scale, tabular financial numbers, locale `de-DE` number/date formatting, and accounting semantic `ThemeExtension` (bezahlt/überfällig/entwurf etc) not overloaded on primary/error.
- **Modified**: Existing `openinvoices` shell placeholder and `lib/main.dart` demo counter are replaced by the new shell. Setup guard remains but renders inside the shell layout, not a full-screen black canvas.

## Capabilities

### New Capabilities
- `app-shell`: Three-area shell (sidebar + header/toolbar + content canvas + optional inspector + transients), responsive breakpoints, window 1280×800 initial / 960×640 minimum, state persistence.
- `app-theme`: Material 3 light/dark/System themes, German/English localization, semantic accounting colors, design tokens (spacing, radius, duration).

### Modified Capabilities
- `app`: Existing app routing, setup guard, and navigation are moved into the new shell. The previous sidebar taxonomy (6 collapsible sections Fakturierung/Buchhaltung/Auswertung/Stammdaten/Einstellungen/Hilfsmittel with list-detail splitter) is superseded by DESIGN.md §4 ÜBERSICHT/GESCHÄFT/STEUERN flat structure via delta `specs/app/spec.md` (MODIFIED Layout Structure). No backend or DB contract changes.
- `setup`: Wizard content is re-hosted inside the shell's constrained width (720–900 px) and header pattern instead of a standalone black page. `l10n` source is consolidated to `assets/l10n/l10n_{de,en}.arb` with `l10n.yaml` template `l10n_de.arb` (not `lib/l10n/app_*.arb` duplicate).

## Impact

- **Code**: `lib/app/`, `lib/design_system/` (theme, tokens, components: `app_sidebar`, `app_page_header`, `app_page`, `app_inspector`), `assets/l10n/`, `lib/l10n/` generated, `lib/core/router` updated. No new backend dependencies; `flutter_localizations` + `intl` already required.
- **Theming**: `MaterialApp(theme/darkTheme/themeMode)` per DESIGN.md §8. Light `#F7F8FA`/`#FFFFFF`, dark `#101217`/`#171A21`, `AppSpacing`/`AppRadius`/`AppDuration` tokens.
- **Platform**: Windows/macOS/Linux desktop only, no mobile. Window size/position/sidebar state persisted where practical.
