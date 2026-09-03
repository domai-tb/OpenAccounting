# Implementation Tasks: OpenInvoices

> Red-green-refactor ordering. Each task group maps to a spec capability.
> Full test-plan with 669 scenario→test mappings in test-plan.md.

## 1. Project Setup

- [x] 1.1 Write failing test: `test/core/setup_test.dart` — app creates database connection on startup
- [x] 1.2 Implement: `flutter create openinvoices`, add dependencies (drift, riverpod, go_router, dio, pdf, system_tray, hotkey_manager, window_manager, auto_updater)
- [x] 1.3 Refactor; full suite stays green

## 2. Core Theme & Routing

- [x] 2.1 Write failing test: `test/core/theme_test.dart` — theme switches between light/dark/system
- [x] 2.2 Implement: Material 3 theme with German locale, light/dark/system mode
- [x] 2.3 Write failing test: `test/core/router_test.dart` — setup guard redirects to wizard on empty DB
- [x] 2.4 Implement: GoRouter with shell route, nested navigation, setup redirect guard
- [x] 2.5 Refactor; full suite stays green

## 3. API Client

- [x] 3.1 Write failing test: `test/core/api_test.dart` — Dio retries on 5xx, times out after 30s
- [x] 3.2 Implement: Dio client with retry interceptor, timeout, port detection
- [x] 3.3 Write failing test: `test/core/api_test.dart` — 422 response parses detail fields
- [x] 3.4 Implement: Error handling with 422 detail parsing, connection-refused detection
- [x] 3.5 Refactor; full suite stays green

## 4. Database Schema (38 tables)

- [x] 4.1 Write failing test: `test/db/schema_test.dart` — all 38 tables exist after database creation
- [x] 4.2 Implement: drift tables for kunden, lieferanten, artikel, rechnungen, rechnungspositionen, journal, kategorien, unternehmen, nummernkreise, ust_saetze, konten, bank_transaktionen, bank_templates, bank_imports, kunden_belege, kunden_lieferadressen, artikel_gruppen, rechnungsvorlagen, buchungsvorlagen, anlageverzeichnis, dokumentenpakete, dokumentenpaket_belege, mahnungen, mahnstufen, mahnwesen_einstellungen, forderungen, tagesabschluesse, belege, ustva_exporte, euer_exporte, eks_exporte, datev_export_log, eu_laender, eks_einstellungen, vorsteuer_ansprueche, schnellbuchungen, auto_filter_regeln, import_mapping_vorlagen
- [x] 4.3 Write failing test: `test/db/schema_test.dart` — NUMERIC(12,2) for all money columns, NUMERIC(12,4) for vk_netto
- [x] 4.4 Implement: Column type constraints for monetary precision
- [x] 4.5 Refactor; full suite stays green

## 5. Database Migrations & GoBD

- [x] 5.1 Write failing test: `test/db/migration_test.dart` — schema version increments on migration
- [x] 5.2 Implement: PRAGMA user_version versioning, migration runner with backup-before-migrate
- [x] 5.3 Write failing test: `test/db/gobd_test.dart` — UPDATE on immutable journal row is rejected
- [x] 5.4 Implement: GoBD triggers (protect_journal_insert, protect_journal_update, protect_journal_delete)
- [x] 5.5 Write failing test: `test/db/seed_test.dart` — seed data populated on fresh database
- [x] 5.6 Implement: Seed data (kategorien, ust_saetze, nummernkreise, bank_templates, eu_laender)
- [x] 5.7 Refactor; full suite stays green

## 6. Profile System

- [x] 6.1 Write failing test: `test/db/profile_test.dart` — switching profile changes database path
- [x] 6.2 Implement: profile.json pointer, APP_DATA_DIR per profile, restart requirement
- [x] 6.3 Write failing test: `test/db/profile_test.dart` — profile isolation prevents cross-profile data access
- [x] 6.4 Implement: Profile-scoped database connections
- [x] 6.5 Refactor; full suite stays green

## 7. Backup System

- [x] 7.1 Write failing test: `test/db/backup_test.dart` — backup creates WAL-safe copy with rotation
- [x] 7.2 Implement: Local backup with sqlite3.backup(), rotation (max 5)
- [x] 7.3 Write failing test: `test/db/backup_test.dart` — encrypted backup uses AES-256-GCM
- [x] 7.4 Implement: External encrypted backup, SMB backup
- [x] 7.5 Refactor; full suite stays green

