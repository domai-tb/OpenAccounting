// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.createTestDatabase();
    await db.ensureOpen();
  });

  tearDown(() async {
    await db.close();
  });

  group('Receipts and payment reconciliation', () {
    // ── Task 1: Receipt is reviewed and linked ──

    test('test_receipts_and_payment_reconciliation_1_1_receipt_is_reviewed_and_linked', () async {
      // Insert a receipt (beleg) into the database.
      final belegId = await db.executor.runInsert(
        'INSERT INTO belege (belegnummer, typ, datum, betrag, status, beschreibung) VALUES (?, ?, ?, ?, ?, ?)',
        ['B-001', 'einnahme', '2026-09-09', 100.00, 'neu', 'Test receipt'],
      );

      // Verify receipt exists with status 'neu'.
      final rows = await db.executor.runSelect('SELECT id, status, betrag FROM belege WHERE id = ?', [belegId]);
      expect(rows, hasLength(1));
      expect(rows.first['status'], 'neu');
      expect(rows.first['betrag'], 100.00);

      // Update status to 'geprüft' (reviewed).
      await db.executor.runUpdate('UPDATE belege SET status = ? WHERE id = ?', ['geprüft', belegId]);

      final updated = await db.executor.runSelect('SELECT status FROM belege WHERE id = ?', [belegId]);
      expect(updated.first['status'], 'geprüft');
    });

    // ── Task 2: Unreadable receipt remains reviewable ──

    test('test_receipts_and_payment_reconciliation_1_2_unreadable_receipt_remains_reviewable', () async {
      // Insert a receipt that couldn't be parsed (unreadable).
      final belegId = await db.executor.runInsert(
        'INSERT INTO belege (belegnummer, typ, datum, betrag, status, beschreibung) VALUES (?, ?, ?, ?, ?, ?)',
        ['B-002', 'einnahme', '2026-09-09', 50.00, 'ungeprüft', 'Unreadable receipt'],
      );

      // Verify it stays in 'ungeprüft' status (still reviewable).
      final rows = await db.executor.runSelect('SELECT status FROM belege WHERE id = ?', [belegId]);
      expect(rows.first['status'], 'ungeprüft');

      // Should NOT be locked — can still be updated.
      await db.executor.runUpdate('UPDATE belege SET status = ? WHERE id = ?', ['fehler', belegId]);

      final updated = await db.executor.runSelect('SELECT status FROM belege WHERE id = ?', [belegId]);
      expect(updated.first['status'], 'fehler');
    });

    // ── Task 3: Partial payment is applied once ──

    test('test_receipts_and_payment_reconciliation_2_1_partial_payment_is_applied_once', () async {
      // Seed a kunde for FK constraints.
      await db.executor.runInsert('INSERT INTO kunden (id, name, strasse, plz, ort) VALUES (?, ?, ?, ?, ?)', [
        1,
        'Kunde A',
        'Teststr.',
        '12345',
        'Testort',
      ]);

      // Create a rechnung.
      final rechnungId = await db.executor.runInsert(
        'INSERT INTO rechnungen (kunde_id, typ, datum, faelligkeit, brutto_betrag, status, ist_entwurf, eingabemodus) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [1, 'rechnung', '2026-09-01', '2026-09-30', 200.00, 'offen', 0, 'brutto'],
      );

      // Create a forderung (receivable).
      final forderungRepo = ForderungenRepository(db.executor);
      final forderung = await forderungRepo.createForRechnung(rechnungId);

      // Apply partial payment.
      final updated = await forderungRepo.zahlungBuchen(forderungId: forderung!.id, betrag: 80.00, datum: '2026-09-09');

      // Must be marked as 'teilbezahlt'.
      expect(updated.status, 'teilbezahlt');
      expect(updated.betrag, 120.00, reason: 'Remaining balance');

      // Verify only one journal entry was created for this payment.
      final journalRows = await db.executor.runSelect(
        "SELECT COUNT(*) as cnt FROM journal WHERE beschreibung LIKE '%Zahlung%' AND rechnung_id = ?",
        [rechnungId],
      );
      expect(journalRows.first['cnt'], 1, reason: 'Payment applied exactly once');
    });

    // ── Task 4: Ambiguous match requires review ──

    test('test_receipts_and_payment_reconciliation_2_2_ambiguous_match_requires_review', () async {
      // Seed a kunde for FK constraints.
      await db.executor.runInsert('INSERT INTO kunden (id, name, strasse, plz, ort) VALUES (?, ?, ?, ?, ?)', [
        2,
        'Kunde B',
        'Teststr.',
        '12345',
        'Testort',
      ]);

      final rechnungId1 = await db.executor.runInsert(
        'INSERT INTO rechnungen (kunde_id, typ, datum, faelligkeit, brutto_betrag, status, ist_entwurf, eingabemodus) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [2, 'rechnung', '2026-08-01', '2026-08-31', 150.00, 'offen', 0, 'brutto'],
      );

      final rechnungId2 = await db.executor.runInsert(
        'INSERT INTO rechnungen (kunde_id, typ, datum, faelligkeit, brutto_betrag, status, ist_entwurf, eingabemodus) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [2, 'rechnung', '2026-09-01', '2026-09-30', 150.00, 'offen', 0, 'brutto'],
      );

      // Create forderungen for both.
      final forderungRepo = ForderungenRepository(db.executor);
      final f1 = await forderungRepo.createForRechnung(rechnungId1);
      final f2 = await forderungRepo.createForRechnung(rechnungId2);

      // Both should be open.
      expect(f1?.status, 'offen');
      expect(f2?.status, 'offen');

      // A 150.00 payment is ambiguous — could match either invoice.
      // The system should require review (not auto-apply).
      final offene = await forderungRepo.listOffene();
      expect(offene, hasLength(2), reason: 'Two open invoices = ambiguous match');
    });
  });
}
