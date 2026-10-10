# localized-accessible-surface Specification

## Purpose
TBD - created by archiving change adaptive-shell-and-state-surfaces. Update Purpose after archive.

## Requirements

### Requirement: Locale-complete visible UI

Every production-visible label, action, tooltip, heading, dialog, loading message, empty message, error message, date, number, currency value, and accessibility label SHALL use an ARB key and the active locale. Both German (`de`) and English (`en`) SHALL provide the same required key set. A supported locale SHALL never expose an unrelated hardcoded German literal when English is active.

#### Scenario: English state copy is complete
- **GIVEN** the active locale is English
- **WHEN** each documented route renders loading, data, empty, and error states
- **THEN** every visible message, action, tooltip, dialog, heading, and accessibility label SHALL be English and SHALL resolve through the English generated localization catalog

#### Scenario: German production state copy is complete
- **GIVEN** the active locale is German
- **WHEN** each documented route renders loading, data, empty, and error states
- **THEN** every visible message, action, tooltip, dialog, heading, and accessibility label SHALL be German and SHALL resolve through the German generated localization catalog

#### Scenario: Locale formats accounting values
- **GIVEN** the active locale is English and a route contains a date, decimal amount, and currency
- **WHEN** the data state renders
- **THEN** the date, decimal separator, currency symbol, and accessible text SHALL use the active locale formatter rather than a hardcoded German format

#### Scenario: Missing translation fails validation
- **GIVEN** a touched production widget introduces a visible string without an ARB key, or `openspec/specs/app/spec.md` still asserts that all user-facing text is German-only
- **WHEN** localization validation runs
- **THEN** the validation SHALL fail with the source location, missing-key name, or stale app-spec requirement before the change can be accepted

### Requirement: Accessible keyboard and semantics contract

Interactive controls SHALL expose a localized semantic role, name, and state, visible focus in both themes, and a keyboard activation path equivalent to pointer activation. Navigation destinations, buttons, text fields, overflow menus, and dialogs SHALL have deterministic traversal order and Enter/Space or platform-equivalent activation. Narrow layouts SHALL keep all actions reachable.

#### Scenario: Focused navigation activates
- **GIVEN** focus is on a compact sidebar destination
- **WHEN** the user presses Enter or Space
- **THEN** the destination SHALL activate, announce its selected state, and preserve visible focus

#### Scenario: Narrow action remains reachable
- **GIVEN** the viewport is 320 logical pixels wide
- **WHEN** secondary actions collapse into overflow
- **THEN** every action SHALL remain reachable by keyboard and semantics without clipping or overlap

#### Scenario: Focus semantics survive state settling
- **GIVEN** focus is on a search field or action while a route transitions from loading to data or error
- **WHEN** the state settles
- **THEN** the focused control SHALL retain its semantic name and focus ring where it still exists, or focus SHALL move to the route heading with an announced localized state

### Requirement: Active-locale accounting formatting

Money, decimal, short-date, long-date, and semantic amount formatting SHALL receive the active locale from the production widget context or an equivalent explicit locale boundary. This contract covers `AppTypography.formatMoney`, `AppTypography.formatDate`, `AppTypography.formatDateLong`, the `app_money.dart` helpers and `MoneyText`, shared surfaces such as `finance_list_surface.dart`, and page/service formatter paths used by bank import, invoice/document, PDF, and other visible route states. Formatting helpers and shared amount widgets MUST NOT silently default production output to `de_DE` when English is active.

#### Scenario: Active locale formats accounting values
- **GIVEN** English is active and a route contains `1284.32 EUR` and a date of `2026-08-30`
- **WHEN** the route renders the amount, short date, long date, and semantic label through shared helpers and `AppTypography` paths
- **THEN** the output SHALL use English separators, month names, and localized accessibility text

#### Scenario: German locale remains stable
- **GIVEN** German is active for the same accounting values
- **WHEN** the route renders the amount, short date, long date, and semantic label
- **THEN** the output SHALL use German separators, month names, and localized accessibility text

