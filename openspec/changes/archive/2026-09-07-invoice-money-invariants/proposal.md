# Proposal: Enforce invoice money and discount invariants

## Why

Invoice validation skips aggregate checks when a line discount exists, persists caller-supplied line totals, silently
normalizes negative values with `abs`, and does not reject invalid discount bounds. Preview, drafts, finalization, and
generated corrections can therefore disagree.

Evidence: `lib/pages/rechnungen/rechnungen_usecases.dart` skips discounted-line consistency and normalizes signed
values; `rechnungen_datasource.dart` stores caller line totals and calculates corrections separately;
`vorschau_service.dart` uses a second floating-point calculation without complete bounds validation.

## What Changes

- Introduce one integer/rational invoice calculator for line discounts, tax buckets, document discounts, net, VAT,
  gross, and generated correction signs.
- Reject invalid external money/discount inputs with stable domain error codes and line identifiers.
- Enforce the same calculation at preview, use-case, direct persistence, finalization, conversion, Gutschrift, and
  Storno boundaries.
- Preserve four-decimal unit-price input, three-decimal quantity input, two-decimal persisted money, and signed
  internally generated correction documents.

## Capabilities

### New Capabilities

- `invoice-money-invariants`: Deterministic invoice arithmetic and validation shared by every invoice lifecycle path.

### Modified Capabilities

- `documents`: Drafts and generated corrections use one validated calculation and sign policy.
- `stammdaten`: Four-decimal article prices remain valid inputs and round only at the invoice-position money boundary.
- `pdf`: Generated Gutschrift and Storno amounts remain negative after validating their positive source document.

Priority: High. Dependency: `schema-evolution-safety`.

## Impact

`lib/pages/rechnungen/` calculator, use cases, datasource, preview service, domain errors, and invoice integration tests.
No database schema change is required.
