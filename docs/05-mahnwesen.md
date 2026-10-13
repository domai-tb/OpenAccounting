# 05 – Mahnwesen (Dunning System)

## Overview

OpenAccounting includes a configurable dunning system for overdue invoices:
4 dunning levels (Mahnstufen), fixed fees and configured interest, customer
exclusions, and PDF/mail preparation. All amounts, fees, and rates below are
configured product values. They are not statutory rates and establish no
legal compliance.

---

## Mahnstufen (Dunning Levels)

Four default levels, configurable per installation. Each level configures an
absolute calendar-day offset from the invoice due date (`tage_nach_faelligkeit`),
a fixed fee in euro (`gebuehr`), an annual percentage interest rate
(`zinssatz`), and a multiplier flag. The multiplier carries the immediately
preceding level's configured fixed fee into the current level's fixed fee; it
never turns a fee into a percentage of the invoice amount.

Fresh-profile defaults (product settings, not statutory rates):

| Stufe | Bezeichnung | Tage nach Fälligkeit | Gebühr (fix) | Zinssatz (p. a.) | Multiplier |
|-------|-------------|----------------------|--------------|------------------|------------|
| 1 | Mahnung 1 | 7 | €5.00 | 0% | aus |
| 2 | Mahnung 2 | 21 | €10.00 | 5% | aus |
| 3 | Mahnung 3 | 35 | €15.00 | 8% | aus |
| 4 | Letzte Mahnung vor Inkasso | 49 | €25.00 | 8% | aus |

Example: level 2 has a fixed fee of €10.00 and level 3 has a fixed fee of
€5.00 with multiplier enabled — a new level 3 Mahnung carries a level fee of
€15.00, independent of any percentage of the invoice amount. With multiplier
disabled, level 3 carries €5.00 and ignores the prior level's fee.

### Stage dates

Each stage's `days_after_due` is an absolute calendar-day offset from the
invoice due date. Stage N becomes eligible on `due_date + days_after_due`;
the day before is ineligible, the threshold date is eligible if the preceding
stage was transport-accepted. Later stages cannot skip an unaccepted preceding
stage. The legacy `initial_grace_days` setting is deprecated and
non-operative: it never changes a stage threshold.

### System Stufen

`system_stufe = true` means the level cannot be deleted (only edited). These
are the four standard levels from the seed data. Editing a level affects only
new letters; stored Mahnungen keep their snapshot. Initialization never
overwrites user-edited values.

### Custom Stufen

Users can add additional levels between system levels. Custom levels are
deletable if no Mahnung references them.

---

## Mahnung (Dunning Record)

Each dunning action creates one record linked to exactly one invoice. A run
may group separate invoice letters for review but never creates a consolidated
customer letter.

```json
{
  "id": 1,
  "kunde_id": 42,
  "rechnung_id": 17,
  "mahnstufe_id": 2,
  "datum": "2025-04-15",
  "rechnungsnummer": "RE-250042",
  "faelligkeit": "2025-03-15",
  "offener_saldo": 595.00,
  "mahngebuehr": 10.00,
  "verzugszinsen": 0.66,
  "zinssegmente": [{ "von": "2025-04-05", "bis": "2025-04-15", "stufe": 2, "zinssatz": "5.00" }],
  "uebernommene_gebuehr": 5.00,
  "uebernommene_zinsen": 0.00,
  "versendet_am": null,
  "status": "offen"
}
```

### Mahngebühr + Verzugszinsen

- **Mahngebühr**: fixed euro amount per level (configurable, see table above)
- **Verzugszinsen**: configured annual percentage rate, calculated per day on
  the settled open principal over a 365-day year; rate changes apply
  prospectively, partial payments reduce principal from their effective date,
  full settlement stops accrual on that date, and fees/prior interest never
  compound. Totals round once to cents, half-up.
- Both tracked separately: `gebuehr_bezahlt`/`gebuehr_unbezahlt` and
  `zinsen_bezahlt`/`zinsen_unbezahlt`

### Übertragung from Prior Periods

When a new dunning level is reached:

