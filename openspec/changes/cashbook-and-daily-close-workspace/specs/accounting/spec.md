## MODIFIED Requirements

### Requirement: Tagesabschluss

The system SHALL support a daily cash close only for an explicit company, cash account, and local calendar date, using a complete account/date balance result with an integer `balance_cents`, ISO 4217 `currency_code`, stable `source_reference`, and `complete` status. `complete = true` SHALL require an unambiguous account/date/currency and verified coverage of the opening amount and all in-scope cash history. An incomplete result SHALL expose no usable amount and SHALL prevent finalization and PDF generation. Expected cash SHALL NOT be derived by summing same-day journal rows or by adding `konten.saldo` to a setup opening event.

The setup opening event SHALL be counted once. Where the setup event and `konten.saldo` represent the same opening amount, the verified setup event is the opening source and `konten.saldo` is corroborating metadata only; it SHALL NOT be added as another movement. A missing, conflicting, duplicated, or ambiguous opening identity SHALL make the result incomplete. Unbalanced, unlinked, or otherwise unverifiable legacy cash history that could affect the selected balance SHALL also make it incomplete; the system SHALL NOT substitute zero or silently omit it.

The opening event SHALL be sourced only from one complete v26 `account_opening_balance_sources` record defined by this change, linked to its matching setup opening journal row. While the source record or its matching identity is absent or invalid, cashbook writes and account/date balances SHALL remain unavailable; close finalization and PDF generation SHALL additionally remain unavailable until v27 evidence support is implemented. Existing legacy setup rows, `is_opening_balance`, and `konten.saldo` SHALL NOT be treated as a substitute or used to backfill a source.

For a finalized close, existing `tagesabschluesse` columns SHALL have these meanings: `unternehmen_id` is the explicit company; `konto_id` is the selected cash account; `datum` is the selected local date; `betrag` is the expected balance; `kassenbestand` is the user's counted balance; and `differenz` is `kassenbestand - betrag`. The three amount columns SHALL represent exact two-decimal currency amounts corresponding to integer cents, with no floating-point arithmetic. All three amounts SHALL use the result's `currency_code` and SHALL NOT be converted implicitly.

`zaehlung_json` SHALL contain the version-1 immutable source/count snapshot as canonical JSON. Its exact fields SHALL be `account_id`, `company_id`, `counted_amount_cents`, `currency_code`, `date`, `difference_cents`, `expected_amount_cents`, `explanation`, `schema_version`, and `source_reference`. RFC 8785 JSON Canonicalization Scheme SHALL determine the fixed lexicographic property order and JSON representation; the source text SHALL be UTF-8 with no extra whitespace. All monetary JSON values SHALL be integers in cents, within the exactly representable integer range; `currency_code` SHALL be uppercase ISO 4217 with a two-decimal minor unit; `date` SHALL be `YYYY-MM-DD`; `schema_version` SHALL be integer `1`; and `explanation` SHALL be a Unicode NFC string or JSON `null`. No additional or missing fields are valid in version 1.

The writer SHALL store `integrity_hash` as `sha256:` followed by the lowercase hexadecimal SHA-256 digest of the canonical UTF-8 bytes of `zaehlung_json`, atomically with the snapshot and mapped amount columns. New rows SHALL NOT write an authenticated signature into `signatur`; that existing field remains unchanged for legacy compatibility. The digest is an integrity check only: it SHALL NOT be described as a person's signature, prove author identity, or imply Ed25519, key custody, or a trusted signer.

Before a record is presented as finalized or included in a PDF, the reader SHALL parse the versioned snapshot, require the exact version-1 field set, require the stored text to equal its RFC 8785 canonical UTF-8 serialization, recompute SHA-256, and compare it with `integrity_hash`. Unknown versions, malformed or changed snapshots, absent digests, and legacy `signatur` values without a version-1 digest SHALL be shown only as unverified history and SHALL NOT be presented as finalized or exported. Finalization identity SHALL be `(unternehmen_id, konto_id, datum)`; duplicate lookup and insertion SHALL run inside one SQLite `BEGIN IMMEDIATE` transaction. A sole matching verified finalized row SHALL be returned read-only. Any matching legacy row, multiple rows, or ambiguous identity SHALL block another finalization. Finalized rows SHALL remain immutable. The accounting workspace SHALL NOT calculate tax or post an adjustment for a discrepancy.

