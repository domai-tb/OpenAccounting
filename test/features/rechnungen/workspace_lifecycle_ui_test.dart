import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';

const RechnungPositionItem _line = RechnungPositionItem(
  bezeichnung: 'Beratung',
  menge: 1,
  einzelpreis: 100,
  gesamt: 100,
  position: 0,
);

RechnungenUseCases _useCases(AppDatabase db) =>
    RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)));

Future<AppDatabase> _openProfileDb(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final Directory profileDirectory = await Directory.systemTemp.createTemp('invoice-lifecycle-ui-');
    final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
    addTearDown(() async {
      await db.close();
      if (profileDirectory.existsSync()) await profileDirectory.delete(recursive: true);
    });
    await db.ensureOpen();
    await db.executor.runInsert(
      'INSERT INTO unternehmen (name) SELECT ? WHERE NOT EXISTS (SELECT 1 FROM unternehmen)',
      <Object?>['Lifecycle UI test company'],
    );
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'ER-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_eingang'",
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
  }))!;
}

Future<RechnungItem> _finalizedInvoice(WidgetTester tester, RechnungenUseCases useCases) async {
  return (await tester.runAsync(() async {
    final RechnungItem draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[_line],
    );
    return useCases.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
  }))!;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

Future<T> _runWithRealAsync<T>(WidgetTester tester, Future<T> Function() operation) async {
  return (await tester.runAsync<T>(operation)) as T;
}

Future<GoRouter> _pumpInvoiceRoute(WidgetTester tester, AppDatabase db, int invoiceId) async {
  final GoRouter router = createRouter(db);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.go('/invoices/$invoiceId');
  await _settle(tester);
  return router;
}

Future<void> _confirmStorno(WidgetTester tester, String reason) async {
  await tester.tap(find.byKey(const ValueKey<String>('invoice_action_storno')));
  await _settle(tester);
  expect(find.byKey(const ValueKey<String>('invoice_storno_dialog_confirm')), findsOneWidget);
  expect(find.byType(TextField), findsOneWidget);
  await tester.enterText(find.byType(TextField), reason);
  await tester.tap(find.byKey(const ValueKey<String>('invoice_storno_dialog_confirm')));
  await _settle(tester);
}

