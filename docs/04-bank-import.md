# 04 – Bank Import

## Overview

OpenInvoices provides a 3-step bank transaction import workflow: **Upload** CSV/CAMT.053 → **Review** with rule categorization and match scores → **Import** storing confirmed rows in `bank_transaktionen`. Supports seven predefined CSV templates plus the seeded CAMT.053 template and profile-scoped custom templates, deduplication, and manual/automatic matching modes. Imports never create journal entries or payments; automatic mode may link one unambiguous existing journal entry.

---

## Workflow

```
Step 1: Upload        Step 2: Review              Step 3: Import
┌─────────────┐      ┌──────────────────┐        ┌──────────────┐
│ Select file │──────▶│ Match, patterns, │───────▶│ Confirmed    │
│ Choose      │      │ scores, override │        │ rows stored  │
│ template    │      │                  │        │ in bank_     │
└─────────────┘      └──────────────────┘        │ transaktionen│
                                                 └──────────────┘
```

### Step 1: Upload

- User selects CSV or XML file
- System detects format via file extension and content sniffing
- Template selected manually or auto-detected by header matching
- Preview shows first 10 rows with parsed columns

### Step 2: Review

Each transaction displayed with score, confidence label, and best journal candidate (date, amount, description) without changing accounting data. Suggestions never set links automatically in manual mode:

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

CAMT XML parsing supports `camt.053` (Kontoauszug). `camt.052` is not supported.

---

## Auto-Categorization Rules

Rules match transactions to Kategorien based on patterns:

```json
{
  "id": 1,
  "muster": "Amazon",
  "kategorie_id": 5,
  "prioritaet": 10,
  "aktiv": true
}
```

Rules in `auto_filter_regeln` match case-insensitively as substrings of Verwendungszweck only.

### Evaluation Order

1. Active rules sorted by `prioritaet` descending, then rule ID ascending
2. First match wins; equal priority is deterministic by ID
3. Rule changes affect future imports only

---

## Score-Based Matching

Each transaction receives a confidence score:

| Score | Confidence | Action |
|-------|-----------|--------|
| 90-100 | Hoch | Automatic mode may link one unique existing journal entry after confirmation |
| 70-89 | Mittel | Show suggestion, require confirmation |
| 50-69 | Niedrig | Show suggestion, require manual selection |
| 0-49 | Keine | Explicit no-match state |

### Score Factors (40/30/30)

- Amount within 0.01 EUR: +40 points
- Date within 7 days: +30 points
- Partner similarity above 80%: +30 points

---

## Deduplication

SHA-256 hash computed from:

```
hash = SHA256(datum + normalized betrag + partner + verwendungszweck)
```

### Storage

```json
{
  "id": 1,
  "konto_id": 1,
  "datum": "2025-03-15",
  "betrag": 119.00,
  "gegenkonto_name": "ACME GmbH",
  "verwendungszweck": "Rechnung RE-250042",
  "kategorie_id": 5,
  "journal_id": 42,
  "dedupe_hash": "a1b2c3d4e5f6...",
  "importiert_am": "2025-03-15T14:30:00"
}
```

### Duplicate Detection

- `UNIQUE INDEX idx_bank_transaktionen_dedupe` on `(konto_id, dedupe_hash)` where the hash is not null
- Duplicate detected → transaction marked with "Duplikat" badge
- User can override and force-import (e.g., legitimate double payment)

---

## Manual vs Automatic Mode

The profile mode persists in `unternehmen.bank_import_manuell` (`1` = manual default, `0` = automatic), added by the ordered v10 migration. Both modes require explicit Review confirmation.

### Automatic Mode (`bank_import_manuell = 0`)

- After confirmation, links only one unique existing journal candidate scoring at least 90
- Tied tops, lower scores, and unavailable candidate queries stay unlinked
- Never creates a journal entry or payment

### Manual Mode (`bank_import_manuell = 1`)

- Score suggestions never set links; the user may explicitly select an existing journal entry
- User confirms each transaction individually

### Per-Import Override

The one-import override in Review applies only to the staged import and is discarded afterwards. The stored profile mode never changes through an override.

---

## Integration with Journal

Imported transactions are stored in `bank_transaktionen`:

```json
{
  "konto_id": 1,
  "import_id": 7,
  "datum": "2025-03-15",
  "betrag": 119.00,
  "verwendungszweck": "Rechnung RE-250042",
  "gegenkonto": null,
  "gegenkonto_name": "ACME GmbH",
  "kategorie_id": 5,
  "journal_id": 42,
  "dedupe_hash": "a1b2c3d4e5f6...",
  "status": "gebucht"
}
```

- `journal_id` references an existing journal entry or is null; no entry is ever created by import or review
- `status` is `neu` (awaiting review), `geprueft` (user-reviewed), or `gebucht` (linked)
- Duplicate detection: partial unique index on `(konto_id, dedupe_hash)` where the hash is not null
- User can override and force-import (e.g., legitimate double payment)

---

## Technical Notes

- **File parsing**: CSV and CAMT.053 parsing in Dart; no Python, `chardet`, ElementTree, or `hashlib` involved
- **Encoding**: UTF-8 or ISO-8859-1 per template configuration
- **CAMT XML**: `camt.053` only; `camt.052` is not supported
- **Hash**: SHA-256 over date, normalized amount, partner, and Verwendungszweck
- **Custom templates**: profile-scoped rows in `bank_templates` with stable `custom_` type identifiers; predefined types are protected
