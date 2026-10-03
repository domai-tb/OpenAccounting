## MODIFIED Requirements

### Requirement: Explicit feature-table migrations

Feature migrations SHALL declare every table they add, including its columns, constraints, and schema-version change. The existing inventory movement migration SHALL add the named `inventarbewegungen` table defined in the inventory specification. A separate physical stocktake migration SHALL add exactly `inventuren` and `inventur_positionen` with the columns, constraints, and foreign key defined in the inventory specification. These stocktake tables SHALL store count evidence only; this change SHALL NOT add an inventory valuation or journal table. No other unspecified movement or log table SHALL be created.

#### Scenario: Named inventory table migration

GIVEN the existing inventory movement migration is enabled
WHEN that migration completes
THEN `inventarbewegungen` SHALL exist with the columns and constraints specified by the inventory capability
AND the 38 base tables SHALL remain present.

#### Scenario: Named stocktake table migration

GIVEN the physical stocktake migration is enabled
WHEN that migration completes
THEN `inventuren` and `inventur_positionen` SHALL exist with the columns and constraints specified by the inventory capability
AND existing article and movement rows SHALL retain their values.

#### Scenario: Failed stocktake migration leaves prior schema intact

GIVEN the physical stocktake migration fails while creating a declared constraint
WHEN migration error handling completes
THEN neither stocktake table SHALL remain
AND the schema version and pre-existing article and movement rows SHALL retain their pre-migration values.
