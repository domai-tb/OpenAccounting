import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart'
    show BatchedStatements, OpeningDetails, QueryExecutor, QueryExecutorUser, SqlDialect, TransactionExecutor;
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

void main() {
  group('Forderungen request fingerprint and conditional transitions', () {
    late _Fixture fixture;

    setUp(() async {
      fixture = await _Fixture.create();
    });

    tearDown(() => fixture.close());

    test('test_keyed_payment_persists_canonical_fingerprint_and_applies_once', () async {
      final Forderung f = await fixture.forderung();
      final Forderung result = await fixture.repo.zahlungBuchen(
        forderungId: f.id,
        betrag: 12.34,
        datum: '2026-09-29',
        idempotencyKey: 'fingerprint-1',
      );
      expect(result.betrag, 87.66);
      final rows = await fixture.db.executor.runSelect(
        'SELECT requested_betrag_cents, forderung_id, fingerprint_direction, fingerprint_date_policy, datum '
        'FROM forderung_zahlungen WHERE idempotency_key = ?',
        <Object?>['fingerprint-1'],
      );
      expect(rows.single['requested_betrag_cents'], 1234);
      expect(rows.single['forderung_id'], f.id);
      expect(rows.single['fingerprint_direction'], 'incoming');
      expect(rows.single['fingerprint_date_policy'], 'explicit');
      expect(rows.single['datum'], '2026-09-29');
    });

    test('test_invalid_keyed_request_has_no_effect', () async {
      final Forderung f = await fixture.forderung();
      final before = await fixture.snapshot(f.id);
      await expectCode(
        fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 0, datum: '2026-02-31', idempotencyKey: 'bad'),
        ForderungenErrorCode.invalidRequest,
      );
      expect(await fixture.snapshot(f.id), before);
    });

    test('test_keyed_amount_with_more_than_two_decimals_is_rejected', () async {
      final Forderung f = await fixture.forderung();
      await expectCode(
        fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 1.005, idempotencyKey: 'scale'),
        ForderungenErrorCode.amountScale,
      );
    });

    test('test_double_inputs_use_exact_decimal_text_without_binary_rounding', () async {
      final Forderung f = await fixture.forderung();
      await expectCode(
        fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 0.1 + 0.2, idempotencyKey: 'binary'),
        ForderungenErrorCode.amountScale,
      );
      final Forderung accepted = await fixture.repo.zahlungBuchen(
        forderungId: f.id,
        betrag: 1.1,
        idempotencyKey: 'decimal',
      );
      expect(accepted.betrag, 98.9);
    });

    test('test_missing_date_uses_injected_utc_request_day', () async {
      final Forderung f = await fixture.forderung();
      await fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 1, idempotencyKey: 'utc-day');
      final rows = await fixture.db.executor.runSelect(
        'SELECT datum, fingerprint_date_policy FROM forderung_zahlungen WHERE idempotency_key = ?',
        <Object?>['utc-day'],
      );
      expect(rows.single['datum'], '2026-09-30');
      expect(rows.single['fingerprint_date_policy'], 'request-day');
    });

    test('test_unknown_partner_direction_is_rejected', () async {
      final Forderung f = await fixture.forderung();
      await fixture.db.executor.runCustom('PRAGMA ignore_check_constraints = ON');
      await fixture.db.executor.runUpdate('UPDATE forderungen SET partner_typ = ? WHERE id = ?', <Object?>[
        'other',
        f.id,
      ]);
      await fixture.db.executor.runCustom('PRAGMA ignore_check_constraints = OFF');
      await expectCode(
        fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 1, datum: '2026-09-29', idempotencyKey: 'direction'),
        ForderungenErrorCode.unknownDirection,
      );
    });

    test('test_null_partner_type_is_preserved_and_returns_unknown_direction', () async {
      final Forderung f = await fixture.nullPartnerForderung();
      expect(f.partnerTyp, null);
      await expectCode(
        fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 1, datum: '2026-09-29', idempotencyKey: 'null-direction'),
        ForderungenErrorCode.unknownDirection,
      );
    });

    test('test_typed_idempotency_conflict_exposes_stable_ordered_fields', () async {
      final Forderung first = await fixture.forderung();
      final Forderung second = await fixture.forderung();
      final List<Object?> before = await fixture.snapshot(first.id);
      await fixture.repo.zahlungBuchen(
        forderungId: first.id,
        betrag: 40,
        datum: '2026-09-29',
        idempotencyKey: 'ordered',
      );
      try {
        // Different target (same direction: both customers), different cents, omitted
        // date resolving to the injected request day with a different date policy.
        await fixture.repo.zahlungBuchen(forderungId: second.id, betrag: 50, idempotencyKey: 'ordered');
        fail('expected idempotency conflict');
      } on ForderungenException catch (error) {
        expect(error.code, ForderungenErrorCode.idempotencyConflict);
        expect(error.mismatchFields, <ForderungenMismatchField>[
          ForderungenMismatchField.requestedCents,
          ForderungenMismatchField.forderungTarget,
          ForderungenMismatchField.datePolicy,
          ForderungenMismatchField.effectiveDate,
        ]);
      }
      // Direction matched, so it is absent from the mismatch list; no loser side effects.
      expect(await fixture.snapshot(first.id), isNot(equals(before)));
      expect(await _tableCount(fixture.db.executor, 'journal'), 1);
      expect(await _tableCount(fixture.db.executor, 'forderung_zahlungen'), 1);
      expect(num.parse((await fixture.snapshot(second.id))[1].toString()), 100);
    });

    test('test_public_error_codes_use_explicit_snake_case_wire_values', () {
      expect(forderungenErrorCodeWireValues, <ForderungenErrorCode, String>{
        ForderungenErrorCode.invalidRequest: 'invalid_request',
        ForderungenErrorCode.amountScale: 'amount_scale',
        ForderungenErrorCode.dateFormat: 'date_format',
        ForderungenErrorCode.unknownDirection: 'unknown_direction',
        ForderungenErrorCode.idempotencyConflict: 'idempotency_conflict',
        ForderungenErrorCode.legacyFingerprintUnknown: 'legacy_fingerprint_unknown',
        ForderungenErrorCode.alreadyClosed: 'already_closed',
        ForderungenErrorCode.concurrentWriteConflict: 'concurrent_write_conflict',
        ForderungenErrorCode.schemaMigrationFailed: 'schema_migration_failed',
      });
      expect(forderungenMismatchFieldWireValues, <ForderungenMismatchField, String>{
        ForderungenMismatchField.requestedCents: 'requested_cents',
        ForderungenMismatchField.forderungTarget: 'forderung_target',
        ForderungenMismatchField.direction: 'direction',
        ForderungenMismatchField.datePolicy: 'date_policy',
        ForderungenMismatchField.effectiveDate: 'effective_date',
      });
    });

    test('test_typed_error_defensively_copies_immutable_mismatch_fields', () {
      final fields = <ForderungenMismatchField>[ForderungenMismatchField.requestedCents];
      final error = ForderungenException(
        'conflict',
        code: ForderungenErrorCode.idempotencyConflict,
        mismatchFields: fields,
      );
      fields.add(ForderungenMismatchField.direction);
      expect(error.mismatchFields, <ForderungenMismatchField>[ForderungenMismatchField.requestedCents]);
      expect(() => error.mismatchFields.add(ForderungenMismatchField.direction), throwsUnsupportedError);
    });

    test('test_typed_error_preserves_human_readable_to_string_message', () {
      final error = ForderungenException('Zahlung bereits verbucht', code: ForderungenErrorCode.idempotencyConflict);
      expect(error.toString(), 'Zahlung bereits verbucht');
    });

    test('test_invalid_request_precedes_date_and_direction_errors', () async {
      final Forderung f = await fixture.forderung();
      await fixture.setUnknownDirection(f.id);
      await expectCode(
        fixture.repo.zahlungBuchen(forderungId: 0, betrag: 0, datum: 'bad', idempotencyKey: 'precedence'),
        ForderungenErrorCode.invalidRequest,
      );
    });

    test('test_amount_scale_precedes_date_errors', () async {
      final Forderung f = await fixture.forderung();
      await expectCode(
        fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 1.005, datum: 'bad', idempotencyKey: 'precedence-scale'),
        ForderungenErrorCode.amountScale,
      );
    });

    test('test_date_errors_precede_unknown_direction_errors', () async {
      final Forderung f = await fixture.forderung();
      await fixture.setUnknownDirection(f.id);
      await expectCode(
        fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 1, datum: 'bad', idempotencyKey: 'precedence-date'),
        ForderungenErrorCode.dateFormat,
      );
    });

    test('test_valid_amount_and_date_expose_unknown_direction', () async {
      final Forderung f = await fixture.forderung();
      await fixture.setUnknownDirection(f.id);
      await expectCode(
        fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 1, datum: '2026-09-29', idempotencyKey: 'unknown'),
        ForderungenErrorCode.unknownDirection,
      );
    });

    test('test_identical_key_and_fingerprint_returns_original_effect', () async {
      final Forderung f = await fixture.forderung();
      final first = await fixture.repo.zahlungBuchen(
        forderungId: f.id,
        betrag: 10,
        datum: '2026-09-29',
        idempotencyKey: 'replay',
      );
      final before = await fixture.counts();
      final second = await fixture.repo.zahlungBuchen(
        forderungId: f.id,
        betrag: 10,
        datum: '2026-09-29',
        idempotencyKey: 'replay',
      );
      expect(second.id, first.id);
      expect(await fixture.counts(), before);
    });

    test('test_reused_key_with_different_amount_is_typed_conflict', () async {
      final Forderung f = await fixture.forderung();
      await fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 10, idempotencyKey: 'amount-conflict');
      await expectCode(
        fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 11, idempotencyKey: 'amount-conflict'),
        ForderungenErrorCode.idempotencyConflict,
      );
    });

    test('test_reused_key_with_different_target_is_typed_conflict', () async {
      final Forderung first = await fixture.forderung();
      final Forderung second = await fixture.forderung();
      await fixture.repo.zahlungBuchen(forderungId: first.id, betrag: 10, idempotencyKey: 'target-conflict');
      try {
        await fixture.repo.zahlungBuchen(forderungId: second.id, betrag: 10, idempotencyKey: 'target-conflict');
        fail('expected conflict');
      } on ForderungenException catch (error) {
        expect(error.code, ForderungenErrorCode.idempotencyConflict);
        expect(error.mismatchFields, contains(ForderungenMismatchField.forderungTarget));
      }
    });

    test('test_reused_key_with_different_date_is_typed_conflict', () async {
      final Forderung f = await fixture.forderung();
      await fixture.repo.zahlungBuchen(
        forderungId: f.id,
        betrag: 10,
        datum: '2026-09-29',
        idempotencyKey: 'date-conflict',
      );
      try {
        await fixture.repo.zahlungBuchen(
          forderungId: f.id,
          betrag: 10,
          datum: '2026-09-30',
          idempotencyKey: 'date-conflict',
        );
        fail('expected conflict');
      } on ForderungenException catch (error) {
        expect(error.code, ForderungenErrorCode.idempotencyConflict);
        expect(error.mismatchFields, contains(ForderungenMismatchField.effectiveDate));
      }
    });

    test('test_concurrent_identical_keyed_requests_commit_one_effect', () async {
      final Forderung f = await fixture.forderung();
      final results = await Future.wait(<Future<Forderung>>[
        fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 10, idempotencyKey: 'race'),
        fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 10, idempotencyKey: 'race'),
      ]);
      expect(results[0].betrag, results[1].betrag);
      expect(
        (await fixture.db.executor.runSelect(
          'SELECT count(*) AS c FROM forderung_zahlungen WHERE idempotency_key = ?',
          <Object?>['race'],
        )).single['c'],
        1,
      );
    });

    test('test_concurrent_conflicting_key_race_reloads_loser_with_ordered_fields', () async {
      final mismatchFields = await _runDeferredWalConflictRace(differentTarget: true);
      expect(mismatchFields, <ForderungenMismatchField>[
        ForderungenMismatchField.requestedCents,
        ForderungenMismatchField.forderungTarget,
        ForderungenMismatchField.direction,
        ForderungenMismatchField.datePolicy,
        ForderungenMismatchField.effectiveDate,
      ]);
    });

    test('test_deferred_wal_sqlite_busy_snapshot_reloads_and_classifies_idempotency_conflict', () async {
      final mismatchFields = await _runDeferredWalConflictRace(differentTarget: false);
      expect(mismatchFields, <ForderungenMismatchField>[
        ForderungenMismatchField.requestedCents,
        ForderungenMismatchField.effectiveDate,
      ]);
    });

    test('test_persistent_sqlite_lock_exhausts_exactly_three_retries', () async {
      final Directory directory = await Directory.systemTemp.createTemp('openaccounting_receivable_lock_payment_');
      final AppDatabase victimDb = AppDatabase.forProfile(directory.path);
      final AppDatabase lockerDb = AppDatabase.forProfile(directory.path);
      try {
        await victimDb.ensureOpen();
        await lockerDb.ensureOpen();
        final ForderungenRepository setupRepo = ForderungenRepository(
          victimDb.executor,
          nowUtc: () => DateTime.utc(2026, 9, 30),
        );
        await setupRepo.ensureSchema();
        final int partnerId = await victimDb.executor.runInsert(
          "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Lock Test', 'A', '10115', 'Berlin', 'DE')",
          const <Object?>[],
        );
        final Forderung f = await setupRepo.create(
          typ: 'rechnung',
          betrag: 100,
          partnerTyp: 'kunde',
          partnerId: partnerId,
        );
        final List<Object?> before = await _accountingSnapshot(victimDb.executor, f.id);
        final int keyedBefore = await _keyedRelationCount(victimDb.executor, f.id);

        final List<int> attempts = <int>[];
        final List<_RecordedStatement> recorded = <_RecordedStatement>[];
        bool inAttempt = false;
        final ForderungenRepository repo = ForderungenRepository(
          _PhaseRecordingExecutor(victimDb.executor, recorded, () => inAttempt),
          nowUtc: () => DateTime.utc(2026, 9, 30),
          onPaymentTransactionAttempt: (int attempt) {
            attempts.add(attempt);
            recorded.add(_RecordedStatement('ATTEMPT_$attempt', inAttempt: true));
            inAttempt = true;
          },
        );
        await repo.ensureSchema();

        // Fixture setup completed above; a separate file-backed executor now holds the
        // persistent write lock while the payment command runs its retry window.
        await lockerDb.executor.runCustom('BEGIN EXCLUSIVE');
        ForderungenException? conflict;
        try {
          await repo.zahlungBuchen(forderungId: f.id, betrag: 5, idempotencyKey: 'locked');
          fail('expected concurrentWriteConflict while the exclusive lock is held');
        } on ForderungenException catch (error) {
          conflict = error;
        }
        await lockerDb.executor.runCustom('ROLLBACK');

        expect(attempts, <int>[1, 2, 3]);
        expect(conflict, isNotNull);
        expect(conflict.code, ForderungenErrorCode.concurrentWriteConflict);
        // The failure comes from real SQLite lock contention, not a manufactured error.
        expect(conflict.cause, isA<SqliteException>());
        final SqliteException cause = conflict.cause! as SqliteException;
        expect(cause.resultCode, anyOf(5, 6), reason: 'SQLITE_BUSY or SQLITE_LOCKED expected');
        expect(cause.extendedResultCode, isNot(517), reason: 'immediate busy, not a deferred snapshot error');
        // No ensureSchema/DDL/PRAGMA/seed SQL runs during the retry attempts; any setup
        // SQL is emitted strictly before attempt 1.
        final List<_RecordedStatement> setupDuringAttempts = recorded
            .where((_RecordedStatement entry) => entry.inAttempt && _isSetupSql(entry.statement))
            .toList();
        expect(setupDuringAttempts, isEmpty);
        final int firstAttemptIndex = recorded.indexWhere((_RecordedStatement entry) => entry.inAttempt);
        for (final _RecordedStatement entry in recorded.where((_RecordedStatement e) => _isSetupSql(e.statement))) {
          expect(recorded.indexOf(entry), lessThan(firstAttemptIndex));
        }
        // After lock release the accounting snapshot and keyed relation count are unchanged.
        expect(await _accountingSnapshot(victimDb.executor, f.id), before);
        expect(await _keyedRelationCount(victimDb.executor, f.id), keyedBefore);
      } finally {
        await victimDb.close();
        await lockerDb.close();
        await directory.delete(recursive: true);
      }
    });

    test('test_legacy_key_returns_unknown_fingerprint_conflict', () async {
      final Forderung f = await fixture.forderung();
      final journalId = await fixture.db.executor.runInsert(
        "INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, rechnung_id, erstellungsdatum) VALUES ('2026-09-29', 'legacy', '1.00', 'zahlung', NULL, CURRENT_TIMESTAMP)",
        const <Object?>[],
      );
      await fixture.db.executor.runInsert(
        "INSERT INTO forderung_zahlungen (forderung_id, journal_id, betrag, typ, datum, idempotency_key) VALUES (?, ?, '1.00', 'zahlung', '2026-09-29', ?)",
        <Object?>[f.id, journalId, 'legacy'],
      );
      await expectCode(
        fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 1, idempotencyKey: 'legacy'),
        ForderungenErrorCode.legacyFingerprintUnknown,
      );
    });

    test('test_valid_writeoff_commits_one_loss_effect', () async {
      final Forderung f = await fixture.forderung(amount: 75);
      final result = await fixture.repo.ausbuchen(forderungId: f.id, grund: 'insolvent');
      expect(result.status, 'ausgebucht');
      expect(
        (await fixture.db.executor.runSelect(
          "SELECT count(*) AS c FROM forderung_zahlungen WHERE typ = 'ausbuchen'",
          const <Object?>[],
        )).single['c'],
        1,
      );
    });

    test('test_two_simultaneous_writeoffs_commit_one_effect', () async {
      await _runFileBackedWriteoffRace();
    });

    test('test_writeoff_and_full_payment_race_has_one_effect_no_orphan', () async {
      await _runFileBackedWriteoffPaymentRace();
    });

    test('test_invalid_or_closed_writeoff_has_no_effect', () async {
      final Forderung f = await fixture.forderung(amount: 75);
      await expectCode(fixture.repo.ausbuchen(forderungId: f.id, grund: ' '), ForderungenErrorCode.invalidRequest);
      await fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 75);
      await expectCode(fixture.repo.ausbuchen(forderungId: f.id, grund: 'late'), ForderungenErrorCode.alreadyClosed);
    });

    test('test_conditional_payment_update_rolls_back_on_observed_balance_race', () async {
      await _runObservedBalanceRace();
    });

    test('test_ordinary_zero_row_conditional_payment_update_is_already_closed_for_every_branch', () async {
      await _runZeroRowPaymentRollbackBranches();
    });

    test('test_persistent_sqlite_lock_exhausts_exactly_three_writeoff_retries', () async {
      final Directory directory = await Directory.systemTemp.createTemp('openaccounting_receivable_lock_writeoff_');
      final AppDatabase victimDb = AppDatabase.forProfile(directory.path);
      final AppDatabase lockerDb = AppDatabase.forProfile(directory.path);
      try {
        await victimDb.ensureOpen();
        await lockerDb.ensureOpen();
        final ForderungenRepository setupRepo = ForderungenRepository(
          victimDb.executor,
          nowUtc: () => DateTime.utc(2026, 9, 30),
        );
        await setupRepo.ensureSchema();
        final int partnerId = await victimDb.executor.runInsert(
          "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Lock Writeoff', 'A', '10115', 'Berlin', 'DE')",
          const <Object?>[],
        );
        final Forderung f = await setupRepo.create(
          typ: 'rechnung',
          betrag: 100,
          partnerTyp: 'kunde',
          partnerId: partnerId,
        );
        final List<Object?> before = await _accountingSnapshot(victimDb.executor, f.id);
        final int lossRelationBefore = await _tableCount(victimDb.executor, 'forderung_zahlungen');

        final List<int> attempts = <int>[];
        final List<_RecordedStatement> recorded = <_RecordedStatement>[];
        bool inAttempt = false;
        final ForderungenRepository repo = ForderungenRepository(
          _PhaseRecordingExecutor(victimDb.executor, recorded, () => inAttempt),
          nowUtc: () => DateTime.utc(2026, 9, 30),
          onWriteoffTransactionAttempt: (int attempt) {
            attempts.add(attempt);
            recorded.add(_RecordedStatement('ATTEMPT_$attempt', inAttempt: true));
            inAttempt = true;
          },
        );
        await repo.ensureSchema();

        await lockerDb.executor.runCustom('BEGIN EXCLUSIVE');
        ForderungenException? conflict;
        try {
          await repo.ausbuchen(forderungId: f.id, grund: 'locked');
          fail('expected concurrentWriteConflict while the exclusive lock is held');
        } on ForderungenException catch (error) {
          conflict = error;
        }
        await lockerDb.executor.runCustom('ROLLBACK');

        expect(attempts, <int>[1, 2, 3]);
        expect(conflict, isNotNull);
        expect(conflict.code, ForderungenErrorCode.concurrentWriteConflict);
        expect(conflict.cause, isA<SqliteException>());
        final SqliteException cause = conflict.cause! as SqliteException;
        expect(cause.resultCode, anyOf(5, 6), reason: 'SQLITE_BUSY or SQLITE_LOCKED expected');
        expect(cause.extendedResultCode, isNot(517), reason: 'immediate busy, not a deferred snapshot error');
        // No ensureSchema/DDL/PRAGMA/seed SQL runs during the retry attempts.
        expect(recorded.where((_RecordedStatement entry) => entry.inAttempt && _isSetupSql(entry.statement)), isEmpty);
        // Status, balance, and loss-journal/relation counts are unchanged after lock release.
        expect(await _accountingSnapshot(victimDb.executor, f.id), before);
        expect(await _tableCount(victimDb.executor, 'forderung_zahlungen'), lossRelationBefore);
      } finally {
        await victimDb.close();
        await lockerDb.close();
        await directory.delete(recursive: true);
      }
    });

    test('test_production_transaction_takes_the_write_lock_immediately', () async {
      final Directory directory = await Directory.systemTemp.createTemp('openaccounting_receivable_immediate_');
      final AppDatabase firstDb = AppDatabase.forProfile(directory.path);
      final AppDatabase secondDb = AppDatabase.forProfile(directory.path);
      try {
        await firstDb.ensureOpen();
        await secondDb.ensureOpen();
        // The production path opens transactions through executor.beginTransaction().
        final TransactionExecutor transaction = firstDb.executor.beginTransaction();
        await transaction.ensureOpen(_TestTransactionUser());
        Object? competingError;
        bool exclusiveAcquired = false;
        try {
          await secondDb.executor.runCustom('BEGIN EXCLUSIVE');
          exclusiveAcquired = true;
        } on SqliteException catch (error) {
          competingError = error;
        }
        if (exclusiveAcquired) await secondDb.executor.runCustom('ROLLBACK');
        // A competing write lock is denied while the first transaction is open, proving
        // the default transaction start already holds the write lock (BEGIN IMMEDIATE).
        expect(competingError, isA<SqliteException>());
        await transaction.rollback();
      } finally {
        await firstDb.close();
        await secondDb.close();
        await directory.delete(recursive: true);
      }
    });
  });
}

