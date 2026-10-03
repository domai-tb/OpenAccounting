## ADDED Requirements

### Requirement: S/G report values require versioned accounting mappings

An Anlage S/G supporting report SHALL use an accepted form-year field mapping and an accepted accounting source/period contract. It SHALL identify its schedule and not infer whether the selected company belongs to Anlage S or Anlage G. Each available field SHALL expose its contributing records/categories and mapping version. Calendar-only values SHALL NOT be relabeled as configured business-year values, and tax filing periods SHALL remain owned by the accepted tax-report period contract.

#### Scenario: S/G source mapping is not accepted

- **GIVEN** the selected schedule field has no accepted mapping from accounting records
- **WHEN** the report is requested
- **THEN** the field SHALL be unavailable
- **AND** the service SHALL NOT copy an EÜR/EKS aggregate or compute an undocumented substitute.

#### Scenario: Schedule choice is explicit

- **GIVEN** company profile data does not contain an accepted S/G classification
- **WHEN** the user opens the supporting-report view
- **THEN** the user SHALL select which schedule to inspect
- **AND** the application SHALL NOT infer eligibility from company name, profession text, or transaction descriptions.
