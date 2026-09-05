## Why

PDF template specs Rabatt/Position/PaymentBlock/Mahnung/Einleitung still red; dedicated change isolates printing and template logic.

## What Changes

- Split from openinvoices monolith for agent-friendly scope (<15 tasks)
- Implements deferred/red specs for pdf-template-polish
- VM-safe fakes, DESIGN.md alignment

## Capabilities

### New Capabilities
- pdf-rabatt: discount display
- pdf-position: table
- pdf-payment-block: payment info
- pdf-mahnung: dunning PDF

### Modified Capabilities
- none — additive

## Impact

- Affected: lib/features/*, test/features/*
- Dependencies: existing drift/riverpod, no new heavy deps
