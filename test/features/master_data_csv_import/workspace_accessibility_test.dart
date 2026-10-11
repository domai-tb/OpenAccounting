import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_models.dart';
import 'package:openaccounting/pages/stammdaten/master_data_csv_import_page.dart';

/// Import review accessibility: keyboard flow and localized unavailable state.
void main() {
  group('Import workspace accessibility', () {
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_csv_a11y_test_');
    });

    tearDown(() async {
      await profileDirectory.delete(recursive: true);
    });

    Future<AppDatabase> openDatabase() async {
      final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      addTearDown(db.close);
      return db;
    }

    Widget wrapPage(AppDatabase db, Widget child) {
      return ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AppScope(services: AppServices(db), child: child),
        ),
      );
    }

    bool buttonHasFocus(WidgetTester tester, Finder finder) {
      final Finder label = find.descendant(of: finder, matching: find.byType(Text));
      final List<Element> elements = label.evaluate().toList();
      if (elements.length != 1) return false;
      return Focus.of(elements.single).hasPrimaryFocus;
    }

    Future<void> mapColumn(WidgetTester tester, int column, String field) async {
      final Finder mappingMenu = find.byKey(ValueKey<String>('map_col_$column'));
      tester.widget<DropdownMenu<String?>>(mappingMenu).onSelected?.call(field);
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownMenu<String?>>(mappingMenu).initialSelection, field);
    }

    testWidgets('test_master_data_csv_import_review_and_confirm_with_keyboard', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final AppDatabase db = await openDatabase();
      await tester.pumpWidget(wrapPage(db, const MasterDataCsvImportView(entity: MasterDataImportEntity.supplier)));
      await tester.pumpAndSettle();

      // Keyboard moves focus out of the source text field.
      final Finder csvField = find.byType(TextField).at(1);
      await tester.enterText(csvField, 'Name;Straße;PLZ;Ort\nGut GmbH;Weg 1;10115;Berlin\nSchlecht AG;Weg 2;80331;');
      await tester.pump();
      final EditableText csvEditableText = tester.widget<EditableText>(
        find.descendant(of: csvField, matching: find.byType(EditableText)),
      );
      expect(csvEditableText.focusNode.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(csvEditableText.focusNode.hasPrimaryFocus, isFalse);

      // Create-new strategy needs no match field.
      final Finder duplicatePolicy = find.byType(DropdownMenu<MasterDataDuplicatePolicy>);
      tester
          .widget<DropdownMenu<MasterDataDuplicatePolicy>>(duplicatePolicy)
          .onSelected
          ?.call(MasterDataDuplicatePolicy.createNew);
      await tester.pumpAndSettle();

      final Finder parseButton = find.widgetWithText(FilledButton, 'Parsen und zuordnen');
      await tester.ensureVisible(parseButton);
      await tester.pumpAndSettle();
      await tester.tap(parseButton);
      await tester.pumpAndSettle();
      await mapColumn(tester, 0, 'name');
      await mapColumn(tester, 1, 'strasse');
      await mapColumn(tester, 2, 'plz');
      await mapColumn(tester, 3, 'ort');

      await tester.tap(find.widgetWithText(FilledButton, 'Vorschau prüfen'));
      await tester.pumpAndSettle();

      // Row error and status are text, not color alone; status has accessible semantics.
      expect(find.textContaining('1 Ungültig'), findsWidgets);
      expect(find.textContaining('Ort ist Pflicht'), findsOneWidget);
      final SemanticsHandle semantics = tester.ensureSemantics();
      try {
        final Finder rowStatusSemantics = find.byWidgetPredicate(
          (Widget widget) => widget is Semantics && widget.properties.label == 'Zeile 3: Ungültig',
        );
        expect(rowStatusSemantics, findsOneWidget);
        expect(tester.getSemantics(rowStatusSemantics).label, 'Zeile 3: Ungültig');
      } finally {
        semantics.dispose();
      }

      // Focus order across review actions is logical: back, cancel, confirm.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      final Finder back = find.widgetWithText(OutlinedButton, 'Zurück');
      final Finder cancel = find.widgetWithText(OutlinedButton, 'Abbrechen');
      final Finder confirm = find.widgetWithText(FilledButton, 'Import bestätigen');
      final List<String> order = <String>[];
      for (int i = 0; i < 30 && order.length < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        if (!order.contains('Zurück') && buttonHasFocus(tester, back)) order.add('Zurück');
        if (!order.contains('Abbrechen') && buttonHasFocus(tester, cancel)) order.add('Abbrechen');
        if (!order.contains('Import bestätigen') && buttonHasFocus(tester, confirm)) order.add('Import bestätigen');
      }
      expect(order, <String>['Zurück', 'Abbrechen', 'Import bestätigen']);

      // The focused confirmation action is reachable and operable from the keyboard.
      expect(buttonHasFocus(tester, confirm), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('1 Neu · 0 Aktualisierung · 0 Übersprungen'), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      final Finder confirmBatch = find.widgetWithText(FilledButton, 'Bestätigen');
      for (int i = 0; i < 10 && !buttonHasFocus(tester, confirmBatch); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(buttonHasFocus(tester, confirmBatch), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.textContaining('Erstellt: 1'), findsOneWidget);
    });

    testWidgets('test_master_data_csv_import_show_a_localized_unavailable_state', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final AppDatabase db = await openDatabase();
      await db.close();
      addTearDown(() async {
        try {
          await db.close();
        } catch (_) {}
      });
      await tester.pumpWidget(wrapPage(db, const MasterDataCsvImportView(entity: MasterDataImportEntity.customer)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), 'Name;Straße;PLZ;Ort\nA;B 1;10115;Berlin');
      final Finder parseButton = find.widgetWithText(FilledButton, 'Parsen und zuordnen');
      await tester.ensureVisible(parseButton);
      await tester.pumpAndSettle();
      await tester.tap(parseButton);
      await tester.pumpAndSettle();

      // Localized retryable unavailable result, not an empty list or success.
      expect(find.textContaining('Daten nicht verfügbar'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Erneut versuchen'), findsOneWidget);
      // Selected entity and mapping state are preserved behind the error.
      expect(find.textContaining('CSV-Import'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('map_col_0')), findsOneWidget);
      expect(find.textContaining('Erstellt:'), findsNothing);
    });
  });
}
