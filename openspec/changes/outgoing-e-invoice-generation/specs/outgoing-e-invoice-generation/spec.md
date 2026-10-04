## ADDED Requirements

### Requirement: Version-pinned e-invoice formats

The initial supported formats SHALL be ZUGFeRD 2.5.2 using the `EN16931` profile and UN/CEFACT CII D22B, and XRechnung 3.0 using UBL 2.1. XRechnung validation SHALL use the official XRechnung Bundle 3.0.2 Summer 2026 technical artifacts dated 2026-08-31; the bundle version MUST NOT be presented as the normative XRechnung version. The application SHALL package the official schema and business-rule artifacts locally, identify format and validator-bundle versions in application/release metadata, and validate without network access. Runtime SHALL NOT download, update, or silently select a different release. A later format or bundle release SHALL require an explicit compatibility change and updated fixtures.

#### Scenario: Generate supported pinned format

- **GIVEN** a finalized outgoing invoice has all source data required by the selected profile and its pinned local validator is available
- **WHEN** the user requests the supported output
- **THEN** the generated XML validates against the exact packaged XSD and Schematron/configuration artifacts, with XRechnung identified as version 3.0 and its validator bundle as 3.0.2 Summer 2026

#### Scenario: Unsupported or unavailable validation bundle

- **GIVEN** the required pinned validator artifacts are missing, corrupt, or cannot run on the active desktop platform
- **WHEN** generation is requested
- **THEN** the system reports validation unavailable, creates no output, and does not claim the file is compliant

### Requirement: Generate from one canonical invoice snapshot

Finalization SHALL materialize one typed immutable snapshot inside the finalization transaction after number allocation and canonical invoice calculation and before PDF/e-invoice generation. The snapshot SHALL contain the allocated number, selected `ausgabeformat` enum (`zugferd`, `xrechnung`, or `pdf`), dates, sender and customer data, invoice lines, typed tax classifications, currency, and canonical totals. If finalization commits, the same snapshot values MUST be persisted on the finalized invoice row. The visual PDF and embedded ZUGFeRD XML SHALL consume that same snapshot. A standalone XRechnung export SHALL consume a typed immutable snapshot read from the committed finalized outgoing invoice. Serialization SHALL preserve applicable snapshot values and MUST NOT calculate or round invoice money, infer tax treatment, fabricate identifiers or terms, create accounting entries, or mutate the invoice. This initial capability covers ordinary outgoing invoices only.

#### Scenario: Finalization outputs share one canonical snapshot

- **GIVEN** an outgoing invoice draft has all canonical values required by the selected output and its finalization transaction allocates its invoice number
- **WHEN** the immutable snapshot is materialized and the selected PDF/e-invoice output is generated
- **THEN** the PDF and embedded CII fields and totals match that snapshot, and the values persisted on commit equal the snapshot

#### Scenario: Standalone export reads the committed snapshot

- **GIVEN** an ordinary outgoing invoice is finalized with persisted canonical values
- **WHEN** standalone XML is generated
- **THEN** its fields and totals represent the committed snapshot exactly and no invoice or accounting record changes

#### Scenario: Snapshot output failure rolls back finalization

- **GIVEN** finalization has materialized a snapshot but its selected output fails generation or validation
- **WHEN** the finalization transaction handles the failure
- **THEN** no invoice number, finalized row, stock effect, final artifact, or temporary artifact remains

#### Scenario: Draft invoice cannot be exported

- **GIVEN** an outgoing invoice is still a draft
- **WHEN** XRechnung export is requested
- **THEN** export is unavailable and no invoice data or artifact is changed

### Requirement: Tax categories are explicitly classified

Each invoice line SHALL resolve to an explicit tax category and any required exemption reason from an accepted, typed accounting/tax classification source before serialization. A percentage or zero rate alone SHALL NOT be used to infer tax-category code, exemption, reverse-charge, intra-community-supply, or §25a treatment. If no approved mapping exists for a line, generation SHALL fail with a localized field-level diagnostic and no output.

#### Scenario: Explicit tax classification is serialized

- **GIVEN** every invoice line has an approved typed category and any required exemption reason
- **WHEN** an e-invoice is generated
- **THEN** each line uses that category and reason without inferring them from the tax percentage

#### Scenario: Tax category mapping is unavailable

- **GIVEN** a finalized invoice contains a line whose stored tax data has no approved mapping to the selected profile
- **WHEN** e-invoice generation is requested
- **THEN** generation fails with the affected line and unresolved classification identified, without choosing a code or writing an artifact

### Requirement: Required-field and business-rule validation

Before output is exposed or written, the selected format's pinned validator SHALL validate required fields and business rules. The system SHALL map validation findings to typed field/business-term or rule identifiers and localized corrective messages. If the source snapshot is missing a required value or violates a pinned rule, generation SHALL fail without a partial file. Diagnostics MUST NOT silently default or infer missing financial, identity, tax, buyer-reference, or payment-term values.

#### Scenario: Valid data passes pinned validation

- **GIVEN** the selected output is generated from a snapshot with all required source values
- **WHEN** its pinned schema and business-rule validation runs
- **THEN** the validated artifact is made available and the UI reports the selected format as valid

#### Scenario: Missing required source field

- **GIVEN** the selected format requires a value absent from the invoice snapshot
- **WHEN** generation is requested
- **THEN** the system identifies the missing field/rule in a localized validation summary and writes no output

#### Scenario: Pinned business rule rejects invoice