Future<void> expectCode(Future<Object?> operation, ForderungenErrorCode code) async {
  try {
    await operation;
    fail('expected ForderungenException with code $code');
  } on ForderungenException catch (error) {
    expect(error.code, code);
  }
}

Future<void> _runObservedBalanceRace() async {
  final Directory directory = await Directory.systemTemp.createTemp('openaccounting_receivable_observed_');
  final AppDatabase firstDb = AppDatabase.forProfile(directory.path);
  final AppDatabase competitorDb = AppDatabase.forProfile(directory.path);
  final _DeferredWalTransactionFactory firstFactory = _DeferredWalTransactionFactory();
  try {
    await firstDb.ensureOpen();
    await competitorDb.ensureOpen();
    DateTime clock() => DateTime.utc(2026, 9, 30);
    final ForderungenRepository setupRepo = ForderungenRepository(firstDb.executor, nowUtc: clock);
    final ForderungenRepository competitorRepo = ForderungenRepository(competitorDb.executor, nowUtc: clock);
    await setupRepo.ensureSchema();
    await competitorRepo.ensureSchema();
    final int partnerId = await firstDb.executor.runInsert(
      "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Observed Race', 'A', '10115', 'Berlin', 'DE')",
      const <Object?>[],
    );
    final Forderung f = await setupRepo.create(typ: 'rechnung', betrag: 100, partnerTyp: 'kunde', partnerId: partnerId);
    final int beforeJournalCount = await _tableCount(firstDb.executor, 'journal');
    final int beforeRelationCount = await _tableCount(firstDb.executor, 'forderung_zahlungen');
    final List<String> observed = <String>[];
    final Completer<void> observedState = Completer<void>();
    final Completer<void> allowFirst = Completer<void>();
    final ForderungenRepository firstRepo = ForderungenRepository(
      firstDb.executor,
      nowUtc: clock,
      transactionFactory: firstFactory,
      afterPaymentStateReadBeforeConditionalUpdate: (id, status, cents) async {
        observed.add('$id:$status:$cents');
        observedState.complete();
        await allowFirst.future;
      },
    );
    final Future<Forderung> firstFuture = firstRepo.zahlungBuchen(
      forderungId: f.id,
      betrag: 10,
      idempotencyKey: 'observed-race',
    );
    await observedState.future;

    final Forderung competitor = await competitorRepo.zahlungBuchen(
      forderungId: f.id,
      betrag: 100,
      idempotencyKey: 'observed-competitor',
    );
    expect(competitor.status, 'bezahlt');
    expect(competitor.betrag, 0);
    allowFirst.complete();
    await expectCode(firstFuture, ForderungenErrorCode.alreadyClosed);

    expect(observed, <String>['${f.id}:offen:10000']);
    expect(firstFactory.busySnapshotErrors, 1);
    // The stale conditional update is bound to the originally observed id/status/observed balance.
    expect(firstFactory.conditionalUpdates, isNotEmpty);
    final _ConditionalUpdateCall staleUpdate = firstFactory.conditionalUpdates.first;
    expect(staleUpdate.statement, contains('WHERE id = ? AND status = ? AND betrag = ?'));
    expect(staleUpdate.args.sublist(2), <Object?>[f.id, 'offen', '100.00']);
    expect(_centsOf(staleUpdate.args[4]), 10000, reason: 'observed balance 10000 cents is the bound predicate value');
    expect(firstFactory.deferredAttempts, <int>[1]);
    expect(firstFactory.immediateAttempts, <int>[2]);
    expect(await _tableCount(firstDb.executor, 'journal'), beforeJournalCount + 1);
    expect(await _tableCount(firstDb.executor, 'forderung_zahlungen'), beforeRelationCount + 1);
    final keyedRows = await firstDb.executor.runSelect(
      'SELECT count(*) AS c FROM forderung_zahlungen WHERE idempotency_key = ?',
      const <Object?>['observed-race'],
    );
    expect(keyedRows.single['c'], 0);
    expect(await _orphanRows(firstDb.executor, <String>['Zahlung Forderung #${f.id}']), isEmpty);
  } finally {
    await firstDb.close();
    await competitorDb.close();
    await directory.delete(recursive: true);
  }
}

