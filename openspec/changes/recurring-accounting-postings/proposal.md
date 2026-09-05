# Proposal: Make recurring invoice and booking-template postings tax-aware

## Why

Recurring invoice generation forces every position to 19 percent and computes gross as net times 1.19, ignoring 7 percent, zero-rate, or mixed-rate templates. Direct recurring bookings write the full gross expense as Vorsteuer, overstating tax claims.

Evidence: lib/features/recurring/rechnungsvorlagen_repository.dart:298-332 hardcodes 19 percent; lib/features/recurring/buchungsvorlagen_repository.dart:283-295 stores the full expense amount as vorsteuer_betrag.

## What Changes

- Preserve each recurring invoice position's tax rate and calculate net, VAT, and gross per position.
- Derive input tax from gross expense amounts and explicit tax rates for recurring bookings.
- Make generated recurring postings visible to UStVA and idempotent across schedule retries.

## Capabilities

- Make recurring invoice and booking-template postings tax-aware
- Priority: High
- Dependencies: invoice-money-invariants; journal-integrity-and-snapshots; tax-reporting-and-export-integrity.

## Impact

lib/features/recurring/rechnungsvorlagen_repository.dart, buchungsvorlagen_repository.dart, accounting reporting integration, and recurring tests.