## 8. Master Data (Stammdaten)

- [ ] 8.1 Write failing test: `test/features/stammdaten/kunden_test.dart` — create/read/update/delete Kunden
- [ ] 8.2 Implement: Kunden CRUD with all fields (20+), Debitor-Nr auto-assign
- [ ] 8.3 Write failing test: `test/features/stammdaten/lieferanten_test.dart` — create/read/update/delete Lieferanten
- [ ] 8.4 Implement: Lieferanten CRUD, Kreditor-Nr auto-assign
- [ ] 8.5 Write failing test: `test/features/stammdaten/artikel_test.dart` — artikel with 4 types, VK-Preise precision
- [ ] 8.6 Implement: Artikel CRUD, vk_eingabe flag, NUMERIC(12,4) precision
- [ ] 8.7 Write failing test: `test/features/stammdaten/unternehmen_test.dart` — 80+ fields saved correctly
- [ ] 8.8 Implement: Unternehmen CRUD with all sub-features (SMTP, PDF, logo, etc.)
- [ ] 8.9 Write failing test: `test/features/stammdaten/kategorien_test.dart` — SKR03/04 mapping, euer_zeile
- [ ] 8.10 Implement: Kategorien CRUD with SKR/EÜR/eks mapping
- [ ] 8.11 Refactor; full suite stays green

## 9. Invoicing (Rechnungen)

- [x] 9.1 Write failing test: `test/features/rechnungen/erstellung_test.dart` — create draft invoice
- [x] 9.2 Implement: Rechnung creation with positions, Entwurf mode
- [x] 9.3 Write failing test: `test/features/rechnungen/finalisierung_test.dart` — finalization locks document, assigns nummer
- [ ] 9.4 Implement: Finalization flow (lock, PDF generate, nummernkreis)
- [ ] 9.5 Write failing test: `test/features/rechnungen/storno_test.dart` — Storno creates negative amounts
- [ ] 9.6 Implement: Storno with Stornogrund, Stornodatum, own nummernkreis
- [ ] 9.7 Write failing test: `test/features/rechnungen/gutschrift_test.dart` — Gutschrift references original
- [ ] 9.8 Implement: Gutschrift with bidirectional link
- [ ] 9.9 Write failing test: `test/features/rechnungen/ketten_test.dart` — Angebot → Auftrag → LS → Rechnung conversion
- [ ] 9.10 Implement: Document conversion chains with position propagation
- [ ] 9.11 Write failing test: `test/features/rechnungen/eingabemodus_test.dart` — netto and brutto produce correct totals
- [ ] 9.12 Implement: Server-side preview as single source of truth
- [ ] 9.13 Refactor; full suite stays green

## 10. PDF Generation

- [x] 10.1 Write failing test: `test/features/pdf/rechnung_test.dart` — PDF contains company header, positions, total
- [x] 10.2 Implement: Rechnung PDF with Standard template
- [x] 10.3 Write failing test: `test/features/pdf/angebot_test.dart` — PDF contains Angebot-specific fields
- [x] 10.4 Implement: All 7 document type PDFs (Rechnung, Storno, Gutschrift, Angebot, Auftrag, Proforma, Lieferschein)
- [x] 10.5 Write failing test: `test/features/pdf/einleitungstext_test.dart` — per-type text appears in PDF
- [ ] 10.6 Implement: Einleitungstext/Schlusstext per document type, no cross-fallback
- [ ] 10.7 Write failing test: `test/features/pdf/kopie_test.dart` — copy shows KOPIE watermark
- [ ] 10.8 Implement: KOPIE watermark on document copies
- [ ] 10.9 Refactor; full suite stays green

## 11. Accounting (Buchhaltung)

- [x] 11.1 Write failing test: `test/features/accounting/journal_test.dart` — booking creates immutable entry
- [x] 11.2 Implement: Journal with GoBD trigger protection
- [x] 11.3 Write failing test: `test/features/accounting/euer_test.dart` — EÜR output matches line items
- [x] 11.4 Implement: EÜR Anlage 2025 with 60+ line items
- [x] 11.5 Write failing test: `test/features/accounting/ustva_test.dart` — UStVA KZ calculation correct
- [x] 11.6 Implement: UStVA KZ 1-22, monthly/quarterly
- [x] 11.7 Write failing test: `test/features/accounting/eks_test.dart` — EKS produces 9-page form
- [x] 11.8 Implement: Anlage EKS for Jobcenter Transferleistungen
- [x] 11.9 Write failing test: `test/features/accounting/datev_test.dart` — DATEV EXTF export valid
- [x] 11.10 Implement: DATEV EXTF Buchungsstapel export
- [x] 11.11 Refactor; full suite stays green

