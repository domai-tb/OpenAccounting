# Proposal: Make reversals and replacement documents financially consistent

## Why

Credit-note persistence forces ust_betrag to zero and sets gross equal to net even when positions carry VAT rates. Replacement duplicate protection checks a field that is not selected, so a second replacement can bypass the intended guard.

Evidence: lib/pages/rechnungen/rechnungen_datasource.dart:649-663 writes zero tax/gross=net for credit notes; :724-733 omits ersatzrechnung_id from the source query before checking it.

## What Changes

- Recalculate correction-document net, VAT, and gross totals from their signed positions and rates.
- Persist complete bidirectional source/replacement links and enforce one replacement where required.
- Ensure correction postings reverse the source financial effects without mutable or orphaned audit state.

## Capabilities

- Make reversals and replacement documents financially consistent
- Priority: High
- Dependencies: invoice-accounting-posting-lifecycle; journal-integrity-and-snapshots; invoice-money-invariants.

## Impact

lib/pages/rechnungen/rechnungen_datasource.dart and correction/integration tests; depends on invoice posting, journal, and money invariants.
