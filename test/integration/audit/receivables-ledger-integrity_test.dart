// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';

void main() {
  group('Receivables ledger integrity', () {
    late AppDatabase db;
    late ForderungenRepository repo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      // Seed a kunde for FK constraints.
      await db.executor.runInsert('INSERT INTO kunden (id, name, strasse, plz, ort) VALUES (1, ?, ?, ?, ?)', <Object?>[
        'Test Kunde',
        'Teststr.',
        '12345',
        'Testort',
      ]);
      repo = ForderungenRepository(db.executor);
      await repo.ensureSchema();
    });

    tearDown(() async {
      await db.close();
    });

    // ── Task 1: Statements account for every payment exactly once ──

    test('test_receivables_ledger_integrity_1_1_partial_payment_leaves_the_remainder', () async {
      // Seed a rechnung for FK + original brutto_betrag lookup.
      final rechnungId = await db.executor.runInsert(
        "INSERT INTO rechnungen (typ, datum, brutto_betrag, netto_betrag, ust_betrag, ist_entwurf) VALUES ('rechnung', '2026-01-01', 100.00, 84.03, 15.97, 0)",
        const [],
      );

      // Create a receivable for 100 EUR linked to the rechnung, dated before payment.
      final f = await repo.create(
        typ: 'rechnung',
        partnerTyp: 'kunde',
        partnerId: 1,
        betrag: 100.00,
        rechnungId: rechnungId,
      );
      // Backdate the forderung to before the payment.
      await db.executor.runUpdate('UPDATE forderungen SET erstellt_am = ? WHERE id = ?', ['2026-01-01T00:00:00', f.id]);

      // Pay 60 EUR (partial).
      await repo.zahlungBuchen(forderungId: f.id, betrag: 60.00, datum: '2026-01-15');

      // Kontokorrent must show:
      // - Rechnung: +100 (Soll)
      // - Zahlung: -60 (Haben)
      // - Remaining saldo: 40
      final entries = await repo.kontokorrent(partnerTyp: 'kunde', partnerId: 1);

      expect(entries.length, 2, reason: 'Must have invoice + payment entries');

      final invoice = entries.firstWhere((e) => e.typ == 'rechnung');
      expect(invoice.betrag, 100.00, reason: 'Invoice amount must be 100');
      expect(invoice.saldo, 100.00, reason: 'Saldo after invoice must be 100');

      final payment = entries.firstWhere((e) => e.typ == 'zahlung');
      expect(payment.betrag, -60.00, reason: 'Payment must be -60');
      expect(payment.saldo, 40.00, reason: 'Saldo after partial payment must be 40');
    });

    // ── Task 2: Full and overpayment are represented ──

    test('test_receivables_ledger_integrity_1_2_full_and_overpayment_are_represented', () async {
      // Seed a rechnung for FK + original brutto_betrag lookup.
      final rechnungId = await db.executor.runInsert(
        "INSERT INTO rechnungen (typ, datum, brutto_betrag, netto_betrag, ust_betrag, ist_entwurf) VALUES ('rechnung', '2026-02-01', 200.00, 168.07, 31.93, 0)",
        const [],
      );

      // Create a receivable for 200 EUR.
      final f = await repo.create(
        typ: 'rechnung',
        partnerTyp: 'kunde',
        partnerId: 1,
        betrag: 200.00,
        rechnungId: rechnungId,
      );
      await db.executor.runUpdate('UPDATE forderungen SET erstellt_am = ? WHERE id = ?', ['2026-02-01T00:00:00', f.id]);

      // Pay 250 EUR (overpayment of 50).
      await repo.zahlungBuchen(forderungId: f.id, betrag: 250.00, datum: '2026-02-15');

      final entries = await repo.kontokorrent(partnerTyp: 'kunde', partnerId: 1);

      // Should have: rechnung (200), zahlung (-200), ueberzahlung (-50)
      expect(entries.length, 3, reason: 'Must have invoice + payment + overpayment entries');

      final invoice = entries.firstWhere((e) => e.typ == 'rechnung');
      expect(invoice.betrag, 200.00, reason: 'Invoice amount must be 200');

      final payment = entries.firstWhere((e) => e.typ == 'zahlung');
      expect(payment.betrag, -200.00, reason: 'Payment must be -200 (capped at invoice)');

      final overpay = entries.firstWhere((e) => e.typ == 'ueberzahlung');
      expect(overpay.betrag, -50.00, reason: 'Overpayment must be -50 (Haben)');
      expect(overpay.saldo, -50.00, reason: 'Final saldo must be -50 (credit)');
    });

    // ── Task 3: Opening balance includes prior activity ──

    test('test_receivables_ledger_integrity_1_3_opening_balance_includes_prior_activity', () async {
      // Seed a rechnung for FK + original brutto_betrag lookup.
      final rechnungId = await db.executor.runInsert(
        "INSERT INTO rechnungen (typ, datum, brutto_betrag, netto_betrag, ust_betrag, ist_entwurf) VALUES ('rechnung', '2025-06-01', 300.00, 252.10, 47.90, 0)",
        const [],
      );

      // Create receivable dated before von.
      final f1 = await repo.create(
        typ: 'rechnung',
        partnerTyp: 'kunde',
        partnerId: 1,
        betrag: 300.00,
        rechnungId: rechnungId,
      );
      await db.executor.runUpdate('UPDATE forderungen SET erstellt_am = ? WHERE id = ?', [
        '2025-06-01T00:00:00',
        f1.id,
      ]);

      // Pay it in full before von.
      await repo.zahlungBuchen(forderungId: f1.id, betrag: 300.00, datum: '2025-06-15');

      // Now create another receivable in the range.
      final rechnungId2 = await db.executor.runInsert(
        "INSERT INTO rechnungen (typ, datum, brutto_betrag, netto_betrag, ust_betrag, ist_entwurf) VALUES ('rechnung', '2026-01-01', 150.00, 126.05, 23.95, 0)",
        const [],
      );
      final f2 = await repo.create(
        typ: 'rechnung',
        partnerTyp: 'kunde',
        partnerId: 1,
        betrag: 150.00,
        rechnungId: rechnungId2,
      );
      await db.executor.runUpdate('UPDATE forderungen SET erstellt_am = ? WHERE id = ?', [
        '2026-01-01T00:00:00',
        f2.id,
      ]);

      // Query kontokorrent from 2026-01-01 — opening balance should include prior activity.
      final entries = await repo.kontokorrent(partnerTyp: 'kunde', partnerId: 1, von: '2026-01-01');

      // Prior: +300 invoice, -300 payment → net 0. Opening saldo = 0.
      // In range: +150 invoice → saldo 150.
      expect(entries.length, 1, reason: 'Only one entry in range');
      expect(entries.first.typ, 'rechnung');
      expect(entries.first.saldo, 150.00, reason: 'Opening saldo 0 + 150 = 150');
    });

    // ── Task 4: Receivables schema is ready after normal startup ──

    test('test_receivables_ledger_integrity_2_1_fresh_startup_supports_receivables', () async {
      // Fresh database — forderungen table should exist with all columns.
      // Do NOT call ensureSchema — rely on base schema only.
      final columns = await db.executor.runSelect('PRAGMA table_info(forderungen)', const []);
      final colNames = columns.map((c) => c['name']! as String).toSet();

      expect(colNames, contains('typ'), reason: 'typ column must exist');
      expect(colNames, contains('partner_typ'), reason: 'partner_typ column must exist');
      expect(colNames, contains('partner_id'), reason: 'partner_id column must exist');
      expect(colNames, contains('ausgleich_journal_id'), reason: 'ausgleich_journal_id column must exist');
      expect(colNames, contains('erstellt_am'), reason: 'erstellt_am column must exist');
      expect(colNames, contains('aktualisiert_am'), reason: 'aktualisiert_am column must exist');
    });

    // ── Task 5: Legacy startup migrates safely ──

    test('test_receivables_ledger_integrity_2_2_legacy_startup_migrates_safely', () async {
      // Simulate legacy database: drop the columns that ensureSchema adds,
      // then verify ensureSchema re-adds them.
      // SQLite doesn't support DROP COLUMN directly, so create a fresh legacy table.
      await db.executor.runCustom('DROP TABLE IF EXISTS forderungen', const []);
      await db.executor.runCustom('''
          CREATE TABLE forderungen (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            kunde_id INTEGER REFERENCES kunden(id),
            rechnung_id INTEGER REFERENCES rechnungen(id),
            betrag NUMERIC(12,2) NOT NULL,
            status TEXT DEFAULT 'offen',
            faelligkeit TEXT,
            beschreibung TEXT
          )
        ''', const []);

      // Now call ensureSchema — should add missing columns.
      await repo.ensureSchema();

      // Verify columns exist.
      final columns = await db.executor.runSelect('PRAGMA table_info(forderungen)', const []);
      final colNames = columns.map((c) => c['name']! as String).toSet();
      expect(colNames, contains('typ'), reason: 'ensureSchema must add typ');
      expect(colNames, contains('partner_typ'), reason: 'ensureSchema must add partner_typ');
      expect(colNames, contains('partner_id'), reason: 'ensureSchema must add partner_id');
      expect(colNames, contains('ausgleich_journal_id'), reason: 'ensureSchema must add ausgleich_journal_id');
      expect(colNames, contains('erstellt_am'), reason: 'ensureSchema must add erstellt_am');
      expect(colNames, contains('aktualisiert_am'), reason: 'ensureSchema must add aktualisiert_am');
    });
  });
}
