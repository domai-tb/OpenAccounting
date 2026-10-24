import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/beleg_typ.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/setup/setup_repository.dart';

void main() {
  group('Cashbook v26 setup opening source', () {
    late AppDatabase db;
    late SetupRepository repository;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repository = SetupRepository(db.executor);
      await repository.saveUnternehmen(name: 'Cashbook Source Test GmbH');
    });

    tearDown(() => db.close());

    test('test_setup_opening_source_commits_atomically', () async {
      await _expectSetupFailuresToRollBack(db, repository, _newAccountWriteFailures);
    });

    test('failed company creation leaves setup state unchanged', () async {
      await db.executor.runCustom('DELETE FROM unternehmen WHERE id = 1');

      await _expectSetupFailuresToRollBack(db, repository, const <_InjectedSetupWriteFailure>[_companyInsertFailure]);
    });

    test('existing Kasse setup rolls back every write failure', () async {
      await db.executor.runInsert(
        'INSERT INTO konten (name, kontoart, waehrung, unternehmen_id, saldo) VALUES (?, ?, ?, ?, ?)',
        const <Object?>['Kasse', 'Bank', 'EUR', null, '0.00'],
      );

      await _expectSetupFailuresToRollBack(db, repository, _existingAccountWriteFailures);
    });

    test('test_setup_rejects_initial_nonzero_saldo_without_journal_history', () async {
      final int accountId = await db.executor.runInsert(
        'INSERT INTO konten (name, kontoart, waehrung, unternehmen_id, saldo) VALUES (?, ?, ?, ?, ?)',
        const <Object?>['Kasse', 'Kasse', 'EUR', 1, '25.00'],
      );
      final List<Map<String, Object?>> accountBefore = await db.executor.runSelect(
        'SELECT id, name, kontoart, waehrung, unternehmen_id, saldo FROM konten WHERE id = ?',
        <Object?>[accountId],
      );
      final List<Map<String, Object?>> journalBefore = await db.executor.runSelect(
        'SELECT id, datum, konto_id, betrag, beleg_typ, beschreibung FROM journal WHERE konto_id = ? ORDER BY id',
        <Object?>[accountId],
      );
      final List<Map<String, Object?>> sourcesBefore = await db.executor.runSelect(
        'SELECT * FROM account_opening_balance_sources WHERE konto_id = ?',
        <Object?>[accountId],
      );
      expect(journalBefore, isEmpty, reason: 'This case isolates saldo from pre-existing journal history.');
      expect(sourcesBefore, isEmpty);

      await expectLater(repository.ensureKassenKonto(betrag: '125.00'), throwsA(isA<SetupException>()));

      expect(
        await db.executor.runSelect(
          'SELECT id, name, kontoart, waehrung, unternehmen_id, saldo FROM konten WHERE id = ?',
          <Object?>[accountId],
        ),
        equals(accountBefore),
      );
      expect(
        await db.executor.runSelect(
          'SELECT id, datum, konto_id, betrag, beleg_typ, beschreibung FROM journal WHERE konto_id = ? ORDER BY id',
          <Object?>[accountId],
        ),
        equals(journalBefore),
      );
      expect(
        await db.executor.runSelect('SELECT * FROM account_opening_balance_sources WHERE konto_id = ?', <Object?>[
          accountId,
        ]),
        equals(sourcesBefore),
      );
    });

    test('test_setup_retry_preserves_opening_source_identity', () async {
      await repository.ensureKassenKonto(betrag: '125.00');
      final List<Map<String, Object?>> originalRows = await _readSources(db);
      expect(originalRows, hasLength(1));
      final Map<String, Object?> originalSource = originalRows.single;
      expect(originalSource['unternehmen_id'], 1);
      expect(originalSource['amount_cents'], 12500);
      expect(originalSource['currency_code'], 'EUR');
      expect(originalSource['source_reference'], isNotEmpty);

      final List<Map<String, Object?>> linkedRows = await db.executor.runSelect(
        'SELECT k.unternehmen_id, k.waehrung, k.saldo, j.konto_id, j.datum, j.betrag, j.beleg_typ, '
        'j.is_opening_balance FROM konten AS k JOIN journal AS j ON j.id = ? WHERE k.id = ?',
        <Object?>[originalSource['journal_id'], originalSource['konto_id']],
      );
      expect(linkedRows, hasLength(1));
      expect(linkedRows.single['unternehmen_id'], originalSource['unternehmen_id']);
      expect(linkedRows.single['waehrung'], originalSource['currency_code']);
      expect(money.formatBetrag(linkedRows.single['saldo'].toString()), '125.00');
      expect(linkedRows.single['konto_id'], originalSource['konto_id']);
      expect(linkedRows.single['datum'], originalSource['effective_date']);
      expect(money.formatBetrag(linkedRows.single['betrag'].toString()), '125.00');
      expect(linkedRows.single['beleg_typ'], 'Eroeffnung');
      expect(linkedRows.single['is_opening_balance'], 1);
      final List<Map<String, Object?>> originalJournalRows = await _readJournal(db, originalSource['journal_id']);

      await repository.ensureKassenKonto(betrag: '125.00');
      expect(await _readSources(db), equals(originalRows));
      expect(await _readJournal(db, originalSource['journal_id']), equals(originalJournalRows));

      final int accountId = (originalSource['konto_id']! as num).toInt();
      final DateTime openingDate = DateTime.parse(originalSource['effective_date']! as String);
      final String movementDate = openingDate.add(const Duration(days: 1)).toIso8601String().substring(0, 10);
      final int laterMovementId = await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, konto_id, immutable, is_opening_balance) '
        'VALUES (?, ?, ?, ?, ?, 1, 0)',
        <Object?>[movementDate, 'Later cash receipt', '25.00', BelegTyp.einnahme, accountId],
      );
      await db.executor.runUpdate('UPDATE konten SET saldo = ? WHERE id = ?', <Object?>['150.00', accountId]);

      await repository.ensureKassenKonto(betrag: '125.00');
      expect(await _readSources(db), equals(originalRows));
      expect(await _readJournal(db, originalSource['journal_id']), equals(originalJournalRows));
      expect(await _readJournal(db, laterMovementId), hasLength(1));
      final List<Map<String, Object?>> balanceAfterExactRetry = await db.executor.runSelect(
        'SELECT saldo FROM konten WHERE id = ?',
        <Object?>[accountId],
      );
      expect(money.formatBetrag(balanceAfterExactRetry.single['saldo'].toString()), '150.00');

      await expectLater(repository.ensureKassenKonto(betrag: '150.00'), throwsA(isA<Object>()));
      expect(await _readSources(db), equals(originalRows));
      expect(await _readJournal(db, originalSource['journal_id']), equals(originalJournalRows));
      expect(await _readJournal(db, laterMovementId), hasLength(1));
      final List<Map<String, Object?>> accountBalances = await db.executor.runSelect(
        'SELECT saldo FROM konten WHERE id = ?',
        <Object?>[originalSource['konto_id']],
      );
      expect(accountBalances, hasLength(1));
      expect(money.formatBetrag(accountBalances.single['saldo'].toString()), '150.00');
    });

    test('test_legacy_opening_without_source_is_not_adopted', () async {
      await _ensureOpeningBalanceMarker(db);
      final int accountId = await db.executor.runInsert(
        'INSERT INTO konten (name, kontoart, waehrung, unternehmen_id, saldo) VALUES (?, ?, ?, ?, ?)',
        const <Object?>['Kasse', 'Kasse', 'EUR', 1, '125.00'],
      );
      final int journalId = await db.executor.runInsert(
        'INSERT INTO journal (datum, konto_id, betrag, beleg_typ, beschreibung, is_opening_balance) '
        'VALUES (?, ?, ?, ?, ?, 1)',
        <Object?>['2025-01-01', accountId, '125.00', 'eroeffnung', 'Legacy Kassenöffnung'],
      );
      final List<Map<String, Object?>> accountsBefore = await db.executor.runSelect(
        'SELECT id, unternehmen_id, kontoart, waehrung, saldo FROM konten WHERE id = ?',
        <Object?>[accountId],
      );
      final List<Map<String, Object?>> journalBefore = await _readJournal(db, journalId);

      await expectLater(repository.ensureKassenKonto(betrag: '125.00'), throwsA(isA<Object>()));

      expect(
        await db.executor.runSelect(
          'SELECT id, unternehmen_id, kontoart, waehrung, saldo FROM konten WHERE id = ?',
          <Object?>[accountId],
        ),
        equals(accountsBefore),
      );
      expect(await _readJournal(db, journalId), equals(journalBefore));
      expect(await _readSources(db), isEmpty);
    });

    test('unrelated account opening source does not satisfy Kasse setup', () async {
      await _ensureOpeningBalanceMarker(db);
      final int bankAccountId = await db.executor.runInsert(
        'INSERT INTO konten (name, kontoart, waehrung, unternehmen_id, saldo) VALUES (?, ?, ?, ?, ?)',
        const <Object?>['Bank', 'Bank', 'EUR', 1, '50.00'],
      );
      final List<Map<String, Object?>> categories = await db.executor.runSelect(
        'SELECT id FROM kategorien LIMIT 1',
        const <Object?>[],
      );
      final int categoryId = categories.isEmpty
          ? await db.executor.runInsert(
              'INSERT INTO kategorien (bezeichnung, beschreibung, aktiv, mapping_status) '
              "VALUES ('Opening Test', 'Test fixture', 1, 'unmapped')",
              const <Object?>[],
            )
          : (categories.single['id'] as num?)!.toInt();
      final int bankJournalId = await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, konto_id, is_opening_balance) '
        'VALUES (?, ?, ?, ?, ?, ?, 1)',
        <Object?>['2025-01-01', 'Bank opening', categoryId, '50.00', 'Eroeffnung', bankAccountId],
      );
      await db.executor.runInsert(
        'INSERT INTO account_opening_balance_sources '
        '(unternehmen_id, konto_id, journal_id, effective_date, amount_cents, currency_code, source_reference) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[1, bankAccountId, bankJournalId, '2025-01-01', 5000, 'EUR', 'bank-opening:1:$bankAccountId'],
      );

      await repository.ensureKassenKonto(betrag: '125.00');

      final List<Map<String, Object?>> sources = await _readSources(db);
      expect(sources, hasLength(2));
      expect(sources.where((Map<String, Object?> row) => row['konto_id'] == bankAccountId), hasLength(1));
      final Map<String, Object?> cashSource = sources.singleWhere(
        (Map<String, Object?> row) => row['konto_id'] != bankAccountId,
      );
      expect(cashSource['unternehmen_id'], 1);
      expect(cashSource['amount_cents'], 12500);
      expect(cashSource['journal_id'], isNot(bankJournalId));
      expect(cashSource['source_reference'], 'setup-opening:1:${cashSource['konto_id']}');
    });
  });
}

