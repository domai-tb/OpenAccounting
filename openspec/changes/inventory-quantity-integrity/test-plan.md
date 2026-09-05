## Test Plan

<!-- Every scenario from specs/ mapped to a concrete test. The mapping is a -->
<!-- floor, not a ceiling: extra tests are welcome but need no entry here. -->
<!-- LIVE LEDGER: during apply, flip each row 🔴 red → 🟢 green as its test -->
<!-- passes. verify blocks on any row left red. -->

| Requirement | Scenario | Test File | Test Name | Initial State |
|-------------|----------|-----------|-----------|---------------|
| specs/inventory-quantity-integrity/spec.md → Inventory quantity retains configured precision | Fractional adjustment round-trips | test/integration/audit/inventory-quantity-integrity_test.dart | test_inventory_quantity_integrity_1_1_fractional_adjustment_round_trips | 🔴 red |
| specs/inventory-quantity-integrity/spec.md → Inventory quantity retains configured precision | Invalid precision is rejected consistently | test/integration/audit/inventory-quantity-integrity_test.dart | test_inventory_quantity_integrity_1_2_invalid_precision_is_rejected_consistently | 🔴 red |

## Coverage Notes

Every scenario is mapped exactly once to a planned red integration/regression test. Existing unit tests remain useful lower-level coverage, but they do not replace these production-path tests. Use injected external adapters only where the design names them; keep the application composition real.
