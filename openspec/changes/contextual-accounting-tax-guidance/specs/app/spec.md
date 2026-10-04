## ADDED Requirements

### Requirement: Help workspace

The `/help` route SHALL provide a typed, localized Help workspace. It SHALL include a searchable glossary of reviewed accounting and tax guidance entries and SHALL use the same stable entry content as in-context field explanations. Missing or review-needed coverage states are maintainer-only and SHALL NOT appear as end-user missing-help warnings or placeholder affordances. The workspace SHALL show an honest empty state when no reviewed entries match and SHALL not present static placeholder tiles as accounting guidance.

#### Scenario: Help opens with reviewed contextual entries

- **GIVEN** the Help catalog contains reviewed entries
- **WHEN** the user opens `/help`
- **THEN** the page SHALL group and display those entries with localized names and workflow locations
- **AND** opening an entry SHALL show its full reviewed explanation.

#### Scenario: Search finds no reviewed entry

- **GIVEN** no reviewed entry matches the user's query
- **WHEN** the user searches Help
- **THEN** the page SHALL show a localized no-results state
- **AND** SHALL not show unrelated or invented content.