const _InjectedSetupWriteFailure _companyInsertFailure = _InjectedSetupWriteFailure(
  'company creation',
  'fail_cashbook_company_insert',
  '''
CREATE TRIGGER fail_cashbook_company_insert
BEFORE INSERT ON unternehmen
WHEN NEW.id = 1
BEGIN
  SELECT RAISE(ABORT, 'injected company insert failure');
END
''',
);

const List<_InjectedSetupWriteFailure> _newAccountWriteFailures = <_InjectedSetupWriteFailure>[
  _InjectedSetupWriteFailure('account creation', 'fail_cashbook_account_insert', '''
CREATE TRIGGER fail_cashbook_account_insert
BEFORE INSERT ON konten
WHEN NEW.kontoart = 'Kasse'
BEGIN
  SELECT RAISE(ABORT, 'injected Kasse account insert failure');
END
'''),
  _InjectedSetupWriteFailure('opening category creation', 'fail_cashbook_category_insert', '''
CREATE TRIGGER fail_cashbook_category_insert
BEFORE INSERT ON kategorien
WHEN NEW.bezeichnung = 'Eröffnung'
BEGIN
  SELECT RAISE(ABORT, 'injected opening category insert failure');
END
'''),
  _InjectedSetupWriteFailure('opening journal insertion', 'fail_cashbook_journal_insert', '''
CREATE TRIGGER fail_cashbook_journal_insert
BEFORE INSERT ON journal
WHEN NEW.beschreibung = 'Eröffnung Kasse'
BEGIN
  SELECT RAISE(ABORT, 'injected opening journal insert failure');
END
'''),
  _InjectedSetupWriteFailure('opening saldo update', 'fail_cashbook_saldo_update', '''
CREATE TRIGGER fail_cashbook_saldo_update
BEFORE UPDATE OF saldo ON konten
WHEN OLD.saldo <> NEW.saldo
BEGIN
  SELECT RAISE(ABORT, 'injected opening saldo update failure');
END
'''),
  _InjectedSetupWriteFailure('opening source insertion', 'fail_cashbook_source_insert', '''
CREATE TRIGGER fail_cashbook_source_insert
BEFORE INSERT ON account_opening_balance_sources
BEGIN
  SELECT RAISE(ABORT, 'injected opening source insert failure');
END
'''),
];

