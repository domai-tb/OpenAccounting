## ADDED Requirements

### Requirement: Optional modules have an explicit, validated business state

The system SHALL maintain enabled state for each known optional module in the active business profile. The module catalog SHALL identify whether a module is available and any required modules. Unknown, unavailable, or dependency-blocked modules SHALL NOT be enabled by a saved flag. Invalid or unreadable state SHALL resolve through the catalog's declared default and SHALL NOT delete or rewrite business records.

#### Scenario: Available module state is restored
- **GIVEN** a known module is available and enabled for the active business
- **WHEN** the application starts and loads module state
- **THEN** the module remains enabled and its saved state is unchanged

#### Scenario: Unknown or unavailable module cannot be enabled
- **GIVEN** saved state requests an unknown or unavailable module
- **WHEN** the application resolves module availability
- **THEN** the module is treated as disabled and no module action can mutate its records

### Requirement: Disabling a module hides its entry points without deleting data

The system SHALL apply module state consistently to sidebar navigation, dashboard widgets and quick links, and module-specific create actions. Disabling a module SHALL preserve its database records and files. A direct route or stale shortcut into a disabled module SHALL show a localized unavailable state and SHALL NOT perform a write.

#### Scenario: Module is disabled while it has existing records
- **GIVEN** an enabled module has business records
- **WHEN** the user disables the module in Settings
- **THEN** its navigation, dashboard widgets, shortcuts, and create actions are hidden or disabled, its existing records remain byte-for-byte unchanged, and the updated state is visible without restarting the app

#### Scenario: Direct navigation reaches a safe unavailable state
- **GIVEN** a module is disabled and an old deep link points to one of its routes
- **WHEN** the route is opened
- **THEN** the application displays a localized unavailable state and performs no database write

### Requirement: Module controls follow the Settings and accessibility design

The module controls SHALL be available from the Settings workspace and use the shared desktop design system. Every module name, status, explanation, and failure state SHALL be localized in German and English. Controls SHALL support keyboard navigation, visible focus, screen-reader labels, and text scaling without clipping.

#### Scenario: User changes a supported module
- **GIVEN** the user can reach the module section in Settings
- **WHEN** the user enables or disables an available module using keyboard or pointer input
- **THEN** the persisted setting changes, the affected entry points update, and an accessible localized status confirms the result

#### Scenario: Module setting cannot be saved
- **GIVEN** persistence fails while the user changes a module
- **WHEN** the save operation returns an error
- **THEN** the previous enabled state remains in effect and a localized retryable error is announced
