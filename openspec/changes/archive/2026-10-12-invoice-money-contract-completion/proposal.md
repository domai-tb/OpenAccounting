## Why

The archived invoice-money proposal remains rejected, while balanced journal posting and document correction both rely on its missing rules. Current code, maintained document requirements, and the database specification disagree about rounding, source discounts, correction signs, and SQLite precision.

## What Changes

- Define one testable decimal-to-cent contract for invoice preview, persistence, finalization, conversion, PDF totals, and generated corrections.
- Specify deterministic mixed-rate discount and settlement-cent allocation, with stable tie-breaking.
- Align maintained discount and database requirements with the accepted calculation and SQLite behavior.
- Add typed validation metadata and require invalid or inconsistent documents to fail before durable side effects.

## Capabilities

### New Capabilities
- `invoice-money-contract`: Exact input scales, rounding, cent allocation, validation errors, persistence, and correction-sign rules.

### Modified Capabilities
- `documents`: Correct position and document discount calculation and PDF totals.
- `db`: State which precision SQLite enforces, require application validation, and preserve supported invoice scales across reloads.

## Impact

The invoice calculator and UI, invoice use-case/repository/datasource lifecycle paths, SQLite schema declarations and migration tests, document requirements, and accounting settlement allocation. No currency, tax rate, or posting policy is changed.
