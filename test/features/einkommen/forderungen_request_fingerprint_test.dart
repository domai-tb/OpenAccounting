import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';

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

    test('test_typed_idempotency_conflict_exposes_stable_ordered_fields', () async {
      final Forderung f = await fixture.forderung();
      await fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 1, datum: '2026-09-29', idempotencyKey: 'same');
      try {
        await fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 2, datum: '2026-09-30', idempotencyKey: 'same');
        fail('expected idempotency conflict');
      } on ForderungenException catch (error) {
        expect(error.code, ForderungenErrorCode.idempotencyConflict);
        expect(error.mismatchFields, <ForderungenMismatchField>[
          ForderungenMismatchField.requestedCents,
          ForderungenMismatchField.effectiveDate,
        ]);
      }
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
      final Forderung f = await fixture.forderung();
      final calls = <String>[];
      final repo = ForderungenRepository(
        fixture.db.executor,
        nowUtc: () => DateTime.utc(2026, 9, 30),
        afterFingerprintMissBeforeInsert: (key) async => calls.add(key),
      );
      await repo.zahlungBuchen(forderungId: f.id, betrag: 10, datum: '2026-09-29', idempotencyKey: 'barrier');
      await expectCode(
        repo.zahlungBuchen(forderungId: f.id, betrag: 11, datum: '2026-09-30', idempotencyKey: 'barrier'),
        ForderungenErrorCode.idempotencyConflict,
      );
      expect(calls, contains('barrier'));
    });

    test('test_deferred_wal_sqlite_busy_snapshot_reloads_and_classifies_idempotency_conflict', () async {
      final Forderung f = await fixture.forderung();
      await fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 10, idempotencyKey: 'snapshot');
      await expectCode(
        fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 11, idempotencyKey: 'snapshot'),
        ForderungenErrorCode.idempotencyConflict,
      );
    });

    test('test_persistent_sqlite_lock_exhausts_exactly_three_retries', () async {
      final Forderung f = await fixture.forderung();
      final attempts = <int>[];
      final repo = ForderungenRepository(
        fixture.db.executor,
        onPaymentTransactionAttempt: attempts.add,
        transactionFactory: _AlwaysLockedFactory(),
      );
      await expectCode(
        repo.zahlungBuchen(forderungId: f.id, betrag: 1, idempotencyKey: 'locked'),
        ForderungenErrorCode.concurrentWriteConflict,
      );
      expect(attempts, <int>[1, 2, 3]);
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
      final Forderung f = await fixture.forderung(amount: 75);
      final outcomes = await Future.wait(<Future<Object?>>[
        fixture.repo.ausbuchen(forderungId: f.id, grund: 'first').then<Object?>((value) => value),
        fixture.repo
            .ausbuchen(forderungId: f.id, grund: 'second')
            .then<Object?>((value) => value)
            .catchError((error) => error),
      ]);
      expect(outcomes.whereType<Forderung>().length, 1);
      expect(outcomes.whereType<ForderungenException>().single.code, ForderungenErrorCode.alreadyClosed);
    });

    test('test_writeoff_and_full_payment_race_has_one_effect_no_orphan', () async {
      final Forderung f = await fixture.forderung(amount: 75);
      final outcomes = await Future.wait(<Future<Object?>>[
        fixture.repo
            .ausbuchen(forderungId: f.id, grund: 'race')
            .then<Object?>((value) => value)
            .catchError((error) => error),
        fixture.repo
            .zahlungBuchen(forderungId: f.id, betrag: 75, idempotencyKey: 'race-payment')
            .then<Object?>((value) => value)
            .catchError((error) => error),
      ]);
      expect(outcomes.whereType<Forderung>().length, 1);
      final orphanRows = await fixture.db.executor.runSelect(
        'SELECT j.id FROM journal j LEFT JOIN forderung_zahlungen p ON p.journal_id = j.id '
        "WHERE j.beschreibung LIKE '%Forderung #${f.id}%' AND p.id IS NULL",
        const <Object?>[],
      );
      expect(orphanRows, isEmpty);
    });

    test('test_invalid_or_closed_writeoff_has_no_effect', () async {
      final Forderung f = await fixture.forderung(amount: 75);
      await expectCode(fixture.repo.ausbuchen(forderungId: f.id, grund: ' '), ForderungenErrorCode.invalidRequest);
      await fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 75);
      await expectCode(fixture.repo.ausbuchen(forderungId: f.id, grund: 'late'), ForderungenErrorCode.alreadyClosed);
    });

    test('test_conditional_payment_update_rolls_back_on_observed_balance_race', () async {
      final observed = <String>[];
      final Forderung f = await fixture.forderung();
      final repo = ForderungenRepository(
        fixture.db.executor,
        afterPaymentStateReadBeforeConditionalUpdate: (id, status, cents) async {
          observed.add('$id:$status:$cents');
        },
      );
      await repo.zahlungBuchen(forderungId: f.id, betrag: 10, idempotencyKey: 'observed');
      expect(observed, contains('${f.id}:offen:10000'));
    });

    test('test_ordinary_zero_row_conditional_payment_update_is_already_closed_for_every_branch', () async {
      final Forderung f = await fixture.forderung(amount: 75);
      await fixture.repo.zahlungBuchen(forderungId: f.id, betrag: 75);
      for (final amount in <num>[1, 75, 100]) {
        await expectCode(
          fixture.repo.zahlungBuchen(forderungId: f.id, betrag: amount, idempotencyKey: 'closed-$amount'),
          ForderungenErrorCode.alreadyClosed,
        );
      }
    });

    test('test_persistent_sqlite_lock_exhausts_exactly_three_writeoff_retries', () async {
      final Forderung f = await fixture.forderung();
      final attempts = <int>[];
      final repo = ForderungenRepository(
        fixture.db.executor,
        onWriteoffTransactionAttempt: attempts.add,
        transactionFactory: _AlwaysLockedFactory(),
      );
      await expectCode(
        repo.ausbuchen(forderungId: f.id, grund: 'locked'),
        ForderungenErrorCode.concurrentWriteConflict,
      );
      expect(attempts, <int>[1, 2, 3]);
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

class _AlwaysLockedFactory implements ForderungenTransactionFactory {
  @override
  Future<T> run<T>({
    required ForderungenTransactionKind kind,
    required int attempt,
    required QueryExecutor executor,
    required Future<T> Function(QueryExecutor transaction) action,
  }) {
    throw StateError('database is locked');
  }
}
