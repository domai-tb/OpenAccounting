## MODIFIED Requirements

### Requirement: Anlagenverzeichnis

The system SHALL maintain an Anlagenverzeichnis for AVEÜR with linear AfA, supporting KFZ, EDV, and sonstig asset types. The annual amount SHALL follow the maintained accounting contract's full-year formula from net purchase price and useful life. Each full-year amount SHALL be `kaufpreis_netto / nutzungsdauer_jahre` rounded half-up to the cent for `NUMERIC(12,2)` storage, computed independently per year with no final-year remainder adjustment; the schedule SHALL contain at most `nutzungsdauer_jahre` full-year rows. Apply private-use reduction only to KFZ as specified in the maintained contract; a non-zero private-use value for EDV or sonstig SHALL make the schedule unavailable until that rule is accepted. An annual schedule SHALL identify its asset, period, source inputs, formula, and result. The owning EÜR workflow, under its independently accepted reporting contract, may consume only complete schedule amounts whose inputs map to this contract; this change defines no EÜR report output on its own and waits on no other change for its asset and schedule scope; unresolved assets or unsupported period calculations SHALL make the result incomplete instead of contributing an invented zero or amount. Disposal-year cutoff, opening/remaining book value, and asset account mapping SHALL remain unavailable until their rules are accepted. The asset register SHALL NOT write journal entries.

#### Scenario: Asset registration

- **GIVEN** an EDV asset is registered with `kaufpreis_netto=1000`, `nutzungsdauer_jahre=3`, `afa_methode='linear'`, and no private-use share
- **WHEN** the asset is saved and its full-year schedule is generated
- **THEN** the schedule shows annual AfA `333.33` and identifies the asset, inputs, and formula without creating a journal entry

#### Scenario: KFZ with private share

- **GIVEN** a KFZ asset has net purchase price `1000`, useful life `3` years, and `privat_anteil_prozent=30`
- **WHEN** the full-year AfA schedule is computed
- **THEN** the annual amount is reduced by 30% and shows the business portion `233.33`

#### Scenario: Non-KFZ private-use amount remains unavailable

- **GIVEN** an EDV or sonstig asset has `privat_anteil_prozent` greater than zero and no accepted type-specific rule
- **WHEN** a full-year AfA amount is computed
- **THEN** the schedule row is unavailable and does not apply the KFZ reduction rule by analogy

#### Scenario: Asset disposal

- **GIVEN** an asset has `verkauft_am` recorded but no accepted cutoff or remaining-book-value contract exists
- **WHEN** the schedule is generated for the disposal year
- **THEN** the row is unavailable and the EÜR does not invent a disposal-year amount or remaining book value

#### Scenario: AVEÜR integration

- **GIVEN** active assets have complete inputs and contract-backed full-year schedule values
- **WHEN** the owning EÜR workflow consumes schedule values under its independently accepted reporting contract
- **THEN** it may consume only complete annual AfA values in the Abschreibungen section (EÜR Zeile 33) with asset-level source references retained, and this change defines no report output on its own

#### Scenario: Unresolved AfA or disposal inputs

- **GIVEN** an asset uses ambiguous legacy fields, a partial acquisition/disposal year, or an unresolved disposal/book-value rule
- **WHEN** the EÜR or AVEÜR result is generated
- **THEN** the affected schedule and report are marked incomplete with the asset and missing policy identified, and no guessed amount or zero is substituted

#### Scenario: Legacy-only asset values do not feed EÜR

- **GIVEN** an active asset has legacy cost, useful-life, or private-use values without an accepted mapping to canonical inputs
- **WHEN** EÜR line 33 is generated
- **THEN** generation fails closed with the asset ID and does not calculate depreciation from the legacy values