## 12. Bank Import

- [x] 12.1 Write failing test: `test/features/bank_import/upload_test.dart` — CSV parses into transactions
- [x] 12.2 Implement: CSV upload and parsing with bank templates
- [x] 12.3 Write failing test: `test/features/bank_import/dedup_test.dart` — duplicate hash prevents re-import
- [x] 12.4 Implement: SHA-256 deduplication, auto-categorization rules
- [x] 12.5 Write failing test: `test/features/bank_import/camt_test.dart` — CAMT XML parses correctly
- [x] 12.6 Implement: CAMT XML import support
- [x] 12.7 Refactor; full suite stays green

## 13. Dunning (Mahnwesen)

- [x] 13.1 Write failing test: `test/features/mahnwesen/stufen_test.dart` — 4 levels configured correctly
- [x] 13.2 Implement: Mahnstufen CRUD with system_stufe protection
- [x] 13.3 Write failing test: `test/features/mahnwesen/mahnung_test.dart` — dunning creates snapshot
- [x] 13.4 Implement: Mahnung creation with rechnung snapshot, Gebühr/Zinsen tracking
- [x] 13.5 Write failing test: `test/features/mahnwesen/sperrung_test.dart` — Kundensperrung at threshold
- [x] 13.6 Implement: Kundensperrung (warnung + sperrung), Mahnsperre per Kunde
- [x] 13.7 Refactor; full suite stays green

## 14. Dashboard

- [x] 14.1 Write failing test: `test/features/dashboard/widgets_test.dart` — all 13+ widgets render
- [x] 14.2 Implement: Widget providers for Offene Rechnungen, Zahlungseingänge, Lagerwarnung, etc.
- [ ] 14.3 Write failing test: `test/features/dashboard/config_test.dart` — widget order persists
- [ ] 14.4 Implement: Dashboard config (Reihenfolge, Sichtbarkeit, Schnellzugriff)
- [ ] 14.5 Refactor; full suite stays green

## 15. Desktop Integration

- [ ] 15.1 Write failing test: `test/features/desktop/tray_test.dart` — system tray shows icon
- [ ] 15.2 Implement: System tray with context menu
- [ ] 15.3 Write failing test: `test/features/desktop/shortcuts_test.dart` — global shortcuts registered
- [ ] 15.4 Implement: Global keyboard shortcuts (Ctrl+F, Ctrl+Shift+E, +, E/A)
- [ ] 15.5 Write failing test: `test/features/desktop/update_test.dart` — auto-update checks GitHub Releases
- [ ] 15.6 Implement: Auto-updater for GitHub Releases
- [ ] 15.7 Refactor; full suite stays green

## 16. Receivables & Inventory

- [ ] 16.1 Write failing test: `test/features/einkommen/forderungen_test.dart` — Überzahlung creates Forderung
- [ ] 16.2 Implement: Forderungen table, Überzahlungs-Protokoll, Forderungsausgang
- [ ] 16.3 Write failing test: `test/features/inventory/lager_test.dart` — stock decrements on finalization
- [ ] 16.4 Implement: Lagerführung with stock decrement/restore, Mindestbestand warnings
- [ ] 16.5 Refactor; full suite stays green

## 17. Setup Wizard

- [ ] 17.1 Write failing test: `test/features/setup/wizard_test.dart` — 4-step wizard completes
- [ ] 17.2 Implement: 4-step wizard (Stammdaten → Konten → Kategorien → Abschluss)
- [ ] 17.3 Write failing test: `test/features/setup/kassenbestand_test.dart` — initial cash balance set
- [ ] 17.4 Implement: Kassenbestand initialization
- [ ] 17.5 Refactor; full suite stays green

## 18. Recurring Templates

- [ ] 18.1 Write failing test: `test/features/recurring/rechnungsvorlagen_test.dart` — template creates invoice on schedule
- [ ] 18.2 Implement: Rechnungsvorlagen with interval, positionen, Artikelverknüpfung
- [ ] 18.3 Write failing test: `test/features/recurring/buchungsvorlagen_test.dart` — booking template auto-generates
- [ ] 18.4 Implement: Buchungsvorlagen with direkt/beleg modus
- [ ] 18.5 Refactor; full suite stays green
