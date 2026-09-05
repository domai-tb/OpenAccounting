## MODIFIED Requirements

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
