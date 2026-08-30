import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';

void main() {
  test('creates a draft invoice with positions', () async {
    final database = AppDatabase.createTestDatabase();
    addTearDown(database.close);
    await database.ensureOpen();

    await database.executor.runCustom(
      '''
INSERT INTO rechnungen (typ, datum, ist_entwurf, eingabemodus)
VALUES (?, ?, ?, ?)
''',
      <Object?>['rechnung', '2026-08-30', 1, 'netto'],
    );

    final invoice = (await database.executor.runSelect(
      'SELECT id, typ, status, ist_entwurf, eingabemodus FROM rechnungen',
      const <Object?>[],
    )).single;

    await database.executor.runCustom(
      '''
INSERT INTO rechnungspositionen (rechnung_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz)
VALUES (?, ?, ?, ?, ?, ?)
''',
      <Object?>[invoice['id'], 'Beratung', 2, 100, 200, 19],
    );

    final positions = await database.executor.runSelect(
      'SELECT bezeichnung, menge, einzelpreis, gesamt FROM rechnungspositionen WHERE rechnung_id = ?',
      <Object?>[invoice['id']],
    );

    expect(invoice['typ'], 'rechnung');
    expect(invoice['status'], 'entwurf');
    expect(invoice['ist_entwurf'], 1);
    expect(invoice['eingabemodus'], 'netto');
    expect(positions, hasLength(1));
    expect(positions.single['bezeichnung'], 'Beratung');
    expect(positions.single['menge'], 2);
    expect(positions.single['gesamt'], 200);
  });
}