void main() {
  testWidgets('test_invoice_detail_storno_confirms_reason_and_commits_artifact', (WidgetTester tester) async {
    final AppDatabase db = await _openProfileDb(tester);
    final RechnungenUseCases useCases = _useCases(db);
    final RechnungItem source = await _finalizedInvoice(tester, useCases);
    expect(useCases.correctionActionsAvailable, isTrue);
    await _pumpInvoiceRoute(tester, db, source.id);

    await tester.tap(find.byKey(const ValueKey<String>('invoice_action_storno')));
    await _settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('invoice_storno_dialog_confirm')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Kundenauftrag widerrufen');
    await tester.tap(find.byKey(const ValueKey<String>('invoice_storno_dialog_confirm')));
    await _settle(tester);

    final List<Map<String, Object?>> correctionRows = await _runWithRealAsync(
      tester,
      () => db.executor.runSelect(
        'SELECT id, typ, storno_von, original_pdf_pfad FROM rechnungen WHERE storno_von = ?',
        <Object?>[source.id],
      ),
    );
    expect(correctionRows, hasLength(1));
    final Map<String, Object?> correction = correctionRows.single;
    expect(correction['typ'], 'storno');
    expect(correction['storno_von'], source.id);
    final int correctionId = (correction['id']! as num).toInt();
    final List<Map<String, Object?>> sourceRows = await _runWithRealAsync(
      tester,
      () => db.executor.runSelect('SELECT status, storno_grund FROM rechnungen WHERE id = ?', <Object?>[source.id]),
    );
    expect(sourceRows.single['status'], 'storniert');
    expect(sourceRows.single['storno_grund'], 'Kundenauftrag widerrufen');
    final File artifact = File(correction['original_pdf_pfad']! as String);
    expect(await _runWithRealAsync(tester, artifact.exists), isTrue);
    expect(await _runWithRealAsync(tester, artifact.length), greaterThan(0));

    final RechnungItem? sourceDetail = await _runWithRealAsync(tester, () => useCases.findById(source.id));
    final RechnungItem? correctionDetail = await _runWithRealAsync(tester, () => useCases.findById(correctionId));
    expect(
      sourceDetail!.beziehungen.any((link) => link.kind == 'storno Ziel' && link.documentId == correctionId),
      isTrue,
    );
    expect(
      correctionDetail!.beziehungen.any((link) => link.kind == 'storno Quelle' && link.documentId == source.id),
      isTrue,
    );
  });

  testWidgets('test_invoice_detail_gutschrift_creates_one_linked_correction', (WidgetTester tester) async {
    final AppDatabase db = await _openProfileDb(tester);
    final RechnungenUseCases useCases = _useCases(db);
    final RechnungItem source = await _finalizedInvoice(tester, useCases);
    await _pumpInvoiceRoute(tester, db, source.id);

    final Finder action = find.byKey(const ValueKey<String>('invoice_action_credit_note'));
    final Finder cancel = find.byKey(const ValueKey<String>('invoice_gutschrift_dialog_cancel'));
    final Finder confirm = find.byKey(const ValueKey<String>('invoice_gutschrift_dialog_confirm'));
    await tester.tap(action);
    await _settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(cancel, findsOneWidget);
    expect(confirm, findsOneWidget);
    expect(
      await _runWithRealAsync(
        tester,
        () => db.executor.runSelect('SELECT id FROM rechnungen WHERE gutschrift_von = ?', <Object?>[source.id]),
      ),
      isEmpty,
    );
    await tester.tap(cancel);
    await _settle(tester);
    expect(
      await _runWithRealAsync(
        tester,
        () => db.executor.runSelect('SELECT id FROM rechnungen WHERE gutschrift_von = ?', <Object?>[source.id]),
      ),
      isEmpty,
    );

    await tester.tap(action);
    await _settle(tester);
    expect(confirm, findsOneWidget);
    expect(
      await _runWithRealAsync(
        tester,
        () => db.executor.runSelect('SELECT id FROM rechnungen WHERE gutschrift_von = ?', <Object?>[source.id]),
      ),
      isEmpty,
    );
    await tester.tap(confirm);
    await _settle(tester);

    final List<Map<String, Object?>> correctionRows = await _runWithRealAsync(
      tester,
      () => db.executor.runSelect('SELECT id, typ, gutschrift_von FROM rechnungen WHERE gutschrift_von = ?', <Object?>[
        source.id,
      ]),
    );
    expect(correctionRows, hasLength(1));
    final Map<String, Object?> correction = correctionRows.single;
    expect(correction['typ'], 'gutschrift');
    expect(correction['gutschrift_von'], source.id);
    final int correctionId = (correction['id']! as num).toInt();
    final RechnungItem? sourceDetail = await _runWithRealAsync(tester, () => useCases.findById(source.id));
    final RechnungItem? correctionDetail = await _runWithRealAsync(tester, () => useCases.findById(correctionId));
    expect(
      sourceDetail!.beziehungen.any((link) => link.kind == 'gutschrift Ziel' && link.documentId == correctionId),
      isTrue,
    );
    expect(
      correctionDetail!.beziehungen.any((link) => link.kind == 'gutschrift Quelle' && link.documentId == source.id),
      isTrue,
    );
  });

  testWidgets('test_invoice_detail_replacement_is_available_after_storno_and_links_draft', (WidgetTester tester) async {
    final AppDatabase db = await _openProfileDb(tester);
    final RechnungenUseCases useCases = _useCases(db);
    final RechnungItem source = await _finalizedInvoice(tester, useCases);
    final GoRouter router = await _pumpInvoiceRoute(tester, db, source.id);
    final Finder replacementAction = find.byKey(const ValueKey<String>('invoice_action_replacement'));
    expect(replacementAction, findsNothing);

    await _confirmStorno(tester, 'Kundenauftrag widerrufen');
    router.go('/invoices/${source.id}');
    await _settle(tester);
    expect(replacementAction, findsOneWidget);
    final Finder cancel = find.byKey(const ValueKey<String>('invoice_replacement_dialog_cancel'));
    final Finder confirm = find.byKey(const ValueKey<String>('invoice_replacement_dialog_confirm'));
    await tester.tap(replacementAction);
    await _settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(cancel, findsOneWidget);
    expect(confirm, findsOneWidget);
    expect(
      await _runWithRealAsync(
        tester,
        () => db.executor.runSelect('SELECT id FROM rechnungen WHERE ersatz_fuer = ?', <Object?>[source.id]),
      ),
      isEmpty,
    );
    await tester.tap(cancel);
    await _settle(tester);
    expect(
      await _runWithRealAsync(
        tester,
        () => db.executor.runSelect('SELECT id FROM rechnungen WHERE ersatz_fuer = ?', <Object?>[source.id]),
      ),
      isEmpty,
    );

    await tester.tap(replacementAction);
    await _settle(tester);
    expect(confirm, findsOneWidget);
    expect(
      await _runWithRealAsync(
        tester,
        () => db.executor.runSelect('SELECT id FROM rechnungen WHERE ersatz_fuer = ?', <Object?>[source.id]),
      ),
      isEmpty,
    );
    await tester.tap(confirm);
    await _settle(tester);

    final List<Map<String, Object?>> replacementRows = await _runWithRealAsync(
      tester,
      () => db.executor.runSelect(
        'SELECT id, typ, ist_entwurf, ersatz_fuer FROM rechnungen WHERE ersatz_fuer = ?',
        <Object?>[source.id],
      ),
    );
    expect(replacementRows, hasLength(1));
    final Map<String, Object?> replacement = replacementRows.single;
    expect(replacement['typ'], 'rechnung');
    expect(replacement['ist_entwurf'], 1);
    expect(replacement['ersatz_fuer'], source.id);
    final int replacementId = (replacement['id']! as num).toInt();
    final RechnungItem? sourceDetail = await _runWithRealAsync(tester, () => useCases.findById(source.id));
    final RechnungItem? replacementDetail = await _runWithRealAsync(tester, () => useCases.findById(replacementId));
    expect(
      sourceDetail!.beziehungen.any((link) => link.kind == 'ersatz Ziel' && link.documentId == replacementId),
      isTrue,
    );
    expect(
      replacementDetail!.beziehungen.any((link) => link.kind == 'ersatz Quelle' && link.documentId == source.id),
      isTrue,
    );
  });

  testWidgets('test_invoice_detail_confirms_permitted_angebot_conversion_and_links_auftrag', (
    WidgetTester tester,
  ) async {
    final AppDatabase db = await _openProfileDb(tester);
    final RechnungenUseCases useCases = _useCases(db);
    final RechnungItem angebotDraft = (await tester.runAsync(
      () =>
          useCases.createDokument(typ: 'angebot', datum: '2026-08-30', positionen: const <RechnungPositionItem>[_line]),
    ))!;
    final RechnungItem angebot = (await tester.runAsync(
      () => useCases.finalizeRechnung(locale: 'de_DE', rechnungId: angebotDraft.id),
    ))!;
    await _pumpInvoiceRoute(tester, db, angebot.id);
    const ValueKey<String> actionKey = ValueKey<String>('invoice_action_convert_auftrag');
    await tester.tap(find.byKey(actionKey));
    await _settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('invoice_convert_dialog_confirm')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('invoice_convert_dialog_confirm')));
    await _settle(tester);

    final List<Map<String, Object?>> targetRows = await _runWithRealAsync(
      tester,
      () => db.executor.runSelect(
        'SELECT id, typ, ist_entwurf, konvertiert_von FROM rechnungen WHERE konvertiert_von = ?',
        <Object?>[angebot.id],
      ),
    );
    expect(targetRows, hasLength(1));
    final Map<String, Object?> target = targetRows.single;
    expect(target['typ'], 'auftrag');
    expect(target['ist_entwurf'], 1);
    expect(target['konvertiert_von'], angebot.id);
    final int auftragId = (target['id']! as num).toInt();
    final List<Map<String, Object?>> sourceRows = await _runWithRealAsync(
      tester,
      () => db.executor.runSelect('SELECT konvertiert_zu FROM rechnungen WHERE id = ?', <Object?>[angebot.id]),
    );
    expect(sourceRows.single['konvertiert_zu'], auftragId);
    final RechnungItem? angebotDetail = await _runWithRealAsync(tester, () => useCases.findById(angebot.id));
    final RechnungItem? auftragDetail = await _runWithRealAsync(tester, () => useCases.findById(auftragId));
    expect(
      angebotDetail!.beziehungen.any((link) => link.kind == 'konvertierung Ziel' && link.documentId == auftragId),
      isTrue,
    );
    expect(
      auftragDetail!.beziehungen.any((link) => link.kind == 'konvertierung Quelle' && link.documentId == angebot.id),
      isTrue,
    );
  });

  testWidgets('test_incoming_invoice_detail_storno_creates_linked_reversal', (WidgetTester tester) async {
    final AppDatabase db = await _openProfileDb(tester);
    final RechnungenUseCases useCases = _useCases(db);
    final int supplierId = (await tester.runAsync(
      () => db.executor.runInsert('INSERT INTO lieferanten (name) VALUES (?)', <Object?>['Fixture-Lieferant']),
    ))!;
    final RechnungItem draft = (await tester.runAsync(
      () => useCases.createDraftRechnung(
        datum: '2026-08-30',
        typ: 'rechnung_eingang',
        positionen: const <RechnungPositionItem>[_line],
      ),
    ))!;
    await tester.runAsync(
      () =>
          db.executor.runUpdate('UPDATE rechnungen SET lieferant_id = ? WHERE id = ?', <Object?>[supplierId, draft.id]),
    );
    final RechnungItem incoming = (await tester.runAsync(
      () => useCases.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id),
    ))!;
    expect(incoming.typ, 'rechnung_eingang');
    expect(incoming.istEntwurf, isFalse);
    await _pumpInvoiceRoute(tester, db, incoming.id);
    expect(find.byKey(const ValueKey<String>('invoice_action_storno')), findsOneWidget);

    await _confirmStorno(tester, 'Eingangsrechnung korrigieren');

    final List<Map<String, Object?>> correctionRows = await _runWithRealAsync(
      tester,
      () => db.executor.runSelect(
        'SELECT id, typ, storno_von, lieferant_id, original_pdf_pfad FROM rechnungen WHERE storno_von = ?',
        <Object?>[incoming.id],
      ),
    );
    expect(correctionRows, hasLength(1));
    final Map<String, Object?> correction = correctionRows.single;
    expect(correction['typ'], 'storno');
    expect(correction['storno_von'], incoming.id);
    expect(correction['lieferant_id'], supplierId);
    final int correctionId = (correction['id']! as num).toInt();
    final File artifact = File(correction['original_pdf_pfad']! as String);
    expect(await _runWithRealAsync(tester, artifact.exists), isTrue);
    expect(await _runWithRealAsync(tester, artifact.length), greaterThan(0));

    final RechnungItem? sourceDetail = await _runWithRealAsync(tester, () => useCases.findById(incoming.id));
    final RechnungItem? correctionDetail = await _runWithRealAsync(tester, () => useCases.findById(correctionId));
    expect(
      sourceDetail!.beziehungen.any((link) => link.kind == 'storno Ziel' && link.documentId == correctionId),
      isTrue,
    );
    expect(
      correctionDetail!.beziehungen.any((link) => link.kind == 'storno Quelle' && link.documentId == incoming.id),
      isTrue,
    );
    final List<Map<String, Object?>> reversalJournals = await _runWithRealAsync(
      tester,
      () => db.executor.runSelect('SELECT storno_von FROM journal WHERE rechnung_id = ?', <Object?>[correctionId]),
    );
    expect(reversalJournals, hasLength(1));
    expect(reversalJournals.single['storno_von'], isNotNull);
  });
}
