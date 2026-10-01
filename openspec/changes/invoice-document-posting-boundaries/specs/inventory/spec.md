## MODIFIED Requirements

### Requirement: Per-article inventory activation

Each article SHALL have a `lager_aktiv` boolean flag (default `false`). Normally, only articles with `lager_aktiv = true` SHALL participate in stock tracking. During outgoing invoice finalization and Storno only, the legacy predicate `lager_aktiv = false`, `bestand_aktuell = 0`, and `bestand != 0` SHALL be treated as tracked stock: finalization SHALL use the legacy `bestand`, update both stock columns, and enable tracking; Storno SHALL restore recorded source movements to both columns and enable tracking. A disabled article outside that exact legacy predicate SHALL ignore all stock-related operations.

#### Scenario: Article with inventory disabled

GIVEN an article has `lager_aktiv = false` and both `bestand_aktuell` and `bestand` are zero
WHEN an outgoing invoice containing that article is finalized
THEN no stock change SHALL occur for that article.

#### Scenario: Article with inventory enabled

GIVEN an article has `lager_aktiv = true` with `bestand_aktuell = 50` and `mindestbestand = 10`
WHEN an outgoing sales invoice containing 3 units of that article is finalized
THEN `bestand_aktuell` SHALL decrease to 47.

### Requirement: Stock decrement on invoice finalization

When an outgoing sales invoice is finalized, the system SHALL aggregate its line quantities by article where inventory tracking is enabled and decrement `bestand_aktuell` once by each combined quantity. Combined quantities SHALL be validated against the starting stock before any deduction; if a combined quantity would cause negative stock and `minusbestand_erlaubt` is false, the transaction SHALL make no stock change and finalization SHALL fail. Incoming invoices and other document types SHALL NOT run sales-stock validation or change stock. The legacy compatibility predicate is exactly `lager_aktiv = false`, `bestand_aktuell = 0`, and `bestand != 0`; for those rows, finalization SHALL use `bestand`, update both stock columns, and set `lager_aktiv = true`.

#### Scenario: Multiple line items

GIVEN an outgoing invoice contains 3 line items: Article A (qty=10, lager_aktiv=true), Article B (qty=5, lager_aktiv=false, bestand=0, bestand_aktuell=0), Article C (qty=3, lager_aktiv=true)
WHEN the invoice is finalized
THEN Article A `bestand_aktuell` SHALL decrease by 10
AND Article B SHALL NOT be affected
AND Article C `bestand_aktuell` SHALL decrease by 3.

#### Scenario: No stock fields on non-inventory articles

GIVEN an article has `lager_aktiv = false` and both stock columns are zero
WHEN an outgoing invoice with that article is finalized
THEN `bestand_aktuell` and `mindestbestand` SHALL be ignored by the system.

#### Scenario: Partial stock decrement on finalization failure

GIVEN an outgoing invoice contains Article A (qty=10, lager_aktiv=true) and Article B (qty=5, lager_aktiv=true, `bestand_aktuell=2`, `minusbestand_erlaubt=false`)
WHEN invoice finalization is attempted
THEN the system SHALL NOT decrement stock for either article
AND SHALL display a stock warning for Article B.

#### Scenario: Incoming invoice does not decrement sales stock

GIVEN an incoming invoice contains an article with `lager_aktiv = true` and stock 20
WHEN the invoice is finalized
THEN stock remains 20 and no negative invoice movement is recorded.

#### Scenario: Repeated article quantities are combined

GIVEN an outgoing invoice has two inventory-enabled lines for the same article, quantities 3 and 4, with current stock 20
WHEN the invoice is finalized
THEN stock decreases exactly once by 7 to 13
AND one negative inventory movement records -7.

#### Scenario: Repeated quantities cannot exceed disallowed stock

GIVEN an outgoing invoice has two inventory-enabled lines for the same article, quantities 3 and 3, with current stock 5 and negative stock disallowed
WHEN the invoice is finalized
THEN finalization fails before deduction
AND stock remains 5 with no movement for either line.

#### Scenario: Legacy stock is migrated by first outgoing movement

GIVEN an article has `lager_aktiv=false`, `bestand_aktuell=0`, and legacy `bestand=20`
WHEN an outgoing invoice for 3 units is finalized
THEN both stock columns become 17, `lager_aktiv` becomes true, and one -3 movement is recorded.

#### Scenario: Repeated legacy quantity finalizes and reverses exactly

GIVEN a legacy article has `lager_aktiv=false`, `bestand_aktuell=0`, and `bestand=20`, and the outgoing invoice has two lines for that article with quantities 3 and 4
WHEN the invoice is finalized and then storniert
THEN finalization sets both stock columns to 13, enables tracking, and records one -7 movement
AND Storno restores both stock columns to 20 and records one +7 movement.

