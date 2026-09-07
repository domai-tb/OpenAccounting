# Design: Preserve fractional inventory quantities

## Context

Inventory adjustments store the current quantity as a numeric bestand_aktuell and then synchronize a legacy bestand column with neuerBestand.toInt(), losing valid decimal quantities. The inventory warning path reads the numeric value, so different consumers can disagree.

## Goals

Inventory is numerically consistent across storage and every consumer.

## Non-Goals

Changing product units or warehouse valuation policy.

## Decisions

Store decimal quantities using one canonical representation and define an explicit compatibility strategy for legacy integer columns.

## Risks / Trade-offs

Existing integer consumers may need schema/API changes; migration must identify any data already truncated.

## Migration Plan

Add fractional round-trip/red tests, migrate compatibility storage, then update dashboard/invoice and warning consumers.

## Open Questions

What precision should be supported for each unit class (pieces, weight, volume, time)?
