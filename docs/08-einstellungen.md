# 08 – Einstellungen & Setup (Settings and Configuration)

## Overview

OpenInvoices provides a 4-step Setup Wizard for initial configuration, multi-profile management, comprehensive backup system (local, encrypted external, SMB), SMTP configuration with certificate pinning, and printer/export settings.

---

## Setup Wizard

Four-step wizard for first-time configuration:

### Step 1: Unternehmen (Company Data)

```
┌──────────────────────────────────────┐
│ Schritt 1 von 4: Unternehmen        │
├──────────────────────────────────────┤
│ Firmenname: [________________]       │
│ Straße:     [________________]       │
│ Hausnummer: [________________]       │
│ PLZ:        [________________]       │
│ Ort:        [________________]       │
│ Land:       [DE ▼]                   │
│ USt-IdNr:   [________________]       │
│ Steuernummer:[_______________]       │
│                                      │
│ Tätigkeit: (•) Freiberufler          │
│            ( ) Gewerbe               │
│            ( ) Gemischt              │
│                                      │
│ [Weiter →]                           │
└──────────────────────────────────────┘
```

### Step 2: Konten (Bank Accounts)

```
┌──────────────────────────────────────┐
│ Schritt 2 von 4: Konten             │
├──────────────────────────────────────┤
│ Bezeichnung: [Geschäftskonto___]     │
│ IBAN:        [DE________________]    │
│ BIC:         [________________]      │
│ Anbieter:    [________________]      │
│                                      │
│ [+ Weiteres Konto hinzufügen]        │
│                                      │
│ [← Zurück]  [Weiter →]              │
└──────────────────────────────────────┘
```

### Step 3: Nummernkreise (Number Sequences)

```
┌──────────────────────────────────────┐
│ Schritt 3 von 4: Nummernkreise      │
├──────────────────────────────────────┤
│ Rechnung:    RE-YY####  [Standard]  │
│ Storno:      STORNO-YY#### [Standard]│
│ Gutschrift:  GS-YY####  [Standard]  │
│ Angebot:     ANG-YY#### [Standard]  │
│ Auftrag:     AU-YY####  [Standard]  │
│ Proforma:    PRF-YY#### [Standard]  │
│ Lieferschein:LS-YY####  [Standard]  │
│                                      │
│ [← Zurück]  [Weiter →]              │
└──────────────────────────────────────┘
```

### Step 4: Einrichtung abschließen (Finalize)

```
┌──────────────────────────────────────┐
│ Schritt 4 von 4: Fertig!            │
├──────────────────────────────────────┤
│ ✓ Unternehmen gespeichert            │
│ ✓ Konten angelegt                   │
│ ✓ Nummernkreise initialisiert       │
│ ✓ Kategorien geladen (65+)          │
│ ✓ USt-Sätze konfiguriert            │
│                                      │
│ [Dashboard öffnen →]                 │
└──────────────────────────────────────┘
```

### Wizard Data Sources

| Step | Tables | Seed Data |
|------|--------|-----------|
| 1 | `unternehmen` | — |
| 2 | `konten` | — |
| 3 | `nummernkreise` | Standard formats |
| 4 | `kategorien`, `ust_saetze` | 65+ categories, 3 tax rates |

---

## Multi-Profile

### Profile Manager

Each profile maintains an isolated database:

```
~/.local/share/openinvoices/
├── profile/
│   ├── Hauptgeschäft/
│   │   ├── openinvoices.db
│   │   ├── uploads/
│   │   └── backups/
│   └── Nebengeschäft/
│       ├── openinvoices.db
│       ├── uploads/
│       └── backups/
├── profile.json          # Active profile pointer
└── backups/              # Global backups
```

### Profile Switching

```json
{
  "active_profile": "Hauptgeschäft",
  "profiles": [
    {"name": "Hauptgeschäft", "created": "2025-01-15"},
    {"name": "Nebengeschäft", "created": "2025-03-20"}
  ]
}
```

- `APP_DATA_DIR` always points to active profile
- Profile switch requires process restart
- Multiple profiles visible when >1 exists (independent of `profilmanager_aktiv` toggle)

### Feature Toggle

```json
{
  "profilmanager_aktiv": false
}
```

- Default: hidden
- Activated in Einstellungen → Unternehmen → Funktionen
- Remains visible once >1 profile exists

---

## Backup System

### Local Backup

Automatic backup before every migration:

```python
def _backup_datenbank():
    source = sqlite3.connect(db_path)
    target = sqlite3.connect(backup_path)
    source.backup(target)
    # Rotation: max 5 backups
    # Target: ~/.local/share/openinvoices/backups/
    # Filename: openinvoices_YYYYMMDD_HHMMSS.db
```

### External Backup (Encrypted)

AES-256-GCM encrypted backup to external path:

```json
{
  "backup_extern_pfad_1": "/mnt/nas/backups/openinvoices/",
  "backup_extern_pfad_1_lokal_ok": false,
  "backup_extern_pfad_2": "/media/usb/backups/",
  "backup_extern_pfad_2_lokal_ok": true,
  "backup_extern_passwort": "encrypted_key_here"
}
```

### System Laufwerk Check

`_ist_systemlaufwerk()` prevents backing up to system drives:

- Windows: C:\, D:\ (system volumes)
- Linux: /, /boot, /home (root filesystems)
- macOS: /, /System, /Library

Override per path: `backup_extern_pfad_*_lokal_ok = true`

### SMB Backup

Network backup via SMB protocol:

```json
{
  "backup_smb_benutzer": "backup_user",
  "backup_smb_passwort": "encrypted"
}
```

- Uses `smbprotocol` library (no system mount required)
- Path format: `smb://server/share/backups/`
- Authentication stored encrypted

### Backup Rotation

