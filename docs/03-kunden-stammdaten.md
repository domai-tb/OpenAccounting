# 03 – Kunden & Stammdaten (Customer and Vendor Master Data)

## Overview

OpenInvoices maintains relational master data for customers (Kunden), vendors (Lieferanten), articles (Artikel), the owning company (Unternehmen), accounting categories (Kategorien), bank accounts (Konten), and document number sequences (Nummernkreise).

All master data is profile-scoped: each profile maintains its own dataset, isolated at the database level.

---

## Kunden (Customers)

### Fields

```json
{
  "id": 1,
  "kundennummer": "10001",
  "firmenname": "ACME GmbH",
  "ansprechpartner": "Max Mustermann",
  "strasse": "Berliner Str.",
  "hausnummer": "42",
  "plz": "10115",
  "ort": "Berlin",
  "land": "DE",
  "ust_idnr": "DE123456789",
  "ust_idnr_validiert": true,
  "ust_idnr_validierung_datum": "2025-03-15",
  "steuernummer_ausland": "CHE-123.456.789",
  "telefon": "+49 30 123456",
  "mail": "info@acme.de",
  "z_hd": "Herr Mustermann",
  "zugferd_aktiv": false,
  "skonto_prozent": 3,
  "skonto_tage": 10,
  "mahnung_gesperrt": false,
  "mahnsperre_bis": null,
  "mahnsperre_grund": null,
  "mahnstufe_aktuell": 0,
  "debitor_nr": "10001",
  "notizen": "VIP-Kunde"
}
```

### Key Behaviors

- **Auto-numbering**: `kundennummer` auto-assigned from Nummernkreis `kunde` (format `1####`)
- **Debitor-Nr**: Auto-assigned from Nummernkreis `debitor` (format `10001`, `10002`, ...)
- **USt-IdNr validation**: Client-side format check per EU country (regex patterns from `EU_LAENDER` seed)
- **BZSt validation**: Link to BZSt eVatR verification; `ust_idnr_validiert` + `ust_idnr_validierung_datum` track confirmation
- **Land DE/Drittland**: `ust_idnr` used as normal Steuernummer, no format validation
- **EU-Länder**: Format validation enforced; link to BZSt shown in UI

### CRUD Operations

- `POST /kunden` – Create
- `GET /kunden` – List with search, pagination
- `GET /kunden/{id}` – Detail
- `PUT /kunden/{id}` – Update
- `DELETE /kunden/{id}` – Soft-delete (check for linked documents)

---

## Lieferanten (Vendors)

Mirror of Kunden with vendor-specific fields:

```json
{
  "id": 1,
  "lieferantennummer": "70001",
  "firmenname": "Lieferant AG",
  "kreditor_nr": "70001",
  "z_hd": "Frau Schmidt",
  "ust_idnr": "DE987654321",
  "ust_idnr_validiert": false,
  "ust_idnr_validierung_datum": null
}
```

- Auto-numbering: `lieferantennummer` from Nummernkreis `lieferant` (format `7####`)
- `kreditor_nr` from Nummernkreis `kreditor` (format `70001`, `70002`, ...)
- Same USt-IdNr validation as Kunden

---

## Artikel (Articles)

### Four Types

| Typ | Beschreibung | Hat EK-Preis | Hat VK-Preis | Lager |
|-----|-------------|-------------|-------------|-------|
| `artikel` | Physical product | ✓ | ✓ | Optional |
| `fremdleistung` | Third-party service | ✓ | ✓ | ✗ |
| `dienstleistung` | Own service | ✗ | ✓ | ✗ |
| `eigenleistung` | Internal work | ✗ | ✓ | ✗ |

### Fields

```json
{
  "id": "ART-00001",
  "bezeichnung": "Webdesign",
  "typ": "dienstleistung",
  "vk_netto": 85.00,
  "vk_brutto": 101.15,
  "vk_eingabe": "netto",
  "ek_netto": null,
  "ust_satz": 19,
  "gruppe_id": 3,
  "differenzbesteuerung": false,
  "lager_aktiv": false,
  "bestand_aktuell": 0,
  "mindestbestand": 0,
  "minusbestand_erlaubt": false,
  "aktiv": true
}
```

### VK-Preise NUMERIC(12,4)

Prices stored with 4 decimal places to prevent rounding drift:

- `vk_netto` derived from `vk_brutto` based on `vk_eingabe`
- `vk_eingabe`: `"netto"` or `"brutto"` — determines which price is the source of truth
- Frontend `fillPositionFromArtikel()` uses `vk_netto` unrounded
- Example: 3.50€ brutto → 2.9412€ netto (not 2.94€)

### Lagerführung

- `lager_aktiv`: Per-article stock tracking toggle
- `bestand_aktuell`: Current stock quantity (3 decimal places)
- `mindestbestand`: Warning threshold
- `minusbestand_erlaubt`: Allow negative stock
- Stock changes on invoice finalization and storno

### Artikelgruppen

```json
{
  "id": 3,
  "typ": "dienstleistung",
  "name": "IT-Dienstleistungen",
  "aktiv": true
}
```

Separate grouping for service/product categorization, distinct from Kategorien (accounting).

