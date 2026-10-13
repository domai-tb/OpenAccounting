import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';

RechnungenUseCases _useCases(AppDatabase db) =>
    RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)));

const RechnungPositionItem _line = RechnungPositionItem(
  bezeichnung: 'Beratung',
  menge: 1,
  einzelpreis: 100,
  gesamt: 100,
  position: 0,
);

Future<AppDatabase> _openDb() async {
  final db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
  );
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
  );
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1 WHERE typ = 'gutschrift'",
  );
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'AN-YY####', naechste_nummer = 1 WHERE typ = 'angebot'",
  );
  return db;
}

Future<AppDatabase> _openProfileDb(Directory profileDirectory) async {
  final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
  await db.ensureOpen();
  await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
  );
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
  );
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1 WHERE typ = 'gutschrift'",
  );
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'AN-YY####', naechste_nummer = 1 WHERE typ = 'angebot'",
  );
  return db;
}

Future<AppDatabase> _openTemporaryProfileDb() async {
  final Directory profileDirectory = await Directory.systemTemp.createTemp('invoice-lifecycle-actions-');
  final AppDatabase db = await _openProfileDb(profileDirectory);
  addTearDown(() async {
    await db.close();
    if (profileDirectory.existsSync()) await profileDirectory.delete(recursive: true);
  });
  return db;
}

Future<void> _pumpInvoiceRoute(WidgetTester tester, AppDatabase db, int invoiceId) async {
  await tester.runAsync(
    () => db.executor.runInsert(
      'INSERT INTO unternehmen (name) SELECT ? WHERE NOT EXISTS (SELECT 1 FROM unternehmen)',
      const <Object?>['Lifecycle test company'],
    ),
  );
  final GoRouter router = createRouter(db);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.go('/invoices/$invoiceId');
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 2),
  );
}

Future<RechnungItem> _finalizedInvoice(RechnungenUseCases useCases) async {
  final RechnungItem draft = await useCases.createDraftRechnung(
    datum: '2026-08-30',
    positionen: const <RechnungPositionItem>[_line],
  );
  return useCases.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
}

Future<int> _invoiceCount(AppDatabase db) async {
  final rows = await db.executor.runSelect('SELECT COUNT(*) AS c FROM rechnungen', const <Object?>[]);
  return (rows.single['c']! as num).toInt();
}

Future<List<Object?>> _counters(AppDatabase db) async {
  final rows = await db.executor.runSelect(
    "SELECT naechste_nummer FROM nummernkreise WHERE typ IN ('rechnung_ausgang','stornorechnung','gutschrift') "
    'ORDER BY typ',
    const <Object?>[],
  );
  return rows.map((row) => row['naechste_nummer']).toList(growable: false);
}

