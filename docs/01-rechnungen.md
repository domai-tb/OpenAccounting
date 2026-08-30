# 01 – Rechnungen (Invoicing)

## Overview

OpenInvoices manages seven document types through a unified lifecycle: **Rechnung**, **Storno**, **Gutschrift**, **Angebot**, **Auftrag**, **Proforma**, and **Lieferschein**. Every document starts as an **Entwurf** (draft), transitions to **Finalisiert** (finalized/issued), and can then reach **Bezahlt** (paid) or **Storniert** (cancelled).

The invoicing engine runs server-side in a FastAPI backend with SQLAlchemy 2.0 + SQLite (WAL mode). The frontend is React 19 + Vite + TypeScript + Tailwind v4, wrapped in Tauri 2 for desktop deployment.

---

## Document Types

| Typ | Nummernkreis | Zweck |
|-----|-------------|-------|
| Rechnung | RE-YY#### | Standard invoice with tax calculation |
| Storno | STORNO-YY#### | Negative reversal of a finalized Rechnung |
| Gutschrift | GS-YY#### | Credit note (positive adjustment) |
| Angebot | ANG-YY#### | Quote/proposal, convertible to other types |
| Auftrag | AU-YY#### | Work order, linked to Angebot or standalone |
| Proforma | PRF-YY#### | Advance document, convertible to Rechnung |
| Lieferschein | LS-YY#### | Delivery note (no prices), convertible to Rechnung |

Nummernkreis format `YY####` uses the last two digits of the year plus a four-digit sequence.

---

## Lifecycle

```
Entwurf ──[Finalisieren]──▶ Finalisiert ──[Bezahlen]──▶ Bezahlt
                               │
                               └──[Stornieren]──▶ Storniert
```

### Entwurf (Draft)

- Editable fields: all document data, positions, texts
- No tax obligations yet
- Lager (stock) not affected
- Preview endpoint `POST /rechnungen/vorschau` returns calculated totals without persisting

### Finalisiert (Finalized)

- Locked: core fields immutable (GoBD compliance)
- `absender_snapshot` captures company data at finalization time
- `ausgegeben_am` timestamp set
- Lagerückgang recorded (if `lagerführung_aktiv`)
- Vorsteueranspruch created (Soll-Prinzip §15 UStG)
- Original PDF generated and stored
- Cannot be edited, only storniert or copied

### Bezahlt (Paid)

- `bezahlt_betrag` tracks actual payment received
- `zahlungsstatus` updated automatically
- Journal entries linked to payment

### Storniert (Cancelled)

- Negative amounts on all positions
- `storno_grund` (500 char) mandatory explanation
- `storno_datum` and `storno_rechnungsnummer` recorded
- Lagerrückbuchung (stock reversal)
- Original document preserved with Storno reference

---

## Eingabemodus (Input Mode)

One input mode per document: **netto** or **brutto**.

- **Netto mode**: Enter net prices → tax and gross derived
- **Brutto mode**: Enter gross prices → net and tax derived

Calculation happens on **position level** (Einzelpreis × Menge), not per unit, to prevent rounding drift with large quantities. The `POST /rechnungen/vorschau` endpoint runs the same calculation for live preview.

```json
{
  "eingabemodus": "netto",
  "positionen": [
    {
      "artikel_id": "ART-00001",
      "menge": 30,
      "einzelpreis": 2.94,
      "ust_satz": 19
    }
  ]
}
```

Netto direction: sum positions → derive USt from unrounded position total.  
Brutto direction: sum positions → derive Netto from unrounded total.  
Netto + USt = Brutto holds exactly in both directions.

---

## Position Management

Each document carries an ordered list of **Rechnungspositionen**:

```json
{
  "bezeichnung": "Webdesign (3 Stunden)",
  "menge": 3,
  "einzelpreis": 85.00,
  "ust_satz": 19,
  "rabatt_prozent": 0,
  "artikel_id": null,
  "kategorie_id": 5
}
```

### Article-linked Positions

When `artikel_id` is set, the position pulls from the article master:

- `bezeichnung` from article
- `einzelpreis` from `vk_netto` or `vk_brutto` (based on `vk_eingabe`)
- `ust_satz` from article's default USt category
- `kategorie_id` for SKR03/04 mapping

