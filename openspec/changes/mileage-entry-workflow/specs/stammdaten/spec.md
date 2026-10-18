## MODIFIED Requirements

### Requirement: Konten — CRUD

The existing `konten` domain SHALL explicitly support `kontoart = 'Sachkonto'` as a non-bank ledger account with nullable banking fields. Creating/selecting a Sachkonto SHALL require an explicit user choice; the system SHALL NOT infer one from a name, account number, or absent banking fields. Existing bank and cash account types and rows SHALL remain unchanged. Mileage settings MAY assign reviewed Sachkonten to the travel-expense and private-contribution roles. Mileage role pickers SHALL offer only Sachkonten. Bank-import, bank-balance, and other bank-specific account selectors SHALL exclude Sachkonten and preserve their existing behavior for all other account types.

#### Scenario: PayPal account without IBAN
- GIVEN a user creates a Konto with kontoart = "Paypal"
- WHEN iban is left NULL and the account is saved
- THEN the account is persisted without IBAN validation

#### Scenario: Sachkonto without bank details
- GIVEN a user explicitly creates a Konto with kontoart = "Sachkonto"
- WHEN IBAN and BIC are left NULL
- THEN the account is persisted as a ledger account without bank-field validation
- AND bank-specific account selectors do not offer it

#### Scenario: Duplicate IBAN rejected
- GIVEN an existing Girokonto has iban = "DE89370400440532013000"
- WHEN a user creates a second account with iban = "DE89370400440532013000"
- THEN the system rejects the save with error "IBAN bereits vergeben"

#### Scenario: Keep Sachkonten out of bank-specific selectors
- **GIVEN** a profile has both bank accounts and explicitly created Sachkonten
- **WHEN** a bank-import, bank-balance, or other bank-specific account selector opens
- **THEN** it offers no Sachkonto
- **AND** it preserves existing behavior for bank and cash types
