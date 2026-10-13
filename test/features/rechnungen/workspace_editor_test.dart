import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/pages/rechnungen/invoice_workspace_state.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';

Future<AppDatabase> _configuredWorkspaceDb() async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  await db.executor.runCustom("INSERT INTO unternehmen (name) VALUES ('Test GmbH')");
  await db.executor.runCustom(
    "INSERT INTO kunden (name, strasse, plz, ort) VALUES ('Workspace Kunde', 'Str. 1', '10115', 'Berlin')",
  );
  return db;
}

Widget _wrapWorkspace(GoRouter router, AppDatabase db) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: MaterialApp.router(routerConfig: router),
  );
}

RechnungenUseCases _useCases(AppDatabase db) =>
    RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));

const RechnungPositionItem _positionA = RechnungPositionItem(
  bezeichnung: 'Beratung',
  menge: 2,
  einzelpreis: 100,
  gesamt: 200,
  position: 0,
);

const RechnungPositionItem _positionB = RechnungPositionItem(
  bezeichnung: 'Schulung',
  menge: 1,
  einzelpreis: 50,
  gesamt: 50,
  position: 1,
);

void main() {
  test('test_invoice_draft_multiple_positions_round_trip', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    final useCases = _useCases(db);

    final RechnungItem draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[_positionA],
    );
    expect(draft.positionen, hasLength(1));

    // Add a second position, edit the first, reorder them, and save.
    final RechnungItem saved = await useCases.updateDraftRechnung(
      rechnungId: draft.id,
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Schulung', menge: 1, einzelpreis: 50, gesamt: 50, position: 0),
        RechnungPositionItem(bezeichnung: 'Beratung plus', menge: 2, einzelpreis: 100, gesamt: 200, position: 1),
      ],
    );
    expect(saved.istEntwurf, isTrue);
    expect(saved.status, 'entwurf');

    final RechnungItem? reopened = await useCases.findById(draft.id);
    expect(reopened, isNotNull);
    expect(reopened!.istEntwurf, isTrue);
    expect(reopened.positionen, hasLength(2));
    expect(reopened.positionen[0].bezeichnung, 'Schulung');
    expect(reopened.positionen[1].bezeichnung, 'Beratung plus');
    expect(reopened.positionen[0].gesamt, 50);
    expect(reopened.positionen[1].gesamt, 200);
  });

  test('test_header_discounts_round_trip_and_recalculate_after_reopen', () async {
    final AppDatabase db = await _configuredWorkspaceDb();
    addTearDown(db.close);
    final RechnungenUseCases useCases = _useCases(db);
    final List<Map<String, Object?>> customerRows = await db.executor.runSelect(
      "SELECT id FROM kunden WHERE name = 'Workspace Kunde'",
      const <Object?>[],
    );
    final int kundeId = (customerRows.single['id']! as num).toInt();

    Future<void> verifyDiscount({
      required num? rabattProzent,
      required num? rabattBetrag,
      required int expectedNetCents,
      required int expectedVatCents,
      required int expectedGrossCents,
    }) async {
      final RechnungItem draft = await useCases.createDraftRechnung(
        datum: '2026-08-30',
        kundeId: kundeId,
        positionen: const <RechnungPositionItem>[_positionA],
        rabattProzent: rabattProzent,
        rabattBetrag: rabattBetrag,
      );
      final RechnungItem? opened = await useCases.findById(draft.id);
      expect(opened, isNotNull);
      expect(opened!.rabattProzent, rabattProzent ?? 0);
      expect(opened.rabattBetrag, rabattBetrag ?? 0);

      final InvoiceEditorState editor = InvoiceEditorState();
      editor.loadDraft(opened);
      expect(editor.preview!.nettoCents, expectedNetCents);
      expect(editor.preview!.ustCents, expectedVatCents);
      expect(editor.preview!.bruttoCents, expectedGrossCents);

      await useCases.updateDraftRechnung(
        rechnungId: opened.id,
        datum: opened.datum,
        positionen: opened.positionen,
        eingabemodus: opened.eingabemodus,
        rabattProzent: editor.rabattProzent,
        rabattBetrag: editor.rabattBetrag,
      );
      final RechnungItem? saved = await useCases.findById(opened.id);
      expect(saved, isNotNull);
      expect(saved!.rabattProzent, rabattProzent ?? 0);
      expect(saved.rabattBetrag, rabattBetrag ?? 0);
      final VorschauResult preview = VorschauService.calculate(
        eingabemodus: saved.eingabemodus,
        positionen: saved.positionen,
        rabattProzent: saved.rabattProzent,
        rabattBetrag: saved.rabattBetrag,
      );
      expect(preview.nettoCents, expectedNetCents);
      expect(preview.ustCents, expectedVatCents);
      expect(preview.bruttoCents, expectedGrossCents);
    }

    await verifyDiscount(
      rabattProzent: 10,
      rabattBetrag: 0,
      expectedNetCents: 18000,
      expectedVatCents: 3420,
      expectedGrossCents: 21420,
    );
    await verifyDiscount(
      rabattProzent: 0,
      rabattBetrag: 25,
      expectedNetCents: 17500,
      expectedVatCents: 3325,
      expectedGrossCents: 20825,
    );
  });

  test('test_rejected_draft_edit_preserves_saved_values', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    final useCases = _useCases(db);

    final RechnungItem draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[_positionA, _positionB],
    );

    final Map<String, Object?> before = (await db.executor.runSelect(
      'SELECT datum, netto_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
      <Object?>[draft.id],
    )).single;
    final List<Map<String, Object?>> beforePositions = await db.executor.runSelect(
      'SELECT bezeichnung, gesamt FROM rechnungspositionen WHERE rechnung_id = ? ORDER BY position, id',
      <Object?>[draft.id],
    );

    // The form holds a position rejected by domain validation.
    await expectLater(
      useCases.updateDraftRechnung(
        datum: '2026-08-30',
        rechnungId: draft.id,
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: '  ', menge: 1, einzelpreis: 100, gesamt: 100, position: 0),
        ],
      ),
      throwsA(isA<ArgumentError>()),
    );

    // The persisted draft remains byte-for-byte unchanged.
    final Map<String, Object?> after = (await db.executor.runSelect(
      'SELECT datum, netto_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
      <Object?>[draft.id],
    )).single;
    expect(after, before);
    final List<Map<String, Object?>> afterPositions = await db.executor.runSelect(
      'SELECT bezeichnung, gesamt FROM rechnungspositionen WHERE rechnung_id = ? ORDER BY position, id',
      <Object?>[draft.id],
    );
    expect(afterPositions, hasLength(beforePositions.length));

    // The in-progress form values remain available for correction.
    final InvoiceEditorState editor = InvoiceEditorState();
    editor.addPosition(const EditorPosition(bezeichnung: '  ', menge: 1, einzelpreis: 100, ustSatz: 19));
    expect(editor.recalculate(), isFalse);
    expect(editor.positionen.single.bezeichnung, '  ');
    expect(editor.fieldErrors, isNotEmpty);
  });

  test('test_invalid_numeric_editor_text_is_preserved_and_cannot_be_converted', () {
    final InvoiceEditorState editor = InvoiceEditorState();
    editor.addPosition(const EditorPosition(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, ustSatz: 19));
    expect(editor.recalculate(), isTrue);

    editor.updatePosition(0, editor.positionen.single.copyWith(mengeText: 'unfinished', menge: 1));
    expect(editor.positionen.single.mengeText, 'unfinished');
    expect(editor.recalculate(), isFalse);
    expect(editor.preview, isNull);
    expect(editor.fieldErrors['position[0].menge'], 'invalidNumber');
    expect(editor.toDomainPositions, throwsA(isA<InvoiceMoneyValidationException>()));
  });

  testWidgets('test_workspace_requires_customer_and_saves_selected_customer', (WidgetTester tester) async {
    final AppDatabase db = await _configuredWorkspaceDb();
    addTearDown(db.close);
    final GoRouter router = createRouter(db);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrapWorkspace(router, db));
    await tester.pumpAndSettle();
    router.go('/invoices/new');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('workspace_add_position')));
    await tester.pumpAndSettle();
    final Finder description = find.byKey(const ValueKey<String>('workspace_position_0_description'));
    final Finder quantity = find.byKey(const ValueKey<String>('workspace_position_0_quantity'));
    final Finder price = find.byKey(const ValueKey<String>('workspace_position_0_price'));
    await tester.enterText(description, 'Beratung');
    await tester.enterText(quantity, 'unfinished');
    await tester.enterText(price, '100');
    await tester.pumpAndSettle();

    expect(find.descendant(of: quantity, matching: find.text('Eingaben prüfen')), findsOneWidget);
    final EditableText retainedQuantity = tester.widget<EditableText>(
      find.descendant(of: quantity, matching: find.byType(EditableText)),
    );
    expect(retainedQuantity.controller.text, 'unfinished');

    await tester.tap(find.byKey(const ValueKey<String>('workspace_save')));
    await tester.pumpAndSettle();
    final List<Map<String, Object?>> rejectedDrafts = await db.executor.runSelect(
      'SELECT id FROM rechnungen WHERE ist_entwurf = 1',
      const <Object?>[],
    );
    expect(rejectedDrafts, isEmpty);
    final EditableText retainedAfterSave = tester.widget<EditableText>(
      find.descendant(of: quantity, matching: find.byType(EditableText)),
    );
    expect(retainedAfterSave.controller.text, 'unfinished');

    await tester.enterText(quantity, '1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('workspace_save')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('workspace_customer')),
        matching: find.text('Kunde ist erforderlich'),
      ),
      findsOneWidget,
    );
    final EditableText retainedDescription = tester.widget<EditableText>(
      find.descendant(of: description, matching: find.byType(EditableText)),
    );
    expect(retainedDescription.controller.text, 'Beratung');

    await tester.tap(find.byKey(const ValueKey<String>('workspace_customer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workspace Kunde'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('workspace_save')));
    await tester.pumpAndSettle();

    final List<Map<String, Object?>> savedInvoices = await db.executor.runSelect(
      'SELECT id, kunde_id FROM rechnungen WHERE ist_entwurf = 1 ORDER BY id DESC LIMIT 1',
      const <Object?>[],
    );
    expect(savedInvoices, hasLength(1));
    final int invoiceId = (savedInvoices.single['id']! as num).toInt();
    expect(savedInvoices.single['kunde_id'], isNotNull);
    final List<Map<String, Object?>> savedPositions = await db.executor.runSelect(
      'SELECT bezeichnung, menge, einzelpreis FROM rechnungspositionen WHERE rechnung_id = ?',
      <Object?>[invoiceId],
    );
    expect(savedPositions.single['bezeichnung'], 'Beratung');
    expect(savedPositions.single['menge'], 1);
    expect(savedPositions.single['einzelpreis'], 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('test_workspace_reorders_position_values_and_saves_in_visible_order', (WidgetTester tester) async {
    final AppDatabase db = await _configuredWorkspaceDb();
    addTearDown(db.close);
    final GoRouter router = createRouter(db);
    tester.view.physicalSize = const Size(1280, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrapWorkspace(router, db));
    await tester.pumpAndSettle();
    router.go('/invoices/new');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('workspace_add_position')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('workspace_add_position')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey<String>('workspace_position_0_description')), 'Beratung');
    await tester.enterText(find.byKey(const ValueKey<String>('workspace_position_0_quantity')), '1');
    await tester.enterText(find.byKey(const ValueKey<String>('workspace_position_0_price')), '100');
    await tester.enterText(find.byKey(const ValueKey<String>('workspace_position_1_description')), 'Schulung');
    await tester.enterText(find.byKey(const ValueKey<String>('workspace_position_1_quantity')), '2');
    await tester.enterText(find.byKey(const ValueKey<String>('workspace_position_1_price')), '50');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_upward).last);
    await tester.pumpAndSettle();

    EditableText descriptionAt(int index) => tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(ValueKey<String>('workspace_position_${index}_description')),
        matching: find.byType(EditableText),
      ),
    );
    expect(descriptionAt(0).controller.text, 'Schulung');
    expect(descriptionAt(1).controller.text, 'Beratung');

    await tester.tap(find.byKey(const ValueKey<String>('workspace_customer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workspace Kunde'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('workspace_save')));
    await tester.pumpAndSettle();

    final List<Map<String, Object?>> positions = await db.executor.runSelect(
      'SELECT bezeichnung, menge, einzelpreis FROM rechnungspositionen ORDER BY position',
      const <Object?>[],
    );
    expect(positions, hasLength(2));
    expect(positions[0]['bezeichnung'], 'Schulung');
    expect(positions[0]['menge'], 2);
    expect(positions[0]['einzelpreis'], 50);
    expect(positions[1]['bezeichnung'], 'Beratung');
    expect(positions[1]['menge'], 1);
    expect(positions[1]['einzelpreis'], 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('test_workspace_marks_invalid_date_on_the_date_field', (WidgetTester tester) async {
    final AppDatabase db = await _configuredWorkspaceDb();
    addTearDown(db.close);
    final GoRouter router = createRouter(db);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrapWorkspace(router, db));
    await tester.pumpAndSettle();
    router.go('/invoices/new');
    await tester.pumpAndSettle();

    final Finder date = find.byKey(const ValueKey<String>('workspace_date'));
    await tester.enterText(date, '2026-02-30');
    await tester.pumpAndSettle();
    expect(find.descendant(of: date, matching: find.text('Datum im Format JJJJ-MM-TT eingeben')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('workspace_save')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: date, matching: find.text('Datum im Format JJJJ-MM-TT eingeben')), findsOneWidget);
    final List<Map<String, Object?>> drafts = await db.executor.runSelect(
      'SELECT id FROM rechnungen WHERE ist_entwurf = 1',
      const <Object?>[],
    );
    expect(drafts, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