Future<void> _runZeroRowPaymentRollbackBranches() async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  try {
    await db.ensureOpen();
    final ForderungenRepository setupRepo = ForderungenRepository(db.executor, nowUtc: () => DateTime.utc(2026, 9, 30));
    await setupRepo.ensureSchema();
    final int partnerId = await db.executor.runInsert(
      "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Zero Row', 'A', '10115', 'Berlin', 'DE')",
      const <Object?>[],
    );
    final Forderung f = await setupRepo.create(typ: 'rechnung', betrag: 75, partnerTyp: 'kunde', partnerId: partnerId);
    for (final num amount in <num>[10, 75, 100]) {
      final _ZeroConditionalUpdateFactory factory = _ZeroConditionalUpdateFactory();
      final ForderungenRepository repo = ForderungenRepository(
        db.executor,
        nowUtc: () => DateTime.utc(2026, 9, 30),
        transactionFactory: factory,
      );
      final List<Object?> before = await _accountingSnapshot(db.executor, f.id);
      await expectCode(
        repo.zahlungBuchen(forderungId: f.id, betrag: amount, idempotencyKey: 'zero-row-$amount'),
        ForderungenErrorCode.alreadyClosed,
      );
      expect(factory.rollbackCount, 1);
      expect(factory.conditionalUpdates, hasLength(1));
      final _ConditionalUpdateCall call = factory.conditionalUpdates.single;
      expect(call.statement, contains('WHERE id = ? AND status = ? AND betrag = ?'));
      final List<Object?> bound = call.args;
      expect(bound.sublist(2), <Object?>[f.id, 'offen', '75.00']);
      expect(_centsOf(bound[4]), 7500, reason: 'observed balance 7500 cents is the bound predicate value');
      expect(await _accountingSnapshot(db.executor, f.id), before);
      expect(await _orphanRows(db.executor, <String>['Zahlung Forderung #${f.id}']), isEmpty);
    }
  } finally {
    await db.close();
  }
}

