# 04 – Bank Import

## Overview

OpenInvoices provides a 3-step bank transaction import workflow: **Upload** CSV/XML → **Review** with auto-categorization → **Import** into the journal. Supports 10+ bank templates, CAMT XML, deduplication, and both automatic and manual matching modes.

---

## Workflow

```
Step 1: Upload        Step 2: Review         Step 3: Import
┌─────────────┐      ┌─────────────┐        ┌─────────────┐
│ Select file │──────▶│ Match &     │────────▶│ Journal     │
│ Choose      │      │ Categorize  │        │ entries     │
│ template    │      │             │        │ created     │
└─────────────┘      └─────────────┘        └─────────────┘
```

### Step 1: Upload

- User selects CSV or XML file
- System detects format via file extension and content sniffing
- Template selected manually or auto-detected by header matching
- Preview shows first 10 rows with parsed columns

### Step 2: Review

Each transaction displayed with:

- **Date**, **Amount**, **Partner**, **Reference** (Verwendungszweck)
- **Auto-category** (if rule matches)
- **Score** (0-100 confidence)
- **Match** to existing journal entry (if duplicate detected)
- Manual override for category, partner, and amount

### Step 3: Import

- Creates journal entries for all confirmed transactions
- Links to `bank_transaktionen` table with `journal_id` FK
- Records `konto_id` (which bank account)
- Runs deduplication check on import

---

## Bank Templates

Pre-configured parsers for common German bank formats:

### Sparkasse / Volksbank (CSV)

```json
{
  "id": "SPARKASSE_CSV",
  "name": "Sparkasse / Volksbank",
  "format": "csv",
  "delimiter": ";",
  "encoding": "utf-8",
  "date_column": "Buchungstag",
  "amount_column": "Betrag",
  "partner_column": "Empfänger/Zahlungsberechtigter",
  "reference_column": "Verwendungszweck",
  "date_format": "dd.MM.yyyy",
  "amount_positive_is_credit": false
}
```

### PayPal (CSV)

```json
{
  "id": "PAYPAL_CSV",
  "name": "PayPal",
  "format": "csv",
  "delimiter": ",",
  "encoding": "utf-8",
  "date_column": "Datum",
  "amount_column": "Brutto",
  "partner_column": "Name",
  "reference_column": "Beschreibung",
  "date_format": "dd.MM.yyyy HH:mm:ss"
}
```

### N26 (CSV)

```json
{
  "id": "N26_CSV",
  "name": "N26",
  "format": "csv",
  "delimiter": ",",
  "encoding": "utf-8",
  "date_column": "Datum",
  "amount_column": "Betrag (EUR)",
  "partner_column": "Empfänger",
  "reference_column": "Referenz",
  "date_format": "yyyy-MM-dd"
}
```

### Vivid (CSV)

```json
{
  "id": "VIVID_CSV",
  "name": "Vivid",
  "format": "csv",
  "delimiter": ",",
  "encoding": "utf-8",
  "date_column": "Completed date",
  "amount_column": "Payment amount",
  "partner_column": "Counterparty name",
  "reference_column": "Reference",
  "date_format": "yyyy-MM-dd"
}
```

### CAMT XML (ISO 20022)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08">
  <BkToStmRpt>
    <Stmt>
      <Txs>
        <Ntry>
          <BookgDt><Dt>2025-03-15</Dt></BookgDt>
          <Amt Ccy="EUR">119.00</Amt>
          <NtryDtls>
            <TxDtls>
              <RmtInf><Ustrd>Rechnung RE-250042</Ustrd></RmtInf>
            </TxDtls>
          </NtryDtls>
        </Ntry>
      </Txs>
    </Stmt>
  </BkToStmRpt>