const List<_InjectedSetupWriteFailure> _existingAccountWriteFailures = <_InjectedSetupWriteFailure>[
  _InjectedSetupWriteFailure('account association update', 'fail_cashbook_account_association', '''
CREATE TRIGGER fail_cashbook_account_association
BEFORE UPDATE OF unternehmen_id ON konten
WHEN OLD.unternehmen_id IS NULL AND NEW.unternehmen_id = 1
BEGIN
  SELECT RAISE(ABORT, 'injected account association failure');
END
'''),
  _InjectedSetupWriteFailure('opening category creation', 'fail_cashbook_existing_category_insert', '''
CREATE TRIGGER fail_cashbook_existing_category_insert
BEFORE INSERT ON kategorien
WHEN NEW.bezeichnung = 'Eröffnung'
BEGIN
  SELECT RAISE(ABORT, 'injected opening category insert failure');
END
'''),
  _InjectedSetupWriteFailure('opening journal insertion', 'fail_cashbook_existing_journal_insert', '''
CREATE TRIGGER fail_cashbook_existing_journal_insert
BEFORE INSERT ON journal
WHEN NEW.beschreibung = 'Eröffnung Kasse'
BEGIN
  SELECT RAISE(ABORT, 'injected opening journal insert failure');
END
'''),
  _InjectedSetupWriteFailure('opening saldo update', 'fail_cashbook_existing_saldo_update', '''
CREATE TRIGGER fail_cashbook_existing_saldo_update
BEFORE UPDATE OF saldo ON konten
WHEN OLD.saldo <> NEW.saldo
BEGIN
  SELECT RAISE(ABORT, 'injected opening saldo update failure');
END
'''),
  _InjectedSetupWriteFailure('opening source insertion', 'fail_cashbook_existing_source_insert', '''
CREATE TRIGGER fail_cashbook_existing_source_insert
BEFORE INSERT ON account_opening_balance_sources
BEGIN
  SELECT RAISE(ABORT, 'injected opening source insert failure');
END
'''),
];

