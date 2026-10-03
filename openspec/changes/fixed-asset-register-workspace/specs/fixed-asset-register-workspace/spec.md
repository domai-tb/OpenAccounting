## ADDED Requirements

### Requirement: Reachable fixed-asset register

The application SHALL provide a typed asset register at the canonical `/assets` route. Users SHALL be able to create, view, update, and remove assets that have not been used by a materialized annual schedule; records with schedule history SHALL be archived or retired instead of hard-deleted. New records SHALL use the maintained accounting contract's supported fields: description, asset type (`KFZ`, `EDV`, or `sonstig`), acquisition date, net purchase price, useful life in years, linear method, private-use percentage, category reference, and disposal date when applicable. A non-KFZ asset SHALL use zero private-use percentage unless a later accepted accounting rule defines otherwise. The workspace SHALL preserve a stable asset ID. It SHALL NOT create, update, or delete journal entries, assign posting accounts, or infer a tax result from an asset-category reference.

#### Scenario: Create and update an asset record

- **GIVEN** the user enters a description, supported asset type, acquisition date, net purchase price, useful life in years, linear method, an allowed private-use percentage, and optional category
- **WHEN** the user saves the asset and later updates its descriptive or supported register fields
- **THEN** the same stable asset record is returned with the saved values and no journal entry or account mapping is created

#### Scenario: Reject invalid new asset inputs

- **GIVEN** a new asset has a missing description, unsupported type or method, invalid date, negative net price, nonpositive useful life, or private-use percentage outside 0–100
- **WHEN** the user saves it
- **THEN** the asset is not saved and the workspace identifies the invalid field

#### Scenario: Preserve assets with schedule history

- **GIVEN** an asset has been used by a materialized annual schedule
- **WHEN** the user requests deletion
- **THEN** hard deletion is refused and the asset remains available to inspect or archive

#### Scenario: Do not reinterpret legacy asset fields

- **GIVEN** a legacy row stores `anschaffungskosten`, `nutzungsdauer`, or `privatanteil` without a confirmed semantic mapping to the maintained accounting inputs
- **WHEN** the asset is opened or selected for a schedule
- **THEN** the workspace preserves the stored values for review and marks unmapped fields unresolved rather than silently treating them as net price, years, or a percentage

### Requirement: Traceable annual depreciation schedule

The application SHALL expose an annual per-asset schedule only when the source fields map to the maintained accounting contract. For a full year with no acquisition or disposal during that year, it SHALL calculate linear annual AfA from net purchase price divided by useful life in years. It SHALL apply the private-use reduction only to KFZ assets as defined by the maintained accounting contract. A non-KFZ asset with a non-zero private-use percentage SHALL remain unavailable until that type's treatment is accepted. Each result SHALL identify the asset, schedule year, source inputs, formula, and resulting amount. Opening book value, remaining book value, and disposal effects SHALL be marked unavailable until their formulas and cutoff rules are accepted. Partial acquisition or disposal years, unresolved legacy inputs, unsupported methods, and unresolved account/report mappings MUST fail closed: the schedule SHALL show an unavailable reason, SHALL NOT substitute zero, and SHALL NOT be represented as complete EÜR/AVEÜR output.

#### Scenario: Show a supported full-year linear amount

- **GIVEN** a reconciled KFZ asset has net purchase price `1000.00`, useful life `3` years, linear method, private-use share `30%`, and the selected year is a full year between acquisition and disposal
- **WHEN** the annual schedule is generated
- **THEN** the row identifies the asset and inputs, shows the formula `1000.00 / 3 × 70%`, and reports annual AfA `233.33` with opening/remaining book values marked unavailable

#### Scenario: Non-KFZ private-use rule is unresolved

- **GIVEN** an EDV or sonstig asset has a non-zero private-use percentage
- **WHEN** the annual schedule is generated
- **THEN** its amount SHALL be unavailable with the unsupported asset-type rule identified
- **AND** no private-use reduction or full amount SHALL be reported as final

#### Scenario: Fail closed on partial-year or disposal calculations

- **GIVEN** the selected year contains an acquisition or disposal date, or the disposal cutoff and remaining-book-value contract is unresolved
- **WHEN** the annual schedule is generated
- **THEN** the affected row is unavailable with the unresolved policy named, and no annual amount or disposal effect is reported as zero or final

#### Scenario: Fail closed on ambiguous source values

- **GIVEN** an asset has a legacy amount, useful life, private-use value, acquisition date, or category/account mapping that cannot be mapped to the maintained contract
- **WHEN** an annual schedule or AVEÜR result is requested
- **THEN** the asset is identified as unresolved and the result is marked incomplete rather than calculating from guessed field semantics

### Requirement: Asset changes have no journal side effect

Creating, editing, archiving, or scheduling an asset SHALL only change asset-register or schedule data. The asset workspace MUST NOT post acquisition, depreciation, disposal, tax, or account-mapping rows directly to the journal. Any future financial effect SHALL require the accepted shared accounting posting contract and its explicit asset-event mapping; until then, the action SHALL remain unavailable with its blocking reason.

#### Scenario: Save an asset without posting

- **GIVEN** an asset is created or updated with valid register data
- **WHEN** the change is saved
- **THEN** the asset data is stored and no journal or tax-claim row is created

#### Scenario: Block an unsupported financial effect

- **GIVEN** an asset action would require an accounting entry but the accepted shared posting contract or asset account mapping is unavailable
- **WHEN** the user requests that financial action
- **THEN** no journal row is written and the workspace shows the missing contract or mapping