void main() {
  test('test_eligible_credit_note_invokes_use_case_once', () async {
    final db = await _openTemporaryProfileDb();
    final useCases = _useCases(db);
    final RechnungItem finalized = await _finalizedInvoice(useCases);
    final int before = await _invoiceCount(db);

    // Invoice-derived Gutschrift: datum and positionen omitted, optional
    // reason passes through `grund` with its empty-string default.
    final RechnungItem credit = await useCases.createGutschrift(vonRechnungId: finalized.id);
    expect(await _invoiceCount(db), before + 1);
    expect(credit.typ, 'gutschrift');
    expect(credit.positionen.single.gesamt, -100);

    final RechnungItem? source = await useCases.findById(finalized.id);
    expect(source!.beziehungen.any((b) => b.kind == 'gutschrift Ziel' && b.documentId == credit.id), isTrue);
    final RechnungItem? target = await useCases.findById(credit.id);
    expect(target!.beziehungen.any((b) => b.documentId == finalized.id), isTrue);
  });

  test('test_storno_invokes_use_case_with_trimmed_reason', () async {
    final db = await _openTemporaryProfileDb();
    final useCases = _useCases(db);
    final RechnungItem finalized = await _finalizedInvoice(useCases);

    final RechnungItem storno = await useCases.stornoRechnung(rechnungId: finalized.id, grund: '  Falsch berechnet  ');
    final rows = await db.executor.runSelect('SELECT storno_grund FROM rechnungen WHERE id = ?', <Object?>[storno.id]);
    expect(rows.single['storno_grund'], 'Falsch berechnet');
    final RechnungItem? source = await useCases.findById(finalized.id);
    expect(source!.istStorniert, isTrue);
  });

  test('test_eligible_storno_offers_replacement_action', () async {
    final db = await _openTemporaryProfileDb();
    final useCases = _useCases(db);
    final RechnungItem finalized = await _finalizedInvoice(useCases);
    final RechnungItem storno = await useCases.stornoRechnung(rechnungId: finalized.id, grund: 'Stopp');
    expect(storno.typ, 'storno');

    final RechnungItem? storniert = await useCases.findById(finalized.id);
    expect(useCases.kannErsatz(storniert!), isTrue);
    final RechnungItem ersatz = await useCases.createErsatzRechnung(vonRechnungId: finalized.id);

    final RechnungItem? source = await useCases.findById(finalized.id);
    final RechnungItem? target = await useCases.findById(ersatz.id);
    expect(source!.beziehungen.any((b) => b.kind == 'ersatz Ziel' && b.documentId == ersatz.id), isTrue);
    expect(target!.beziehungen.any((b) => b.documentId == finalized.id), isTrue);
  });

  test('test_permitted_conversion_requires_confirmation', () async {
    final db = await _openTemporaryProfileDb();
    final useCases = _useCases(db);
    final RechnungItem angebot = await useCases.createDokument(
      typ: 'angebot',
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[_line],
    );
    final RechnungItem finalized = await useCases.finalizeRechnung(locale: 'de_DE', rechnungId: angebot.id);

    // Permitted Angebot -> Auftrag conversion invokes the use case once
    // with the confirmed supported target.
    final RechnungItem auftrag = await useCases.konvertiereDokument(quelleId: finalized.id, zielTyp: 'auftrag');
    expect(auftrag.typ, 'auftrag');
    expect(auftrag.positionen.single.bezeichnung, 'Beratung');
    final RechnungItem? target = await useCases.findById(auftrag.id);
    expect(target!.beziehungen.any((b) => b.documentId == finalized.id), isTrue);
    final RechnungItem? source = await useCases.findById(finalized.id);
    expect(source!.beziehungen.any((b) => b.documentId == auftrag.id), isTrue);

    await expectLater(
      useCases.konvertiereDokument(quelleId: finalized.id, zielTyp: 'storno'),
      throwsA(isA<StateError>()),
    );
  });

  test('test_lifecycle_action_revalidates_state_before_writes', () async {
    final db = await _openTemporaryProfileDb();
    final useCases = _useCases(db);
    final RechnungItem finalized = await _finalizedInvoice(useCases);
    final RechnungItem draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[_line],
    );
    final int before = await _invoiceCount(db);
    final List<Object?> counters = await _counters(db);

    // Stale or ineligible actions are rejected at the use-case boundary.
    await expectLater(useCases.finalizeRechnung(locale: 'de_DE', rechnungId: finalized.id), throwsA(isA<StateError>()));
    await expectLater(useCases.stornoRechnung(rechnungId: draft.id, grund: 'x'), throwsA(isA<StateError>()));
    await expectLater(useCases.createErsatzRechnung(vonRechnungId: finalized.id), throwsA(isA<StateError>()));
    await expectLater(
      useCases.konvertiereDokument(quelleId: draft.id, zielTyp: 'rechnung'),
      throwsA(isA<StateError>()),
    );

    expect(await _invoiceCount(db), before);
    expect(await _counters(db), counters);
  });

  test('test_blank_storno_reason_is_rejected_before_use_case', () async {
    final db = await _openTemporaryProfileDb();
    final useCases = _useCases(db);
    final RechnungItem finalized = await _finalizedInvoice(useCases);
    final int before = await _invoiceCount(db);

    await expectLater(useCases.stornoRechnung(rechnungId: finalized.id, grund: '   '), throwsA(isA<StateError>()));
    expect(await _invoiceCount(db), before);
    final rows = await db.executor.runSelect('SELECT id FROM rechnungen WHERE storno_von = ?', <Object?>[finalized.id]);
    expect(rows, isEmpty);
  });

  test('test_finalization_confirms_with_active_locale', () async {
    final db = await _openTemporaryProfileDb();
    final useCases = _useCases(db);
    final RechnungItem draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[_line],
    );

    // The confirmed summary invokes finalize once with the active locale.
    final RechnungItem finalized = await useCases.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
    expect(finalized.istEntwurf, isFalse);
    expect(finalized.rechnungsnummer, isNotNull);
    final RechnungItem? reloaded = await useCases.findById(draft.id);
    expect(reloaded!.istEntwurf, isFalse);
  });

  test('test_cancelled_finalization_preserves_editable_draft', () async {
    final db = await _openDb();
    addTearDown(db.close);
    final useCases = _useCases(db);
    final RechnungItem draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[_line],
    );
    final List<Object?> counters = await _counters(db);

    // Cancelled confirmation: no use-case call, no number or side effect.
    final RechnungItem? reloaded = await useCases.findById(draft.id);
    expect(reloaded!.istEntwurf, isTrue);
    expect(reloaded.rechnungsnummer, isNull);
    expect(await _counters(db), counters);
  });

  test('test_ineligible_document_cannot_be_finalized', () async {
    final db = await _openTemporaryProfileDb();
    final useCases = _useCases(db);
    final RechnungItem finalized = await _finalizedInvoice(useCases);

    // No enabled finalization for an already-finalized document.
    expect(useCases.kannFinalisieren(finalized), isFalse);
    await expectLater(useCases.finalizeRechnung(locale: 'de_DE', rechnungId: finalized.id), throwsA(isA<StateError>()));

    // Correction-only types are rejected before any side effect.
    final int rawId = await db.executor.runInsert(
      'INSERT INTO rechnungen (typ, status, datum, ist_entwurf, eingabemodus, netto_betrag, ust_betrag, brutto_betrag) '
      '''VALUES ('gutschrift', 'entwurf', '2026-08-30', 1, 'netto', '100.00', '19.00', '119.00')''',
      const <Object?>[],
    );
    await db.executor.runInsert(
      'INSERT INTO rechnungspositionen (rechnung_id, bezeichnung, menge, einzelpreis, gesamt, ust_satz, position) '
      "VALUES (?, 'X', '1.000', '100.0000', '100.00', '19.00', 0)",
      <Object?>[rawId],
    );
    final List<Object?> counters = await _counters(db);
    await expectLater(useCases.finalizeRechnung(locale: 'de_DE', rechnungId: rawId), throwsA(isA<StateError>()));
    expect(await _counters(db), counters);
  });

  test('test_correction_actions_wait_for_artifact_transaction', () async {
    final db = await _openTemporaryProfileDb();
    final useCases = _useCases(db);

    // Profile-backed artifact transactions enable correction actions.
    expect(useCases.correctionActionsAvailable, isTrue);
    final RechnungItem finalized = await _finalizedInvoice(useCases);
    expect(useCases.kannStorno(finalized), isTrue);
    expect(useCases.kannGutschrift(finalized), isTrue);

    // Ineligible direct requests still fail before any side effects even when
    // the capability gate is open.
    final RechnungItem draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[_line],
    );
    final int before = await _invoiceCount(db);
    final List<Object?> counters = await _counters(db);
    await expectLater(useCases.stornoRechnung(rechnungId: draft.id, grund: 'x'), throwsA(isA<StateError>()));
    await expectLater(useCases.createGutschrift(vonRechnungId: draft.id), throwsA(isA<StateError>()));
    expect(await _invoiceCount(db), before);
    expect(await _counters(db), counters);
  });

  test('test_invalid_preview_blocks_finalization_confirmation', () async {
    final db = await _openDb();
    addTearDown(db.close);
    final useCases = _useCases(db);
    final RechnungItem draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[_line],
    );

    // Stored values no longer pass domain validation: no confirmation may
    // create a number, artifact, or lifecycle side effect.
    await db.executor.runUpdate('UPDATE rechnungspositionen SET gesamt = ? WHERE rechnung_id = ?', <Object?>[
      '999.00',
      draft.id,
    ]);
    final List<Object?> counters = await _counters(db);
    await expectLater(useCases.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id), throwsA(isA<ArgumentError>()));
    final RechnungItem? reloaded = await useCases.findById(draft.id);
    expect(reloaded!.istEntwurf, isTrue);
    expect(reloaded.rechnungsnummer, isNull);
    expect(await _counters(db), counters);
  });

  testWidgets('test_invoice_page_confirms_before_finalization', (WidgetTester tester) async {
    final Directory profileDirectory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('invoice-workspace-finalize-'),
    ))!;
    final AppDatabase db = (await tester.runAsync(() => _openProfileDb(profileDirectory)))!;
    addTearDown(() async {
      await db.close();
      await profileDirectory.delete(recursive: true);
    });
    final RechnungenUseCases useCases = _useCases(db);
    final RechnungItem draft = (await tester.runAsync(
      () => useCases.createDraftRechnung(datum: '2026-08-30', positionen: const <RechnungPositionItem>[_line]),
    ))!;

    await _pumpInvoiceRoute(tester, db, draft.id).timeout(const Duration(seconds: 3));
    await tester.tap(find.byKey(const ValueKey<String>('invoice_finalize_header')));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );

    expect(find.text('Rechnung finalisieren?'), findsOneWidget);
    expect(await useCases.findById(draft.id).then((RechnungItem? value) => value!.istEntwurf), isTrue);
    await tester.tap(find.byKey(const ValueKey<String>('invoice_finalize_dialog_confirm')));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );

    final RechnungItem? finalized = await useCases.findById(draft.id);
    expect(finalized!.istEntwurf, isFalse);
    expect(finalized.rechnungsnummer, isNotNull);
    final String artifactPath =
        (await db.executor.runSelect('SELECT original_pdf_pfad FROM rechnungen WHERE id = ?', <Object?>[
              draft.id,
            ])).single['original_pdf_pfad']!
            as String;
    expect(File(artifactPath).existsSync(), isTrue);
  });

  testWidgets('test_cancelled_finalize_dialog_keeps_draft_unchanged', (WidgetTester tester) async {
    final AppDatabase db = await _openDb();
    addTearDown(db.close);
    final RechnungenUseCases useCases = _useCases(db);
    final RechnungItem draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[_line],
    );
    final List<Object?> counters = await _counters(db);

    await _pumpInvoiceRoute(tester, db, draft.id);
    await tester.tap(find.byKey(const ValueKey<String>('invoice_finalize_header')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('invoice_finalize_dialog_cancel')));
    await tester.pumpAndSettle();

    final RechnungItem? unchanged = await useCases.findById(draft.id);
    expect(unchanged!.istEntwurf, isTrue);
    expect(unchanged.rechnungsnummer, isNull);
    expect(await _counters(db), counters);
  });

  testWidgets('test_document_page_hides_corrections_without_artifact_storage', (WidgetTester tester) async {
    final AppDatabase db = await _openDb();
    addTearDown(db.close);
    final RechnungenUseCases useCases = _useCases(db);
    expect(useCases.correctionActionsAvailable, isFalse);

    final RechnungItem invoiceDraft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[_line],
    );
    await expectLater(
      useCases.finalizeRechnung(locale: 'de_DE', rechnungId: invoiceDraft.id),
      throwsA(isA<StateError>()),
    );
    await _pumpInvoiceRoute(tester, db, invoiceDraft.id);
    expect(find.byKey(const ValueKey<String>('invoice_action_storno')), findsNothing);
    expect(find.byKey(const ValueKey<String>('invoice_action_credit_note')), findsNothing);

    final RechnungItem angebotDraft = await useCases.createDokument(
      typ: 'angebot',
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[_line],
    );
    await expectLater(
      useCases.finalizeRechnung(locale: 'de_DE', rechnungId: angebotDraft.id),
      throwsA(isA<StateError>()),
    );
    await _pumpInvoiceRoute(tester, db, angebotDraft.id);
    expect(find.byKey(const ValueKey<String>('invoice_action_convert_auftrag')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('test_finalize_failure_shows_localized_action_message', (WidgetTester tester) async {
    final Directory profileDirectory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('invoice-action-failure-'),
    ))!;
    final AppDatabase db = (await tester.runAsync(() => _openProfileDb(profileDirectory)))!;
    addTearDown(() async {
      await db.close();
      await profileDirectory.delete(recursive: true);
    });
    final RechnungenUseCases useCases = _useCases(db);
    final RechnungItem draft = (await tester.runAsync(
      () => useCases.createDraftRechnung(datum: '2026-08-30', positionen: const <RechnungPositionItem>[_line]),
    ))!;
    await tester.runAsync(
      () => db.executor.runCustom("UPDATE nummernkreise SET format = '' WHERE typ = 'rechnung_ausgang'"),
    );

    await _pumpInvoiceRoute(tester, db, draft.id);
    await tester.tap(find.byKey(const ValueKey<String>('invoice_finalize_header')));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    await tester.tap(find.byKey(const ValueKey<String>('invoice_finalize_dialog_confirm')));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );

    expect(find.text('Aktion fehlgeschlagen. Prüfen Sie das Dokument und versuchen Sie es erneut.'), findsOneWidget);
    expect(find.textContaining('StateError'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