Future<void> _runFileBackedWriteoffRace() async {
  final Directory directory = await Directory.systemTemp.createTemp('openaccounting_receivable_writeoff_');
  final AppDatabase firstDb = AppDatabase.forProfile(directory.path);
  final AppDatabase secondDb = AppDatabase.forProfile(directory.path);
  try {
    await firstDb.ensureOpen();
    await secondDb.ensureOpen();
    DateTime clock() => DateTime.utc(2026, 9, 30);
    final ForderungenRepository firstRepo = ForderungenRepository(firstDb.executor, nowUtc: clock);
    final ForderungenRepository secondRepo = ForderungenRepository(secondDb.executor, nowUtc: clock);
    await firstRepo.ensureSchema();
    await secondRepo.ensureSchema();
    final int partnerId = await firstDb.executor.runInsert(
      "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Writeoff Race', 'A', '10115', 'Berlin', 'DE')",
      const <Object?>[],
    );
    final Forderung f = await firstRepo.create(typ: 'rechnung', betrag: 75, partnerTyp: 'kunde', partnerId: partnerId);
    final int beforeJournalCount = await _tableCount(firstDb.executor, 'journal');
    final int beforeRelationCount = await _tableCount(firstDb.executor, 'forderung_zahlungen');
    final List<Object?> outcomes = await Future.wait(<Future<Object?>>[
      firstRepo
          .ausbuchen(forderungId: f.id, grund: 'race-first')
          .then<Object?>((value) => value)
          .catchError((error) => error),
      secondRepo
          .ausbuchen(forderungId: f.id, grund: 'race-second')
          .then<Object?>((value) => value)
          .catchError((error) => error),
    ]);
    expect(outcomes.whereType<Forderung>(), hasLength(1));
    expect(outcomes.whereType<ForderungenException>().single.code, ForderungenErrorCode.alreadyClosed);
    expect(await _tableCount(firstDb.executor, 'journal'), beforeJournalCount + 1);
    expect(await _tableCount(firstDb.executor, 'forderung_zahlungen'), beforeRelationCount + 1);
    final state = (await firstDb.executor.runSelect('SELECT status, betrag FROM forderungen WHERE id = ?', <Object?>[
      f.id,
    ])).single;
    expect(state['status'], 'ausgebucht');
    expect(num.parse(state['betrag'].toString()), 0);
    expect(
      await _orphanRows(firstDb.executor, const <String>[
        'Forderungsausfall: race-first',
        'Forderungsausfall: race-second',
      ]),
      isEmpty,
    );
  } finally {
    await firstDb.close();
    await secondDb.close();
    await directory.delete(recursive: true);
  }
}

