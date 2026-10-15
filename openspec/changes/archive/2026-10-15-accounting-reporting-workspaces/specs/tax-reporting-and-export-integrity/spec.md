## ADDED Requirements

### Requirement: Reporting workspace file-output scope

For the report workspaces introduced by `accounting-reporting-workspaces`, DATEV is the only report type with file output. Its format and field contract is owned by the modified `accounting` DATEV requirement, and its safe destination, validation, integrity metadata, and history are owned by this capability's existing `Tax and GoBD exports are real validated artifacts` requirement. EÜR, EKS, GuV, UStVA, and ZM SHALL remain on-screen previews in this change; their workspace SHALL NOT create PDF, CSV, ZIP, or official filing artifacts. Existing GoBD export behavior is unchanged and remains governed by its existing contract.

#### Scenario: DATEV export uses the maintained artifact lifecycle

- **GIVEN** a supported DATEV preview and complete version-pinned source mapping exist
- **WHEN** the user exports to a selected safe destination
- **THEN** the DATEV v13 CSV is written, reopened, validated, and recorded in history using the existing artifact lifecycle
- **AND** success is shown only after validation completes

#### Scenario: Preview-only report has no file export

- **GIVEN** the user is viewing an EÜR, EKS, GuV, UStVA, or ZM preview
- **WHEN** the workspace displays available actions
- **THEN** it offers no file-export or submission action for that report type
- **AND** the preview status does not create an export-history row

#### Scenario: Unsupported export format remains unavailable

- **GIVEN** the user requests a file for a preview-only report type
- **WHEN** the workspace handles the request
- **THEN** it explains that no accepted file-format contract is available in this change
- **AND** it writes no file and records no successful export
