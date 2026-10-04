import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_mode_repository.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';

/// Profile import mode behavior + per-import override (bank-import sections 4-5).
void main() {
  group('Import mode behavior', () {
    late AppDatabase db;
    late BankImportService service;
    late BankImportModeRepository modes;
    late int kontoId;
    late int kategorieId;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      service = BankImportService(db.executor);
      modes = BankImportModeRepository(db.executor);
      kontoId = await db.executor.runInsert('INSERT INTO konten (name, iban) VALUES (?, ?)', const <Object?>[
        'Giro',
        'DE001',
      ]);
      kategorieId = await db.executor.runInsert(
        "INSERT INTO kategorien (bezeichnung, aktiv) VALUES ('Moduskat', 1)",
        const <Object?>[],
      );
      await db.executor.runInsert("INSERT INTO unternehmen (name) VALUES ('Testprofil')", const <Object?>[]);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> addJournal() {
      return db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>['2026-03-10', 'Amazon Bestellung 123', kategorieId, '100.00', 'Einnahme'],
      );
    }

    RawTx matchingTx() {
      return RawTx(
        datum: DateTime.parse('2026-03-12'),
        betrag: '100.00',
        verwendungszweck: 'Rechnung Amazon',
        partner: 'Amazon',
      );
    }

    Future<int> journalCount() async {
      final rows = await db.executor.runSelect('SELECT COUNT(*) AS c FROM journal', const []);
      return ((rows.single['c']! as num)).toInt();
    }

    test('test_automatic_mode', () async {
      await modes.setMode(BankImportMode.automatic);
      final int journalId = await addJournal();
      final before = await journalCount();
      final result = await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[matchingTx()],
        mode: 'automatisch',
        locale: 'de_DE',
      );
      final rows = await db.executor.runSelect('SELECT journal_id, status FROM bank_transaktionen', const []);
      expect(rows.single['journal_id'], journalId);
      expect(rows.single['status'], 'gebucht');
      expect(await journalCount(), before, reason: 'no journal entry is created');
      expect(result.candidatesUnavailable, isFalse);
    });

    test('test_manual_mode', () async {
      await modes.setMode(BankImportMode.manual);
      await addJournal();
      final result = await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[matchingTx()],
        mode: 'manuell',
        locale: 'de_DE',
      );
      final rows = await db.executor.runSelect('SELECT journal_id, status FROM bank_transaktionen', const []);
      expect(rows.single['journal_id'], isNull);
      expect(rows.single['status'], 'neu');
      expect(result.candidatesUnavailable, isFalse);
    });

    test('test_override_for_single_import', () async {
      await modes.setMode(BankImportMode.manual);
      final int journalId = await addJournal();
      final result = await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[matchingTx()],
        mode: 'automatisch',
        locale: 'de_DE',
      );
      final rows = await db.executor.runSelect('SELECT journal_id FROM bank_transaktionen', const []);
      expect(rows.single['journal_id'], journalId);
      expect(result.candidatesUnavailable, isFalse);
    });

    test('test_override_does_not_persist', () async {
      await modes.setMode(BankImportMode.manual);
      await addJournal();
      await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[matchingTx()],
        mode: 'automatisch',
        locale: 'de_DE',
      );
      expect(await modes.getMode(), BankImportMode.manual);

      await modes.setMode(BankImportMode.automatic);
      await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[matchingTx()],
        mode: 'manuell',
        locale: 'de_DE',
      );
      expect(await modes.getMode(), BankImportMode.automatic);
    });
  });
}