Future<void> _runFileBackedWriteoffPaymentRace() async {
  final Directory directory = await Directory.systemTemp.createTemp('openaccounting_receivable_cross_race_');
  final AppDatabase writeoffDb = AppDatabase.forProfile(directory.path);
  final AppDatabase paymentDb = AppDatabase.forProfile(directory.path);
  try {
    await writeoffDb.ensureOpen();
    await paymentDb.ensureOpen();
    DateTime clock() => DateTime.utc(2026, 9, 30);
    final ForderungenRepository writeoffRepo = ForderungenRepository(writeoffDb.executor, nowUtc: clock);
    final ForderungenRepository paymentRepo = ForderungenRepository(paymentDb.executor, nowUtc: clock);
    await writeoffRepo.ensureSchema();
    await paymentRepo.ensureSchema();
    final int partnerId = await writeoffDb.executor.runInsert(
      "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Cross Race', 'A', '10115', 'Berlin', 'DE')",
      const <Object?>[],
    );
    final Forderung f = await writeoffRepo.create(
      typ: 'rechnung',
      betrag: 75,
      partnerTyp: 'kunde',
      partnerId: partnerId,
    );
    final int beforeJournalCount = await _tableCount(writeoffDb.executor, 'journal');
    final int beforeRelationCount = await _tableCount(writeoffDb.executor, 'forderung_zahlungen');
    final List<Object?> outcomes = await Future.wait(<Future<Object?>>[
      writeoffRepo
          .ausbuchen(forderungId: f.id, grund: 'race-writeoff')
          .then<Object?>((value) => value)
          .catchError((error) => error),
      paymentRepo
          .zahlungBuchen(forderungId: f.id, betrag: 75, idempotencyKey: 'race-payment')
          .then<Object?>((value) => value)
          .catchError((error) => error),
    ]);
    expect(outcomes.whereType<Forderung>(), hasLength(1));
    expect(outcomes.whereType<ForderungenException>().single.code, ForderungenErrorCode.alreadyClosed);
    expect(await _tableCount(writeoffDb.executor, 'journal'), beforeJournalCount + 1);
    expect(await _tableCount(writeoffDb.executor, 'forderung_zahlungen'), beforeRelationCount + 1);
    final state = (await writeoffDb.executor.runSelect('SELECT status, betrag FROM forderungen WHERE id = ?', <Object?>[
      f.id,
    ])).single;
    expect(<String>['bezahlt', 'ausgebucht'], contains(state['status']));
    expect(num.parse(state['betrag'].toString()), 0);
    expect(
      await _orphanRows(writeoffDb.executor, <String>[
        'Zahlung Forderung #${f.id}',
        'Forderungsausfall: race-writeoff',
      ]),
      isEmpty,
    );
  } finally {
    await writeoffDb.close();
    await paymentDb.close();
    await directory.delete(recursive: true);
  }
}

