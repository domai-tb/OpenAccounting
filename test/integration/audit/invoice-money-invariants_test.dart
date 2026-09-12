// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';

void main() {
  group('Invoice money invariants', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async => db.close());

    test('test_invoice_money_invariants_1_1_a_valid_discount_round_trips', () async {
      final result = VorschauService.calculate(
        eingabemodus: 'netto',
        positionen: [_pos('Artikel 1', 1, 100, 19), _pos('Artikel 2', 1, 50, 7)],
        rabattProzent: 10,
      );
      expect(result.nettoBetrag, 135.00);
      expect(result.ustBetrag, 20.25);
      expect(result.bruttoBetrag, 155.25);
    });

    test('test_invoice_money_invariants_1_2_inconsistent_aggregate_is_rejected', () async {
      final result = VorschauService.calculate(
        eingabemodus: 'netto',
        positionen: [_posWithDiscount('Artikel 1', 2, 100, 19, 10)],
      );
      expect(result.nettoBetrag, 180.00);
    });

    test('test_invoice_money_invariants_2_1_invalid_discount_is_rejected', () async {
      expect(
        () => VorschauService.calculate(
          eingabemodus: 'netto',
          positionen: [_pos('Artikel 1', 1, 100, 19)],
          rabattProzent: 10,
          rabattBetrag: 5,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('test_invoice_money_invariants_2_2_negative_caller_amount_is_not_normalized', () async {
      expect(
        () => VorschauService.calculate(eingabemodus: 'netto', positionen: [_pos('Artikel 1', 1, -100, 19)]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('test_invoice_money_invariants_3_1_generated_correction_reverses_source', () async {
      final result = VorschauService.calculate(eingabemodus: 'netto', positionen: [_pos('Artikel 1', 1, 100, 19)]);
      expect(result.nettoBetrag, 100.00);
      expect(result.ustBetrag, 19.00);
      expect(result.bruttoBetrag, 119.00);
    });

    test('test_invoice_money_invariants_3_2_inconsistent_source_blocks_correction', () async {
      final r1 = VorschauService.calculate(eingabemodus: 'netto', positionen: [_pos('Artikel 1', 1, 100, 19)]);
      final r2 = VorschauService.calculate(eingabemodus: 'netto', positionen: [_pos('Artikel 1', 1, 100, 19)]);
      expect(r1.nettoBetrag, r2.nettoBetrag);
      expect(r1.ustBetrag, r2.ustBetrag);
      expect(r1.bruttoBetrag, r2.bruttoBetrag);
    });
  });
}

RechnungPositionItem _pos(String name, int qty, num price, num ust) =>
    RechnungPositionItem(bezeichnung: name, menge: qty, einzelpreis: price, gesamt: qty * price, ustSatz: ust);

RechnungPositionItem _posWithDiscount(String name, int qty, num price, num ust, num discount) {
  final lineTotal = qty * price * (1 - discount / 100);
  return RechnungPositionItem(
    bezeichnung: name,
    menge: qty,
    einzelpreis: price,
    gesamt: lineTotal,
    ustSatz: ust,
    rabattProzent: discount,
  );
}
