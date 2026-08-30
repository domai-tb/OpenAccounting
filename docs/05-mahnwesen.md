# 05 – Mahnwesen (Dunning System)

## Overview

OpenInvoices includes a configurable dunning system for overdue invoices: 4 dunning levels (Mahnstufen), automatic fees and interest, customer blocking, and PDF/mail generation. The system respects German legal requirements for Mahngebühren and Verzugszinsen.

---

## Mahnstufen (Dunning Levels)

Four default levels, configurable per installation:

```json
[
  {
    "stufe": 1,
    "bezeichnung": "1. Mahnung",
    "tage_nach_faelligkeit": 7,
    "mahngebuehr_prozent": 5,
    "verzugszinsen_prozent": 2,
    "mail_betreff": "Zahlungserinnerung - Rechnung {rechnungsnummer}",
    "mail_text": "Sehr geehrte Damen und Herren,\n\nwir haben Ihre Zahlung noch nicht erhalten...",
    "pdf_vorlage": "mahnung_1",
    "system_stufe": true,
    "aktiv": true
  },
  {
    "stufe": 2,
    "bezeichnung": "2. Mahnung",
    "tage_nach_faelligkeit": 21,
    "mahngebuehr_prozent": 10,
    "verzugszinsen_prozent": 2,
    "mail_betreff": "2. Mahnung - Rechnung {rechnungsnummer}",
    "mail_text": "Sehr geehrte Damen und Herren,\n\ntrotz unserer Zahlungserinnerung...",
    "pdf_vorlage": "mahnung_2",
    "system_stufe": true,
    "aktiv": true
  },
  {
    "stufe": 3,
    "bezeichnung": "3. Mahnung",
    "tage_nach_faelligkeit": 35,
    "mahngebuehr_prozent": 15,
    "verzugszinsen_prozent": 2,
    "mail_betreff": "3. Mahnung - Rechnung {rechnungsnummer}",
    "mail_text": "Sehr geehrte Damen und Herren,\n\nunsere bisherigen Mahnungen blieben erfolglos...",
    "pdf_vorlage": "mahnung_3",
    "system_stufe": true,
    "aktiv": true
  },
  {
    "stufe": 4,
    "bezeichnung": "Letzte Mahnung vor Inkasso",
    "tage_nach_faelligkeit": 49,
    "mahngebuehr_prozent": 20,
    "verzugszinsen_prozent": 2,
    "mail_betreff": "Letzte Mahnung - Rechnung {rechnungsnummer}",
    "mail_text": "Sehr geehrte Damen und Herren,\n\nhiermit setzen wir Ihnen eine letzte Frist...",
    "pdf_vorlage": "mahnung_4",
    "system_stufe": true,
    "aktiv": true
  }
]
```

### System Stufen

`system_stufe = true` means the level cannot be deleted (only deactivated). These are the four standard levels from the seed data.

### Custom Stufen

Users can add additional levels between system levels. Custom levels are deletable if no Mahnung references them.

---

## Mahnung (Dunning Record)

Each dunning action creates a record:

```json
{
  "id": 1,
  "kunde_id": 42,
  "mahnstufe_id": 2,
  "datum": "2025-04-15",
  "faelligkeit_ab": "2025-03-15",
  "faelligkeit_bis": "2025-04-15",
  "gesamt_betrag": 595.00,
  "mahngebuehr_bezahlt": 0.00,
  "mahngebuehr_verzugszinsen": 11.90,
  "uebertragen_in_mahnung_id": null,
  "uebernommene_gebuehr_vorperioden": 0.00,
  "versendet_am": null,
  "status": "entwurf"
}
```

### Mahngebühr + Verzugszinsen

- **Mahngebühr**: Percentage of overdue amount (configurable per level)
- **Verzugszinsen**: Annual interest rate (§288 BGB), calculated per day
- Both tracked separately: `mahngebuehr_bezahlt` and `verzugszinsen_bezahlt`

### Übertragung from Prior Periods

When a new dunning level is reached:

1. Open fees from previous levels automatically transferred
2. `uebertragen_in_mahnung_id` links to the new Mahnung
3. `uebernommene_gebuehr_vorperioden` holds the accumulated amount
4. Customer sees total outstanding including prior period fees

---

## Kundensperrung (Customer Blocking)