1. Open fees from previous levels are carried into the snapshot
2. `uebernommene_gebuehr` / `uebernommene_zinsen` hold the accumulated amount
3. Customer sees total outstanding including prior period fees
4. Stored snapshots are immutable: later edits never rewrite prior letters

### Balance source

Current balances and interest always come from the settled-receivable
projection with dated settlement events. Without a positive outstanding
balance no Mahnung is created. If that source is missing, invalid, or
conflicting, every balance-dependent operation returns a retryable
unavailable result and performs no write, artifact, or transport call. The
system never falls back to invoice gross/net totals.

---

## Runs: manual and assisted only

Manual and assisted runs share the same date, balance, exclusion, and
Mahnsperre rules. Assisted mode shows a reviewable preview and creates
letters only after confirmation. For each invoice and stage, a repeated run
reuses an existing unsent draft or reports the already transport-accepted
reminder instead of duplicating it.

Unsupported until a separate accepted contract and runtime path exist:
dashboard-triggered or scheduled automatic runs, automatic customer
blocking/release, consolidated customer letters, and statutory-rate behavior.

---

## Kundensperrung (Customer Blocking)

Manual per-customer Mahnsperre with reason and optional end date. While active,
no dunning runs for that customer.

```json
{
  "kunde": {
    "mahnsperre_bis": "2025-06-30",
    "mahnsperre_grund": "Ratenzahlungsvereinbarung"
  }
}
```

Manual, dated block with reason. Automatic customer blocking and automatic
release when overdue amounts are paid are not available.

### Configuration

Warning and block thresholds (`schwelle_warnung`, `schwelle_sperrung`) remain
stored for compatibility. Customer and invoice exclusions additionally remove
individual customers or invoices from runs.

---

## PDF Generation

Dunning PDFs are generated per Mahnung from its immutable snapshot: company
header, customer address, invoice details, fixed fee, interest, total due, and
payment deadline. The artifact is written atomically below the profile
directory, verified readable, and never replaced by a placeholder or empty
file. The PDF of a transport-accepted Mahnung is immutable.

---

## Mail-Versand

A dunning letter is sent only when SMTP is configured and a readable
generated PDF artifact is available. The message contains the PDF; the record
stores transport acceptance and its timestamp. UI and history say
"transport accepted" — never delivered or read. A missing transport, missing
artifact, or rejected send leaves the Mahnung unsent and retryable and does
not advance the invoice's dunning level.

### Attachment Configuration per Level (planned)

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
| `mahnstufe_aktuell` | INTEGER | Current dunning level, highest transport-accepted stage (0 = none) |
| `mahnung_gesperrt` | BOOLEAN | Customer-level block |

### Stage progression

1. Rechnung finalized → `faelligkeit` known
2. Current date on or after `due_date + stage.days_after_due` → stage eligible
3. Manual/assisted run creates the Mahnung as draft (`status = offen`)
4. Transport accepts the message → `status = versendet`, `mahnstufe_aktuell` advances
5. A draft or failed send never advances the stage
6. Full settlement clears `mahnstufe_aktuell`; partial settlement preserves it

---

## Collection preparation

For a customer selected for collection preparation, the system assembles a
read-only manifest of the account statement, selected open invoices, prior
Mahnungen, and the as-of balance snapshot. Every artifact must resolve to a
readable stored document; a missing required artifact is reported and the
package stays incomplete. An unavailable balance source blocks package
creation without writing an artifact.

---

## Technical Notes

- **GoBD**: Mahnungen are operational records, not financial records
- **Runs**: manual or assisted with confirmation; no scheduler, no dashboard trigger
- **Rates**: configured annual percentages per level; no statutory-rate source
- **Inkasso handoff**: Level 4 ("Letzte Mahnung vor Inkasso") marks the final internal step before external collection
- **Database**: `mahnwesen_einstellungen`, `mahnstufen`, `mahnungen`, `mahnwesen_ausschluesse` tables
- **Mail**: Uses the configured SMTP transport (see Einstellungen); acceptance is not delivery