### Custom Positions

No `artikel_id` → free-text entry. Useful for one-off services.

### Differenzbesteuerung (§25a UStG)

Per-position flag. When active:

- `ust_satz` set to 0 (no USt displayed on invoice)
- `ust_satz_25a` holds the nominal rate (19%/7%) for internal calculation
- Marge calculated as `VK_brutto − EK_netto × Menge`
- USt on the margin, not the full gross

---

## Rabatt System

Three levels of discount:

| Level | Field | Scope |
|-------|-------|-------|
| Position | `rabatt_prozent` | Per-line discount |
| Rechnung | `rabatt_prozent` | Entire document percentage |
| Rechnung | `rabatt_betrag` | Fixed Euro amount (alternative to %) |

When `rabatt_betrag` is set, it overrides `rabatt_prozent`. The PDF shows "Abzug" for fixed amounts, "Rabatt X %" for percentage.

Zwischensumme (subtotal before Rabatt) displayed in PDF when any Rabatt is active.

---

## Einleitungstext & Schlusstext

Per-document-type text blocks:

- **Einleitungstext**: Shown above position table
- **Schlusstext**: Shown below position table (before payment block)

Each document type (Rechnung, Angebot, Auftrag, Proforma, Lieferschein) maintains its own text. Stored at company level (`unternehmen.einleitungstext_*` / `schlusstext_*`) and overridable per document (`rechnungen.einleitungstext` / `schlusstext`).

Supports Markdown formatting: `**fett**` and `*kursiv*`.

---

## ZUGFeRD / XRechnung

E-invoicing integration for B2B mandates:

- ZUGFeRD 2.1.1 (EN 16931 compliant) embedded as PDF/A-3 attachment
- XRechnung as standalone XML output
- Mandatory fields: USt-IdNr, Leistungsdatum, Zahlungsbedingungen
- Automatic generation on Rechnung finalization

---

## Lagerführung (Stock Management)

When `unternehmen.lagerführung_aktiv` is enabled:

- Each article has `bestand_aktuell`, `mindestbestand`, `minusbestand_erlaubt`
- Stock decreases on Rechnung finalization (`_lager_buchen()`)
- Stock reverses on Storno
- Warning widget on Dashboard when `bestand_aktuell < mindestbestand`
- Frontend shows bestand warning in Rechnungsformular before finalization

```json
{
  "lager_aktiv": true,
  "bestand_aktuell": 150.000,
  "mindestbestand": 20.000,
  "minusbestand_erlaubt": false
}
```

---

## Conversion Chains

Documents convert forward through the lifecycle:

```
Angebot ──[Annehmen]──▶ Auftrag ──[Abschließen]──▶ Lieferschein ──[Rechnung]──▶ Rechnung
    │                       │                           │
    └──[Direkt]─────────────┼───────────────────────────┤
                            │                           │
                    Proforma ──[Konvertieren]───────────┘
```

Each conversion:

1. Copies positions and partner data
2. Links source document via FK (`rechnung_zu_angebot_id`, etc.)
3. Inherits `einleitungstext`/`schlusstext` if not overridden
4. Creates Nummernkreis entry for new document type

### Ersatzrechnung after Storno

A Storno can trigger an Ersatzrechnung (replacement invoice):

- `ersatzrechnung_id` on original → points to replacement
- `ersatz_fuer_rechnung_id` on replacement → points to original
- Both documents cross-linked for audit trail

---

## Technical Notes

- **Database**: SQLite WAL mode, schema version tracked in `SCHEMA_VERSION` constant
- **Migrations**: Version-gated blocks in `_run_migrations()`, each incrementing `user_version`
- **GoBD**: Immutable entries protected by DB triggers; `absender_snapshot` freezes company data at finalization
- **PDF**: Generated via `pdf_rechnung_base.py` utilities; `Content-Disposition: inline` for display, `attachment` for downloads
- **Rounding**: Position-level rounding (not per unit) to prevent cumulative drift
- **Preview**: `POST /rechnungen/vorschau` runs identical calculation logic as finalization
