## MODIFIED Requirements

### Requirement: Layout Structure

The application SHALL use a persistent left sidebar per DESIGN.md §4 supplemented by the shell in `app-shell`. The sidebar SHALL be 240 px expanded at ≥1200 px, 72 px rail at 900–1199 px (icons only with tooltip, temporary expand), and overlay drawer at <900 px. The taxonomy SHALL be ÜBERSICHT (Übersicht) / GESCHÄFT (Rechnungen, Belege, Bank & Zahlungen, Kontakte) / STEUERN (Steuern, Auswertungen) / Einstellungen/Hilfe pinned, with workspace selector at top and “● Lokal” indicator at bottom, replacing the previous 6 collapsible sections (Fakturierung/Buchhaltung/Auswertung/Stammdaten/Einstellungen/Hilfsmittel) which are superseded by this change.

#### Scenario: Sidebar taxonomy supersedes old sections
- **GIVEN** the new shell is mounted
- **WHEN** the sidebar renders
- **THEN** it SHALL show ÜBERSICHT/GESCHÄFT/STEUERN groups not the old 6 sections, and no test SHALL expect the old Fakturierung/Buchhaltung collapsible groups

#### Scenario: Old layout tests are retired
- **GIVEN** a test asserts the old list-detail splitter with 240/480 minima from the previous spec
- **WHEN** the new shell runs
- **THEN** that test SHALL be updated or removed, and the new spec's sidebar/header/canvas scenarios SHALL be the source of truth

#### Scenario: Deep link still highlights correct section
- **GIVEN** the user opens `/rechnungen?status=offen` under the new taxonomy
- **WHEN** the route resolves
- **THEN** GESCHÄFT → Rechnungen SHALL be highlighted, preserving deep-link behavior from the previous spec