---

## Unternehmen (Company Settings)

80+ fields for the owning company:

### Core Identity

```json
{
  "id": 1,
  "firmenname": "Mein Unternehmen GmbH",
  "strasse": "Musterstr.",
  "hausnummer": "1",
  "plz": "80331",
  "ort": "München",
  "bundesland": "BY",
  "land": "DE",
  "telefon": "+49 89 123456",
  "mail": "kontakt@meinunternehmen.de",
  "web": "https://meinunternehmen.de",
  "ust_idnr": "DE123456789",
  "w_idnr": "WST01234567890",
  "steuernummer": "123/456/78901",
  "handelsregister_nr": "HRB 12345",
  "handelsregister_gericht": "AG München"
}
```

### Financial Configuration

```json
{
  "taetigkeitsart": "freiberufler",
  "standard_zahlungsziel": 14,
  "standard_skonto_prozent": 3,
  "standard_skonto_tage": 10,
  "pdf_vorlage": "standard",
  "bundesland": "BY",
  "dauerfristverlaengerung_ust": false,
  "est_vorauszahlungen_aktiv": false,
  "gewst_vorauszahlungen_aktiv": false
}
```

### Feature Toggles

```json
{
  "lagerführung_aktiv": false,
  "angebote_aktiv": true,
  "proforma_aktiv": false,
  "auftraege_aktiv": false,
  "wiederkehrend_aktiv": false,
  "buchungsvorlagen_aktiv": false,
  "bank_import_aktiv": false,
  "guv_aktiv": false,
  "kontenuebersicht_aktiv": false,
  "profilmanager_aktiv": false,
  "datenmigration_aktiv": false
}
```

### SMTP Configuration

```json
{
  "smtp_aktiv": false,
  "smtp_host": "smtp.gmail.com",
  "smtp_port": 587,
  "smtp_ssl": true,
  "smtp_user": "user@gmail.com",
  "smtp_passwort": "encrypted",
  "smtp_von_adresse": "rechnung@meinunternehmen.de",
  "smtp_zertifikat_ignorieren": false,
  "smtp_zertifikat_fingerprint": null
}
```

Certificate pinning: First connection stores SHA-256 fingerprint. Subsequent connections must match exactly.

### PDF/A-3 & GoBD

```json
{
  "logo_pfad": "/uploads/logo.png",
  "unterschrift_bild": "/uploads/signature.png",
  "unterschrift_auf_rechnung": true,
  "einleitungstext": "Vielen Dank für Ihren Auftrag.",
  "schlusstext": "Mit freundlichen Grüßen"
}
```

---

## Kategorien (Accounting Categories)

65+ predefined categories with SKR03/SKR04 and EÜR mapping:

```json
{
  "id": 5,
  "bezeichnung": "Betriebseinnahmen",
  "art": "einnahme",
  "konto_skr03": "8400",
  "konto_skr04": "8400",
  "euer_zeile": 12,
  "eks_kategorie": null,
  "ust_satz_standard": 19,
  "vorsteuer_prozent": 100,
  "aktiv": true,
  "beschreibung": "Erlöse aus dem gewöhnlichen Geschäftsbetrieb"
}
```

### Customization

- Users can modify `konto_skr03`/`konto_skr04` (tracked via `user_modified_skr03`/`user_modified_skr04`)
- `aktiv` flag hides categories from selection dropdowns without deleting
- `beschreibung` supports inline editing and usage hints

---

## Konten (Bank Accounts)

```json
{
  "id": 1,
  "bezeichnung": "Geschäftskonto",
  "anbieter": "Commerzbank",
  "iban": "DE89370400440532013000",
  "bic": "COBADEFFXXX",
  "kontoart": "girokonto",
  "kennung": "GK-001",
  "datev_kontonummer": "1200",
  "aktiv": true
}
```

- `datev_kontonummer`: Per-account DATEV export override
- Partial unique index: prevents duplicate IBANs per profile (nullable IBAN allowed)

---

## Nummernkreise (Number Sequences)

```json
{
  "id": 1,
  "typ": "rechnung_ausgang",
  "bezeichnung": "Rechnung",
  "format": "RE-YY####",
  "letzte_nummer": 42,
  "aktiv": true
}
```

### Format Patterns

| Pattern | Example | Usage |
|---------|---------|-------|
| `YY####` | RE-250042 | Year + 4-digit sequence |
| `YYYY####` | RE-20250042 | Full year + sequence |
| `MM####` | — | Month-based reset |
| `#` | — | Incrementing digit |

### Supported Types

`rechnung_ausgang`, `stornorechnung`, `gutschrift`, `angebot`, `auftrag`, `proforma`, `lieferschein`, `debitor`, `kreditor`

---

## Technical Notes

- **Profile isolation**: All master data scoped to active profile via `APP_DATA_DIR`
- **Cascade behavior**: Deleting a customer with linked documents prevents deletion
- **USt-IdNr validation**: Client-side regex per EU country, no server-side BZSt API call
- **Debitor/Kreditor auto-numbering**: Assigned on first save, never reused
- **Article prices**: 4-decimal precision prevents cumulative rounding errors in bulk orders