#### Scenario: Hardcoded German formatting fails English smoke
- **GIVEN** English is active
- **WHEN** a production route or shared/page formatter path renders an amount, date, or accessibility label using a German-only default
- **THEN** the route smoke and active-locale source guard SHALL fail and identify the unlocalized formatter, call site, or semantic text

### Requirement: Live locale switching preserves navigation context

Changing between the supported locales SHALL update visible production copy without an application restart and SHALL preserve the current route, query parameters, search text, selected tab, and filter state. Persisting the selected locale SHALL be best effort and SHALL not make the current session unusable.

#### Scenario: Locale switch preserves route and filters
- **GIVEN** a production route has a query, search value, and active filter
- **WHEN** the user selects the other supported locale from the real settings control
- **THEN** visible copy SHALL update in place and the router location, query, search value, selected tab, and filter SHALL remain unchanged

#### Scenario: Unsupported persisted locale falls back safely
- **GIVEN** persisted settings contain an unsupported locale code
- **WHEN** the application starts
- **THEN** the application SHALL choose the documented German fallback, render the German catalog, and leave the route usable without exposing a partial or mixed catalog

### Requirement: German and English application language contract

The application SHALL support German as the primary locale and English as the secondary locale. The selected locale SHALL persist across restart when storage is available. The stale German-only wording in `openspec/specs/app/spec.md` is superseded by this two-locale requirement; informal German wording remains applicable to German translations.

#### Scenario: English selection persists across restart
- **GIVEN** the user selects English in the production settings route
- **WHEN** the application is rebuilt with the persisted preference
- **THEN** the root app locale SHALL be English and the first rendered production route SHALL use English catalog values

#### Scenario: Locale persistence failure keeps the session usable
- **GIVEN** the user selects English and the preference store rejects the write
- **WHEN** the locale change completes
- **THEN** the current session SHALL remain English and SHALL not throw an uncaught error or reset the active route

### Requirement: Production route and ARB parity coverage

The localization change SHALL cover the documented production routes `/`, `/settings`, `/banking`, `/invoices`, `/receipts`, `/contacts`, `/taxes`, `/reports`, `/help`, `/setup`, and `/inventory`, including their loading, data, empty, error, dialog, action, and tooltip states where those states exist. The `/setup` route SHALL cover its wizard steps and validation/unavailable states; `/inventory` SHALL cover its truthful localized unavailable/read-only/retry boundary without a generic data fallback. The German and English ARB key sets SHALL be equal, and a required route-state key check SHALL fail before generated localization output is accepted when a required key is absent.

#### Scenario: Documented routes expose both locale catalogs
- **GIVEN** the production app is mounted with each supported locale
- **WHEN** `/`, `/settings`, `/banking`, `/invoices`, `/receipts`, `/contacts`, `/taxes`, `/reports`, `/help`, `/setup`, and `/inventory` render their representative data and state fixtures
- **THEN** every route SHALL expose the expected localized action and state strings; `/setup` SHALL assert wizard failure and completion states; `/inventory` SHALL assert unavailable, read-only, and retry states; and the two ARB key sets SHALL be equal

#### Scenario: Missing required route-state key fails parity check
- **GIVEN** a required route-state key is present in one ARB file but absent in the other
- **WHEN** the parity and required-key check runs
- **THEN** the check SHALL fail with the locale and key that are missing

### Requirement: Localized accessible interaction states

Navigation destinations, buttons, text fields, overflow menus, dialogs, loading indicators, empty states, and error states SHALL expose localized semantic names, roles, and states. Focused controls SHALL remain visibly focused and keyboard-activatable in both locales and at the documented narrow viewport.

#### Scenario: Localized control keeps keyboard and focus semantics
- **GIVEN** focus is on a production navigation destination or action
- **WHEN** the user presses Enter or Space in either supported locale
- **THEN** the control SHALL activate, announce its localized name and selected state, and preserve visible focus

#### Scenario: Narrow loading and error states remain reachable
- **GIVEN** the viewport is 320 logical pixels wide and a route transitions between loading, empty, data, and error
- **WHEN** secondary actions collapse into overflow or the state settles
- **THEN** every action SHALL remain reachable by keyboard and semantics without clipped text, overlap, or an unlocalized state announcement
