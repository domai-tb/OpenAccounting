# Design: Replace synthetic accounting and bank-import seed data

## Context

Fresh databases receive formulaic category names, arbitrary SKR numbers, generic EÜR lines, and no EKS mappings. The bank catalog is only 7-8 generic templates despite documented broader support. Reporting and import behavior therefore starts from data that is not domain-valid.

## Goals

Fresh profiles start with useful, auditable domain data rather than placeholders.

## Non-Goals

Supporting every bank in the market or importing external chart-of-accounts licensing data.

## Decisions

Keep seed data versioned and immutable by ID, separate catalog updates from user edits, and make unsupported formats explicit.

## Risks / Trade-offs

Curated accounting mappings need domain review; the OpenSpec acceptance fixture should be reviewed by an accountant.

## Migration Plan

Build a canonical seed manifest, add fresh/upgrade tests, then replace formulaic generation and reconcile static/DB bank catalogs.

## Open Questions

Which exact SKR03/SKR04 and bank-template source/version will be approved for distribution?
