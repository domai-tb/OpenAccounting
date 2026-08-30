# 02 – Buchhaltung (Accounting)

## Overview

OpenInvoices provides double-entry bookkeeping with a journal-based ledger, pre-configured SKR03/SKR04 chart of accounts, and German tax authority reporting (EÜR, UStVA, EKS, GuV, ZM). All journal entries are GoBD-immutable once posted.

---

## Journal

The central ledger table (`journal`) records every financial transaction:

```json
{
  "datum": "2025-03-15",
  "belegdatum": "2025-03-14",
  "betrag": 119.00,
  "brutto_betrag": 119.00,
  "vorsteuer_betrag": 19.00,
  "kategorie_id": 3,
  "partner_typ": "kunde",
  "partner_id": 42,
  "rechnung_id": 101,
  "konto_id": 1,
  "konto_skr03": "1200",
  "konto_skr04": "1200",
  "ust_satz": 19,
  "gruppe_id": null,
  "beleg_id": null
}
```

### GoBD Immutability

- `immutable=1` flag set on finalization
- DB triggers (`protect_journal_*`) prevent UPDATE/DELETE on immutable rows
- Triggers temporarily disabled during migrations, re-enabled after
- Storno entries: negative `vorsteuer_betrag`, linked via `gruppe_id` to original

### Buchungsgruppen

`gruppe_id` links Original → Storno → Neubuchung as a transaction group, enabling reliable reversal tracking without text-parsing descriptions.

---

## Kategorien (Chart of Accounts Mapping)