Future<List<ForderungenMismatchField>> _runDeferredWalConflictRace({required bool differentTarget}) async {
  final Directory directory = await Directory.systemTemp.createTemp('openaccounting_receivable_wal_');
  final AppDatabase winnerDb = AppDatabase.forProfile(directory.path);
  final AppDatabase loserDb = AppDatabase.forProfile(directory.path);
  final _DeferredWalTransactionFactory winnerFactory = _DeferredWalTransactionFactory();
  final _DeferredWalTransactionFactory loserFactory = _DeferredWalTransactionFactory();
  try {
    await winnerDb.ensureOpen();
    await loserDb.ensureOpen();
    final ForderungenRepository winnerRepo = ForderungenRepository(
      winnerDb.executor,
      nowUtc: () => DateTime.utc(2026, 9, 30),
      transactionFactory: winnerFactory,
    );
    final ForderungenRepository loserRepo = ForderungenRepository(
      loserDb.executor,
      nowUtc: () => DateTime.utc(2026, 9, 30),
      transactionFactory: loserFactory,
    );
    await winnerRepo.ensureSchema();
    await loserRepo.ensureSchema();

    final int partnerId = await winnerDb.executor.runInsert(
      "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'WAL Race', 'A', '10115', 'Berlin', 'DE')",
      const <Object?>[],
    );
    final Forderung winnerForderung = await winnerRepo.create(
      typ: 'rechnung',
      betrag: 100,
      partnerTyp: 'kunde',
      partnerId: partnerId,
    );
    final Forderung loserForderung = await loserRepo.create(
      typ: 'rechnung',
      betrag: 100,
      partnerTyp: 'lieferant',
      partnerId: partnerId,
    );
    final int loserTargetId = differentTarget ? loserForderung.id : winnerForderung.id;
    final int beforeJournalCount = await _tableCount(winnerDb.executor, 'journal');
    final int beforeRelationCount = await _tableCount(winnerDb.executor, 'forderung_zahlungen');
    final Completer<void> bothMissed = Completer<void>();
    final Completer<void> allowWinner = Completer<void>();
    final Completer<void> allowLoser = Completer<void>();
    var missCount = 0;

    void markMiss() {
      missCount += 1;
      if (missCount == 2) bothMissed.complete();
    }

    final ForderungenRepository coordinatedWinnerRepo = ForderungenRepository(
      winnerDb.executor,
      nowUtc: () => DateTime.utc(2026, 9, 30),
      transactionFactory: winnerFactory,
      afterFingerprintMissBeforeInsert: (_) async {
        markMiss();
        await bothMissed.future;
        await allowWinner.future;
      },
    );
    final ForderungenRepository coordinatedLoserRepo = ForderungenRepository(
      loserDb.executor,
      nowUtc: () => DateTime.utc(2026, 9, 30),
      transactionFactory: loserFactory,
      afterFingerprintMissBeforeInsert: (_) async {
        markMiss();
        await bothMissed.future;
        await allowLoser.future;
      },
    );
    await coordinatedWinnerRepo.ensureSchema();
    await coordinatedLoserRepo.ensureSchema();

    final Future<Forderung> winnerFuture = coordinatedWinnerRepo.zahlungBuchen(
      forderungId: winnerForderung.id,
      betrag: 40,
      datum: '2026-09-29',
      idempotencyKey: 'wal-race',
    );
    final Future<Forderung> loserFuture = coordinatedLoserRepo.zahlungBuchen(
      forderungId: loserTargetId,
      betrag: 50,
      datum: differentTarget ? null : '2026-09-30',
      idempotencyKey: 'wal-race',
    );
    await bothMissed.future;
    allowWinner.complete();
    final Forderung winner = await winnerFuture;
    expect(winner.id, winnerForderung.id);
    allowLoser.complete();

    ForderungenException? loserError;
    try {
      await loserFuture;
      fail('expected the deferred loser to reload the committed key');
    } on ForderungenException catch (error) {
      loserError = error;
    }
    expect(loserError, isNot(equals(null)));
    expect(loserError.code, ForderungenErrorCode.idempotencyConflict);
    expect(loserFactory.busySnapshotErrors, 1);

    expect(await _tableCount(winnerDb.executor, 'journal'), beforeJournalCount + 1);
    expect(await _tableCount(winnerDb.executor, 'forderung_zahlungen'), beforeRelationCount + 1);
    final keyedRows = await winnerDb.executor.runSelect(
      'SELECT count(*) AS c FROM forderung_zahlungen WHERE idempotency_key = ?',
      const <Object?>['wal-race'],
    );
    expect(keyedRows.single['c'], 1);
    final orphanRows = await winnerDb.executor.runSelect(
      'SELECT j.id FROM journal j LEFT JOIN forderung_zahlungen p ON p.journal_id = j.id '
      "WHERE j.beschreibung LIKE 'Zahlung Forderung #%' AND p.id IS NULL",
      const <Object?>[],
    );
    expect(orphanRows, isEmpty);

    final winnerRow = (await winnerDb.executor.runSelect(
      'SELECT status, betrag FROM forderungen WHERE id = ?',
      <Object?>[winnerForderung.id],
    )).single;
    expect(num.parse(winnerRow['betrag'].toString()), 60);
    if (differentTarget) {
      final loserRow = (await winnerDb.executor.runSelect(
        'SELECT status, betrag FROM forderungen WHERE id = ?',
        <Object?>[loserForderung.id],
      )).single;
      expect(num.parse(loserRow['betrag'].toString()), 100);
    }
    return loserError.mismatchFields;
  } finally {
    await winnerDb.close();
    await loserDb.close();
    await directory.delete(recursive: true);
  }
}