#### Scenario: Disabled stock is not mistaken for legacy stock

GIVEN an article has `lager_aktiv=false`, `bestand_aktuell=0`, and `bestand=0`
WHEN an outgoing invoice line exceeds current stock
THEN finalization is not blocked by that article and neither stock column nor movement log changes.

### Requirement: Stock restore on storno

When a document is storniert, the system SHALL sum only negative inventory movements recorded for its source using `referenz_typ = 'rechnung'` and the source document ID, grouped by article. It SHALL restore those quantities atomically as one positive movement per eligible article. Articles with `lager_aktiv = true` are eligible; rows matching the legacy predicate `lager_aktiv = false`, `bestand_aktuell = 0`, and `bestand != 0` are also eligible and SHALL be restored in both stock columns with tracking enabled. A disabled non-legacy article SHALL remain unchanged even if an old source movement exists. A source with no negative movement SHALL not increase stock.

#### Scenario: Storno restores stock

GIVEN the source invoice has one negative movement of 10 for Article A and current stock is 47
WHEN the source invoice is storniert
THEN Article A `bestand_aktuell` SHALL increase by 10 to 57
AND one positive movement of 10 SHALL reference the Storno document.

#### Scenario: Storno of already-reduced stock

GIVEN the source invoice recorded a negative movement of 10 and the article's stock was manually adjusted downward since finalization
WHEN the source invoice is storniert
THEN the storno SHALL still add back the recorded quantity of 10 without comparing stock to a prior snapshot.

#### Scenario: Storno without a source stock movement

GIVEN a finalized offer or incoming invoice has an inventory-enabled article but no negative source movement
WHEN the document is storniert
THEN stock remains unchanged and no positive Storno movement is recorded.

#### Scenario: Storno of invoice with non-inventory articles

GIVEN a source invoice has a negative movement for Article A but none for Article B, whose inventory tracking is disabled
WHEN the source invoice is storniert
THEN Article A stock SHALL be restored by its recorded quantity
AND Article B SHALL NOT be affected.

#### Scenario: Storno restores only negative movements for its source

GIVEN movements for one source article have diffs -2.000 and -3.500, plus +7.000, and other rows have -4.000 for another invoice or another reference type
WHEN that source invoice is storniert
THEN the system SHALL restore 5.500 for that article once
AND SHALL NOT restore the positive or unrelated rows.

#### Scenario: Storno restores legacy stock and preserves disabled stock

GIVEN Article A matches the legacy predicate with `bestand=17`, while Article B has tracking disabled and both stock columns zero despite a historical source movement
WHEN the source invoice is storniert
THEN Article A's two stock columns increase by the recorded quantity and its tracking is enabled
AND Article B's stock columns, flag, and movement log remain unchanged.

#### Scenario: Storno late failure rolls back restoration

GIVEN an outgoing invoice has a recorded negative movement and article stock is 17 after deduction
WHEN reversal posting fails after the Storno movement is inserted
THEN source stock remains 17, the source invoice remains unstorniert, and no Storno document, counter increment, positive movement, reversal journal, payable, or tax row remains
AND retry restores stock exactly once.

### Requirement: Inventory movement storage

The inventory feature migration SHALL add exactly one named table, `inventarbewegungen`, with `id`, `artikel_id` (foreign key to `artikel`), `datum`, `diff` (NUMERIC(10,3)), `grund`, and nullable `referenz_typ` and `referenz_id` fields. Outgoing-invoice deductions, Storno restores, and manual adjustments SHALL each write movement rows in the same transaction as the stock change. Repeated outgoing lines for one article SHALL produce a movement whose `diff` equals the combined stock change. Storno SHALL use the source invoice's recorded negative movement as its restoration amount.

#### Scenario: Automatic movement recorded

GIVEN an inventory-enabled article is included in a finalized outgoing invoice
WHEN stock is decremented
THEN `inventarbewegungen` SHALL contain the negative quantity with the invoice reference
AND the movement row and stock update SHALL commit or roll back together.

#### Scenario: Storno movement recorded

GIVEN an outgoing invoice has a recorded negative stock movement and is storniert
WHEN stock is restored
THEN `inventarbewegungen` SHALL contain the positive restored quantity with the Storno reference
AND the movement row and stock update SHALL commit or roll back together.

#### Scenario: Incoming and document-only finalization has no automatic movement

GIVEN an inventory-enabled article is included in a finalized incoming invoice or offer
WHEN document finalization commits
THEN no automatic inventory movement SHALL be recorded.