65+ predefined categories, each mapping to SKR03 and SKR04 account numbers:

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
  "aktiv": true,
  "beschreibung": "Erlöse aus dem gewöhnlichen Geschäftsbetrieb"
}
```

### Key Fields

| Field | Purpose |
|-------|---------|
| `konto_skr03` | SKR03 Kontonummer for DATEV export |
| `konto_skr04` | SKR04 Kontonummer for DATEV export |
| `user_modified_skr03` | User override of default SKR03 account |
| `user_modified_skr04` | User override of default SKR04 account |
| `euer_zeile` | Line number in Anlage EÜR (60+ items) |
| `eks_kategorie` | EKS field code (B6_5, C14, etc.) |
| `vorsteuer_prozent` | Vorsteuer deduction percentage (e.g. 70% for Bewirtung) |

### Migration Pattern

Categories updated via `_migrate_kategorien()` which runs at every startup (idempotent). New categories added to `neue` list. Existing DBs get updates without version-gated migrations.

---

## EÜR – Anlage EÜR 2025

Einnahmenüberschussrechnung with 60+ line items mapped to the 2025 BMF form:

### Key Line Items

| Zeile | Beschreibung | Typical SKR03 |
|-------|-------------|---------------|
| 12 | Betriebseinnahmen (Kleinunternehmer §19) | 8400 |
| 15 | Umsatzsteuerpflichtige Betriebseinnahmen (7%+19%) | 8400, 8410 |
| 16 | Steuerfreie Betriebseinnahmen §4 | 8420 |
| 17 | Vereinnahmte USt | 1776 |
| 18 | FA-erstattete USt | 1790 |
| 21 | Eigenverbrauch | 8915 |
| 33 | AfA bewegliche WG | 4830 |
| 60 | Sonstige Betriebsausgaben | 6900 |
| 106 | Privatentnahmen | — |
| 107 | Privateinlagen | — |

### Calculation

- **Zuflussprinzip** (§11 EStG): Revenue counted when received, expenses when paid
- `vorsteuer_betrag` in journal reflects actually abziehbarer Anteil (e.g. 70% for Bewirtung)
- Storno entries carry negative `vorsteuer_betrag`

---

## UStVA – Umsatzsteuervoranmeldung

Monthly or quarterly VAT pre-registration:

| KZ | Beschreibung |
|----|-------------|
| 81 | Umsätze 19% |
| 82 | Umsätze 7% |
| 83 | Umsätze 0%/steuerfreie (innergemeinschaftlich) |
| 89 | USt-pflichtige innergemeinschaftliche Erwerbe |
| 93 | USt auf ig Erwerbe |
| 61 | Vorsteuer auf ig Erwerbe §1a |
| 62 | Vorsteuer allgemein |
| 66 | Vorsteuer aus Rechnungen |
| 67 | Vorsteuer aus Storage/other |

### Soll-Prinzip (§15 UStG)

Vorsteuerabzug occurs at **Rechnungseingang** (invoice receipt), not at payment:

- `vorsteuer_ansprueche` table tracks independent Vorsteuer claims
- `journal.vorsteuer_betrag` remains payment-date based (for EÜR/Zufluss)
- CUTOVER_DATUM separates old (journal-based) from new (anspruch-based) logic

### Voranmeldungsrhythmus

Configured per `unternehmen.voranmeldungsrhythmus`: `monat` or `quartal`.

---

## EKS – Anlage EKS (9-Page Jobcenter Form)

Detailed expense tracking for social benefit applications (Transferleistungen):

### Structure

- **Page 1-2**: Section D (固定 costs – Miete, NK, Versicherungen)
- **Page 3-4**: Section F 23-41 (variable costs – Lebensmittel, Kleidung, etc.)
- **Page 5-9**: Additional detail pages

### Category Mapping

Each Kategorie can have an `eks_kategorie` field (e.g. `B6_5` for food):

```json
{
  "eks_kategorie": "B6_5",
  "eks_feld_meta": [100, 0, 1, "Lebensmittel", true]
}
```

Meta array: [monthly_default, flags, multiplier, label, is_positive].

---

## GuV – Gewinn- und Verlustrechnung (§141 AO)

Activated when turnover exceeds €800,000 or profit exceeds €80,000:

- `unternehmen.guv_aktiv` flag
- Dashboard warning at 80% threshold
- Auto-activation for `taetigkeitsart` = gewerbe/gemischt
- Full §141 AO Buchführungspflicht compliance

---

## ZM – Zusammenfassende Meldung

EU intra-community trade reporting:

- Tracks `ist_eu_lieferung` and `ist_reverse_charge` on invoices
- Aggregates by partner USt-IdNr
- Quarterly filing per §18 UStG

---

## DATEV EXTF Export

Buchungsstapel export for DATEV accounting software:

### Configuration (`unternehmen`)

```json
{
  "datev_beraternummer": "12345",
  "datev_mandantennummer": "001",
  "datev_konto_bar": "1000",
  "datev_konto_bank": "1200",
  "datev_konto_karte": "1210",
  "datev_konto_paypal": "1220"
}
```

### Per-Konto Override

`konten.datev_kontonummer` overrides global `datev_konto_bank` for individual bank accounts.

### Export Format

- ASCII fixed-width (DATEV EXTF standard)
- Header with Berater-/Mandantennummer
- One row per journal entry with Soll/Haben split
- Auto-categorized based on `konto_skr03`/`konto_skr04`

---

## Differenzbesteuerung (§25a UStG)

Margin-based taxation for used goods:

```json
{
  "position": {
    "differenzbesteuerung": true,
    "ek_netto_25a": 50.00,
    "ust_satz_25a": 19,
    "ust_satz": 0
  },
  "rechnung": {
    "marge_25a_brutto": 69.00
  }
}
```

- USt calculated on margin (VK_brutto − EK_netto × Menge)
- Displayed in UStVA KZ 81/83
- `ust_satz` = 0 on invoice (no USt shown to customer)

---

## Skonto (3-Level)

```json
{
  "unternehmen": {
    "standard_skonto_prozent": 3,
    "standard_skonto_tage": 10
  },
  "kunde": {
    "skonto_prozent": 5,
    "skonto_tage": 14
  },
  "rechnung": {
    "skonto_prozent": 2,
    "skonto_tage": 7
  }
}
```

Priority: Rechnung > Kunde > Unternehmen. Zuflussprinzip: Skonto reduces payment amount, EÜR entry shows net.

---

## Reverse Charge §13b

Three sub-categories:

| Kategorie | USt-Sonderfall | KZ USt | KZ VoSt |
|-----------|---------------|--------|---------|
| EU-Dienstleistungen (§13b Abs. 1) | 13b_abs1 | 89 | 61 |
| Bauleistungen (§13b Abs. 2) | 13b_abs2 | 89 | 61 |
| Innergemeinschaftl. Erwerb | ig_erwerb | 89/93 | 61 |

- USt additive (Rechnungsbetrag = Netto)
- Vorsteuer auto-calculated
- Dedicated SKR accounts: DATEV Automatikkonten (3425/3123/3120 SKR03)

---

## Anlagenverzeichnis (Fixed Asset Register)

```json
{
  "id": 1,
  "bezeichnung": "MacBook Pro 16\"",
  "typ": "edv",
  "kaufdatum": "2025-01-15",
  "kaufpreis_netto": 2499.00,
  "nutzungsdauer_jahre": 3,
  "afa_methode": "linear",
  "privat_anteil_prozent": 0,
  "aktiv": true
}
```

- Typen: `kfz`, `edv`, `sonstig`
- AfA: linear or degressiv
- Connected to EÜR Zeile 33 (AfA bewegliche WG)
- Dashboard widget for AfA overview

---

## Technical Notes

- **Immutable entries**: DB triggers on `journal` prevent mutation of `immutable=1` rows
- **Vorsteueransprüche**: Independent table with own triggers, not affected by journal triggers
- **CUTOVER_DATUM**: Fixed constant in `api/ustva.py` separating old/new Vorsteuer logic
- **Konto snapshots**: `konto_skr03`/`konto_skr04` stored on journal entry at creation time (not referenced)
- **Datenfixes**: Version-gated UPDATE statements correct historical category mappings