Future<int> _tableCount(QueryExecutor executor, String table) async {
  final rows = await executor.runSelect('SELECT count(*) AS c FROM $table', const <Object?>[]);
  return (rows.single['c']! as num).toInt();
}

Future<List<Object?>> _accountingSnapshot(QueryExecutor executor, int forderungId) async {
  final rows = await executor.runSelect('SELECT status, betrag FROM forderungen WHERE id = ?', <Object?>[forderungId]);
  return <Object?>[
    rows.single['status'],
    rows.single['betrag'],
    await _tableCount(executor, 'journal'),
    await _tableCount(executor, 'forderung_zahlungen'),
  ];
}

Future<List<Map<String, Object?>>> _orphanRows(QueryExecutor executor, List<String> descriptions) async {
  final String placeholders = List<String>.filled(descriptions.length, '?').join(', ');
  return executor.runSelect(
    'SELECT j.id FROM journal j LEFT JOIN forderung_zahlungen p ON p.journal_id = j.id '
    'WHERE j.beschreibung IN ($placeholders) AND p.id IS NULL',
    List<Object?>.from(descriptions),
  );
}

class _DeferredWalTransactionFactory implements ForderungenTransactionFactory {
  int busySnapshotErrors = 0;
  final List<int> deferredAttempts = <int>[];
  final List<int> immediateAttempts = <int>[];
  final List<_ConditionalUpdateCall> conditionalUpdates = <_ConditionalUpdateCall>[];

  @override
  Future<T> run<T>({
    required ForderungenTransactionKind kind,
    required int attempt,
    required QueryExecutor executor,
    required Future<T> Function(QueryExecutor transaction) action,
  }) async {
    if (kind != ForderungenTransactionKind.payment) {
      throw StateError('Deferred WAL factory is payment-fixture-only');
    }
    if (attempt != 1) {
      immediateAttempts.add(attempt);
      return _runImmediateTransaction(
        executor: executor,
        action: (QueryExecutor transaction) => action(_RecordingConditionalExecutor(transaction, conditionalUpdates)),
      );
    }
    deferredAttempts.add(attempt);
    await executor.runCustom('BEGIN DEFERRED');
    try {
      final T result = await action(_RecordingConditionalExecutor(executor, conditionalUpdates));
      await executor.runCustom('COMMIT');
      return result;
    } catch (error, stackTrace) {
      if (error is SqliteException && error.extendedResultCode == 517) busySnapshotErrors += 1;
      try {
        await executor.runCustom('ROLLBACK');
      } catch (_) {}
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

Future<T> _runImmediateTransaction<T>({
  required QueryExecutor executor,
  required Future<T> Function(QueryExecutor transaction) action,
  void Function()? onRollback,
}) async {
  final TransactionExecutor transaction = executor.beginTransaction();
  await transaction.ensureOpen(_TestTransactionUser());
  try {
    final T result = await action(transaction);
    await transaction.send();
    return result;
  } catch (error, stackTrace) {
    try {
      await transaction.rollback();
      onRollback?.call();
    } catch (rollbackError, rollbackStackTrace) {
      Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}

class _TestTransactionUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

class _ZeroConditionalUpdateFactory implements ForderungenTransactionFactory {
  int rollbackCount = 0;
  final List<_ConditionalUpdateCall> conditionalUpdates = <_ConditionalUpdateCall>[];

  @override
  Future<T> run<T>({
    required ForderungenTransactionKind kind,
    required int attempt,
    required QueryExecutor executor,
    required Future<T> Function(QueryExecutor transaction) action,
  }) async {
    if (kind != ForderungenTransactionKind.payment || attempt != 1) {
      throw StateError('Zero-row factory is a single payment-attempt fixture');
    }
    return _runImmediateTransaction(
      executor: executor,
      action: (QueryExecutor transaction) => action(_ZeroUpdateExecutor(transaction, conditionalUpdates)),
      onRollback: () => rollbackCount += 1,
    );
  }
}

class _ConditionalUpdateCall {
  _ConditionalUpdateCall(this.statement, this.args);

  final String statement;
  final List<Object?> args;
}

final class _ZeroUpdateExecutor extends QueryExecutor {
  _ZeroUpdateExecutor(this._delegate, this._calls);

  final QueryExecutor _delegate;
  final List<_ConditionalUpdateCall> _calls;

  @override
  SqlDialect get dialect => _delegate.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _delegate.ensureOpen(user);

  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) =>
      _delegate.runSelect(statement, args);

  @override
  Future<int> runInsert(String statement, List<Object?> args) => _delegate.runInsert(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    if (statement.startsWith('UPDATE forderungen SET betrag = ?, status = ?')) {
      _calls.add(_ConditionalUpdateCall(statement, List<Object?>.from(args)));
      return Future<int>.value(0);
    }
    return _delegate.runUpdate(statement, args);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) => _delegate.runDelete(statement, args);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) => _delegate.runCustom(statement, args);

  @override
  Future<void> runBatched(BatchedStatements statements) => _delegate.runBatched(statements);

  @override
  TransactionExecutor beginTransaction() => _delegate.beginTransaction();

  @override
  QueryExecutor beginExclusive() => _delegate.beginExclusive();

  @override
  Future<void> close() => _delegate.close();
}

class _Fixture {
  _Fixture(this.db, this.repo);

  final AppDatabase db;
  final ForderungenRepository repo;

  static Future<_Fixture> create() async {
    final db = AppDatabase.createTestDatabase();
    await db.ensureOpen();
    final repo = ForderungenRepository(db.executor, nowUtc: () => DateTime.utc(2026, 9, 30));
    await repo.ensureSchema();
    return _Fixture(db, repo);
  }

  Future<Forderung> forderung({num amount = 100}) async {
    final partnerId = await db.executor.runInsert(
      "INSERT INTO kunden (anrede, name, strasse, plz, ort, land) VALUES ('Herr', 'Fingerprint Kunde', 'A', '10115', 'Berlin', 'DE')",
      const <Object?>[],
    );
    return repo.create(typ: 'rechnung', betrag: amount, partnerTyp: 'kunde', partnerId: partnerId);
  }

  Future<void> setUnknownDirection(int id) async {
    await db.executor.runCustom('PRAGMA ignore_check_constraints = ON');
    await db.executor.runUpdate('UPDATE forderungen SET partner_typ = ? WHERE id = ?', <Object?>['other', id]);
    await db.executor.runCustom('PRAGMA ignore_check_constraints = OFF');
  }

  Future<Forderung> nullPartnerForderung() async {
    await db.executor.runCustom('PRAGMA foreign_keys = OFF');
    await db.executor.runCustom('DROP TABLE forderung_zahlungen');
    await db.executor.runCustom('ALTER TABLE forderungen RENAME TO forderungen_legacy');
    await db.executor.runCustom('''
CREATE TABLE forderungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kunde_id INTEGER REFERENCES kunden(id),
  rechnung_id INTEGER REFERENCES rechnungen(id),
  betrag NUMERIC(12,2) NOT NULL,
  anfangsbetrag NUMERIC(12,2),
  status TEXT DEFAULT 'offen',
  faelligkeit TEXT,
  beschreibung TEXT,
  typ TEXT NOT NULL DEFAULT 'rechnung' CHECK (typ IN ('rechnung','rechnung_eingang','journal')),
  partner_typ TEXT CHECK (partner_typ IN ('kunde','lieferant')),
  partner_id INTEGER NOT NULL DEFAULT 0,
  journal_id INTEGER REFERENCES journal(id),
  ausgleich_journal_id INTEGER REFERENCES journal(id),
  erstellt_am TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  aktualisiert_am TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
)''');
    await db.executor.runCustom('''
INSERT INTO forderungen (
  id, kunde_id, rechnung_id, betrag, anfangsbetrag, status, faelligkeit, beschreibung,
  typ, partner_typ, partner_id, journal_id, ausgleich_journal_id, erstellt_am, aktualisiert_am
)
SELECT id, kunde_id, rechnung_id, betrag, anfangsbetrag, status, faelligkeit, beschreibung,
       typ, partner_typ, partner_id, journal_id, ausgleich_journal_id, erstellt_am, aktualisiert_am
FROM forderungen_legacy''');
    await db.executor.runCustom('DROP TABLE forderungen_legacy');
    await db.executor.runCustom('PRAGMA foreign_keys = ON');
    final id = await db.executor.runInsert(
      'INSERT INTO forderungen (betrag, anfangsbetrag, status, typ, partner_typ, partner_id) VALUES (?, ?, ?, ?, ?, ?)',
      const <Object?>[100, 100, 'offen', 'rechnung', null, 1],
    );
    return (await repo.findById(id))!;
  }

  Future<List<Object?>> snapshot(int id) async {
    final rows = await db.executor.runSelect('SELECT status, betrag FROM forderungen WHERE id = ?', <Object?>[id]);
    final journals = await db.executor.runSelect('SELECT count(*) AS c FROM journal', const <Object?>[]);
    final relations = await db.executor.runSelect('SELECT count(*) AS c FROM forderung_zahlungen', const <Object?>[]);
    return <Object?>[rows.single['status'], rows.single['betrag'], journals.single['c'], relations.single['c']];
  }

  Future<List<Object?>> counts() async {
    final journals = await db.executor.runSelect('SELECT count(*) AS c FROM journal', const <Object?>[]);
    final relations = await db.executor.runSelect('SELECT count(*) AS c FROM forderung_zahlungen', const <Object?>[]);
    return <Object?>[journals.single['c'], relations.single['c']];
  }

  Future<void> close() => db.close();
}

class _RecordingConditionalExecutor extends QueryExecutor {
  _RecordingConditionalExecutor(this._delegate, this._calls);

  final QueryExecutor _delegate;
  final List<_ConditionalUpdateCall> _calls;

  @override
  SqlDialect get dialect => _delegate.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _delegate.ensureOpen(user);

  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) =>
      _delegate.runSelect(statement, args);

  @override
  Future<int> runInsert(String statement, List<Object?> args) => _delegate.runInsert(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    if (statement.startsWith('UPDATE forderungen SET betrag = ?, status = ?')) {
      _calls.add(_ConditionalUpdateCall(statement, List<Object?>.from(args)));
    }
    return _delegate.runUpdate(statement, args);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) => _delegate.runDelete(statement, args);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) => _delegate.runCustom(statement, args);

  @override
  Future<void> runBatched(BatchedStatements statements) => _delegate.runBatched(statements);

  @override
  TransactionExecutor beginTransaction() => _delegate.beginTransaction();

  @override
  QueryExecutor beginExclusive() => _delegate.beginExclusive();

  @override
  Future<void> close() => _delegate.close();
}

class _RecordedStatement {
  _RecordedStatement(this.statement, {required this.inAttempt});

