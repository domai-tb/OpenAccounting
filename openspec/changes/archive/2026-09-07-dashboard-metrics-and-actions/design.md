# Design: Make dashboard metrics and actions truthful and navigable

## Context

Dashboard queries do not consistently exclude drafts/cancellations or apply a period, income/expense treats positive/negative values inconsistently with journal art, the VAT deadline is hardcoded, and several cards/quick links point to unrelated routes. Configuration changes are optimistic without rollback.

## Goals

The dashboard is a reliable decision surface rather than a decorative summary.

## Non-Goals

Changing the full visual card design; shared design concerns are in desktop-shell-and-design-quality.

## Decisions

Make period and profile/company scope explicit in the dashboard query contract and use semantic route intents instead of raw path strings.

## Risks / Trade-offs

Correct filtering may change headline values users currently see; provide drilldown explanations and migration notes.

## Migration Plan

Add fixture-based metric/action tests, introduce scoped query parameters and intent mappings, then wire period/config state.

## Open Questions

What should the default dashboard period be for a new profile?
