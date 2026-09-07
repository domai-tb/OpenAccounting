## ADDED Requirements

### Requirement: Chart-of-accounts seeds have valid reporting mappings

A new profile MUST receive curated categories with valid SKR03/SKR04 account numbers and non-empty EÜR/EKS mappings where applicable, with deterministic identifiers and names suitable for user selection.

Implementation evidence: The current seed generates generic Kategorie i rows, 8000/4000+i accounts, formulaic EÜR values, and no EKS field.

#### Scenario: Fresh profile supports reporting without custom fixtures

- Given a new profile is opened with the default chart
- When EÜR or EKS is generated for a mapped booking
- Then the booking is classified through seeded mappings and no fixture-only category patch is required

#### Scenario: Seed upgrade preserves user edits

- Given a user renamed or modified a seeded category
- When the application upgrades/reopens the profile
- Then the migration adds missing catalog entries without overwriting the user's customized values

### Requirement: Bank templates are documented and deterministic

The supported bank-template catalog MUST match the documented format coverage, include stable matching/mapping metadata, and seed idempotently so a fresh profile and a reopened profile expose the same catalog.

Implementation evidence: Database and static catalogs disagree and contain only a small generic set.

#### Scenario: Supported template parses its format

- Given a transaction file uses one of the supported bank formats
- When the user selects the matching template
- Then the parser applies the documented fields and produces reviewable transactions

#### Scenario: Unknown format is not silently mapped

- Given an imported file has no matching template
- When template detection runs
- Then the user is asked to review/select or receives a clear unsupported-format result and no wrong bank template is stored