class _InjectedSetupWriteFailure {
  const _InjectedSetupWriteFailure(this.label, this.triggerName, this.triggerSql);

  final String label;
  final String triggerName;
  final String triggerSql;
}

Future<void> _expectSetupFailuresToRollBack(
  AppDatabase db,
  SetupRepository repository,
  List<_InjectedSetupWriteFailure> failures,
) async {
  for (final _InjectedSetupWriteFailure failure in failures) {
    await db.executor.runCustom(failure.triggerSql);
    final Map<String, List<Map<String, Object?>>> before = await _readSetupWriteState(db);
    try {
      await expectLater(
        repository.ensureKassenKonto(betrag: '125.00'),
        throwsA(predicate((Object? error) => error.toString().contains('injected '))),
        reason: 'Injected ${failure.label} failure should propagate from its write boundary',
      );
      expect(
        await _readSetupWriteState(db),
        equals(before),
        reason: 'Injected ${failure.label} failure should leave every setup write unchanged',
      );
    } finally {
      await db.executor.runCustom('DROP TRIGGER ${failure.triggerName}');
    }
  }
}

Future<Map<String, List<Map<String, Object?>>>> _readSetupWriteState(AppDatabase db) async {
  final Map<String, List<Map<String, Object?>>> state = <String, List<Map<String, Object?>>>{};
  for (final String table in <String>[
    'unternehmen',
    'konten',
    'kategorien',
    'journal',
    'account_opening_balance_sources',
  ]) {
    state[table] = await db.executor.runSelect('SELECT * FROM $table ORDER BY id', const <Object?>[]);
  }
  return state;
}

Future<void> _ensureOpeningBalanceMarker(AppDatabase db) async {
  final List<Map<String, Object?>> journalColumns = await db.executor.runSelect(
    'PRAGMA table_info(journal)',
    const <Object?>[],
  );
  if (journalColumns.every((Map<String, Object?> column) => column['name'] != 'is_opening_balance')) {
    await db.executor.runCustom('ALTER TABLE journal ADD COLUMN is_opening_balance INTEGER NOT NULL DEFAULT 0');
  }
}

Future<List<Map<String, Object?>>> _readSources(AppDatabase db) {
  return db.executor.runSelect(
    'SELECT id, unternehmen_id, konto_id, journal_id, effective_date, amount_cents, currency_code, source_reference '
    'FROM account_opening_balance_sources',
    const <Object?>[],
  );
}

Future<List<Map<String, Object?>>> _readJournal(AppDatabase db, Object? journalId) {
  return db.executor.runSelect(
    'SELECT id, datum, konto_id, betrag, beleg_typ, beschreibung, is_opening_balance '
    'FROM journal WHERE id = ?',
    <Object?>[journalId],
  );
}