- **GIVEN** generated XML violates a business rule from the selected pinned standard bundle
- **WHEN** validation runs
- **THEN** the output is rejected with the stable rule identifier, no partial artifact is exposed, and the source invoice is unchanged

### Requirement: Selected ZUGFeRD hybrid finalization

When ZUGFeRD is explicitly selected for an ordinary outgoing invoice, finalization SHALL generate a ZUGFeRD 2.5.2 `EN16931` CII invoice embedded in the human-readable PDF/A-3b visual document. The customer `zugferd_aktiv` value SHALL preselect this format but MUST NOT hide or force the per-invoice choice. The hybrid PDF SHALL validate its XML, PDF/A-3b conformance, embedded-file relationship, and required format metadata before the database finalization transaction commits. If generation or validation fails, invoice numbering, finalized status, inventory side effects, and other database changes SHALL roll back and temporary files SHALL be removed. If PDF or XRechnung is selected, finalization SHALL use the existing non-hybrid visual PDF path; standalone XRechnung generation remains a separate post-finalization export.

#### Scenario: Selected ZUGFeRD finalization

- **GIVEN** an outgoing invoice draft has ZUGFeRD selected and its snapshot meets the selected profile
- **WHEN** the invoice is finalized
- **THEN** the stored original PDF is the validated PDF/A-3b hybrid with embedded ZUGFeRD 2.5.2 XML, and the finalized invoice references that artifact

#### Scenario: Customer default is overridden per invoice

- **GIVEN** a customer's `zugferd_aktiv` value preselects ZUGFeRD for a draft invoice
- **WHEN** the user explicitly selects PDF or XRechnung before finalization
- **THEN** the chosen non-ZUGFeRD format is shown as selected and no ZUGFeRD XML is embedded in the finalized PDF

#### Scenario: ZUGFeRD validation failure rolls back finalization

- **GIVEN** ZUGFeRD is selected and the invoice snapshot fails a required field or pinned rule
- **WHEN** finalization is attempted
- **THEN** the invoice remains a draft without an allocated number or stock side effect, and no final or temporary artifact remains

### Requirement: Standalone XRechnung export

The detail workspace SHALL allow a finalized ordinary outgoing invoice to be exported as standalone XRechnung 3.0 UBL 2.1 XML validated with the pinned XRechnung Bundle 3.0.2 Summer 2026. The page SHALL obtain generation and validation through the registered invoice service/repository, validate before writing, and use a native save-file dialog. A successful export MUST NOT change invoice fields, finalization state, numbering, or accounting records.

#### Scenario: Export standalone XRechnung

- **GIVEN** a finalized ordinary outgoing invoice passes XRechnung 3.0 validation using Bundle 3.0.2 Summer 2026
- **WHEN** the user selects XRechnung export and saves the chosen file
- **THEN** a standalone UBL 2.1 XML file is written atomically and the invoice remains unchanged

#### Scenario: Cancel standalone XRechnung export

- **GIVEN** a finalized invoice passes validation and the native save dialog is open
- **WHEN** the user cancels the dialog
- **THEN** no XML file is written and the invoice remains unchanged

#### Scenario: Export cannot validate

- **GIVEN** the finalized snapshot is missing a required XRechnung value or its pinned validator is unavailable
- **WHEN** the user requests XRechnung export
- **THEN** localized validation or availability is shown, the save dialog is not opened, and no file or invoice field changes

### Requirement: E-invoice output follows application boundaries and design

The invoice finalization/detail surface SHALL expose a visible per-invoice choice of ZUGFeRD, XRechnung, and PDF, with the customer ZUGFeRD value used only as the default selection. It SHALL show the selected output and its validation/readiness state, plus available export actions; unavailable outputs SHALL explain why. The XRechnung action SHALL use the registered invoice application-scope service and typed repository; the widget MUST NOT issue SQL or construct a data source. New controls, status, errors, and validation SHALL use generated localization, keyboard-accessible interaction, visible focus, responsive layout, and non-color validation cues as defined by `DESIGN.md`.

#### Scenario: Output choices and state are visible

- **GIVEN** an outgoing invoice draft or finalized invoice is open in its detail surface
- **WHEN** the user reviews output formats
- **THEN** ZUGFeRD, XRechnung, and PDF are explicit choices, the customer ZUGFeRD value supplies only the draft default, and selected-format state and available actions are visible with text

#### Scenario: Selected format survives reopening a finalized invoice

- **GIVEN** a draft invoice is finalized with `ausgabeformat = xrechnung`
- **WHEN** the finalized invoice is closed and reopened from its detail route
- **THEN** the detail surface restores XRechnung as the selected output and shows its export as not yet validated until the user requests export

#### Scenario: Invoice detail exposes a reachable export

- **GIVEN** an eligible finalized invoice is open in the production detail route
- **WHEN** the user reviews its available actions
- **THEN** XRechnung export is reachable by keyboard with a localized accessible name, and validation errors identify the fields to correct

#### Scenario: Draft has no standalone export action

- **GIVEN** an outgoing invoice is still a draft
- **WHEN** the user reviews the detail actions
- **THEN** the XRechnung export action is unavailable and the UI does not imply that an e-invoice artifact exists

#### Scenario: Legacy finalized invoice defaults to PDF

- **GIVEN** a finalized invoice row has no saved `ausgabeformat` from before this change
- **WHEN** the invoice is reopened
- **THEN** the detail surface shows PDF as selected and does not infer a format from the customer's current ZUGFeRD preference
