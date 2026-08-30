# 06 – Dokumente (Document Lifecycle)

## Overview

OpenInvoices manages the complete lifecycle of financial documents: creation, finalization, reversal (Storno), credit notes (Gutschrift), replacement invoices (Ersatzrechnung), and archival. All finalized documents are GoBD-compliant with immutable snapshots and original PDF storage.

---

## Storno (Reversal)

A Storno reverses a finalized Rechnung with negative amounts:

### Creation Flow

```
Rechnung (finalized, +500€)
    │
    ▼
Storno (-500€) ──[Creates]──▶ Storno-Rechnung PDF
    │
    ▼
Original marked as storniert
```

### Required Fields

```json
{
  "storno_grund": "Kunde hat Vertrag gekündigt, Leistung nicht erbracht",
  "storno_datum": "2025-04-15",
  "storno_rechnungsnummer": "STORNO-250001"
}
```

- `storno_grund`: 500 characters mandatory (audit trail)
- `storno_datum`: Date of reversal (may differ from original)
- `storno_rechnungsnummer`: Own number from Nummernkreis `stornorechnung`

### Storno PDF

- Title: "Stornorechnung" (not "Rechnung")
- Shows: Storno-Nr., Original-Nr., Stornodatum, Originaldatum
- All amounts negated
- No payment block (Zahlungsblock)
- Same layout as original but with "STORNO" watermark

### Stock Reversal

If `lagerführung_aktiv`:

- Original finalization: stock decreased
- Storno: stock increased by same amount (`_lager_buchen()` with negative sign)

### Buchungsgruppe

`journal.gruppe_id` links Original + Storno + Neubuchung:

```json
{
  "gruppe_id": 42,
  "beschreibung": "Original RE-250042",
  "betrag": 500.00
},
{
  "gruppe_id": 42,
  "beschreibung": "Storno STORNO-250042",
  "betrag": -500.00
}
```

---

## Gutschrift (Credit Note)

Positive adjustment document for overpayments or returns:

```json
{
  "dokument_typ": "Gutschrift",
  "rechnungsnummer": "GS-250001",
  "kunde_id": 42,
  "betrag": 150.00,
  "positionen": [
    {
      "bezeichnung": "Rückerstattung Lieferung",
      "menge": 1,
      "einzelpreis": 150.00,
      "ust_satz": 19
    }
  ]
}
```

### Nummernkreis

