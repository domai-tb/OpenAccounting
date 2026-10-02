## ADDED Requirements

### Requirement: Wizard fields and review reflect canonical setup data

The existing four-step wizard SHALL keep the canonical order Stammdaten → Konten → Kategorien → Abschluss. It SHALL present the company and account fields required by the existing `Four-step wizard flow` contract: company name, address, tax ID, legal form, and bank-account IBAN, BIC, and account holder. Category choices SHALL be loaded from seeded category records, display their real stored names rather than generated numeric labels, and persist the selected IDs through the existing transactional setup boundary. The Abschluss summary SHALL display the values that will actually be persisted and MUST NOT substitute raw category IDs or synthetic company/account identity.

#### Scenario: Setup displays saved contract-backed values

- **GIVEN** the setup database exposes the seeded category records
- **WHEN** the user completes all four steps and reviews Abschluss
- **THEN** the summary SHALL show the entered company/account values and selected stored category names, and completion SHALL persist those category IDs through the setup transaction

#### Scenario: Required setup data or seed data is unavailable

- **GIVEN** a required value is invalid or the seeded category source cannot be read
- **WHEN** the user attempts to advance or finish the wizard
- **THEN** the wizard SHALL remain on the relevant step, show a localized actionable validation/load error, and SHALL NOT present generated placeholder categories as configured records