#### Scenario: Tagesabschluss creation

- **GIVEN** the account/date source returns a complete result with expected integer cents, currency, source reference, and verified completeness
- **WHEN** the user starts Tagesabschluss for that explicit account and date
- **THEN** the workspace SHALL present the expected amount, currency, source, and completeness for manual count entry
- **AND** it SHALL NOT derive the amount from same-day journal rows or `konten.saldo`.

#### Scenario: Counting discrepancy

- **GIVEN** the complete source result returns an expected balance and the user enters a different count
- **WHEN** the close is finalized with a required explanation
- **THEN** `differenz` and `difference_cents` SHALL equal counted minus expected
- **AND** the result and explanation SHALL be stored in `zaehlung_json` and no journal adjustment SHALL be created.

#### Scenario: GoBD signature

- **GIVEN** a version-1 close snapshot with the exact required fields, integer-cent amounts, and a non-ASCII explanation
- **WHEN** the snapshot is serialized and finalized
- **THEN** `zaehlung_json` SHALL use the RFC 8785 canonical UTF-8 representation with its fixed property order
- **AND** `integrity_hash` SHALL equal `sha256:` plus the lowercase SHA-256 digest of those bytes
- **AND** this inherited scenario SHALL assert an integrity hash only; it SHALL make no authenticated-signature, signer-identity, or key-custody claim.

#### Scenario: Daily close columns map to expected and counted values

- **GIVEN** the source result identifies expected cents, currency, source reference, company, account, and date, and the user enters counted cents
- **WHEN** the close snapshot is persisted
- **THEN** `betrag` SHALL store expected, `kassenbestand` SHALL store counted, and `differenz` SHALL store counted minus expected
- **AND** `konto_id` SHALL equal the explicitly selected account and `zaehlung_json` SHALL preserve both integer-cent values and the source reference.

#### Scenario: Finalized close requires digest verification

- **GIVEN** a stored close has an unknown snapshot version, a missing digest, or a digest that does not match its canonical snapshot
- **WHEN** close history is loaded
- **THEN** the record SHALL be identified as unverified and SHALL NOT be presented as finalized
- **AND** its snapshot SHALL not be eligible for PDF generation.

#### Scenario: Double close prevention

- **GIVEN** one verified finalized Tagesabschluss already exists for the selected company, cash account, and date
- **WHEN** another close is initiated for that identity
- **THEN** the verified existing record SHALL open read-only
- **AND** the system SHALL NOT create a second close or reopen the record for editing.

#### Scenario: Concurrent finalization is serialized

- **GIVEN** two close requests target the same company, account, and date
- **WHEN** both requests attempt finalization concurrently
- **THEN** the `BEGIN IMMEDIATE` transaction guard SHALL persist at most one finalized close
- **AND** the later request SHALL return the verified existing record read-only.

#### Scenario: Ambiguous legacy close identity

- **GIVEN** a legacy row, multiple rows, or an ambiguous legacy identity matches the selected company, account, and date
- **WHEN** finalization is requested
- **THEN** the system SHALL return an unverified-history state
- **AND** SHALL preserve the old rows and SHALL NOT create another close for that identity.

#### Scenario: Expected cash source is unavailable

- **GIVEN** the account/date source is absent, incomplete, ambiguous, or unverified
- **WHEN** the user attempts to finalize a Tagesabschluss
- **THEN** the system SHALL show a localized unavailable state
- **AND** SHALL NOT persist a close, use a fallback amount, or generate a PDF.
