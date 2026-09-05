# Design: Expose and harden the bank-import workflow

## Context

The parser/import service is implemented and tested, but Banking is a static route. During persistence, row insert failures are swallowed while import history can still report success; auto-categorized counts are incremented before insertion and no failure diagnostics are recorded.

## Goals

Bank import is a user-controlled, auditable workflow rather than a parser-only service.

## Non-Goals

Adding online bank connectivity; existing file formats remain the input boundary.

## Decisions

Separate parse/review/persist states, keep source history immutable, and make row outcomes explicit rather than swallowing errors.

## Risks / Trade-offs

Atomic batch versus partial import changes recovery expectations; choose and document one policy before implementation.

## Migration Plan

Add route and failure-injection tests, introduce row outcome/history fields, then connect the existing parser/service to the UI.

## Open Questions

Should the product default to all-or-nothing imports or allow partial import with mandatory review of failures?
