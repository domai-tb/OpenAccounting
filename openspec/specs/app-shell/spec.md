# app-shell

## Purpose
Purpose for app-shell - desktop shell and theming per DESIGN.

## Requirements

### Requirement: Desktop Shell Layout

The system SHALL render a stable three-area desktop shell with sidebar, header/toolbar, content canvas, optional inspector, and transient overlays per DESIGN.md §3. The shell SHALL be the persistent container for every primary page and SHALL not be replaced by a full-screen black canvas. The existing `app-shell` capability SHALL remain the single owner of this behavior, and regression coverage SHALL live in the general app shell test suite.

#### Scenario: Shell renders on every primary route
- **GIVEN** the app is launched and the shell is mounted
- **WHEN** the user navigates to `/`, `/invoices`, `/receipts`, `/taxes`, or `/settings`
- **THEN** the sidebar, header, and content canvas SHALL all be present and the header SHALL show the correct page title

#### Scenario: Shell does not render as black full-screen fallback
- **GIVEN** the database is empty and the setup guard redirects to `/setup`
- **WHEN** the setup page renders inside the shell
- **THEN** the page SHALL be constrained to 720–900 px width with DESIGN.md spacing and SHALL show the sidebar and header, not a black `Container`

### Requirement: Sidebar Navigation

The sidebar SHALL be persistent, 240 px expanded at ≥1200 px, 72 px rail at 900–1199 px (icons only with tooltip, click to expand temporarily), and an overlay drawer at <900 px per DESIGN.md §4. It SHALL contain the workspace selector at top, sections ÜBERSICHT/GESCHÄFT/STEUERN, Settings/Hilfe pinned at bottom, and the “● Lokal” trust indicator.

#### Scenario: Expanded sidebar at wide window
- **GIVEN** the window width is 1280 px
- **WHEN** the shell renders
- **THEN** the sidebar SHALL be 240 px wide, show icon + label + section labels, and highlight the active destination unmistakably in both themes

#### Scenario: Compact rail at medium window
- **GIVEN** the window width is 1024 px
- **WHEN** the shell renders
- **THEN** the sidebar SHALL be 72 px wide, show icons only, show tooltip on hover, and allow temporary expand via menu control

#### Scenario: Drawer at narrow window
- **GIVEN** the window width is 800 px
- **WHEN** the shell renders
- **THEN** the sidebar SHALL be an overlay drawer and content SHALL receive full width

#### Scenario: Sidebar collapses and persists
- **GIVEN** the sidebar is expanded
- **WHEN** the user toggles collapse and restarts the app
- **THEN** the collapsed state SHALL be restored from persisted preferences

#### Scenario: Sidebar navigation highlights correctly
- **GIVEN** the user navigates to `/rechnungen?status=offen`
- **WHEN** the route resolves
- **THEN** the “Rechnungen” item SHALL be selected and keyboard focus SHALL be reachable via Tab

### Requirement: Page Header

Every primary page SHALL use a consistent header per DESIGN.md §5 with title, optional subtitle/status, primary action on the right, tabs when siblings exist, and a filter/search toolbar below. One primary action per page SHALL be visually dominant.

#### Scenario: Header shows title and primary action
- **GIVEN** the user is on `/rechnungen`
- **WHEN** the page loads
- **THEN** the header SHALL show “Rechnungen” and a dominant “Neue Rechnung” button on the right

#### Scenario: Header filter toolbar present
- **GIVEN** the user is on a data-heavy page
- **WHEN** the page renders
- **THEN** a search field and filter controls SHALL be visible below the title and active filters SHALL appear as removable chips with result count

#### Scenario: Header without primary action still renders subtitle
- **GIVEN** a page has no primary action but has a status subtitle
- **WHEN** it renders
- **THEN** the subtitle SHALL be visible and layout SHALL not collapse

### Requirement: Content Canvas and Layout Constraints

The content canvas SHALL enforce DESIGN.md §6 spacing (4 px grid), page padding 32 px normal / 24 px compact / 16 px small, and width constraints: tables may use full width, forms 720–900 px, settings 900–1100 px, help text 720 px. Dashboard and card layouts SHALL respond to window width, not device type, on a 12-column grid.

#### Scenario: Form width constrained on ultrawide
- **GIVEN** the window width is 1920 px
- **WHEN** a form page renders
- **THEN** the form content SHALL be capped at 900 px centered and SHALL NOT stretch arbitrarily

#### Scenario: Page padding adapts to window size
- **GIVEN** the window is 1000 px wide (compact) vs 1400 px (normal)
- **WHEN** the page renders
- **THEN** padding SHALL be 24 px in compact and 32 px in normal

#### Scenario: Table uses full width
- **GIVEN** a table page is rendered at 1400 px
- **WHEN** the table loads
- **THEN** the table SHALL span the available content width minus padding

### Requirement: Optional Inspector

The shell SHALL provide an optional 360–440 px right-side inspector per DESIGN.md §14 for quick record review without full navigation. It SHALL handle close (Esc), focus trap, and overlay at narrow widths.

#### Scenario: Inspector opens on row selection
- **GIVEN** the user selects a row in the table
- **WHEN** the inspector is enabled
- **THEN** the inspector SHALL slide in at 400 px, show the record, and close on Esc

#### Scenario: Inspector adapts at narrow width
- **GIVEN** the window width is 900 px
- **WHEN** the inspector opens
- **THEN** it SHALL appear as an overlay, not as a side panel that squeezes content below 960 px minimum

### Requirement: Window Behavior

The app SHALL support initial size 1280×800, minimum 960×640, and persist window size/position/maximized/sidebar state where practical per DESIGN.md §35. It SHALL adapt rather than overflow below minimum and SHALL not restore off-screen positions.

#### Scenario: Window respects minimum size
- **GIVEN** the user attempts to resize to 800×500
- **WHEN** the resize occurs
- **THEN** the window SHALL clamp to 960×640 and adapt layout to drawer mode

#### Scenario: Window state persists
- **GIVEN** the user resizes to 1400×900 and maximizes
- **WHEN** the app restarts on the same display
- **THEN** the previous size and maximized state SHALL be restored
