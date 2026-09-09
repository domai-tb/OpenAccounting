## ADDED Requirements

### Requirement: UStVA classifies bookings and Kennzahlen correctly

UStVA MUST exclude ordinary expense bookings from domestic turnover, expose every required Kennzahl including zero-valued fields, and calculate each tax base according to its documented booking direction.

Implementation evidence: Existing tests insert only Einnahme rows, so the current all-rows KZ1 behavior remains false-green; the result map omits documented fields.

#### Scenario: An expense is not turnover

- Given the period contains an ordinary Ausgabe journal row and no sale
- When UStVA is generated
- Then domestic turnover Kennzahlen remain zero while any valid input-tax field is classified separately

#### Scenario: Zero-valued required keys are present

- Given a valid period has no activity for some statutory fields
- When the result is generated
- Then the complete required Kennzahl set contains explicit zero values for inactive fields

#### Scenario: Reverse charge uses the declared base

- Given a reverse-charge booking has a net base and tax rate
- When UStVA is generated
- Then the tax is additive to the net base according to the chosen contract and is not reported as domestic turnover

### Requirement: EÜR applies booking direction and period policy

EÜR MUST classify income and expense from booking semantics plus valid category mapping, stop depreciation from the recorded disposal date, and apply the configured cutover policy consistently when no ad-hoc override is supplied.

Implementation evidence: Current EÜR subtracts/ adds by euer_zeile range, has no disposal date field, and defaults a null cutover to payment-principle logic.

#### Scenario: Income and expense directions are respected

- Given income and expense bookings use categories whose line numbers do not match their art
- When the EÜR is generated
- Then profit follows Einnahme/Ausgabe semantics and not an arbitrary line-number threshold

#### Scenario: Disposal stops AfA

- Given a fixed asset is disposed during a reporting year
- When EÜR spans periods before and after the disposal date
- Then depreciation is included only through the documented cutoff and the disposal remains auditable

#### Scenario: Default cutover is deterministic

- Given the configured cutover policy exists and the caller omits cutoverDatum
- When a period crosses the cutover
- Then the service applies that policy consistently and does not silently switch principles

### Requirement: Tax and GoBD exports are real validated artifacts

DATEV, tax reports, and GoBD exports MUST write validated files to a user-selected safe destination, record export metadata/status, and surface partial or failed writes without claiming success.

Implementation evidence: DATEV currently returns a string and records a literal memory path; the reports route is a placeholder.

#### Scenario: A successful export is reopenable

- Given the selected period and profile data are valid
- When the user exports DATEV or GoBD data
- Then the expected CSV or ZIP exists at the chosen path, passes structural validation, and appears in export history

#### Scenario: Export failure is truthful

- Given the destination is unavailable or validation fails
- When the export is attempted
- Then no successful history entry is recorded and the UI identifies the failed artifact and recovery action

### Requirement: Customer-scoped reports honor their customer filter

EKS and other customer-scoped reports MUST constrain every contributing journal, invoice, receivable, and payment row to the requested customer, and MUST distinguish an empty result from an unfiltered all-customer result.

Implementation evidence: lib/features/accounting/eks_service.dart accepts kundeId but its journal query does not apply a customer predicate; the existing test permits the unfiltered result.

#### Scenario: EKS excludes another customer's bookings

- Given two customers have otherwise identical eligible bookings
- When EKS is generated for only the first customer
- Then the result contains only the first customer's eligible amounts and rows

#### Scenario: Missing customer scope is explicit

- Given the caller requests a customer-scoped report without a valid customer identifier
- When report generation runs
- Then it rejects the request or returns an explicitly unscoped report mode, never silently treating the request as all customers
