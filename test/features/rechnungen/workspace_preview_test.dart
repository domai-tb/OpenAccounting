import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openaccounting/core/database.dart';
import 'package:openaccounting/core/router/app_router.dart';
import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/pages/rechnungen/invoice_workspace_state.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';

Future<AppDatabase> _configuredPreviewDb() async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  await db.executor.runCustom("INSERT INTO unternehmen (name) VALUES ('Test GmbH')");
  await db.executor.runCustom(
    "INSERT INTO kunden (name, strasse, plz, ort) VALUES ('Workspace Kunde', 'Str. 1', '10115', 'Berlin')",
  );
  return db;
}

Widget _wrapPreviewWorkspace(GoRouter router, AppDatabase db) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  test('test_preview_result_is_shared_by_editor_and_document_preview', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    final useCases = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));

    // One authoritative domain result: net 100.00, VAT 19.00, gross 119.00.
    const positions = <RechnungPositionItem>[
      RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100, position: 0),
    ];
    final VorschauResult result = useCases.previewRechnung(eingabemodus: 'netto', positionen: positions);
    expect(result.nettoBetrag, 100);
    expect(result.ustBetrag, 19);
    expect(result.bruttoBetrag, 119);

    // The editor copies the same result instance values, never recalculates.
    final InvoiceEditorState editor = InvoiceEditorState();
    editor.addPosition(const EditorPosition(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, ustSatz: 19));
    expect(editor.recalculate(), isTrue);
    expect(editor.previewStale, isFalse);
    expect(editor.preview!.nettoBetrag, result.nettoBetrag);
    expect(editor.preview!.ustBetrag, result.ustBetrag);
    expect(editor.preview!.bruttoBetrag, result.bruttoBetrag);

    // The document preview binds its total label to the same gross value.
    final RechnungItem draft = await useCases.createDraftRechnung(datum: '2026-08-30', positionen: positions);
    final RechnungItem? loaded = await useCases.findById(draft.id);
    final VorschauResult documentPreview = useCases.previewRechnung(
      eingabemodus: loaded!.eingabemodus,
      positionen: loaded.positionen,
    );
    expect(documentPreview.bruttoBetrag, result.bruttoBetrag);
    expect(documentPreview.nettoBetrag, 100);
    expect(documentPreview.ustBetrag, 19);
  });

  test('test_invalid_preview_does_not_present_stale_totals', () async {
    final InvoiceEditorState editor = InvoiceEditorState();
    editor.addPosition(const EditorPosition(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, ustSatz: 19));
    expect(editor.recalculate(), isTrue);
    expect(editor.previewStale, isFalse);
    expect(editor.preview!.bruttoBetrag, 119);

    // Current form values fail domain validation: previous amounts are
    // cleared/marked stale and no amount is presented as current total.
    editor.updatePosition(0, const EditorPosition(bezeichnung: '', menge: 1, einzelpreis: 100, ustSatz: 19));
    expect(editor.recalculate(), isFalse);
    expect(editor.preview, isNull);
    expect(editor.previewStale, isTrue);
    expect(editor.fieldErrors, isNotEmpty);
    expect(editor.summaryErrors, isNotEmpty);
  });

  testWidgets('test_workspace_shows_editor_summary_and_document_content', (WidgetTester tester) async {
    final AppDatabase db = await _configuredPreviewDb();
    addTearDown(db.close);
    final GoRouter router = createRouter(db);
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrapPreviewWorkspace(router, db));
    await tester.pumpAndSettle();
    router.go('/invoices/new');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('workspace_add_position')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey<String>('workspace_position_0_description')), 'Beratung');
    await tester.enterText(find.byKey(const ValueKey<String>('workspace_position_0_quantity')), '1');
    await tester.enterText(find.byKey(const ValueKey<String>('workspace_position_0_price')), '100');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('workspace_customer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workspace Kunde'));
    await tester.pumpAndSettle();

    for (final String prefix in <String>['workspace_editor', 'workspace_preview']) {
      for (final (String suffix, double amount) in <(String, double)>[('net', 100), ('tax', 19), ('total', 119)]) {
        final Finder row = find.byKey(ValueKey<String>('${prefix}_$suffix'));
        final MoneyText money = tester.widget<MoneyText>(find.descendant(of: row, matching: find.byType(MoneyText)));
        expect(money.amount, amount);
      }
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('workspace_preview_line_0')),
        matching: find.text('Beratung'),
      ),
      findsOneWidget,
    );
    expect(find.text('Workspace Kunde'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byKey(const ValueKey<String>('workspace_position_0_quantity')), 'unfinished');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('workspace_editor_total')), findsNothing);
    expect(find.byKey(const ValueKey<String>('workspace_preview_total')), findsNothing);
    expect(find.byKey(const ValueKey<String>('workspace_editor_stale')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('workspace_preview_stale')), findsOneWidget);
    final EditableText quantity = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('workspace_position_0_quantity')),
        matching: find.byType(EditableText),
      ),
    );
    expect(quantity.controller.text, 'unfinished');
    expect(find.text('Eingaben prüfen'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('test_header_discount_survives_workspace_save_and_document_preview', (WidgetTester tester) async {
    final AppDatabase db = await _configuredPreviewDb();
    addTearDown(db.close);
    final RechnungenUseCases useCases = RechnungenUseCases(
      RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)),
    );
    final List<Map<String, Object?>> customerRows = await db.executor.runSelect(
      "SELECT id FROM kunden WHERE name = 'Workspace Kunde'",
      const <Object?>[],
    );
    final int kundeId = (customerRows.single['id']! as num).toInt();
    const RechnungPositionItem line = RechnungPositionItem(
      bezeichnung: 'Beratung',
      menge: 1,
      einzelpreis: 100,
      gesamt: 100,
      position: 0,
    );
    final RechnungItem draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      kundeId: kundeId,
      positionen: const <RechnungPositionItem>[line],
      rabattProzent: 10,
      rabattBetrag: 0,
    );

    final GoRouter router = createRouter(db);
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(locale: const Locale('de'), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/invoices/${draft.id}/edit');
    await tester.pumpAndSettle();

    for (final (String key, double amount) in <(String, double)>[
      ('workspace_editor_net', 90),
      ('workspace_editor_tax', 17.1),
      ('workspace_editor_total', 107.1),
      ('workspace_preview_net', 90),
      ('workspace_preview_tax', 17.1),
      ('workspace_preview_total', 107.1),
    ]) {
      final Finder row = find.byKey(ValueKey<String>(key));
      final MoneyText money = tester.widget<MoneyText>(find.descendant(of: row, matching: find.byType(MoneyText)));
      expect(money.amount, amount);
    }

    await tester.tap(find.byKey(const ValueKey<String>('workspace_save')));
    await tester.pumpAndSettle();

    final RechnungItem? saved = await useCases.findById(draft.id);
    expect(saved, isNotNull);
    expect(saved!.rabattProzent, 10);
    expect(saved.rabattBetrag, 0);
    final List<MoneyText> documentTotals = tester
        .widgetList<MoneyText>(find.byType(MoneyText))
        .where((MoneyText money) => money.amount == 107.1)
        .toList(growable: false);
    expect(documentTotals, hasLength(1));
    // The net-mode draft labels its line column as Netto in the embedded German invoice paper.
    expect(find.text('Netto'), findsAtLeastNWidgets(2));
    // The embedded PDF paper prints the same discounted gross total as the
    // summary metric. Both stay visible on a draft detail page.
    final List<String?> renderedText = tester
        .widgetList<Text>(find.byType(Text))
        .map((Text widget) => widget.data)
        .toList();
    expect(
      renderedText.where((String? value) => value?.contains('107') ?? false),
      hasLength(2),
      reason: renderedText.toString(),
    );
    expect(tester.takeException(), isNull);
  });
}