Two-stage blocking:

### Warnung (Warning)

- Triggered at configurable Mahnstufe (e.g., level 2)
- `kunden.mahnung_warnung = true`
- Dashboard warning badge
- Customer can still receive new invoices

### Sperrung (Block)

- Triggered at higher Mahnstufe (e.g., level 3)
- `kunden.mahnung_gesperrt = true`
- No new invoices can be created for this customer
- Block clears automatically when all overdue amounts paid

### Configuration

```json
{
  "mahnwesen_einstellungen": {
    "kundensperrung_warnung_ab_stufe": 2,
    "kundensperrung_sperrung_ab_stufe": 3
  }
}
```

### Mahnsperre per Customer

Independent of automatic blocking:

```json
{
  "kunde": {
    "mahnsperre_bis": "2025-06-30",
    "mahnsperre_grund": "Ratenzahlungsvereinbarung"
  }
}
```

Manual, dated block with reason. Overrides automatic unblocking.

---

## PDF Generation

Dunning PDFs generated per Mahnstufe:

### Template Structure

```
┌──────────────────────────────┐
│ [Logo]  Firma GmbH           │
│         Musterstr. 1         │
│         80331 München        │
├──────────────────────────────┤
│ Mahnung Nr. MN-250001        │
│ Stufe: 2. Mahnung            │
│ Datum: 15.04.2025            │
├──────────────────────────────┤
│ An:                          │
│ ACME GmbH                    │
│ Berliner Str. 42             │
│ 10115 Berlin                 │
├──────────────────────────────┤
│ Rechnung: RE-250042          │
│ Betrag: 500,00 €             │
│ Mahngebühr: 50,00 €          │
│ Verzugszinsen: 11,90 €       │
│ ─────────────────────────    │
│ Gesamt: 561,90 €             │
├──────────────────────────────┤
│ Zahlbar bis: 22.04.2025      │
│ IBAN: DE89370400440532013000  │
│ BIC: COBADEFFXXX             │
└──────────────────────────────┘
```

### Configurable Elements

- Mail-Betreff with `{rechnungsnummer}` placeholder
- Mail-Text per level
- PDF-Vorlage per level
- Anhänge optional: Rechnungskopie, bisherige Mahnungen, Kontokorrent

---

## Mail-Versand

Integration with SMTP backend:

```json
{
  "to": "accounts@acme.de",
  "subject": "2. Mahnung - Rechnung RE-250042",
  "body": "Sehr geehrte Damen und Herren...",
  "attachments": [
    {
      "name": "Mahnung_MN-250001.pdf",
      "content": "base64..."
    },
    {
      "name": "Rechnung_RE-250042.pdf",
      "content": "base64..."
    }
  ]
}
```

### Attachment Configuration per Level

```json
{
  "anhang_rechnung": true,
  "anhang_bisherige_mahnungen": true,
  "anhang_kontokorrent": false
}
```

---

## Rechnung Integration

### Fields on rechnungen

| Field | Type | Description |
|-------|------|-------------|
| `mahnstufe_aktuell` | INTEGER | Current dunning level (0 = none) |
| `mahnung_gesperrt` | BOOLEAN | Customer-level block |

### Automatic Progression

1. Rechnung finalized → `faelligkeit` calculated from `standard_zahlungsziel`
2. Faelligkeit überschritten → Dunning engine evaluates
3. Days since faelligkeit ≥ Mahnstufe.tage_nach_faelligkeit → Create Mahnung
4. Mahnung created → Update `mahnstufe_aktuell` on Rechnung
5. Sperrung triggered → Block customer for new invoices

---

## Technical Notes

- **GoBD**: Mahnungen are not GoBD-immutable (they're operational, not financial records)
- **Trigger timing**: Dunning evaluation runs on dashboard load and via scheduled check
- **BGB §288**: Verzugszinsen calculated at statutory rate (currently 5 percentage points above base rate for consumers, 9 for businesses)
- **Inkasso handoff**: Level 4 ("Letzte Mahnung vor Inkasso") marks the final internal step before external collection
- **Database**: `mahnwesen_einstellungen`, `mahnstufen`, `mahnungen`, `mahnungen_rechnungen` tables
- **Mail**: Uses same SMTP configuration as document sending (see Einstellungen)
