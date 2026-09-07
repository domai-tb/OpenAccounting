## Why

Strict validation (`openspec validate --specs --strict`) reports 15 failing maintained specifications. All fail because they lack a `## Purpose` section and use `## ADDED Requirements` instead of `## Requirements`. This blocks the release gate and prevents downstream changes from depending on validated specs.

## What Changes

Add `## Purpose` sections and fix `## Requirements` headers across all 15 failing maintained specifications. Also fix RFC 2119 keyword gaps and long-requirement splitting in `stammdaten`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `accounting`: Add Purpose section, fix Requirements header
- `app`: Add Purpose section, fix Requirements header
- `backup`: Add Purpose section, fix Requirements header
- `bank-import`: Add Purpose section, fix Requirements header
- `dashboard`: Add Purpose section, fix Requirements header
- `db`: Add Purpose section, fix Requirements header
- `desktop`: Add Purpose section, fix Requirements header
- `documents`: Add Purpose section, fix Requirements header
- `einkommen`: Add Purpose section, fix Requirements header
- `inventory`: Add Purpose section, fix Requirements header
- `mahnwesen`: Add Purpose section, fix Requirements header
- `profiles`: Add Purpose section, fix Requirements header
- `recurring`: Add Purpose section, fix Requirements header
- `setup`: Add Purpose section, fix Requirements header
- `stammdaten`: Add Purpose section, fix Requirements header, add SHALL/MUST keywords, shorten long requirement

## Impact

`openspec/specs/*/spec.md` — 15 spec files edited. No code, no tests, no runtime behavior changes.
