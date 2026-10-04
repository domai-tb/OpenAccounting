// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/bank_import/bank_import_entity.dart';
import 'package:openaccounting/features/bank_import/bank_import_failure_payload.dart';
import 'package:openaccounting/features/bank_import/bank_import_page.dart';
import 'package:openaccounting/features/bank_import/bank_import_service.dart';

/// Actionable import history: retry, review states, search (recovery surface).
/// Covers the backend-verifiable scenarios; pure widget scenarios (detail
/// navigation, empty-state offer, keyboard focus, route restoration) follow
/// with the Banking history UI.
void main() {
  group('Import history recovery (backend)', () {
    late AppDatabase db;
    late BankImportService service;
    late int kontoId;
    late int kategorieId;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      service = BankImportService(db.executor);
      kontoId = await db.executor.runInsert('INSERT INTO konten (name, iban) VALUES (?, ?)', const <Object?>[
        'Giro',
        'DE001',
      ]);
      kategorieId = await db.executor.runInsert(
        "INSERT INTO kategorien (bezeichnung, aktiv) VALUES ('Auditkat', 1)",
        const <Object?>[],
      );
    });

    tearDown(() async {
      await db.close();
    });

    RawTx goodRow({String betrag = '10.00', String suffix = 'A'}) {
      return RawTx(
        datum: DateTime.parse('2026-05-01'),
        betrag: betrag,
        verwendungszweck: 'Beitrag $suffix',
        partner: 'Verein $suffix',
      );
    }

    RawTx badRow() {
      return const RawTx(datum: null, betrag: 'not-a-number', verwendungszweck: 'Kaputt', partner: 'X');
    }

    Future<int> importIdOf(ImportResult result) async {
      expect(result.importId, isNotNull);
      return result.importId!;
    }

    Future<Map<String, Object?>> attemptRow(int importId) async {
      final rows = await db.executor.runSelect('SELECT * FROM bank_imports WHERE id = ?', <Object?>[importId]);
      return rows.single;
    }

    test('test_retry_resumes_persisted_failed_rows_under_the_original_identity', () async {
      final first = await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[goodRow(), badRow()],
        locale: 'de_DE',
      );
      final int importId = await importIdOf(first);
      expect(first.status, 'teilweise');
      final childrenBefore = await db.executor.runSelect(
        'SELECT id FROM bank_transaktionen WHERE import_id = ? ORDER BY id',
        <Object?>[importId],
      );
      expect(childrenBefore, hasLength(1));

      final fixed = RawTx(
        datum: DateTime.parse('2026-05-02'),
        betrag: '99.00',
        verwendungszweck: 'Korrigiert',
        partner: 'Verein K',
      );
      final retried = await service.retryImport(importId: importId, locale: 'de_DE', corrected: <int, RawTx>{2: fixed});
      expect(retried.status, 'importiert');
      expect(retried.importId, importId);
      final childrenAfter = await db.executor.runSelect(
        'SELECT id FROM bank_transaktionen WHERE import_id = ? ORDER BY id',
        <Object?>[importId],
      );
      expect(childrenAfter, hasLength(2));
      expect(childrenAfter.first['id'], childrenBefore.single['id']);
      final attempt = await attemptRow(importId);
      expect(attempt['anzahl_fehlgeschlagen'], 0);
      expect(attempt['fehler_details'], isNull);
      final imports = await db.executor.runSelect('SELECT COUNT(*) AS c FROM bank_imports', const []);
      expect(imports.single['c'], 1);
    });

    test('test_repeated_retry_processes_only_remaining_failures', () async {
      final first = await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[badRow(), badRow()],
        locale: 'de_DE',
      );
      final int importId = await importIdOf(first);
      expect(first.status, 'fehlgeschlagen');

      await service.retryImport(
        importId: importId,
        locale: 'de_DE',
        corrected: <int, RawTx>{1: goodRow(suffix: 'R1')},
      );
      var attempt = await attemptRow(importId);
      expect(attempt['status'], 'teilweise');
      expect(attempt['anzahl_fehlgeschlagen'], 1);

      await service.retryImport(
        importId: importId,
        locale: 'de_DE',
        corrected: <int, RawTx>{2: goodRow(suffix: 'R2')},
      );
      attempt = await attemptRow(importId);
      expect(attempt['status'], 'importiert');
      expect(attempt['anzahl_fehlgeschlagen'], 0);
      final children = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM bank_transaktionen WHERE import_id = ?',
        <Object?>[importId],
      );
      expect(children.single['c'], 2);
    });

    test('test_retried_row_becomes_duplicate', () async {
      final first = await service.importTransactions(kontoId: kontoId, rawTxs: <RawTx>[badRow()], locale: 'de_DE');
      final int importId = await importIdOf(first);
      // The same transaction arrives through a separate import first.
      await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[goodRow(suffix: 'Dup')],
        locale: 'de_DE',
      );
      final fixed = RawTx(
        datum: DateTime.parse('2026-05-01'),
        betrag: '10.00',
        verwendungszweck: 'Beitrag Dup',
        partner: 'Verein Dup',
      );
      final retried = await service.retryImport(importId: importId, locale: 'de_DE', corrected: <int, RawTx>{1: fixed});
      expect(retried.status, 'importiert');
      final attempt = await attemptRow(importId);
      expect(attempt['duplikate'], 1);
      final children = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM bank_transaktionen WHERE import_id = ?',
        <Object?>[importId],
      );
      expect(children.single['c'], 0);
    });

    test('test_duplicate_only_import_completes', () async {
      await service.importTransactions(kontoId: kontoId, rawTxs: <RawTx>[goodRow()], locale: 'de_DE');
      final second = await service.importTransactions(kontoId: kontoId, rawTxs: <RawTx>[goodRow()], locale: 'de_DE');
      expect(second.status, 'importiert');
      expect(second.duplicatesSkipped, 1);
      expect(second.imported, 0);
    });

    test('test_legacy_malformed_and_unsupported_payloads_are_not_guessed', () async {
      final int importId = await db.executor.runInsert(
        'INSERT INTO bank_imports (konto_id, dateiname, datum, status, fehler_details) VALUES (?, ?, ?, ?, ?)',
        <Object?>[kontoId, 'alt.csv', '2026-05-01', 'teilweise', '[{"row": 1}]'],
      );
      final detail = await service.historyDetail(importId);
      expect(detail.retryable, isFalse);
      expect(detail.diagnostics, isNotEmpty);
      await expectLater(service.retryImport(importId: importId, locale: 'de_DE'), throwsA(isA<BankImportException>()));
      final children = await db.executor.runSelect(
        'SELECT COUNT(*) AS c FROM bank_transaktionen WHERE import_id = ?',
        <Object?>[importId],
      );
      expect(children.single['c'], 0);
    });

    test('test_rejected_whole_file_attempt_cannot_be_retried_from_history', () async {
      final rejected = await service.recordRejectedImport(
        kontoId: kontoId,
        diagnostic: 'unsupported',
        diagnosticCodes: const <String>['unsupported_format'],
        dateiname: 'fremd.bin',
        locale: 'de_DE',
      );
      final int importId = rejected.importId!;
      final detail = await service.historyDetail(importId);
      expect(detail.retryable, isFalse);
      await expectLater(service.retryImport(importId: importId, locale: 'de_DE'), throwsA(isA<BankImportException>()));
    });

    test('test_rule_categorized_manually_categorized_linked_and_reviewed_rows_have_distinct_states', () async {
      await db.executor.runInsert(
        'INSERT INTO auto_filter_regeln (muster, kategorie_id, prioritaet, aktiv) VALUES (?, ?, ?, ?)',
        <Object?>['Verein', kategorieId, 1, 1],
      );
      final int journalId = await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>['2026-05-01', 'Beitrag', kategorieId, '30.00', 'Einnahme'],
      );
      final result = await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[
          RawTx(datum: DateTime.parse('2026-05-01'), betrag: '30.00', verwendungszweck: 'Verein X', partner: 'P1'),
          RawTx(
            datum: DateTime.parse('2026-05-01'),
            betrag: '31.00',
            verwendungszweck: 'Manuell',
            partner: 'P2',
            kategorieId: kategorieId,
          ),
          RawTx(
            datum: DateTime.parse('2026-05-01'),
            betrag: '32.00',
            verwendungszweck: 'Link',
            partner: 'P3',
            journalId: journalId,
          ),
        ],
        locale: 'de_DE',
      );
      final int importId = result.importId!;
      final reviewed = await service.unresolvedReviewRows(importId: importId);
      expect(reviewed, hasLength(1), reason: 'only the rule-suggested row stays neu');
      final detail = await service.historyDetail(importId);
      expect(detail.unresolvedNeu, 1);
      final all = await db.executor.runSelect(
        'SELECT status FROM bank_transaktionen WHERE import_id = ? ORDER BY id',
        <Object?>[importId],
      );
      expect(all.map((r) => r['status']), <Object?>['neu', 'geprueft', 'gebucht']);
    });

    test('test_untouched_rule_suggestion_remains_distinguishable_from_a_user_choice', () async {
      await db.executor.runInsert(
        'INSERT INTO auto_filter_regeln (muster, kategorie_id, prioritaet, aktiv) VALUES (?, ?, ?, ?)',
        <Object?>['Verein', kategorieId, 1, 1],
      );
      final result = await service.importTransactions(
        kontoId: kontoId,
        rawTxs: const <RawTx>[RawTx(datum: null, betrag: 'not-a-number', verwendungszweck: 'Verein Y', partner: 'P')],
        locale: 'de_DE',
      );
      final attempt = await attemptRow(result.importId!);
      final envelope = BankImportFailurePayload.decodeValidated(attempt['fehler_details']! as String);
      final rows = (envelope['rows']! as List).cast<Map<String, Object?>>();
      expect(rows.single['kategorie_quelle'], 'regel_vorschlag');

      final ok = await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[
          RawTx(
            datum: DateTime.parse('2026-05-01'),
            betrag: '40.00',
            verwendungszweck: 'Verein Z',
            partner: 'P',
            kategorieId: kategorieId,
          ),
        ],
        locale: 'de_DE',
      );
      final stored = await db.executor.runSelect('SELECT status FROM bank_transaktionen WHERE import_id = ?', <Object?>[
        ok.importId,
      ]);
      expect(stored.single['status'], 'geprueft');
    });

    test('test_review_state_is_scoped_across_completed_and_partial_attempts', () async {
      final complete = await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[goodRow(suffix: 'C')],
        locale: 'de_DE',
      );
      final partial = await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[
          goodRow(suffix: 'P'),
          badRow(),
        ],
        locale: 'de_DE',
      );
      expect(await service.unresolvedReviewRows(importId: complete.importId), hasLength(1));
      expect(await service.unresolvedReviewRows(importId: partial.importId), hasLength(1));
      expect((await service.historyDetail(complete.importId!)).unresolvedNeu, 1);
      expect((await service.historyDetail(partial.importId!)).unresolvedNeu, 1);
    });

    test('test_manual_review_is_scoped_to_the_selected_import', () async {
      final first = await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[goodRow(suffix: 'S1')],
        locale: 'de_DE',
      );
      final second = await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[goodRow(suffix: 'S2')],
        locale: 'de_DE',
      );
      final onlyFirst = await service.unresolvedReviewRows(importId: first.importId);
      expect(onlyFirst, hasLength(1));
      final onlyFirstIds = await db.executor.runSelect(
        'SELECT import_id FROM bank_transaktionen WHERE status = ?',
        const <Object?>['neu'],
      );
      expect(onlyFirstIds.map((r) => r['import_id']).toSet(), hasLength(2));
      expect(await service.unresolvedReviewRows(importId: second.importId), hasLength(1));
    });

    test('test_reviewing_a_row_removes_it_from_the_unresolved_set', () async {
      final result = await service.importTransactions(kontoId: kontoId, rawTxs: <RawTx>[goodRow()], locale: 'de_DE');
      final int importId = result.importId!;
      expect(await service.unresolvedReviewRows(importId: importId), hasLength(1));
      final row = (await service.unresolvedReviewRows(importId: importId)).single;
      await service.reviewTransaction(id: (row['id']! as num).toInt(), kategorieId: kategorieId);
      expect(await service.unresolvedReviewRows(importId: importId), isEmpty);
      expect((await service.historyDetail(importId)).unresolvedNeu, 0);
    });

    test('test_completed_attempt_metadata_stays_immutable_while_child_review_remains_available', () async {
      final result = await service.importTransactions(kontoId: kontoId, rawTxs: <RawTx>[goodRow()], locale: 'de_DE');
      final int importId = result.importId!;
      final before = await attemptRow(importId);
      final row = (await service.unresolvedReviewRows(importId: importId)).single;
      await service.reviewTransaction(id: (row['id']! as num).toInt(), kategorieId: kategorieId);
      final after = await attemptRow(importId);
      expect(after['dateiname'], before['dateiname']);
      expect(after['status'], before['status']);
      expect(after['anzahl_importiert'], before['anzahl_importiert']);
      expect(after['fehler_details'], before['fehler_details']);
      expect((await service.historyDetail(importId)).unresolvedNeu, 0);
    });

    test('test_manual_review_does_not_create_a_posting', () async {
      final result = await service.importTransactions(kontoId: kontoId, rawTxs: <RawTx>[goodRow()], locale: 'de_DE');
      final row = await service.unresolvedReviewRows(importId: result.importId).then((rows) => rows.single);
      final int journalId = await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>['2026-05-01', 'Manuell verknüpft', kategorieId, '10.00', 'Einnahme'],
      );
      final journalsBefore = await db.executor.runSelect('SELECT COUNT(*) AS c FROM journal', const []);
      await service.reviewTransaction(id: (row['id']! as num).toInt(), journalId: journalId);
      final journalsAfter = await db.executor.runSelect('SELECT COUNT(*) AS c FROM journal', const []);
      expect(journalsAfter.single['c'], journalsBefore.single['c']);
      final stored = await db.executor.runSelect(
        'SELECT status, journal_id FROM bank_transaktionen WHERE id = ?',
        <Object?>[row['id']],
      );
      expect(stored.single['status'], 'gebucht');
      expect(stored.single['journal_id'], journalId);
    });

    test('test_retry_failure_leaves_the_prior_attempt_usable', () async {
      final first = await service.importTransactions(
        kontoId: kontoId,
        rawTxs: <RawTx>[goodRow(), badRow()],
        locale: 'de_DE',
      );
      final int importId = await importIdOf(first);
      final childrenBefore = await db.executor.runSelect(
        'SELECT id FROM bank_transaktionen WHERE import_id = ? ORDER BY id',
        <Object?>[importId],
      );
      // Retry without corrections: the row fails again, prior state persists.
      final retried = await service.retryImport(importId: importId, locale: 'de_DE');
      expect(retried.status, 'teilweise');
      final childrenAfter = await db.executor.runSelect(
        'SELECT id FROM bank_transaktionen WHERE import_id = ? ORDER BY id',
        <Object?>[importId],
      );
      expect(childrenAfter.map((r) => r['id']), childrenBefore.map((r) => r['id']));
      final attempt = await attemptRow(importId);
      expect(attempt['status'], 'teilweise');
      expect(attempt['anzahl_fehlgeschlagen'], 1);
      final envelope = BankImportFailurePayload.decodeValidated(attempt['fehler_details']! as String);
      expect(envelope['rows']! as List, hasLength(1));
    });

    test('test_history_search_filters_before_stable_pagination', () async {
      for (var i = 1; i <= 3; i++) {
        await db.executor.runInsert(
          'INSERT INTO bank_imports (konto_id, dateiname, datum, template_typ, status) VALUES (?, ?, ?, ?, ?)',
          <Object?>[kontoId, 'konto-$i.csv', '2026-05-0$i', 'sparkasse', 'importiert'],
        );
      }
      final filtered = await service.queryHistory(q: 'konto-2');
      expect(filtered.total, 1);
      expect(filtered.attempts.single.dateiname, 'konto-2.csv');
      expect(filtered.hasMore, isFalse);

      final clamped = await service.queryHistory(page: 99, pageSize: 2);
      expect(clamped.page, 2);
      expect(clamped.attempts, hasLength(1));
      expect(clamped.hasMore, isFalse);

      final first = await service.queryHistory(pageSize: 2);
      expect(first.total, 3);
      expect(first.hasMore, isTrue);
      expect(first.attempts.map((a) => a.id).toList(), orderedEquals(<int>[3, 2]));
    });

    test('test_status_policy_controls_actions', () async {
      final openPolicy = service.historyActions(status: 'importiert', retryable: false, unresolvedNeu: 2);
      expect(openPolicy.retry, isFalse);
      expect(openPolicy.review, isTrue);
      expect(openPolicy.newFile, isTrue);
      final retryPolicy = service.historyActions(status: 'teilweise', retryable: true, unresolvedNeu: 1);
      expect(retryPolicy.retry, isTrue);
      expect(retryPolicy.review, isTrue);
      expect(retryPolicy.newFile, isFalse);
      final rejectedPolicy = service.historyActions(status: 'fehlgeschlagen', retryable: false, unresolvedNeu: 0);
      expect(rejectedPolicy.retry, isFalse);
      expect(rejectedPolicy.newFile, isTrue);
    });
  });
  bankHistoryUiSection();
}

