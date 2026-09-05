## ADDED Requirements

### Requirement: Inventory quantity retains configured precision

Inventory adjustments MUST preserve the configured decimal precision across primary storage, legacy compatibility columns, movement records, warnings, and reloads; converting a valid fractional quantity to an integer is forbidden.

Implementation evidence: setBestand explicitly truncates the compatibility value with toInt.

#### Scenario: Fractional adjustment round-trips

- Given an article is adjusted to 2.5 units
- When the adjustment commits and the article is reloaded
- Then all quantity views report 2.5 units and the movement record retains the same amount

#### Scenario: Invalid precision is rejected consistently

- Given an adjustment exceeds the configured precision or is otherwise invalid
- When the user saves it
- Then the operation rejects with a clear validation error and no consumer receives a silently rounded quantity
