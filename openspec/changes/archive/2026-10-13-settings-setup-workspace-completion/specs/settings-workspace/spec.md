## ADDED Requirements

### Requirement: Settings provides a designed, reachable capability index

The `/settings` route SHALL render a localized full-page workspace with constrained content width and section navigation aligned with `DESIGN.md` §19 and the shared `localized-accessible-surface` contract. It SHALL include the supported Allgemein, Unternehmen, Steuern, Rechnungen, Bank & Integrationen, Daten & Datenschutz, Sicherung, Darstellung, Sprache & Region, Erweitert, and Über destinations. Company, account, tax-rate, number-range, and report/export actions SHALL navigate to their owning production workspaces; Settings SHALL NOT duplicate their forms or calculations. Unsupported features SHALL NOT be presented as working controls. Every visible action SHALL be keyboard-operable, have a localized accessible name, visible focus, deterministic focus order, preserve the current route when a preference changes, and report the result of the action it invokes. At narrow supported widths and increased text scaling, all sections and actions SHALL remain reachable by keyboard and scrolling without horizontal clipping or overlap. Backup status SHALL distinguish never completed, current, stale, and failed states using the operation time and outcome returned by the backup service.

#### Scenario: User opens an available Settings section

- **GIVEN** the user is on a supported desktop width and `/settings` is open
- **WHEN** the user selects Sicherung from the section navigation
- **THEN** the Sicherung section SHALL become the current section, retain the `/settings` route, and expose the backup actions owned by the existing backup capability

#### Scenario: A section owner is unavailable

- **GIVEN** a linked section owner is not registered or returns an unavailable result
- **WHEN** the user selects that section
- **THEN** Settings SHALL show a localized unavailable/error state with no raw database table fallback and SHALL NOT report the action as successful

#### Scenario: Settings stays accessible at narrow width and larger text scale

- **GIVEN** Settings is open at the narrowest supported desktop width with text scaling enabled
- **WHEN** the user traverses the section navigation and all visible controls by keyboard
- **THEN** focus SHALL remain visible and deterministic, every action SHALL be reachable without horizontal clipping or overlap, and the current section SHALL remain identifiable

### Requirement: Settings profile actions follow the canonical profile contract

The profile section SHALL be reachable under Allgemein in Settings and SHALL expose the profile name, database size, last-modified time, create, rename, select, and confirmed non-destructive removal actions required by `profiles`. It SHALL use the injected profile-management boundary and display only profiles in the validated registered catalog. Removal SHALL update the profile registry while retaining the profile directory and database; the application SHALL NOT infer or perform permanent data erasure. Switching to another profile SHALL persist the active selection and clearly state that restart is required before the new profile becomes active.

#### Scenario: Profile changes show canonical outcomes

- **GIVEN** two valid profiles exist and the Settings profile section is loaded
- **WHEN** the user creates or renames a profile, selects another profile, or confirms removal of an eligible inactive profile
- **THEN** the profile list SHALL reflect the manager result, selection SHALL show a restart-required state, and removal SHALL leave the removed profile's files unchanged on disk

#### Scenario: Unsafe or failed profile action is rejected

- **GIVEN** a profile action targets the active or last profile, uses an invalid/duplicate name, or the manager operation fails
- **WHEN** the user submits or confirms that action
- **THEN** Settings SHALL keep the persisted profile state unchanged and display a localized actionable error

### Requirement: Backup settings expose completed local-first operations

The Sicherung section SHALL expose supported manual and scheduled backup preferences, local backup creation, eligible external backup targets, and local/encrypted restore through the existing backup capability. Scheduling SHALL be profile-scoped, default to `manual-only`, and offer only daily or weekly automatic local backups. It SHALL show the most recent operation's actual completion time, target, and outcome, and SHALL keep local backups below the active profile's canonical data directory. External paths SHALL follow the explicit opt-in and safety rules in `backup`. A confirmed restore SHALL be validated and staged while the app is live, then block writes and require exit/restart; the next startup SHALL apply it before opening the database. Settings SHALL report restore success only after the restarted application validates the restored database. The UI SHALL NOT claim scheduling, history, encryption, or network success merely because preferences were saved.

#### Scenario: Successful local backup is visible

- **GIVEN** the active profile database is available and its backup directory is writable
- **WHEN** the user selects Jetzt sichern and the backup service completes
- **THEN** Settings SHALL show the actual profile-local backup path and successful operation time

#### Scenario: Backup or restore fails

- **GIVEN** a selected target is unsafe, unavailable, invalid, or a restore artifact fails validation
- **WHEN** the operation is attempted
- **THEN** Settings SHALL show a localized failure tied to the attempted operation and the active database SHALL remain unchanged after a failed restore

#### Scenario: Backup history status distinguishes never, current, stale, and failed

- **GIVEN** the backup service reports no prior success, a recent success, an overdue success, or a failed latest attempt
- **WHEN** the Sicherung section renders its status
- **THEN** it SHALL distinguish never completed, current, stale, and failed, and SHALL show the actual timestamp and outcome when available

### Requirement: Settings never overstates data portability or erasure

The Daten & Datenschutz section SHALL identify the actual local profile data location and expose only export operations defined by an accepted OpenSpec capability. It SHALL NOT offer permanent profile/accounting-data deletion until a retention and erasure policy is approved and specified. Profile removal SHALL remain the non-destructive registry action required by `profiles`; no automatic cleanup of retained profile files SHALL be inferred from that action.

#### Scenario: Supported export is distinguished from a full data dump

- **GIVEN** an export action is available through an implemented owning capability
- **WHEN** the user opens Daten & Datenschutz
- **THEN** Settings SHALL identify the owning export and its real scope and SHALL NOT label it as a complete account/profile export unless it includes that scope

#### Scenario: Erasure policy is unresolved

- **GIVEN** no approved data-retention and erasure policy exists
- **WHEN** the user opens Daten & Datenschutz or removes an eligible profile
- **THEN** no permanent erase action SHALL be available and profile data SHALL remain on disk after registry removal
