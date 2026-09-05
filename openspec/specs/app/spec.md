# OpenInvoices — Core Application Specification

## ADDED Requirements

### Requirement: Application Routing

The application SHALL implement named route navigation with 40+ routes supporting URL parameters, nested navigation, and a setup guard that redirects unconfigured instances to the initial setup wizard.

#### Scenario: Setup Guard Redirects Unconfigured App

GIVEN no `Unternehmen` record exists in the database
WHEN the user launches the app for the first time
THEN the app SHALL navigate to `/setup` regardless of the initial deep link or URL
AND no other route SHALL be accessible until setup completes

#### Scenario: Setup Guard Does Not Intercept Configured App

GIVEN an `Unternehmen` record exists in the database
WHEN the user launches the app
THEN the app SHALL navigate to the default route or deep link target
AND the setup wizard SHALL NOT be shown

#### Scenario: Nested Navigation Within Sections

GIVEN the user is authenticated and the app is fully configured
WHEN the user navigates to `/rechnungen/123`
THEN the sidebar SHALL highlight "Rechnungen"
AND the detail panel SHALL display the document with ID 123
AND the browser-style URL SHALL reflect `/rechnungen/123`

#### Scenario: Nested Navigation With Invalid ID

GIVEN no document with ID 99999 exists
WHEN the user navigates to `/rechnungen/99999`
THEN the detail panel SHALL display a "not found" state
AND the sidebar SHALL still highlight the correct section

#### Scenario: Deep Link With Query Parameters

GIVEN the user is on any page
WHEN the user opens `/rechnungen?typ=eingang&status=offen`
THEN the list SHALL filter to incoming invoices with open status
AND the filter state SHALL persist across navigation within the section

### Requirement: State Management

The application SHALL use Riverpod 2.x for state management with automatic caching, provider invalidation, and optimistic updates for all mutable operations.

#### Scenario: Provider Caching

GIVEN the user has loaded the Kunden list once
WHEN the user navigates away and back within 5 minutes
THEN the previously fetched customer data SHALL be served from cache
AND no redundant API call SHALL be made

#### Scenario: Provider Cache Expiry

GIVEN the user has loaded the Kunden list more than 5 minutes ago
WHEN the user navigates back to the Kunden list
THEN fresh data SHALL be fetched from the backend
AND the stale cache SHALL be discarded

#### Scenario: Optimistic Update Rollback

GIVEN an invoice is currently marked as unpaid
WHEN the user marks the invoice as paid
AND the backend returns a 422 error within 3 seconds
THEN the UI SHALL revert to the previous unpaid state
AND an error snackbar SHALL display the backend error message

#### Scenario: Optimistic Update Success

GIVEN an invoice is currently marked as unpaid
WHEN the user marks the invoice as paid
AND the backend returns HTTP 200
THEN the invoice SHALL remain in paid state
AND no rollback SHALL occur

#### Scenario: Provider Invalidation After Mutation

GIVEN the customer list provider is cached
WHEN the user creates a new customer
THEN all `kunden`-related providers SHALL be invalidated
AND the customer list SHALL refetch automatically

### Requirement: Theme and Language

The application SHALL support Dark, Light, and System-follow theme modes. All user-facing text SHALL be in German using informal "Du"-Ansprache. Theme preferences SHALL persist across sessions.

#### Scenario: Theme Mode Switching

GIVEN the user is on Light mode
WHEN the user switches to Dark mode in Einstellungen
THEN all UI elements SHALL immediately reflect the dark theme
AND the preference SHALL persist after app restart

#### Scenario: Theme Persistence Failure

GIVEN the user switches to Dark mode
WHEN the SharedPreferences store is unavailable
THEN the app SHALL apply Dark mode for the current session
AND SHALL NOT crash or throw an error

#### Scenario: System Theme Follow

GIVEN the user has selected "System" as theme mode
WHEN the OS switches from light to dark
THEN the app theme SHALL follow the system setting within 1 second

#### Scenario: System Theme Follow Does Not Trigger When Manual

GIVEN the user has selected "Dark" as theme mode (not "System")
WHEN the OS switches from light to dark
THEN the app theme SHALL remain Dark and not flicker

#### Scenario: German Du-Ansprache Enforcement

GIVEN any UI text is rendered
WHEN a label, message, or confirmation is displayed
THEN it SHALL use "Du" form
AND no "Sie" form SHALL appear in any user-facing string

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

### Requirement: Error Handling

The application SHALL map validation failures from local repositories or enabled integrations to field-level errors inline. An unavailable optional integration SHALL produce a scoped, recoverable error without blocking local-first accounting workflows.

