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

RechnungenUseCases _useCases(AppDatabase db) =>
    RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: db.profileDir)));

void main() {
  test('test_detail_shows_reciprocal_lifecycle_relationships', () async {
    final Directory profile = await Directory.systemTemp.createTemp('invoice-relationships-');
    final db = AppDatabase.createTestDatabase(profileDir: profile.path);
    addTearDown(() async {
      await db.close();
      if (profile.existsSync()) await profile.delete(recursive: true);
    });
    await db.ensureOpen();
    await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
    );
    await db.executor.runCustom(
      "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1 WHERE typ = 'gutschrift'",
    );
    final useCases = _useCases(db);

    final RechnungItem draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100, position: 0),
      ],
    );
    final RechnungItem finalized = await useCases.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
    final RechnungItem credit = await useCases.createGutschrift(vonRechnungId: finalized.id);

    // Each typed detail model contains the reciprocal source/target ref.
    final RechnungItem? invoiceDetail = await useCases.findById(finalized.id);
    final RechnungItem? creditDetail = await useCases.findById(credit.id);
    expect(
      invoiceDetail!.beziehungen.any((b) => b.kind == 'gutschrift Ziel' && b.documentId == credit.id && b.available),
      isTrue,
    );
    expect(creditDetail!.beziehungen.any((b) => b.documentId == finalized.id && b.available), isTrue);
  });

  test('test_missing_relationship_target_is_unavailable', () async {
    final db = AppDatabase.createTestDatabase();
    addTearDown(db.close);
    await db.ensureOpen();
    final useCases = _useCases(db);

    final RechnungItem draft = await useCases.createDraftRechnung(
      datum: '2026-08-30',
      positionen: const <RechnungPositionItem>[
        RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100, position: 0),
      ],
    );

    // Seed a legacy orphan explicitly; normal writes enforce this self-reference foreign key.
    await db.executor.runCustom('PRAGMA foreign_keys = OFF');
    try {
      await db.executor.runUpdate('UPDATE rechnungen SET ersatz_fuer = ? WHERE id = ?', <Object?>[999999, draft.id]);
    } finally {
      await db.executor.runCustom('PRAGMA foreign_keys = ON');
    }
    final RechnungItem? detail = await useCases.findById(draft.id);
    final List<RechnungBeziehung> links = detail!.beziehungen.where((b) => b.documentId == 999999).toList();
    expect(links, hasLength(1));
    expect(links.single.available, isFalse);
    // No unrelated document is displayed as the target.
    expect(detail.beziehungen.where((b) => b.available && b.documentId == 999999), isEmpty);
  });

  testWidgets('test_available_relationship_link_navigates_to_document', (WidgetTester tester) async {
    late Directory profile;
    late AppDatabase db;
    late RechnungItem source;
    late RechnungItem target;
    late RechnungBeziehung relationship;
    const List<RechnungPositionItem> positions = <RechnungPositionItem>[
      RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100, position: 0),
    ];

    await tester.runAsync(() async {
      profile = await Directory.systemTemp.createTemp('invoice-relationship-navigation-');
      db = AppDatabase.createTestDatabase(profileDir: profile.path);
      await db.ensureOpen();
      await db.executor.runInsert(
        'INSERT INTO unternehmen (name) SELECT ? WHERE NOT EXISTS (SELECT 1 FROM unternehmen)',
        <Object?>['Relationship navigation test company'],
      );
      await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
      final RechnungenUseCases useCases = _useCases(db);
      source = await useCases.createDraftRechnung(datum: '2026-08-30', positionen: positions);
      target = await useCases.createDokument(typ: 'auftrag', datum: '2026-08-30', positionen: positions);
      await db.executor.runUpdate('UPDATE rechnungen SET konvertiert_zu = ? WHERE id = ?', <Object?>[
        target.id,
        source.id,
      ]);
      final RechnungItem? sourceDetail = await useCases.findById(source.id);
      relationship = sourceDetail!.beziehungen.singleWhere((RechnungBeziehung link) => link.documentId == target.id);
    });
    addTearDown(() async {
      await db.close();
      if (profile.existsSync()) await profile.delete(recursive: true);
    });
    expect(relationship.kind, 'konvertierung Ziel');
    expect(relationship.available, isTrue);

    final GoRouter router = createRouter(db);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go('/invoices/${source.id}');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/invoices/${source.id}');
    expect(find.text('Entwurf #${source.id}'), findsOneWidget);

    // Match the production key from the actual projected link rather than copying its kind by hand.
    final ValueKey<String> linkKey = ValueKey<String>('relationship_${relationship.kind}_${relationship.documentId}');
    final Finder relationshipLink = find.byKey(linkKey);
    expect(relationshipLink, findsOneWidget);
    await tester.ensureVisible(relationshipLink);
    await tester.tap(relationshipLink);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/invoices/${target.id}');
    expect(find.text('Entwurf #${target.id}'), findsWidgets);
  });
}
