# Change: localized-accessible-surface-completion

This delta reconciles the stale base application language requirement with the approved German-primary/English-secondary contract described in `proposal.md` and the `localized-accessible-surface` delta. Theme behavior, persistence, and product policy are unchanged; only the language contract wording is updated.

## MODIFIED Requirements

### Requirement: Theme and Language

The application SHALL support Dark, Light, and System-follow theme modes. The application language contract SHALL be German-primary and English-secondary: German SHALL remain the initial locale, German copy SHALL preserve informal `Du` wording, and every production-visible label, action, tooltip, heading, dialog, loading message, empty message, error message, date, number, currency value, and accessibility label SHALL also be available in English with equal ARB key sets in both catalogs. All user-facing text SHALL be available in German and English using the active locale. Theme preferences SHALL persist across sessions.

#### Scenario: Theme Mode Switching
- **GIVEN** the user is on Light mode
- **WHEN** the user switches to Dark mode in Einstellungen
- **THEN** all UI elements SHALL immediately reflect the dark theme
- **AND** the preference SHALL persist after app restart

#### Scenario: Theme Persistence Failure
- **GIVEN** the user switches to Dark mode
- **WHEN** the SharedPreferences store is unavailable
- **THEN** the app SHALL apply Dark mode for the current session
- **AND** SHALL NOT crash or throw an error

#### Scenario: System Theme Follow
- **GIVEN** the user has selected "System" as theme mode
- **WHEN** the OS switches from light to dark
- **THEN** the app theme SHALL follow the system setting within 1 second

#### Scenario: System Theme Follow Does Not Trigger When Manual
- **GIVEN** the user has selected "Dark" as theme mode (not "System")
- **WHEN** the OS switches from light to dark
- **THEN** the app theme SHALL remain Dark and not flicker

#### Scenario: Active Locale Copy Enforcement
- **GIVEN** any UI text is rendered
- **WHEN** a label, message, or confirmation is displayed
- **THEN** it SHALL come from the active German or English catalog
- **AND** no unkeyed production literal SHALL appear in a user-facing surface

#### Scenario: German Primary Informal Wording
- **GIVEN** the active locale is German
- **WHEN** production copy renders
- **THEN** it SHALL use informal `Du` wording and SHALL remain the initial application locale

#### Scenario: English Secondary Catalog Parity
- **GIVEN** the active locale is English
- **WHEN** any documented route renders its production states
- **THEN** every visible string SHALL resolve from the English catalog and the German and English ARB catalogs SHALL expose the same key set
