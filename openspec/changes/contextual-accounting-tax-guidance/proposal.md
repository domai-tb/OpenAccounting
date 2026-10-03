## Why

Feature-map item 73 requires contextual explanations for accounting and tax-related fields, including VAT treatment, GoBD concepts, tax categories, invoice statuses, and special accounting situations. The production `/help` page currently shows static placeholder tiles for settings and invoices, and a source search finds no contextual accounting/tax field guidance. A single `bankPathHint` exists, but it does not explain business or tax choices. Without explanations near the control, users without bookkeeping experience must guess what the application expects.

## What Changes

- Add a reviewed, German/English explanation catalog for supported accounting and tax terms and decisions.
- Attach explanations to relevant fields and status controls through a typed, keyboard-accessible context-help affordance; expose the same entries in a searchable Help glossary.
- Explain what a choice means in this application and what downstream workflow it affects; do not recommend a tax treatment, infer a user's eligibility, or present the content as tax advice.
- Require an unavailable or review-needed state for guidance when no approved explanation exists, while keeping otherwise supported fields available; explain unresolved feature behavior without presenting it as supported.
- Follow `DESIGN.md` form labels, help-content width, keyboard focus, accessibility, localization, and narrow-window behavior.

## Capabilities

### New Capabilities

- `contextual-accounting-tax-guidance`: Defines reviewed in-context accounting/tax explanations and their Help glossary.

### Modified Capabilities

- `app`: Upgrade the Help placeholder into the glossary and require field-level context-help registration for supported accounting/tax controls.

## Impact

The shared form/help presentation API, `/help` page, supported accounting and tax forms/statuses, German and English ARB catalogs, and contributor guidance for new accounting/tax controls. No business data, tax calculation, category mapping, or posting behavior changes.
