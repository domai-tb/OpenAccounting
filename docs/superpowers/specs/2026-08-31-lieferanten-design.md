# Lieferanten Design

## Scope

Implement OpenSpec tasks 8.3–8.4: full Lieferanten CRUD with the broader
Kunden-style contact, address, payment, and tax field surface. Customer-only
credit-limit, dunning, and ZUGFeRD fields remain excluded. Supplier records
receive sequential Kreditor-Nr values from the existing `kreditor` number range.

## Components

- `Lieferant`: immutable domain entity containing supplier identity, contact,
  address, payment, and tax data.
- `LieferantenRepository`: dedicated repository following the tested Kunden
  repository conventions. It owns schema compatibility checks, validation,
  CRUD, number assignment, and reference-safe deletion.
- VAT validation: reuse the existing country-specific EU patterns. Non-EU
  supplier VAT IDs remain free text.
- Database: reuse the existing `lieferanten` table and `kreditor` number-range
  seed. Extend schema only where required by the selected field surface.

## Data Flow

The test and future UI call `LieferantenRepository`. The repository validates
inputs, allocates the next Kreditor-Nr inside a transaction, writes through the
Drift `QueryExecutor`, and maps rows to immutable `Lieferant` values. Updates
use an explicit allowlist; unknown fields fail rather than being silently
discarded. Deletes inspect invoice and journal foreign-key references before
removing a supplier and report matching reference IDs on failure.

## Error Handling

- Reject blank required fields and invalid EU VAT formats with descriptive
  German messages.
- Reject malformed number-range state instead of assigning duplicate numbers.
- Reject deletes with invoice or journal references; never cascade-delete
  accounting data.
- Keep SQL parameterized and avoid exposing connection or credential details.

## Verification

`test/features/stammdaten/lieferanten_test.dart` covers:

1. Create/read/update/delete round trip.
2. Kreditor-Nr assignment and formatting.
3. Full optional-field persistence.
4. Required-field and unknown-update validation.
5. EU VAT validation and non-EU free-text acceptance.
6. Delete rejection for invoice and journal references.

Run targeted supplier tests and analysis, then the complete Flutter test suite.
