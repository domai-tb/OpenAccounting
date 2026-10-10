## ADDED Requirements

### Requirement: Anlage S/G values require an accepted source contract

Anlage S/G numeric fields SHALL be returned only when an accepted tax-year form and line mapping, schedule-period contract, explicit classification evidence, and complete approved accounting source exist for the selected schedule. This change defines none of those value contracts, so its S/G availability result SHALL remain unavailable and SHALL NOT query an approximate source or relabel another report. An accepted future delta may replace this boundary only by specifying each source, field, formula, version, and completeness rule.

#### Scenario: S/G source mapping is not accepted

- **GIVEN** the selected schedule has no accepted mapping from accounting records to its tax-year form fields
- **WHEN** a user requests S/G availability
- **THEN** the service SHALL return an unavailable result naming the missing form/source contract
- **AND** SHALL NOT copy EÜR/EKS/GuV totals or compute an undocumented substitute.

#### Scenario: S/G completeness cannot be established

- **GIVEN** no accepted S/G period and source-coverage contract exists
- **WHEN** a user requests S/G availability
- **THEN** the service SHALL report `periodContractUnavailable` and `accountingSourceContractUnavailable`
- **AND** SHALL NOT emit a zero, estimate, completeness count, or numeric tax field.

#### Scenario: Schedule choice is explicit

- **GIVEN** the profile has no accepted schedule-classification contract
- **WHEN** the user opens the supporting-report view
- **THEN** the user SHALL choose Anlage S or Anlage G explicitly
- **AND** the application SHALL NOT infer eligibility from profile text or transaction descriptions.
