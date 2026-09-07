# Proposal: Preserve fractional inventory quantities

## Why

Inventory adjustments store the current quantity as a numeric bestand_aktuell and then synchronize a legacy bestand column with neuerBestand.toInt(), losing valid decimal quantities. The inventory warning path reads the numeric value, so different consumers can disagree.

Evidence: lib/features/inventory/lager_repository.dart:39-65 updates bestand_aktuell but writes bestand=neuerBestand.toInt(), while warnings use the numeric value.

## What Changes

- Define one precision and unit contract for inventory quantities.
- Synchronize legacy/read models without truncating fractional stock.
- Add adjustment, warning, invoice, and reload round-trip coverage.

## Capabilities

- Preserve fractional inventory quantities
- Priority: Medium
- Dependencies: schema-evolution-safety; primary-workspace-exposure.

## Impact

lib/features/inventory/lager_repository.dart, inventory schema/migrations, dashboard/invoice consumers, and inventory tests.
