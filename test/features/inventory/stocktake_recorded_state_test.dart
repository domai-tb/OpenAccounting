import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/feature_modules/feature_module_catalog.dart';
import 'package:openaccounting/features/feature_modules/feature_module_repository.dart';
import 'package:openaccounting/features/feature_modules/feature_module_state.dart';
import 'package:openaccounting/features/inventory/stocktake_entity.dart';
import 'package:openaccounting/features/inventory/stocktake_page.dart';
import 'package:openaccounting/features/inventory/stocktake_providers.dart';
import 'package:openaccounting/features/inventory/stocktake_repository.dart';
import 'package:openaccounting/l10n/l10n.dart';

Future<AppDatabase> _openInventoryDatabase() async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  await db.executor.runInsert('INSERT INTO unternehmen (name) VALUES (?)', <Object?>['Inventur GmbH']);
  await db.executor.runInsert('INSERT INTO kategorien (bezeichnung, aktiv) VALUES (?, 1)', <Object?>['Inventur Test']);
  await FeatureModuleRepository(db.executor)
      .save(FeatureModuleState.defaults().withEnabled(FeatureModuleCatalog.inventory, value: true));
  return db;
}

Future<int> _createArticle(AppDatabase db, {required String bezeichnung}) async {
  final artikel = await db.artikelRepository.create(
    bezeichnung: bezeichnung,
    vkBrutto: 11.9,
    lagerAktiv: true,
    bestandAktuell: 11,
  );
  return artikel.id;
}

Widget _stocktakeApp({AppDatabase? db, required List<Stocktake> history, required List<Stocktake> drafts}) {
  return ProviderScope(
    overrides: [
      stocktakeEnabledProvider.overrideWith((ref) async => true),
      stocktakeHistoryProvider.overrideWith((ref) async => history),
      stocktakeDraftsProvider.overrideWith((ref) async => drafts),
      if (db != null) appDatabaseProvider.overrideWithValue(db),
    ],
    child: const MaterialApp(
      locale: Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StocktakeWorkspacePage(),
    ),
  );
}

AppLocalizations _localizations() => lookupAppLocalizations(const Locale('de'));

void main() {
  testWidgets('test_recorded_count_is_physical_and_book_variance_valuation_are_unavailable', (
    WidgetTester tester,
  ) async {
    const Stocktake recorded = Stocktake(
      id: 1,
      stichtag: '2026-10-10',
      status: StocktakeStatus.erfasst,
      erstelltAm: '2026-10-10T13:00:00.000Z',
      positionen: <StocktakePosition>[
        StocktakePosition(
          id: 1,
          inventurId: 1,
          artikelId: 1,
          bezeichnungSnapshot: 'Werkzeug',
          einheitSnapshot: 'Stk',
          mengeGezaehlt: 7.25,
        ),
      ],
    );

    await tester.pumpWidget(_stocktakeApp(history: <Stocktake>[recorded], drafts: const <Stocktake>[]));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = _localizations();
    expect(find.text('7,25'), findsOneWidget);
    expect(find.text(l10n.stocktakePhysicalCount), findsOneWidget);
    expect(find.text(l10n.stocktakeBookUnavailable), findsOneWidget);
    expect(find.text(l10n.stocktakeVarianceUnavailable), findsOneWidget);
    expect(find.text(l10n.stocktakeValuationUnavailable), findsOneWidget);
  });

  testWidgets('test_nonnegative_four_decimal_count_shows_precision_message', (WidgetTester tester) async {
    final AppDatabase db = await _openInventoryDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
    });
    await _createArticle(db, bezeichnung: 'Werkzeug');
    final Stocktake draft = await StocktakeRepository(db.executor).createDraft(stichtag: '2026-10-10');

    await tester.pumpWidget(_stocktakeApp(db: db, history: const <Stocktake>[], drafts: <Stocktake>[draft]));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '1.2345');
    await tester.tap(find.ancestor(of: find.byIcon(Icons.save_outlined), matching: find.byType(OutlinedButton)));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = _localizations();
    expect(find.text(l10n.stocktakePrecisionInvalid), findsOneWidget);
    expect(find.text(l10n.stocktakeNegativeForbidden), findsNothing);
  });
}
