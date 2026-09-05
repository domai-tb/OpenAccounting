# Verify — accounting-tax-polish

## Full Suite Run

- **Command:** `fvm flutter test --dart-define=platform=vm 2>&1 | tail -n 50`
- **Result:** `00:48 +489: All tests passed!` — 489 passed, 0 failed, green.
- **Targeted:** `test/features/accounting-tax-polish/test_accounting-tax-polish.dart` — 2 passed (test_happy, test_failure).
- **Analyze:** `fvm flutter analyze` — 256 issues (info/warning only), 0 new errors in `accounting_tax_polish.dart`. Pre-existing errors only in `pdf-template-polish` (unrelated).

## Tasks Completed

- [x] 1.1 Write failing test: `test/features/accounting-tax-polish/test_accounting-tax-polish.dart`
- [x] 1.2 Implement: `lib/features/accounting_tax_polish/accounting_tax_polish.dart` to pass 1.1
- [x] 1.3 Refactor: extracted `const _kEmptyInput` / `_kNotANumber`, 33 lines (<50), pure functions, readability — ponytail minimal, no new abstractions; full suite stays green

## Refactor Detail

- `lib/features/accounting_tax_polish/accounting_tax_polish.dart` — 33 lines, extracted const error strings, single quotes, package imports, 120 char, trailing commas, `dart format` clean.

## DESIGN.md Alignment

- Reuses money helpers (`money.formatBetrag` / string cents to avoid double drift)
- German terms (`ungültig`, `Betrag`, `polishBetrag`) per domain language
- VM-safe pure logic, no DB — additive, no migration
- Goals/non-goals respected: no breaking changes, VM-safe adapters pattern