Separate Nummernkreis `gutschrift` (GS-YY####). Prior to this, Gutschriften reused `rechnung_ausgang`.

### Relationship to Original

- `gutschrift_zu_rechnung_id`: FK linking Gutschrift to original Rechnung
- Original Rechnung shows linked Gutschrift in detail view
- Both documents preserved for audit trail

---

## Ersatzrechnung (Replacement Invoice)

Created after Storno as a corrected replacement:

### Creation

1. User selects "Ersatzrechnung erstellen" on Storno dialog
2. System creates new Rechnung with corrected data
3. Bidirectional linking:

```json
{
  "rechnung_original": {
    "id": 101,
    "ersatzrechnung_id": 201
  },
  "rechnung_ersatz": {
    "id": 201,
    "ersatz_fuer_rechnung_id": 101
  }
}
```

### Data Inheritance

- Positions copied from original (user can modify)
- Partner data inherited
- `einleitungstext`/`schlusstext` inherited
- New Nummernkreis entry (standard RE-YY####)

---

## Absender Snapshot (GoBD Compliance)

At finalization, company data is frozen:

```json
{
  "absender_snapshot": {
    "firmenname": "Mein Unternehmen GmbH",
    "strasse": "Musterstr.",
    "hausnummer": "1",
    "plz": "80331",
    "ort": "München",
    "land": "DE",
    "ust_idnr": "DE123456789",
    "steuernummer": "123/456/78901",
    "telefon": "+49 89 123456",
    "mail": "kontakt@meinunternehmen.de",
    "logo_pfad": "/uploads/logo.png",
    "unterschrift_bild": "/uploads/signature.png"
  }
}
```

### Why Snapshot

- PDF generation uses snapshot data, not current company data
- Company details may change (address, phone) after finalization
- GoBD requires finalized documents to be unveränderlich (immutable)
- Backfill script updates existing finalized documents without snapshot

---

## Original PDF Storage

### Storage Path

```
~/.local/share/openinvoices/profile/<Name>/uploads/
├── rechnung_101.pdf          # Original
├── rechnung_101_original.pdf # Backup of original (for KOPIE)
└── storno_201.pdf
```

### Fields

```json
{
  "original_pdf_pfad": "/uploads/rechnung_101.pdf",
  "ausgegeben_am": "2025-03-15T14:30:00"
}
```

- `original_pdf_pfad`: Relative path to original PDF
- `ausgegeben_am`: First print/mail timestamp

### KOPIE Watermark

When loading an already-finalized document for viewing:

1. System loads `original_pdf_pfad`
2. Adds "KOPIE" watermark
3. Returns watermarked version

Original remains untouched.

---

## Überzahlung (Overpayment)

When customer pays more than invoice amount:

```json
{
  "rechnung": {
    "betrag": 500.00,
    "bezahlt_betrag": 550.00,
    "ueberzahlung_anerkannt": false
  }
}
```

### Handling

1. Excess amount detected on payment recording
2. Dashboard widget shows overpayment
3. User can:
   - **Anerkennen**: Mark as acknowledged (`ueberzahlung_anerkannt = true`) → removed from widget
   - **Verrechnen**: Apply to next invoice
   - **Rückerstatten**: Create Gutschrift

### Forderungen (Receivables)

Overpayments tracked in `forderungen` table:

```json
{
  "typ": "ueberzahlung",
  "status": "offen",
  "betrag": 50.00,
  "partner_typ": "kunde",
  "partner_id": 42,
  "rechnung_id": 101,
  "journal_id": 102
}
```

---

## Dokumentenpakete (Document Bundles)

Group related documents for mailing or archival:

```json
{
  "id": 1,
  "bezeichnung": "Q1 2025 - ACME GmbH",
  "dokumente": [
    {"dokument_typ": "Rechnung", "dokument_id": 101},
    {"dokument_typ": "Lieferschein", "dokument_id": 501},
    {"dokument_typ": "Gutschrift", "dokument_id": 201}
  ],
  "erstellt_am": "2025-03-31"
}
```

### Use Cases

- Bundle related documents for customer mailing
- Archive project documentation
- Export grouped documents

---

## Belege (Receipts/Attachments)

Upload supporting documents to any entity:

```json
{
  "id": 1,
  "dateiname": "vertrag_acme.pdf",
  "original_name": "Vertrag ACME GmbH.pdf",
  "mime_type": "application/pdf",
  "dateigroesse": 245760,
  "sha256": "a1b2c3d4...",
  "hochgeladen_am": "2025-03-15",
  "beleg_pdfa_pfad": null,
  "loeschdatum": null
}
```

### PDF/A-3 for GoBD

`beleg_pdfa_pfad` stores the PDF/A-3 version for long-term archival (GoBD Stufe 5).

### DSGVO Löschdatum

`loeschdatum` tracks when document should be deleted:

- Red badge: overdue (past deletion date)
- Yellow badge: ≤ 30 days until deletion
- Automatic cleanup removes expired documents

### Linked Entities

- `rechnungen.beleg_id`: Invoice receipt
- `journal.beleg_id`: Journal entry receipt
- `rechnungsvorlagen.beleg_id`: Contract/agreement

---

## Conversion Chains (Document Flow)

```
Angebot ──[Annehmen]──▶ Auftrag ──[Abschließen]──▶ Lieferschein ──[Rechnung erstellen]──▶ Rechnung
    │                       │                           │
    └──[Direkt]─────────────┼───────────────────────────┘
                            │
                    Proforma ──[Konvertieren]──▶ Rechnung
```

### Data Propagation

Each conversion carries:

- All positions (with amounts, taxes)
- Partner data (including Einmalkunden-Adressfelder)
- `einleitungstext`/`schlusstext` (if not overridden)
- FK back-link to source document

### Ersatzrechnung Path

```
Rechnung ──[Stornieren]──▶ Storno ──[Ersatzrechnung]──▶ New Rechnung
```

Bidirectional FK: `ersatzrechnung_id` ↔ `ersatz_fuer_rechnung_id`

---

## Technical Notes

- **GoBD triggers**: DB-level triggers on `rechnungen` and `journal` prevent mutation of finalized/immutable rows
- **PDF storage**: Relative paths from `APP_DATA_DIR/uploads/`
- **Backfill**: Migration scripts update existing documents (e.g., `absender_snapshot` backfill)
- **Nummernkreise**: Each document type has its own sequence; format `YY####`
- **Content-Disposition**: `inline` for display, `attachment` for downloads (CLAUDE.md convention)