- Local: max 5 backups (oldest deleted automatically)
- External: configurable retention
- Encrypted backups: same rotation policy

---

## SMTP Configuration

### Settings

```json
{
  "smtp_aktiv": true,
  "smtp_host": "smtp.gmail.com",
  "smtp_port": 587,
  "smtp_ssl": true,
  "smtp_user": "user@gmail.com",
  "smtp_passwort": "app_password_here",
  "smtp_von_adresse": "rechnung@meinunternehmen.de"
}
```

### SSL/TLS Modes

| Port | Mode | Description |
|------|------|-------------|
| 587 | STARTTLS | Upgrade from plain to TLS |
| 465 | SSL/TLS | Direct SSL connection |
| 25 | Plain | Unencrypted (not recommended) |

### Certificate Pinning

Trust-on-First-Use (TOFU) for self-signed certificates:

```json
{
  "smtp_zertifikat_ignorieren": false,
  "smtp_zertifikat_fingerprint": null
}
```

#### Flow

1. First connection: store SHA-256 fingerprint of presented certificate
2. Subsequent connections: verify fingerprint matches exactly
3. Mismatch → abort before sending credentials
4. Reset: manual action in Einstellungen → SMTP

#### Override

```json
{
  "smtp_zertifikat_ignorieren": true
}
```

Opt-in to accept any certificate (including self-signed). Only recommended with TOFU fingerprinting active.

### Mail Templates

Per-document-type templates:

```json
{
  "mail_betreff_angebot": "Ihr Angebot {rechnungsnummer}",
  "mail_text_angebot": "Sehr geehrte Damen und Herren,\n\nanbei erhalten Sie unser Angebot...",
  "mail_betreff_rechnung": "Ihre Rechnung {rechnungsnummer}",
  "mail_text_rechnung": "Sehr geehrte Damen und Herren,\n\nanbei erhalten Sie Ihre Rechnung...",
  "mail_betreff_proforma": "Proforma-Rechnung {rechnungsnummer}",
  "mail_text_proforma": "Sehr geehrte Damen und Herren,\n\nanbei erhalten Sie die Proforma-Rechnung...",
  "mail_betreff_auftrag": "Auftrag {rechnungsnummer}",
  "mail_text_auftrag": "Sehr geehrte Damen und Herren,\n\nhiermit bestätigen wir Ihren Auftrag...",
  "mail_betreff_lieferschein": "Lieferschein {rechnungsnummer}",
  "mail_text_lieferschein": "Sehr geehrte Damen und Herren,\n\nanbei erhalten Sie Ihren Lieferschein..."
}
```

Placeholders: `{rechnungsnummer}`, `{betrag}`, `{faelligkeit}`, `{firma}`.

---

## Printer & Export Settings

### PDF Vorlagen

```json
{
  "pdf_vorlage": "standard"
}
```

Available templates: `standard`, `modern`, `minimal`.

### Print Configuration

- Default printer selection (OS-level)
- Copies: default 1
- Duplex: optional
- Paper size: A4 (standard)

### Export Formats

| Format | Content-Disposition | Usage |
|--------|-------------------|-------|
| PDF | `inline` | Display in WebviewWindow |
| CSV | `attachment` | Download data export |
| ZIP | `attachment` | Bulk document export |
| JSON | `attachment` | Backup/data exchange |

---

## Feature Toggles

All features controlled via `unternehmen` flags:

```json
{
  "angebote_aktiv": true,
  "proforma_aktiv": false,
  "auftraege_aktiv": false,
  "wiederkehrend_aktiv": false,
  "buchungsvorlagen_aktiv": false,
  "bank_import_aktiv": false,
  "lagerführung_aktiv": false,
  "guv_aktiv": false,
  "kontenuebersicht_aktiv": false,
  "profilmanager_aktiv": false,
  "datenmigration_aktiv": false
}
```

### Visibility Rules

- Features hidden when disabled
- Menu items filtered by active features
- Dashboard widgets respect feature flags (e.g., Lagerwarnung only when `lagerführung_aktiv`)

### Auto-Activation

Some features auto-activate based on data:

- `guv_aktiv`: Auto-activates when Umsatz > €800,000 or Gewinn > €80,000
- `profilmanager_aktiv`: Always visible when >1 profile exists

---

## Datenmigration (Data Import)

CSV-based import for customers, vendors, and articles:

```json
{
  "datenmigration_aktiv": true
}
```

### Import Flow

1. Upload CSV file
2. Map columns to fields (manual mapping UI)
3. Toggle header row detection
4. Choose duplicate strategy: Skip / Update / Create New
5. Save mapping template for reuse
6. Execute import with progress indicator

### Supported Entities

| Entity | Required Fields |
|--------|----------------|
| Kunden | firmenname |
| Lieferanten | firmenname |
| Artikel | bezeichnung, typ |

### Mapping Templates

```json
{
  "id": 1,
  "name": "Kunden Import Q1",
  "entity": "kunde",
  " mappings": {
    "firmenname": "Company Name",
    "mail": "Email",
    "telefon": "Phone"
  },
  "has_header": true,
  "duplicate_strategy": "skip"
}
```

---

## Technical Notes

- **Wizard isolation**: Only runs on empty database; never overwrites existing data
- **Profile restart**: `APP_DATA_DIR` change requires process restart (no hot-reload)
- **Backup WAL**: `sqlite3.backup()` is WAL-safe; consistent snapshot guaranteed
- **SMTP errors**: Specific error handling for `SSLCertVerificationError`, `SSLError`, `socket.gaierror`, `TimeoutError`, `ConnectionRefusedError`
- **Feature flags**: Stored in `unternehmen` table; read once on app start, cached in state
- **No hot-reload**: Settings changes require page refresh or app restart