#### Scenario: 422 Validation Error Display

GIVEN the user has filled out a form
WHEN the user submits the form
AND the active data source returns a validation error with a JSON body containing field errors
THEN each field error SHALL appear beneath the corresponding form field
AND the form SHALL NOT submit again until all errors are resolved

#### Scenario: 422 Validation Error With Multiple Fields

GIVEN the user has submitted a form with errors in three fields
WHEN the active data source returns HTTP 422
THEN all three field errors SHALL display simultaneously
AND the form SHALL remain open for correction

#### Scenario: Optional Integration Unavailable

GIVEN an enabled optional integration has failed after its permitted retry attempts
WHEN the app renders the connection state
THEN a scoped message SHALL display that the optional integration is unavailable
AND the message SHALL include a "Erneut versuchen" button
AND local data and local-first workflows SHALL remain available

#### Scenario: Optional Integration Recovery

GIVEN the app is showing an optional-integration-unavailable message
WHEN the user clicks "Erneut versuchen"
AND the integration is now reachable
THEN the app SHALL dismiss the error screen
AND navigate to the previously requested route
### Requirement: Keyboard Shortcuts

The application SHALL support the following global keyboard shortcuts: Ctrl+F (focus search), Ctrl+Shift+E (navigate to Eingangsrechnungen), + (open new Buchung dialog in Journal), and E/A (toggle Einnahme/Ausgabe in Buchung form). A global zoom shortcut SHALL adjust the app scale factor.

#### Scenario: Ctrl+F Focuses Search

GIVEN the user is on any page with a search input
WHEN the user presses Ctrl+F
THEN the search input on the current page SHALL receive focus

#### Scenario: Ctrl+F No Search Input Exists

GIVEN the user is on a page without a search input
WHEN the user presses Ctrl+F
THEN no action SHALL occur
AND no error SHALL be displayed

#### Scenario: Ctrl+Shift+E Navigates to Eingangsrechnungen

GIVEN the user is on any page
WHEN the user presses Ctrl+Shift+E
THEN the app SHALL navigate to `/rechnungen?typ=eingang`
AND the search input SHALL receive focus

#### Scenario: Plus Key Opens Buchung Dialog

GIVEN the user is on the Journal page
AND no input field is focused
AND no dialog is open
WHEN the user presses `+`
THEN the "Neue Buchung" dialog SHALL open

#### Scenario: Plus Key Ignored When Input Focused

GIVEN an input field is focused
WHEN the user presses `+`
THEN the `+` character SHALL be inserted into the input field
AND no dialog SHALL open

#### Scenario: E/A Toggles Art in Buchung Form

GIVEN the "Neue Buchung" dialog is open
AND no input field is focused
AND no modifier key is held
WHEN the user presses `E` or `A`
THEN the art field SHALL toggle between "Einnahme" and "Ausgabe"

#### Scenario: E/A Ignored When Input Focused

GIVEN the "Neue Buchung" dialog is open
AND an input field is focused
WHEN the user presses `E`
THEN the `E` character SHALL be inserted into the input field
AND the art field SHALL NOT toggle

#### Scenario: Global Zoom

GIVEN the app is running
WHEN the user presses Ctrl+= (zoom in)
THEN the app scale factor SHALL increment by 10%
AND the scale factor SHALL persist across sessions

#### Scenario: Global Zoom Out

GIVEN the app is running
WHEN the user presses Ctrl+- (zoom out)
THEN the app scale factor SHALL decrement by 10%
AND the scale factor SHALL persist across sessions

### Requirement: Form Validation

All forms SHALL validate required fields, German PLZ format (5 digits for DE, country-specific for others), USt-IdNr format (DE followed by 9 digits, or EU country prefix + format), and monetary values (NUMERIC(12,2), no floats).

#### Scenario: PLZ Country-Specific Validation

GIVEN the user has selected country "DE"
WHEN the user enters a PLZ that is not exactly 5 digits
THEN a validation error SHALL display: "PLZ muss 5 Ziffern haben"

#### Scenario: PLZ Valid German Format

GIVEN the user has selected country "DE"
WHEN the user enters "10115" as PLZ
THEN no validation error SHALL appear for the PLZ field

#### Scenario: USt-IdNr EU Format Validation

GIVEN the user enters a USt-IdNr starting with "AT"
WHEN the value is validated
THEN the app SHALL validate against the Austrian USt-IdNr format
AND display a format error if it does not match the expected pattern

