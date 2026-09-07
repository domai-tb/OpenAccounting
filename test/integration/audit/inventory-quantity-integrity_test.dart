// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';

void main() {
  group('Inventory quantity integrity', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async {
      await db.close();
    });

    test('test_inventory_quantity_integrity_1_1_fractional_adjustment_round_trips', () async {
      final artikel = await db.artikelRepository.create(bezeichnung: 'Kg Ware', vkBrutto: 11.9, lagerAktiv: true);

      // Set fractional quantity
      await db.artikelRepository.setBestand(artikel.id, 2.5);

      // Verify bestand_aktuell retains fractional precision
      final reloaded = await db.artikelRepository.findById(artikel.id);
      expect(reloaded, isNotNull);
      expect(reloaded!.bestandAktuell, 2.5);

      // Verify the legacy bestand column also retains fractional precision
      final raw = await db.executor.runSelect('SELECT bestand, bestand_aktuell FROM artikel WHERE id = ?', <Object?>[
        artikel.id,
      ]);
      expect(raw.single['bestand'], 2.5);
      expect(raw.single['bestand_aktuell'], 2.5);

      // Verify movement record retains the fractional diff
      await db.executor.runCustom('''
CREATE TABLE IF NOT EXISTS inventarbewegungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  artikel_id INTEGER NOT NULL REFERENCES artikel(id),
  datum TEXT NOT NULL,
  diff NUMERIC(10,3) NOT NULL,
  grund TEXT NOT NULL,
  referenz_typ TEXT,
  referenz_id INTEGER
)''');
      final movements = await db.executor.runSelect(
        'SELECT diff FROM inventarbewegungen WHERE artikel_id = ?',
        <Object?>[artikel.id],
      );
      expect(movements, isNotEmpty);
      expect(num.tryParse(movements.single['diff'].toString()), 2.5);
    });

    test('test_inventory_quantity_integrity_1_2_invalid_precision_is_rejected_consistently', () async {
      final artikel = await db.artikelRepository.create(bezeichnung: 'Präzision', vkBrutto: 19.99, lagerAktiv: true);

      // Value with more than 3 decimal places exceeds configured NUMERIC(10,3) precision
      await expectLater(
        () => db.artikelRepository.setBestand(artikel.id, 2.5678),
        throwsA(isA<Exception>().having((e) => e.toString().toLowerCase(), 'message', contains('precision'))),
      );

      // No consumer receives a silently rounded quantity
      final raw = await db.executor.runSelect('SELECT bestand_aktuell FROM artikel WHERE id = ?', <Object?>[
        artikel.id,
      ]);
      expect(raw.single['bestand_aktuell'], 0);
    });
  });
}
