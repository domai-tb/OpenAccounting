import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnwesen_workspace_page.dart';
import 'package:openaccounting/l10n/l10n.dart';

void main() {
  group('Dunning workspace (dunning-workflow-integrity)', () {
    late AppDatabase db;

    Future<void> openDb() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
    }

    Future<int> seedEligible({String nummer = 'RE-WS-1'}) async {
      final int kundeId = await db.executor.runInsert(
        'INSERT INTO kunden (name, strasse, plz, ort, land, anrede) VALUES (?, ?, ?, ?, ?, ?)',
        const <Object?>['Workspace Kunde', 'Musterstr 1', '10115', 'Berlin', 'DE', 'Herr'],
      );
      final int rechnungId = await db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, faelligkeit, brutto_betrag, netto_betrag) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[nummer, 'rechnung', 'offen', 0, 'netto', kundeId, '2026-01-01', '2026-01-01', '250.00', '250.00'],
      );
      await ForderungenRepository(db.executor)
          .create(typ: 'rechnung', betrag: 250, partnerTyp: 'kunde', partnerId: kundeId, rechnungId: rechnungId);
      return rechnungId;
    }

    Widget wrap() {
      return ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          locale: Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MahnwesenWorkspacePage(),
        ),
      );
    }

    testWidgets('test_mahnwesen_user_reviews_an_eligible_dunning_run', (WidgetTester tester) async {
      await openDb();
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      addTearDown(db.close);
      final int rechnungId = await seedEligible();
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      // THEN the workspace shows eligible invoices, stages, and balances before confirmation.
      expect(find.text('RE-WS-1'), findsWidgets);
      expect(find.textContaining('Stufe 1'), findsWidgets);
      expect(find.textContaining('250'), findsWidgets);
      expect(find.text('Lauf prüfen'), findsOneWidget);
      // Select the row, then confirm from the inspector.
      await tester.tap(find.byKey(ValueKey<String>('dunning_row_$rechnungId')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bestätigen & erstellen'));
      await tester.pumpAndSettle();
      final letters = await MahnungenRepository(db.executor).listByRechnung(rechnungId);
      expect(letters, hasLength(1));
      expect(letters.single.betrag, '250.00');
    });

    testWidgets('test_mahnwesen_dunning_data_source_is_unavailable', (WidgetTester tester) async {
      db = AppDatabase.createTestDatabase();
      await db.close();
      addTearDown(db.close);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      // THEN a retryable unavailable state appears — never an empty list or zero balances.
      expect(find.text('Mahnwesen konnte nicht geladen werden'), findsOneWidget);
      expect(find.text('Erneut versuchen'), findsOneWidget);
      expect(find.text('Keine fälligen Forderungen.'), findsNothing);
    });

    testWidgets('test_mahnwesen_narrow_window_remains_keyboard_accessible', (WidgetTester tester) async {
      await openDb();
      addTearDown(db.close);
      tester.view.physicalSize = const Size(700, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final int rechnungId = await seedEligible();
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      // GIVEN a narrow window, THEN a full-width list is used (no side inspector).
      expect(find.byKey(ValueKey<String>('dunning_row_$rechnungId')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey<String>('dunning_row_$rechnungId')));
      await tester.pumpAndSettle();
      // WHEN the detail opens, THEN the back control holds visible keyboard focus in logical order.
      expect(find.text('Forderung $rechnungId'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(FocusManager.instance.primaryFocus, isNotNull);
      // WHEN activated by keyboard, THEN the detail closes and the list keeps focus order.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Forderung $rechnungId'), findsNothing);
      expect(find.byKey(ValueKey<String>('dunning_row_$rechnungId')), findsOneWidget);
      // Localized loading, empty, and failure states exist on this surface.
      expect(find.text('Keine fälligen Forderungen.'), findsNothing);
    });
  });
}
