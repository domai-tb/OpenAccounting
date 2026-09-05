# Proposal: Enforce invoice money and discount invariants

## Why

Invoice discount validation skips total consistency when a line discount exists, persists caller-supplied totals, normalizes negative values with abs, and does not reject invalid discount bounds. Preview and persisted totals can therefore disagree.

Evidence: lib/pages/rechnungen/rechnungen_usecases.dart:152 skips consistency checks when discounts exist and :180 applies abs; lib/pages/rechnungen/rechnungen_datasource.dart:74 persists caller totals; vorschau_service.dart:32 and :62 calculate independently without bounds rejection.

## What Changes

- Use one authoritative calculation for line discounts, net, VAT, and gross totals.
- Reject negative prices/totals and discount percentages outside the allowed range.
- Validate persisted totals against calculated positions for every invoice path.

## Capabilities

- Enforce invoice money and discount invariants
- Priority: High
- Dependencies: schema-evolution-safety.

## Impact

lib/pages/rechnungen/rechnungen_usecases.dart, rechnungen_datasource.dart, vorschau_service.dart, and invoice money tests.