</Document>
```

CAMT XML parsed via `xml.etree.ElementTree`; supports `camt.053` (Kontoauszug) and `camt.052` (Tagesauszug).

---

## Auto-Categorization Rules

Rules match transactions to Kategorien based on patterns:

```json
{
  "id": 1,
  "kategorie_id": 5,
  "match_typ": "betreff",
  "match_muster": "Rechnung|Invoice|Faktura",
  "betrag_min": null,
  "betrag_max": null,
  "prioritaet": 1,
  "aktiv": true
}
```

### Match Types

| Typ | Beschreibung |
|-----|-------------|
| `betreff` | Regex on Verwendungszweck/reference |
| `partner` | Exact or partial match on partner name |
| `betrag` | Amount range (min/max) |
| `kombiniert` | All conditions must match |

### Evaluation Order

1. Rules sorted by `prioritaet` (lower = higher priority)
2. First match wins
3. Score reflects match quality (exact = 100, partial = 50-80, no match = 0)

---

## Score-Based Matching

Each transaction receives a confidence score:

| Score | Confidence | Action |
|-------|-----------|--------|
| 90-100 | Hoch | Auto-categorize, suggest import |
| 70-89 | Mittel | Show suggestion, require confirmation |
| 50-69 | Niedrig | Show empty category, require manual selection |
| 0-49 | Keine | Flag as unprocessed |

### Score Factors

- Category rule match: +40 points
- Partner match to existing Kunde/Lieferant: +30 points
- Amount matches existing Rechnung: +20 points
- Reference contains Rechnungsnummer: +10 points

---

## Deduplication

SHA-256 hash computed from:

```
hash = SHA256(datum + betrag + partner_iban + verwendungszweck)
```

### Storage

```json
{
  "id": 1,
  "konto_id": 1,
  "datum": "2025-03-15",
  "betrag": 119.00,
  "partner_name": "ACME GmbH",
  "partner_iban": "DE89370400440532013000",
  "verwendungszweck": "Rechnung RE-250042",
  "kategorie_id": 5,
  "journal_id": 42,
  "dedupe_hash": "a1b2c3d4e5f6...",
  "importiert_am": "2025-03-15T14:30:00"
}
```

### Duplicate Detection

- `UNIQUE INDEX uix_bank_tx_hash` on `(konto_id, dedupe_hash) WHERE NOT NULL`
- Duplicate detected → transaction marked with "Duplikat" badge
- User can override and force-import (e.g., legitimate double payment)

---

## Manual vs Automatic Mode

### Automatic Mode (`bank_import_manuell = false`)

- Score 90+ transactions auto-imported
- Score 50-89 shown for review
- Score <50 skipped

### Manual Mode (`bank_import_manuell = true`)

- All transactions shown for review
- No auto-import
- User confirms each transaction individually

### Per-Session Override

Toggle in the import UI switches mode for current session only. Persistent setting in `unternehmen.bank_import_manuell`.

---

## Integration with Journal

Imported transactions create journal entries:

```json
{
  "datum": "2025-03-15",
  "betrag": 119.00,
  "brutto_betrag": 119.00,
  "vorsteuer_betrag": 19.00,
  "kategorie_id": 5,
  "partner_typ": "kunde",
  "partner_id": 42,
  "konto_id": 1,
  "konto_skr03": "8400",
  "konto_skr04": "8400",
  "quelle": "bank_import",
  "bank_transaktion_id": 1
}
```

- `quelle` field distinguishes bank imports from manual entries
- `bank_transaktion_id` back-link for audit trail
- Vorsteuer calculated based on Kategorie's `ust_satz_standard`

---

## Technical Notes

- **File parsing**: CSV via Python `csv` module; XML via `xml.etree.ElementTree`
- **Encoding**: Auto-detection via `chardet` library; fallback to UTF-8
- **CAMT XML**: ISO 20022 standard; namespace-aware parsing
- **Hash**: SHA-256 via `hashlib`; collision probability negligible for transaction data
- **WAL mode**: Concurrent reads during import; no lock contention
- **Template extensibility**: New templates added as JSON config files in `bank_templates/` seed
