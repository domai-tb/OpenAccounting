# Design: Complete desktop lifecycle persistence and command integrations

## Context

Window state has two incompatible storage implementations and no lifecycle save caller. Shortcut callbacks are no-ops and target /invoices/new even though routing treats new as an ID. Tray actions are empty, while updater download/install are stubs and signature verification accepts only the literal valid.

## Goals

Desktop lifecycle and commands are reliable, testable, and safe to ship.

## Non-Goals

Adding cloud update infrastructure or changing platform packaging dependencies.

## Decisions

Use injected window/shortcut/tray/updater adapters, one canonical persistence owner, and cryptographic verification independent of test literals.

## Risks / Trade-offs

Host platform dependencies may prevent full Linux build verification; maintain VM tests plus platform smoke tests.

## Migration Plan

Resolve min-size/key ownership, add production-service tests, then wire lifecycle/commands and updater adapters.

## Open Questions

Which release manifest and trusted-key distribution mechanism will be used for production updates?