#### Scenario: USt-IdNr DE Format Validation

GIVEN the user enters a USt-IdNr starting with "DE"
WHEN the value does not match `DE` followed by 9 digits
THEN a validation error SHALL display indicating invalid format

#### Scenario: Monetary Value Validation

GIVEN a form contains a monetary input field
WHEN the user enters "1234.567"
THEN the form SHALL reject the value with error: "Betrag darf maximal 2 Dezimalstellen haben"

#### Scenario: Monetary Value Valid Input

GIVEN a form contains a monetary input field
WHEN the user enters "1234.56"
THEN no validation error SHALL appear for the monetary field

### Requirement: API Client

The application MAY use Dio for optional network data sources only. Core local-first workflows SHALL NOT depend on a backend, localhost port scanning, periodic health polling, or backend authentication. Automatic retries SHALL use exponential backoff for idempotent requests such as GET. A retryable finalization, payment, or other transactional mutation MUST carry a unique idempotency key, and the receiving data source MUST deduplicate that key.

#### Scenario: Configured Optional Endpoint

GIVEN the user has enabled an optional network integration with a configured endpoint
WHEN the integration is used
THEN the client SHALL connect only to that configured endpoint
AND local-first workflows SHALL remain independent of its availability

#### Scenario: Optional Integration Unavailable at Startup

GIVEN an enabled optional network integration cannot reach its configured endpoint
WHEN the app starts
THEN the app SHALL report the integration as unavailable
AND the app SHALL remain usable in local-first mode

#### Scenario: Retry on Transient Failure

GIVEN a GET request to an optional integration
WHEN the request fails with a network timeout
THEN the client SHALL retry up to 3 times with exponential backoff
AND display a loading indicator during retries

#### Scenario: Retry Exhausted

GIVEN an idempotent GET request fails 3 consecutive times
WHEN the third retry fails
THEN the client SHALL stop retrying
AND a scoped integration error SHALL be displayed

#### Scenario: Optional Integration Recovery Polling

GIVEN an enabled optional integration is unavailable
WHEN the app performs a permitted recovery check
THEN it MAY check the configured endpoint
AND when the integration responds again, refresh the affected view
### Requirement: Local Storage

User preferences including theme mode, sidebar state, zoom factor, and last-used filters SHALL persist in SharedPreferences.

#### Scenario: Preference Persistence

GIVEN the user sets zoom to 120%
WHEN the user closes and reopens the app
THEN the zoom factor SHALL remain at 120%

#### Scenario: Preference Corruption Recovery

GIVEN SharedPreferences contains corrupted data
WHEN the app reads preferences on startup
THEN the app SHALL use default values
AND SHALL NOT crash or display an error

### Requirement: Version Display

The application version (derived from Git tags) SHALL be displayed in the sidebar footer and in the "Über" dialog.

#### Scenario: Sidebar Version Display

GIVEN the app is running version v1.2.3
WHEN the app renders the sidebar
THEN the version string SHALL appear at the bottom of the sidebar
AND the format SHALL be "v1.2.3"

#### Scenario: Über Dialog Version Display

GIVEN the app is running version v1.2.3
WHEN the user opens the "Über" dialog
THEN the version string "v1.2.3" SHALL be displayed

### Requirement: Print and Export

The application SHALL support inline PDF display via a dedicated PDF viewer window. CSV and ZIP exports SHALL trigger a native save-file dialog.

#### Scenario: Inline PDF Display

GIVEN a finalized invoice exists
WHEN the user clicks "PDF anzeigen"
THEN a PDF viewer window SHALL open displaying the document inline
AND the Content-Disposition SHALL be "inline"

#### Scenario: PDF Display With Missing Document

GIVEN no PDF has been generated for the selected invoice
WHEN the user clicks "PDF anzeigen"
THEN the app SHALL display an error message: "PDF nicht verfügbar"
AND no viewer window SHALL open

#### Scenario: CSV Export Save Dialog

GIVEN the user is on the Journal list
WHEN the user clicks "CSV exportieren"
THEN a native file save dialog SHALL appear
AND the default filename SHALL include the current date in YYYY-MM-DD format

#### Scenario: CSV Export Cancelled

GIVEN the save dialog is open
WHEN the user clicks "Abbrechen"
THEN no file SHALL be written
AND the dialog SHALL close without error

#### Scenario: ZIP Export Save Dialog

GIVEN the user has selected multiple documents
WHEN the user clicks "ZIP exportieren"
THEN a native file save dialog SHALL appear
AND the ZIP SHALL contain one PDF per selected document
