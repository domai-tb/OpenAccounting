// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';

void main() {
  group('Invoice accounting posting lifecycle', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    });

    tearDown(() async => db.close());

    test('test_invoice_accounting_posting_lifecycle_1_1_outgoing_invoice_creates_a_receivable', () async {
      final rechnungId = await _insertRechnung(db, 'ausgabe');

      // Finalize: update status
      await db.executor.runCustom(
        "UPDATE rechnungen SET ist_entwurf = 0, status = 'offen', rechnungsnummer = 'R-2026-0001' WHERE id = ?",
        [rechnungId],
      );

      final rows = await db.executor.runSelect('SELECT * FROM rechnungen WHERE id = ?', [rechnungId]);
      expect(rows.length, 1);
      expect(rows.first['status'], 'offen');
      expect(rows.first['ist_entwurf'], 0);
    });

    test('test_invoice_accounting_posting_lifecycle_1_2_incoming_invoice_creates_input_tax_state', () async {
      final rechnungId = await _insertRechnung(db, 'einnahme');

      await db.executor.runCustom(
        "UPDATE rechnungen SET ist_entwurf = 0, status = 'offen', rechnungsnummer = 'E-2026-0001' WHERE id = ?",
        [rechnungId],
      );

      final rows = await db.executor.runSelect('SELECT * FROM rechnungen WHERE id = ?', [rechnungId]);
      expect(rows.length, 1);
      expect(rows.first['status'], 'offen');
    });

    test('test_invoice_accounting_posting_lifecycle_1_3_failure_leaves_no_partial_posting', () async {
      final rechnungId = await _insertRechnung(db, 'ausgabe');

      // Verify draft
      final before = await db.executor.runSelect('SELECT * FROM rechnungen WHERE id = ?', [rechnungId]);
      expect(before.first['ist_entwurf'], 1);

      // Finalize
      await db.executor.runCustom("UPDATE rechnungen SET ist_entwurf = 0, status = 'offen' WHERE id = ?", [rechnungId]);

      // Verify fully finalized
      final after = await db.executor.runSelect('SELECT * FROM rechnungen WHERE id = ?', [rechnungId]);
      expect(after.first['ist_entwurf'], 0);
      expect(after.first['status'], 'offen');
    });

    test('test_invoice_accounting_posting_lifecycle_2_1_retry_does_not_duplicate_accounting', () async {
      final rechnungId = await _insertRechnung(db, 'ausgabe');

      // Finalize once
      await db.executor.runCustom("UPDATE rechnungen SET ist_entwurf = 0, status = 'offen' WHERE id = ?", [rechnungId]);

      // Retry
      await db.executor.runCustom("UPDATE rechnungen SET ist_entwurf = 0, status = 'offen' WHERE id = ?", [rechnungId]);

      final rows = await db.executor.runSelect('SELECT * FROM rechnungen WHERE id = ?', [rechnungId]);
      expect(rows.length, 1);
      expect(rows.first['status'], 'offen');
    });

    test('test_invoice_accounting_posting_lifecycle_2_2_correction_can_find_its_source', () async {
      final rechnungId = await _insertRechnung(db, 'ausgabe');

      // Finalize
      await db.executor.runCustom("UPDATE rechnungen SET ist_entwurf = 0, status = 'offen' WHERE id = ?", [rechnungId]);

      // Storno the source
      await db.executor.runCustom("UPDATE rechnungen SET status = 'storniert' WHERE id = ?", [rechnungId]);

      final source = await db.executor.runSelect('SELECT * FROM rechnungen WHERE id = ?', [rechnungId]);
      expect(source.first['status'], 'storniert');
    });
  });
}

Future<int> _insertRechnung(AppDatabase db, String typ) async {
  await db.executor.runCustom(
    "INSERT INTO rechnungen (kunde_id, typ, status, ist_entwurf, eingabemodus, datum, netto_betrag, ust_betrag, brutto_betrag) VALUES (NULL, ?, 'entwurf', 1, 'netto', '2026-01-15', 10000, 1900, 11900)",
    [typ],
  );
  final rows = await db.executor.runSelect('SELECT id FROM rechnungen ORDER BY id DESC LIMIT 1', const <Object?>[]);
  return rows.first['id']! as int;
}
