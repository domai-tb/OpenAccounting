## ADDED Requirements

### Requirement: Capture traceable business mileage

The system SHALL provide a user-accessible mileage workflow that records the trip date, purpose, positive distance in kilometers, and business context. Each record SHALL have a stable identity and remain reviewable with its accounting state. Distance precision SHALL be at most two decimal places, matching the existing `journal.km_anzahl` field. Once a mileage record has an accounting posting, its source facts MUST NOT be silently edited or deleted; corrections SHALL use a traceable correction linked to the original record and follow the accepted accounting correction contract.

#### Scenario: Record a business trip
- **GIVEN** a trip has a date, non-empty purpose, positive distance within the supported precision, and business context
- **WHEN** the user saves the trip
- **THEN** one durable mileage record is created with those exact source facts and a stable identifier

#### Scenario: Reject invalid trip facts
- **GIVEN** a trip has a missing purpose, missing business context, non-positive distance, or distance with more than two decimal places
- **WHEN** the user attempts to save it
- **THEN** the record is not created and the form identifies the invalid field

#### Scenario: Preserve posted source facts
- **GIVEN** a mileage record has a linked accounting posting
- **WHEN** the user attempts to edit or delete its date, purpose, distance, or business context
- **THEN** the system rejects the in-place mutation and directs the user to a traceable correction action

### Requirement: Mileage amounts require an approved effective policy

The system SHALL calculate a general deductible amount only from a reviewed policy that is explicitly approved for the trip's purpose and effective on the trip date. The policy SHALL define its source/version, eligibility conditions, rate or calculation basis, caps where applicable, and rounding rule. The record SHALL retain the policy reference and calculation result used. A Jobcenter EKS allowance SHALL remain governed by the existing EKS requirement and MUST NOT be reused as the general deductible mileage rate.

#### Scenario: Calculate from an approved policy
- **GIVEN** a trip matches an approved policy effective on its date and all required eligibility facts are present
- **WHEN** the user requests a calculation
- **THEN** the system stores the amount produced by that policy's defined calculation and rounding rule together with the policy source/version

#### Scenario: Keep an unresolved trip out of accounting
- **GIVEN** no approved policy applies to the trip date and purpose, or a required eligibility fact is missing
- **WHEN** the user requests a calculation or posting
- **THEN** the trip remains visibly unresolved, no general deductible amount is stored, and no accounting or report total changes

#### Scenario: Do not treat the EKS allowance as the general deduction
- **GIVEN** the only available mileage rate is the existing EKS B6_5 allowance of 0.10 per kilometer
- **WHEN** a general business mileage amount is requested
- **THEN** the general deductible amount remains unresolved unless a separate approved general policy applies

### Requirement: Post resolved mileage through the accounting boundary

A mileage record SHALL become a business expense only after the user confirms a policy-resolved amount and the required category/account mapping is valid. The expense SHALL be posted through the accepted accounting posting boundary, use the accounting date and event identity defined by that contract, retain a link to the source mileage record, and be included in reports through the canonical accounting source. Reprocessing the same mileage record MUST NOT create a second posting. The mileage workflow MUST NOT invent debit/credit, VAT, settlement, or report-period rules outside their maintained contracts.

#### Scenario: Post a confirmed resolved mileage expense
- **GIVEN** a trip has a policy-resolved amount, a valid accounting mapping, and no prior posting
- **WHEN** the user confirms posting
- **THEN** one accounting expense is created through the accepted posting boundary, linked to the trip's stable identifier, and included in reports through that posting

#### Scenario: Reject duplicate or incomplete posting
- **GIVEN** a trip already has a posting, lacks an approved amount, or lacks a valid accounting mapping
- **WHEN** posting is requested again
- **THEN** no second posting is created and the system reports either the existing posting or the unresolved policy/mapping state
