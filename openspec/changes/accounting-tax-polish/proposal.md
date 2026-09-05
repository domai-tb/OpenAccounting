## Why

Accounting tax specs UStVA/EÜR/EKS/tax-calc/payment/skonto still red due to doc lag; splitting gives focused 15-task batches for SKR and period logic.

## What Changes

- Split from openinvoices monolith for agent-friendly scope (<15 tasks)
- Implements deferred/red specs for accounting-tax-polish
- VM-safe fakes, DESIGN.md alignment

## Capabilities

### New Capabilities
- accounting-ustva: KZ 1-22
- accounting-euer: EÜR lines
- accounting-eks: EKS 9-page
- accounting-tax-calc: 19%/7%/§19/§25a

### Modified Capabilities
- none — additive

## Impact

- Affected: lib/features/*, test/features/*
- Dependencies: existing drift/riverpod, no new heavy deps
