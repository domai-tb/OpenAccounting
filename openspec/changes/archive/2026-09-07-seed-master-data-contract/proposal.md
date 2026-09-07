# Proposal: Replace synthetic accounting and bank-import seed data

## Why

Fresh databases receive formulaic category names, arbitrary SKR numbers, generic EÜR lines, and no EKS mappings. The bank catalog is only 7-8 generic templates despite documented broader support. Reporting and import behavior therefore starts from data that is not domain-valid.

Evidence: lib/core/db/seed.dart:109-121 generates synthetic categories and omits eks_kategorie; :90-107 seeds only 8 templates; lib/features/bank_import/bank_template.dart:73-181 lists 7 templates; accounting/spec.md:39.

## What Changes

- Seed curated SKR03/SKR04 chart categories with valid EÜR and EKS mappings.
- Seed a deterministic, documented bank-template catalog with real format coverage.
- Version seed data and make upgrades idempotent without overwriting user edits.

## Capabilities

- Replace synthetic accounting and bank-import seed data
- Priority: High
- Dependencies: schema-evolution-safety.

## Impact

lib/core/db/seed.dart, bank_template.dart, seed migrations, fresh-profile fixtures, and accounting/import tests.
