## Why

Feature-map item 58 requires calendar-year accounting by default, an optional company fiscal year, and consistent use of that year by relevant reports. The current company record has no fiscal-year setting or shared boundary service. Existing annual calculations use calendar-year filtering, while the active reporting proposal refers to a company fiscal year without defining how it is selected.

## What Changes

- Add a company-level fiscal-year start month, defaulting to January for existing and new profiles.
- Add one typed fiscal-calendar service that returns labeled, inclusive-start/exclusive-end date ranges for a business month, quarter, year, or requested date.
- Add accessible, localized controls in Settings → Unternehmen and require fiscal-year-aware reporting consumers, including annual EÜR, to use the shared boundary service or show an unsupported period as unavailable.
- Keep tax-form period rules and all accounting calculations with their owning accepted capabilities; selecting a fiscal year does not change postings or statutory period rules.
- Follow the Settings form, localization, keyboard, and responsive requirements in `DESIGN.md`.

## Capabilities

### New Capabilities

- `fiscal-year-calendar`: Defines company configuration, fiscal-year labels, date boundaries, and how reporting consumers obtain business-year periods.

### Modified Capabilities

- `db`: Persist and migrate the company fiscal-year start month without rewriting existing records.
- `stammdaten`: Expose validated fiscal-year configuration with the company profile.
- `accounting`: Define business-year month/quarter/year boundaries and gate EÜR periods that do not yet consume them.

## Impact

Company profile persistence and Settings UI, the shared period-boundary service, and fiscal-year consumers such as accounting reports and dashboard summaries. Existing records and journal postings remain unchanged. Tax filings continue to use their own explicitly configured statutory periods. Changes to the configured start month affect period boundaries for all selected years and must be clearly confirmed to the user.
