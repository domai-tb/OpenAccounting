// ignore_for_file: prefer_single_quotes, avoid_bool_literals_in_conditional_expressions
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/dashboard/dashboard_entity.dart';
import 'package:openaccounting/features/dashboard/dashboard_page.dart';
import 'package:openaccounting/features/dashboard/dashboard_repository.dart';
import 'package:openaccounting/features/dashboard/dashboard_widgets.dart';

void main() {
  group('Dashboard widgets — 13+ render', () {
    late AppDatabase db;
    late DashboardRepository repo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = DashboardRepository(db.executor);
    });

    tearDown(() async => db.close());

    test('defaultConfig has 13 widget ids, order, visibility, quickLinks', () {
      final cfg = repo.defaultConfig();
      expect(cfg.order, hasLength(13));
      expect(cfg.order, containsAll(dashboardWidgetIds));
      expect(cfg.visibility.length, 13);
      expect(cfg.visibility.values.every((v) => v), isTrue);
      expect(cfg.quickLinks, hasLength(3));
      expect(cfg.quickLinks.map((e) => e.label), containsAll(<String>['Neue Rechnung', 'Journal', 'Artikel']));
    });

    test('widgetIds list 13 per spec', () {
      expect(repo.widgetIds, hasLength(13));
      expect(repo.widgetIds, dashboardWidgetIds);
      expect(dashboardWidgetTitles.length, 13);
      expect(dashboardWidgetIcons.length, 13);
    });

    test('all 13 titles defined', () {
      for (final id in dashboardWidgetIds) {
        expect(dashboardWidgetTitles[id], isNotNull, reason: 'missing title $id');
        expect(dashboardWidgetTitles[id]!.isNotEmpty, isTrue);
      }
    });

    test('loadConfig with null/empty returns defaults', () async {
      await db.executor.runCustom('UPDATE unternehmen SET dashboard_config = NULL WHERE id = 1');
      // seed creates unternehmen row? ensure one exists via save then null.
      // Insert unternehmen if missing.
      final rows = await db.executor.runSelect('SELECT COUNT(*) as c FROM unternehmen', const []);
      if (((rows.first['c'] as num?) ?? 0).toInt() == 0) {
        await db.executor.runInsert('INSERT INTO unternehmen (name, dashboard_config) VALUES (?, ?)', <Object?>[
          'Test',
          null,
        ]);
      } else {
        await db.executor.runUpdate('UPDATE unternehmen SET dashboard_config = NULL', const []);
      }
      final cfg = await repo.loadConfig();
      expect(cfg.order, hasLength(13));
      expect(cfg.visibility.values.every((v) => v), isTrue);
    });

    test('corrupted config falls back to defaults', () async {
      final rows = await db.executor.runSelect('SELECT id FROM unternehmen LIMIT 1', const []);
      if (rows.isEmpty) {
        await db.executor.runInsert('INSERT INTO unternehmen (name, dashboard_config) VALUES (?, ?)', <Object?>[
          'X',
          'not-json',
        ]);
      } else {
        await db.executor.runUpdate('UPDATE unternehmen SET dashboard_config = ? WHERE id = ?', <Object?>[
          '{corrupted',
          rows.first['id'],
        ]);
      }
      final cfg = await repo.loadConfig();
      expect(cfg.order, hasLength(13));
      expect(cfg.order, contains('offene_rechnungen'));
    });

    test('save and load persists order and visibility', () async {
      final cfg = DashboardConfig(
        order: List<String>.from(dashboardWidgetIds.reversed),
        visibility: <String, bool>{for (final id in dashboardWidgetIds) id: id != 'lagerwarnung'},
        quickLinks: const <QuickLink>[QuickLink(label: 'Mein Shop', route: '/shop')],
      );
      await repo.saveConfig(cfg);
      final loaded = await repo.loadConfig();
      expect(loaded.order.first, dashboardWidgetIds.last);
      expect(loaded.visibility['lagerwarnung'], isFalse);
      expect(loaded.visibility['offene_rechnungen'], isTrue);
      expect(loaded.quickLinks.first.label, 'Mein Shop');
      expect(loaded.quickLinks.first.route, '/shop');
    });

    test('hidden widget does not fetch — visibility false', () async {
      final cfg = repo.defaultConfig().copyWith(
        visibility: <String, bool>{for (final id in dashboardWidgetIds) id: id != 'lagerwarnung'},
      );
      await repo.saveConfig(cfg);
      final visible = await repo.visibleOrder();
      expect(visible, isNot(contains('lagerwarnung')));
      expect(visible, hasLength(12));
      // provider returns null for hidden
      final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      // need to invalidate config cache
      final data = await container.read(dashboardWidgetDataProvider('lagerwarnung').future);
      expect(data, isNull, reason: 'hidden should not fetch');
    });

    test('Offene Rechnungen shows count+sum', () async {
      final kundeId = await db.executor.runInsert(
        'INSERT INTO kunden (name, strasse, plz, ort, land, anrede) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['Kunde A', 'Str 1', '10115', 'Berlin', 'DE', 'Herr'],
      );
      await db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, faelligkeit, brutto_betrag, netto_betrag) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['RE-001', 'rechnung', 'offen', 0, 'netto', kundeId, '2026-01-01', '2026-02-01', '100.00', '84.03'],
      );
      await db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, faelligkeit, brutto_betrag, netto_betrag) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['RE-002', 'rechnung', 'offen', 0, 'netto', kundeId, '2026-01-02', '2026-02-02', '200.50', '168.48'],
      );
      // bezahlt should not count
      await db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, faelligkeit, brutto_betrag, netto_betrag) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['RE-003', 'rechnung', 'bezahlt', 0, 'netto', kundeId, '2026-01-03', '2026-02-03', '999.00', '839.49'],
      );
      final m = await repo.fetchOffeneRechnungen();
      expect(m['count'], 2);
      expect(m['sum'], '300.50');
    });

    test('Lagerwarnung fetch returns low-stock, empty shows Keine Warnungen via card', () async {
      // no low stock initially
      var low = await repo.fetchLagerwarnung();
      expect(low, isEmpty);
      // insert artikel low stock
      await db.executor.runInsert(
        'INSERT INTO artikel (bezeichnung, vk_netto, bestand, bestand_aktuell, mindestbestand, aktiv) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['WarnArtikel', '10.00', 2, 2, 5, 1],
      );
      low = await repo.fetchLagerwarnung();
      expect(low, hasLength(1));
      expect(low.first['bezeichnung'], 'WarnArtikel');
      // insert normal stock should not appear
      await db.executor.runInsert(
        'INSERT INTO artikel (bezeichnung, vk_netto, bestand, bestand_aktuell, mindestbestand, aktiv) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['OkArtikel', '20.00', 10, 10, 5, 1],
      );
      low = await repo.fetchLagerwarnung();
      expect(low, hasLength(1));
    });

    test('Lagerwarnung follows current inventory quantity', () async {
      await db.executor.runInsert(
        'INSERT INTO artikel (bezeichnung, vk_netto, bestand, bestand_aktuell, mindestbestand, aktiv) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['CurrentStock', '10.00', 10, 2, 5, 1],
      );

      final low = await repo.fetchLagerwarnung();

      expect(low.map((row) => row['bezeichnung']), contains('CurrentStock'));
    });

    test('Zahlungseingänge excludes outgoing bank transactions', () async {
      final kontoId = await db.executor.runInsert('INSERT INTO konten (name, saldo) VALUES (?, ?)', <Object?>[
        'Geschäftskonto',
        '0.00',
      ]);
      await db.executor.runInsert(
        'INSERT INTO bank_transaktionen (konto_id, datum, betrag, verwendungszweck) VALUES (?, ?, ?, ?)',
        <Object?>[kontoId, '2026-01-02', '125.00', 'Kundenzahlung'],
      );
      await db.executor.runInsert(
        'INSERT INTO bank_transaktionen (konto_id, datum, betrag, verwendungszweck) VALUES (?, ?, ?, ?)',
        <Object?>[kontoId, '2026-01-01', '-25.00', 'Software'],
      );

      final payments = await repo.fetchZahlungseingaenge();

      expect(payments, hasLength(1));
      expect(payments.single['verwendungszweck'], 'Kundenzahlung');
    });

    test('13 widget fetch each returns valid WidgetData', () async {
      // Seed minimal data for each widget type
      await db.executor.runCustom("INSERT INTO konten (name, saldo) VALUES ('Geschäftskonto', 1234.56)");
      await db.executor.runCustom(
        "INSERT INTO bank_transaktionen (konto_id, datum, betrag, verwendungszweck) VALUES (1, '2026-01-10', 100.00, 'Test')",
      );
      await db.executor.runCustom(
        "INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ) VALUES ('2026-01-01', 'Test', 1, 500.00, 'Einnahme')",
      );
      await db.executor.runCustom(
        "INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ) VALUES ('2026-01-02', 'Ausgabe', 1, -200.00, 'Ausgabe')",
      );
      final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      for (final id in dashboardWidgetIds) {
        final data = await container.read(dashboardWidgetDataProvider(id).future);
        expect(data, isNotNull, reason: 'widget $id should fetch');
        expect(data!.title, isNotEmpty, reason: 'title $id');
        expect(data.icon, isNotNull, reason: 'icon $id');
        expect(data.route, isNotNull, reason: 'route $id');
      }
    });

    test('Quick-Links default 3 and custom link persists', () async {
      final cfg = await repo.loadConfig();
      expect(cfg.quickLinks, hasLength(3));
      final custom = cfg.copyWith(
        quickLinks: <QuickLink>[
          ...cfg.quickLinks,
          const QuickLink(label: 'Mein Shop', route: '/shop'),
        ],
      );
      await repo.saveConfig(custom);
      final loaded = await repo.loadConfig();
      expect(loaded.quickLinks, hasLength(4));
      expect(loaded.quickLinks.last.route, '/shop');
    });
  });

  group('DashboardCard widget', () {
    test('widget provider exposes data-source failures to error rendering', () async {
      final db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      await db.close();
      final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);

      await expectLater(
        container.read(dashboardWidgetDataProvider('offene_rechnungen').future),
        throwsA(isA<StateError>()),
      );
    });

    testWidgets('dashboard renders every visible widget card from providers', (tester) async {
      final db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      addTearDown(db.close);
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: DashboardPageImpl()),
        ),
      );
      await tester.pumpAndSettle();

      for (final id in dashboardWidgetIds) {
        expect(find.text(dashboardWidgetTitles[id]!), findsOneWidget, reason: 'widget $id should render');
      }
    });

    testWidgets('renders title, icon, content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCard(
              title: 'Offene Rechnungen',
              icon: Icons.receipt_long,
              content: Text('2 Rechnungen • 300.50 €'),
            ),
          ),
        ),
      );
      expect(find.text('Offene Rechnungen'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long), findsOneWidget);
      expect(find.text('2 Rechnungen • 300.50 €'), findsOneWidget);
    });

    testWidgets('loading shows skeleton CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DashboardCard(title: 'Lager', isLoading: true)),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('error shows error text, not content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCard(title: 'Fristen', error: 'DB down', content: Text('should not show')),
          ),
        ),
      );
      expect(find.text('DB down'), findsOneWidget);
      expect(find.text('should not show'), findsNothing);
    });

    testWidgets('empty shows Keine Warnungen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardCard(title: 'Lagerwarnung', emptyMessage: 'Keine Warnungen'),
          ),
        ),
      );
      expect(find.text('Keine Warnungen'), findsOneWidget);
    });

    testWidgets('onTap triggers callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCard(title: 'Offene Rechnungen', content: const Text('1'), onTap: () => tapped = true),
          ),
        ),
      );
      await tester.tap(find.byType(DashboardCard));
      expect(tapped, isTrue);
    });

    testWidgets('hidden does not fetch — provider returns null, no card', (tester) async {
      final db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      final repo = DashboardRepository(db.executor);
      final cfg = repo.defaultConfig().copyWith(
        visibility: <String, bool>{for (final id in dashboardWidgetIds) id: false},
      );
      await repo.saveConfig(cfg);
      final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final data = await container.read(dashboardWidgetDataProvider('offene_rechnungen').future);
      expect(data, isNull);
    });
  });

  group('DashboardRepository additional queries', () {
    late AppDatabase db;
    late DashboardRepository repo;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = DashboardRepository(db.executor);
    });

    tearDown(() async => db.close());

    test('ueberfaellige, einnahmenAusgaben, kontostand, aktivitaetsLog, fristen, mahnung, ustvaFrist', () async {
      final kundeId = await db.executor.runInsert(
        'INSERT INTO kunden (name, strasse, plz, ort, land, anrede) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['K', 'S', '10115', 'B', 'DE', 'Herr'],
      );
      // overdue
      await db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, faelligkeit, brutto_betrag, netto_betrag) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['RE-O', 'rechnung', 'offen', 0, 'netto', kundeId, '2025-01-01', '2025-01-10', '150.00', '126.05'],
      );
      final ue = await repo.fetchUeberfaelligeRechnungen();
      expect(((ue['count'] as int?) ?? 0) >= 1, isTrue);

      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ) VALUES (?, ?, ?, ?, ?)',
        <Object?>['2026-02-01', 'Einnahme', 1, '1000.00', 'Einnahme'],
      );
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ) VALUES (?, ?, ?, ?, ?)',
        <Object?>['2026-02-02', 'Ausgabe', 1, '-400.00', 'Ausgabe'],
      );
      final ea = await repo.fetchEinnahmenAusgaben();
      expect(ea['einnahmen'], isNotNull);
      expect(ea['ausgaben'], isNotNull);

      await db.executor.runInsert('INSERT INTO konten (name, saldo) VALUES (?, ?)', <Object?>['Kasse', '500.00']);
      final ks = await repo.fetchKontostand();
      expect(ks['sum'], isNotNull);

      final log = await repo.fetchAktivitaetsLog();
      expect(log.length, greaterThanOrEqualTo(2));

      final fr = await repo.fetchFristen();
      expect(fr, isA<List<Map<String, Object?>>>());

      final mw = await repo.fetchMahnungWarnung();
      expect(mw, isA<List<Map<String, Object?>>>());

      final uf = await repo.fetchUstvaFrist();
      expect(uf['frist'], isNotNull);
      expect((uf['frist'] as String? ?? '').length, 10);
    });
  });
}
