## MODIFIED Requirements

### Requirement: Kunden — Zugferd aktiv

Each customer MAY have a ZUGFeRD default output preference. When `zugferd_aktiv` is true, the invoice finalization surface SHALL preselect ZUGFeRD for a new outgoing invoice; when false, it SHALL preselect PDF. The user SHALL be able to choose ZUGFeRD, XRechnung, or PDF per invoice, so this customer value MUST NOT force or hide the choice. Selecting ZUGFeRD for finalization SHALL generate a validated ZUGFeRD 2.5.2 `EN16931` CII invoice embedded in a PDF/A-3b visual document. Selecting another format SHALL NOT generate ZUGFeRD XML. The setting SHALL NOT trigger XRechnung generation or network delivery. A selected ZUGFeRD validation, generation, or artifact-write failure SHALL prevent finalization from committing and SHALL leave no allocated invoice number, stock effect, finalized invoice, or partial artifact.

#### Scenario: Customer preference preselects ZUGFeRD

- **GIVEN** a customer has `zugferd_aktiv = true`
- **WHEN** an outgoing invoice draft is opened for finalization
- **THEN** ZUGFeRD is visibly preselected and PDF and XRechnung remain available choices

#### Scenario: Customer preference preselects PDF

- **GIVEN** a customer has `zugferd_aktiv = false`
- **WHEN** an outgoing invoice draft is opened for finalization
- **THEN** PDF is visibly preselected and ZUGFeRD and XRechnung remain available choices

#### Scenario: Per-invoice selection overrides the default

- **GIVEN** a customer preference has preselected an output format
- **WHEN** the user selects another format for this invoice
- **THEN** the selected alternative is used and the saved customer preference remains unchanged

#### Scenario: ZUGFeRD invoice generation

- **GIVEN** a customer has `zugferd_aktiv = true`, the default remains selected, and the invoice has all required fields
- **WHEN** the outgoing invoice is finalized
- **THEN** the system generates a validated PDF/A-3b file with ZUGFeRD XML embedded and the detail view derives readiness from the validated artifact

#### Scenario: ZUGFeRD not generated when disabled

- **GIVEN** a customer has `zugferd_aktiv = false` and the preselected PDF output remains selected
- **WHEN** an invoice is finalized for that customer
- **THEN** the system generates a standard PDF without ZUGFeRD XML embedding

#### Scenario: Invalid selected ZUGFeRD data blocks finalization

- **GIVEN** ZUGFeRD is selected and the invoice is missing a field required by the pinned profile
- **WHEN** invoice finalization is attempted
- **THEN** finalization fails with a localized field-level diagnostic, the invoice remains a draft without number or stock effect, and no partial artifact remains
