## Why

German freelancers and small businesses (§19 UStG) need a cross-platform desktop invoicing application that handles the complete lifecycle from draft to payment, with integrated accounting that produces GoBD-compliant tax exports (EÜR, UStVA, EKS, GuV, ZM, DATEV). No existing open-source solution covers all these requirements in a single desktop application.

## What Changes

- **New**: Complete invoicing system with 7 document types (Rechnung, Storno, Gutschrift, Angebot, Auftrag, Proforma, Lieferschein)
- **New**: Full accounting suite (Journal, EÜR, UStVA, EKS, GuV, ZM, DATEV EXTF export)
- **New**: 38-table SQLite database with GoBD-compliant trigger protection
- **New**: PDF generation for all document types with ZUGFeRD/XRechnung e-invoicing
- **New**: Bank CSV/XML import with auto-categorization and deduplication
- **New**: 4-level dunning system (Mahnwesen) with mail integration
- **New**: Configurable dashboard with 13+ widgets
- **New**: Multi-profile system with isolated databases
- **New**: Local + encrypted external + SMB backup
- **New**: Desktop integration (system tray, global shortcuts, auto-update)

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
None — greenfield project.

## Impact

- **New project**: `flutter create openinvoices`
- **Dependencies**: drift, riverpod, go_router, dio, pdf, system_tray, hotkey_manager, window_manager, auto_updater
- **Target platforms**: Windows, macOS, Linux
- **Database**: SQLite with 38 tables, ~200 columns
- **PDF templates**: 2 (Standard, Grün/Kleinunternehmer)
- **Bank templates**: 15+ predefined CSV formats
- **Tax forms**: EÜR Anlage 2025, UStVA, EKS Anlage, GuV §141, ZM
