## MODIFIED Requirements

### Requirement: Data Type Precision

SQLite column declarations such as `NUMERIC(12,2)` select numeric affinity but do not enforce decimal scale, precision, truncation, or rounding. Currency columns SHALL retain their `NUMERIC(12,2)` declarations; `vk_netto` and related article pricing columns SHALL retain `NUMERIC(12,4)`; invoice unit-price columns SHALL use `NUMERIC(12,4)` and invoice quantity columns `NUMERIC(12,3)`. These declarations document the storage contract but do not enforce it. Application boundaries MUST validate accepted ranges and decimal scales and MUST reject overflow or excess scale rather than silently changing a value. Invoice header and line currency amounts SHALL be persisted as cents. Invoice unit prices SHALL preserve four decimal places up to `99,999,999.9999` and invoice quantities three decimal places up to `999,999,999.999` through save, reload, and supported conversion. Tests SHALL verify these guarantees against the actual SQLite executor; no claim of database-enforced decimal precision is permitted.

#### Scenario: Invoice price and quantity retain application precision in SQLite
- **GIVEN** an invoice position contains unit price `12.3456` and quantity `1.234`
- **WHEN** it is inserted and reloaded through the app's SQLite executor
- **THEN** both values are unchanged at their accepted scales

#### Scenario: Money Column Precision
- **GIVEN** a currency column stores `123456789.12` through the application money boundary
- **WHEN** the value is stored and reloaded
- **THEN** it is exactly `123456789.12` with no observable floating-point imprecision

#### Scenario: Money Column Overflow
- **GIVEN** a currency value exceeds the supported 12-digit range
- **WHEN** it is submitted through the application money boundary
- **THEN** application validation rejects it before SQLite receives it
- **AND** the application does not silently round or truncate it

#### Scenario: Article Price Precision
- **GIVEN** `vk_netto` stores `2.9412` and 100 units are invoiced
- **WHEN** the line total is calculated
- **THEN** the line total is exactly `294.12`
- **AND** it is neither `294.119999...` nor `294.13`

#### Scenario: Article Price Zero
- **GIVEN** `vk_netto` stores `0.0000`
- **WHEN** it is stored and reloaded through the application boundary
- **THEN** its numeric value remains exactly zero
- **AND** no floating-point artifact changes the calculated line amount

#### Scenario: Excess scale is rejected by the application
- **GIVEN** a caller submits a unit price with five fractional digits or quantity with four
- **WHEN** the invoice boundary validates the values
- **THEN** the write is rejected and SQLite receives no rounded or truncated substitute

#### Scenario: Values beyond the supported range are rejected
- **GIVEN** an invoice unit price exceeds `99,999,999.9999` or quantity exceeds `999,999,999.999`
- **WHEN** the invoice boundary validates it
- **THEN** the write is rejected with `valueOutOfRange` before SQLite receives a substitute value

#### Scenario: SQLite declaration does not promise overflow rounding
- **GIVEN** a `NUMERIC(12,2)` column is used by an application
- **WHEN** an out-of-range value is submitted through the supported money boundary
- **THEN** application validation rejects it without relying on SQLite to round or truncate it
