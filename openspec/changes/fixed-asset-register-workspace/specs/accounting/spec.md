## MODIFIED Requirements

### Requirement: Anlagenverzeichnis

The system SHALL maintain an Anlagenverzeichnis for AVEÜR with linear AfA, supporting KFZ, EDV, and sonstig asset types. The annual amount SHALL follow the maintained accounting contract's full-year formula from net purchase price and useful life. Apply private-use reduction only to KFZ as specified in the maintained contract; a non-zero private-use value for EDV or sonstig SHALL make the schedule unavailable until that rule is accepted. An annual schedule SHALL identify its asset, period, source inputs, formula, and result. The EÜR AfA line SHALL consume only complete schedule amounts whose inputs map to this contract; unresolved assets or unsupported period calculations SHALL make the result incomplete instead of contributing an invented zero or amount. Disposal-year cutoff, opening/remaining book value, and asset account mapping SHALL remain unavailable until their rules are accepted. The asset register SHALL NOT write journal entries.

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

- **GIVEN** an asset has `verkauft_am` recorded and an accepted cutoff and remaining-book-value contract is available
- **WHEN** the schedule is generated for years around the disposal
- **THEN** AfA stops at the contract-defined date and the schedule shows the remaining book value with the disposal source date

#### Scenario: AVEÜR integration

- **GIVEN** active assets have complete inputs and contract-backed full-year schedule values
- **WHEN** the EÜR or AVEÜR result is generated
- **THEN** supported annual AfA values appear in the Abschreibungen section (EÜR Zeile 33) and retain their asset-level source references

#### Scenario: Unresolved AfA or disposal inputs

- **GIVEN** an asset uses ambiguous legacy fields, a partial acquisition/disposal year, or an unresolved disposal/book-value rule
- **WHEN** the EÜR or AVEÜR result is generated
- **THEN** the affected schedule and report are marked incomplete with the asset and missing policy identified, and no guessed amount or zero is substituted
