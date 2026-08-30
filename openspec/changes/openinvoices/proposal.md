## Why

OpenAccounting is an existing Flutter desktop application for German freelancers and small businesses (§19 UStG). This change extends it with an invoicing workflow that handles the complete lifecycle from draft to payment, with integrated accounting that produces GoBD-compliant tax exports (EÜR, UStVA, EKS, GuV, ZM, DATEV). The change is brownfield: existing local-first architecture and application services remain authoritative.

## What Changes

- **New**: Complete invoicing system with 7 document types (Rechnung, Storno, Gutschrift, Angebot, Auftrag, Proforma, Lieferschein)
- **New**: Full accounting suite (Journal, EÜR, UStVA, EKS, GuV, ZM, DATEV EXTF export)
- **New**: 38-table base SQLite schema with GoBD-compliant trigger protection and explicitly named feature migrations
- **New**: PDF generation for all document types with ZUGFeRD/XRechnung e-invoicing
- **New**: Bank CSV/XML import with auto-categorization and deduplication
- **New**: 4-level dunning system (Mahnwesen) with mail integration
- **New**: Configurable dashboard with 13+ widgets
- **New**: Multi-profile system with isolated databases
- **New**: Local profile backup plus explicitly approved encrypted external and SMB backup targets
- **New**: Flutter-native desktop integration (system tray, global shortcuts, optional auto-update)

## Capabilities

### New Capabilities
- `app`: Core Flutter shell, routing, theme, keyboard shortcuts
- `db`: 38 SQLite tables, schema versioning, migrations, GoBD triggers
- `pdf`: PDF generation for 7 document types, templates, e-invoicing
- `accounting`: Journal, EÜR, UStVA, EKS, GuV, ZM, DATEV export
- `stammdaten`: Master data CRUD (Kunden, Lieferanten, Artikel, Unternehmen)
- `documents`: Document lifecycle, Storno, Gutschrift, conversion chains
- `bank-import`: CSV/XML import, templates, auto-categorization, dedup
- `mahnwesen`: 4-level dunning, mail, PDF, Kundensperrung
- `recurring`: Recurring invoice and booking templates
- `backup`: Local, encrypted external, SMB backup with rotation
- `setup`: 4-step wizard, profile selection
- `dashboard`: 13+ configurable widgets with drag-and-drop
- `desktop`: System tray, global shortcuts, auto-update
- `einkommen`: Receivables, Kontokorrent, Forderungen
- `inventory`: Light stock management per article
- `profiles`: Multi-profile with isolated databases

### Modified Capabilities
- Existing OpenAccounting shell, dependency injection, local database, and feature-service boundaries are retained and extended.

## Impact

- **Existing project**: extend the current OpenAccounting Flutter desktop app; do not recreate the project or replace its architecture.
- **Architecture**: retain GetIt, AppScope, AppServices, and Page → UseCase → Repository → DataSource. Riverpod, Tauri, a Python sidecar, and backend authentication are not required for local-first behavior.
- **Dependencies**: use existing dependencies where possible; Dio remains optional behind data-source boundaries.
- **Target platforms**: Windows, macOS, Linux
- **Database**: SQLite with a 38-table base schema, ~200 columns, and explicitly named feature-migration tables
- **PDF templates**: `pdf_vorlage` values `standard` and `gruen`; unknown values fall back to `standard`
- **Backups**: local backups below the active profile `APP_DATA_DIR`; USB/NAS/SMB targets are separate, explicit opt-in destinations
- **Bank templates**: 15+ predefined CSV formats
- **Tax forms**: EÜR Anlage 2025, UStVA, EKS Anlage, GuV §141, ZM