/// History UI: detail, empty state, query preservation, keyboard (section 8 UI).
void bankHistoryUiSection() {
  group('Import history UI', () {
    Future<AppDatabase> openDb() async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      addTearDown(db.close);
      await db.executor.runInsert('INSERT INTO konten (name, iban) VALUES (?, ?)', const <Object?>['Giro', 'DE001']);
      return db;
    }

    Future<void> pumpHistory(WidgetTester tester, AppDatabase db) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: BankImportPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verlauf').last);
      await tester.pumpAndSettle();
    }

    testWidgets('test_history_row_opens_details', (tester) async {
      final AppDatabase db = await openDb();
      await db.executor.runInsert(
        'INSERT INTO bank_imports (konto_id, dateiname, datum, status) VALUES (?, ?, ?, ?)',
        const <Object?>[1, 'auszug.csv', '2026-05-01', 'importiert'],
      );
      await pumpHistory(tester, db);
      final Finder detailButton = find.byIcon(Icons.info_outline).first;
      await tester.ensureVisible(detailButton);
      await tester.tap(detailButton, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('auszug.csv'), findsWidgets);
      expect(find.textContaining('importiert'), findsWidgets);
    });

    testWidgets('test_empty_history_offers_import', (tester) async {
      final AppDatabase db = await openDb();
      await pumpHistory(tester, db);
      expect(find.text('Datei wählen'), findsOneWidget);
      await tester.tap(find.text('Datei wählen'));
      await tester.pumpAndSettle();
      expect(find.text('Datei wählen'), findsNothing);
    });

    testWidgets('test_detail_return_restores_the_same_history_query', (tester) async {
      final AppDatabase db = await openDb();
      await db.executor.runInsert(
        'INSERT INTO bank_imports (konto_id, dateiname, datum, status) VALUES (?, ?, ?, ?)',
        const <Object?>[1, 'suche-mich.csv', '2026-05-01', 'importiert'],
      );
      await pumpHistory(tester, db);
      await tester.enterText(find.widgetWithText(TextField, 'Suchen'), 'suche-mich');
      await tester.pumpAndSettle();
      final Finder detailButton = find.byIcon(Icons.info_outline).first;
      await tester.ensureVisible(detailButton);
      await tester.tap(detailButton, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();
      expect(find.text('suche-mich'), findsOneWidget);
      expect(find.text('suche-mich.csv'), findsOneWidget);
    });

    testWidgets('test_history_keyboard_actions_preserve_focus', (tester) async {
      final AppDatabase db = await openDb();
      await pumpHistory(tester, db);
      final Finder search = find.widgetWithText(TextField, 'Suchen');
      await tester.tap(search);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      final FocusNode? before = FocusManager.instance.primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(FocusManager.instance.primaryFocus, isNot(equals(before)));
    });
  });
}
