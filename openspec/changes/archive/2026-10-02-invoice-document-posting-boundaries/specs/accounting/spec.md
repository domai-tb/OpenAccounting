## ADDED Requirements

### Requirement: Input-tax claim direction during generic finalization

The shared generic finalizer SHALL create an independent `vorsteuer_anspruch` only for an incoming invoice with deductible input VAT. It SHALL NOT create an input-tax claim for outgoing invoices or non-invoice documents, regardless of a supplier link. Dedicated correction operations remain governed by the existing Storno correction requirement.

#### Scenario: Incoming invoice alias creates input-tax claim
- **GIVEN** an `eingangsrechnung` linked to a supplier is finalized with deductible input VAT
- **WHEN** generic finalization commits
- **THEN** exactly one `vorsteuer_anspruch` is linked to the incoming invoice with the input-tax amount

#### Scenario: Outgoing VAT is not an input-tax claim
- **GIVEN** an outgoing invoice is finalized with output VAT
- **WHEN** generic finalization commits
- **THEN** no `vorsteuer_anspruch` is linked to that invoice

#### Scenario: Non-invoice supplier link does not create input tax
- **GIVEN** an offer with a supplier link and VAT is finalized
- **WHEN** generic finalization commits
- **THEN** no `vorsteuer_anspruch` is linked to the offer

#### Scenario: Incoming input-tax claim failure rolls back
- **GIVEN** an incoming invoice uses the incoming number range and has a supplier and deductible input VAT
- **WHEN** a transaction failure occurs after its claim is inserted
- **THEN** no input-tax claim, journal entry, supplier payable, document state change, counter increment, or PDF from the failed attempt remains

#### Scenario: Storno still reverses an existing input-tax claim
- **GIVEN** a finalized incoming invoice has an input-tax claim
- **WHEN** its dedicated Storno operation commits
- **THEN** the existing correction behavior creates one linked reversal claim for the negated amount
