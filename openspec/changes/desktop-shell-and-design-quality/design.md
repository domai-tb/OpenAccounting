# Design: Bring shared desktop surfaces into the design and accessibility contract

## Context

The compact sidebar keeps full local-status text and does not bottom-pin Settings/Help, headers render inert search/filter controls on placeholders, monetary values can ellipsize or bypass privacy formatting, inspectors lack closed focus traversal, status chips advertise buttons without keyboard activation, and generic dialogs/error states are not action-specific.

## Goals

Shared shell components embody the desktop design and accessibility requirements consistently.

## Non-Goals

Implementing domain pages or changing the accounting calculations displayed by them.

## Decisions

Use semantic components with explicit capabilities, responsive layout constraints, and keyboard tests; do not rely on visual presence as evidence of actionability.

## Risks / Trade-offs

Accessibility and responsive behavior need platform-aware golden/manual checks in addition to VM widget tests.

## Migration Plan

Add breakpoint/semantics widget tests, refactor shared components, then migrate dashboard and primary pages to explicit state/action contracts.

## Open Questions

Which accessibility platform matrix and screen-reader labels are required for release?