  final String statement;
  final bool inAttempt;
}

class _PhaseRecordingExecutor extends QueryExecutor {
  _PhaseRecordingExecutor(this._delegate, this._recorded, this._inAttempt);

  final QueryExecutor _delegate;
  final List<_RecordedStatement> _recorded;
  final bool Function() _inAttempt;

  void _record(String statement) => _recorded.add(_RecordedStatement(statement, inAttempt: _inAttempt()));

  @override
  SqlDialect get dialect => _delegate.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _delegate.ensureOpen(user);

  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) {
    _record(statement);
    return _delegate.runSelect(statement, args);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    _record(statement);
    return _delegate.runInsert(statement, args);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    _record(statement);
    return _delegate.runUpdate(statement, args);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) {
    _record(statement);
    return _delegate.runDelete(statement, args);
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    _record(statement);
    return _delegate.runCustom(statement, args);
  }

  @override
  Future<void> runBatched(BatchedStatements statements) => _delegate.runBatched(statements);

  @override
  TransactionExecutor beginTransaction() => _delegate.beginTransaction();

  @override
  QueryExecutor beginExclusive() => _delegate.beginExclusive();

  @override
  Future<void> close() => _delegate.close();
}

bool _isSetupSql(String statement) {
  final String s = statement.trim().toUpperCase();
  return s.contains('CREATE TABLE') ||
      s.contains('CREATE INDEX') ||
      s.contains('CREATE TRIGGER') ||
      s.contains('ALTER TABLE') ||
      s.contains('DROP TABLE') ||
      s.contains('DROP INDEX') ||
      s.contains('DROP TRIGGER') ||
      s.startsWith('PRAGMA') ||
      s.startsWith('INSERT OR IGNORE INTO');
}

int _centsOf(Object? formatted) => (double.parse(formatted.toString()) * 100).round();

Future<int> _keyedRelationCount(QueryExecutor executor, int forderungId) async {
  final List<Map<String, Object?>> rows = await executor.runSelect(
    'SELECT count(*) AS c FROM forderung_zahlungen WHERE forderung_id = ?',
    <Object?>[forderungId],
  );
  return (rows.single['c']! as num).toInt();
}
