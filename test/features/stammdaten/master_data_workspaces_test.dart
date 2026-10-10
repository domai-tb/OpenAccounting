import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/router/master_data_routes.dart';
import 'package:openaccounting/pages/stammdaten/artikel_repository.dart';
import 'package:openaccounting/pages/stammdaten/kategorien_repository.dart';
import 'package:openaccounting/pages/stammdaten/kunden_repository.dart';
import 'package:openaccounting/pages/stammdaten/lieferanten_repository.dart';
import 'package:openaccounting/pages/stammdaten/master_data_workspaces.dart';
import 'package:openaccounting/pages/stammdaten/unternehmen_repository.dart';

/// Master-data workspace behavior (stammdaten delta, groups 2 and 3).
void main() {
  group('Customer and supplier workspaces', () {
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_workspace_test_');
    });

    tearDown(() async {
      await profileDirectory.delete(recursive: true);
    });

    Future<AppDatabase> openDatabase() async {
      final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      return db;
    }

    Future<Lieferant> createSupplier(LieferantenRepository repository, String name) {
      return repository.create(name: name, strasse: 'Lagerweg 1', plz: '50667', ort: 'Köln');
    }

    test('test_search_paginate_inspect_and_edit_a_supplier', () async {
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      final SupplierWorkspaceUseCase workspace = SupplierWorkspaceUseCase(LieferantenRepository(db.executor));
      for (int index = 0; index < 30; index++) {
        await createSupplier(LieferantenRepository(db.executor), 'Lieferant $index');
      }
      final Lieferant target = await createSupplier(LieferantenRepository(db.executor), 'Bürobedarf AG');

      final SupplierPage first = await workspace.query(limit: 10);
      expect(first.items, hasLength(10));
      expect(first.totalCount, 31);
      expect(first.hasMore, isTrue);
      final SupplierPage second = await workspace.query(page: 2, limit: 10);
      expect(second.items, hasLength(10));

      final SupplierPage found = await workspace.query(search: target.kreditorNr, limit: 10);
      expect(found.items.map((Lieferant supplier) => supplier.id), contains(target.id));

      final ContactDetailUseCase detail = ContactDetailUseCase(
        kunden: KundenRepository(db.executor),
        lieferanten: LieferantenRepository(db.executor),
      );
      final Lieferant? inspected = await detail.supplierById(target.id);
      expect(inspected, isNotNull);
      expect(inspected!.kreditorNr, target.kreditorNr);

      final Lieferant updated = await workspace.update(target.id, <String, dynamic>{'strasse': 'Neue Strasse 9'});
      expect(updated.strasse, 'Neue Strasse 9');
      final Lieferant? reread = await detail.supplierById(target.id);
      expect(reread!.strasse, 'Neue Strasse 9');
    });

    test('test_archive_a_referenced_customer', () async {
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      final KundenRepository kunden = KundenRepository(db.executor);
      final CustomerWorkspaceUseCase workspace = CustomerWorkspaceUseCase(kunden);
      final Kunde customer = await kunden.create(
        name: 'Müller GmbH',
        strasse: 'Alte Strasse 4',
        plz: '80331',
        ort: 'München',
      );
      await db.executor.runInsert(
        'INSERT INTO rechnungen (typ, status, ist_entwurf, eingabemodus, kunde_id, datum) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['rechnung', 'final', 0, 'netto', customer.id, '2026-03-01'],
      );

      final Kunde archived = await workspace.archive(customer.id);
      expect(archived.id, customer.id);
      expect(archived.archivedAt, isNotNull);

      final CustomerPage archivedView = await workspace.query(archivedOnly: true);
      expect(archivedView.items.map((Kunde row) => row.id), contains(customer.id));

      final Kunde? historical = await kunden.findById(customer.id);
      expect(historical, isNotNull);
      expect(historical!.id, customer.id);
      final List<Map<String, Object?>> invoices = await db.executor.runSelect(
        'SELECT kunde_id FROM rechnungen WHERE kunde_id = ?',
        <Object?>[customer.id],
      );
      expect(invoices, hasLength(1));

      final List<Kunde> picker = await workspace.listForPicker();
      expect(picker.map((Kunde row) => row.id), isNot(contains(customer.id)));
    });

    test('test_bulk_archive_selected_suppliers', () async {
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      final LieferantenRepository repository = LieferantenRepository(db.executor);
      final SupplierWorkspaceUseCase workspace = SupplierWorkspaceUseCase(repository);
      final Lieferant first = await createSupplier(repository, 'Lieferant A');
      final Lieferant second = await createSupplier(repository, 'Lieferant B');

      await workspace.bulkArchive(<int>[first.id, second.id]);

      final SupplierPage archived = await workspace.query(archivedOnly: true);
      expect(archived.items.map((Lieferant row) => row.id), containsAll(<int>[first.id, second.id]));
      expect((await repository.findById(first.id))!.archivedAt, isNotNull);
      expect((await repository.findById(second.id))!.archivedAt, isNotNull);
    });

    test('test_restore_an_archived_customer', () async {
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      final KundenRepository kunden = KundenRepository(db.executor);
      final CustomerWorkspaceUseCase workspace = CustomerWorkspaceUseCase(kunden);
      final Kunde customer = await kunden.create(
        name: 'Müller GmbH',
        strasse: 'Alte Strasse 4',
        plz: '80331',
        ort: 'München',
      );
      await workspace.archive(customer.id);

      final Kunde restored = await workspace.restore(customer.id);
      expect(restored.archivedAt, isNull);

      final List<Kunde> picker = await workspace.listForPicker();
      expect(picker.map((Kunde row) => row.id), contains(customer.id));
    });

    test('test_existing_number_and_vat_form_behavior_is_preserved', () async {
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      final ContactFormUseCase form = ContactFormUseCase(
        kunden: KundenRepository(db.executor),
        lieferanten: LieferantenRepository(db.executor),
      );

      final Kunde customer = await form.createCustomer(
        name: 'Müller GmbH',
        strasse: 'Alte Strasse 4',
        plz: '80331',
        ort: 'München',
        ustIdNr: 'DE123456789',
      );
      expect(customer.kundennummer, customer.debitorNr);
      expect(customer.kundennummer.isNotEmpty, isTrue);

      final Lieferant supplier = await form.createSupplier(
        name: 'Bürobedarf AG',
        strasse: 'Lagerweg 7',
        plz: '50667',
        ort: 'Köln',
        ustIdNr: 'DE987654321',
      );
      expect(supplier.lieferantennummer, supplier.kreditorNr);

      // No external verification evidence is persisted: only local format columns exist.
      for (final String table in <String>['kunden', 'lieferanten']) {
        final List<Map<String, Object?>> columns = await db.executor.runSelect(
          'PRAGMA table_info($table)',
          const <Object?>[],
        );
        final Set<String> names = <String>{
          for (final Map<String, Object?> column in columns) column['name'].toString(),
        };
        expect(names, isNot(contains('ust_verified_at')));
        expect(names, isNot(contains('bzst_status')));
      }
    });

    test('test_search_or_save_fails', () async {
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      final CustomerWorkspaceUseCase workspace = CustomerWorkspaceUseCase(KundenRepository(db.executor));

      final CustomerPage preserved = await workspace.query(search: 'Müller', page: 2, limit: 10);
      expect(preserved.effectiveSearch, 'Müller');
      expect(preserved.page, 2);

      await expectLater(
        workspace.update(999999, <String, dynamic>{'strasse': 'Nirgendwo 1'}),
        throwsA(isA<KundenException>()),
      );

      final _FailingExecutor failing = _FailingExecutor();
      final CustomerWorkspaceUseCase broken = CustomerWorkspaceUseCase(KundenRepository(failing));
      await expectLater(broken.query(search: 'Müller', limit: 10), throwsStateError);
    });
  });

  group('Production master-data entry points', () {
    late Directory profileDirectory;

    setUp(() async {
      profileDirectory = await Directory.systemTemp.createTemp('openaccounting_entrypoints_test_');
    });

    tearDown(() async {
      await profileDirectory.delete(recursive: true);
    });

    Future<AppDatabase> openDatabase() async {
      final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDirectory.path);
      await db.ensureOpen();
      return db;
    }

    test('test_open_a_documented_master_data_workspace', () async {
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);

      final CompanySettingsUseCase company = CompanySettingsUseCase(UnternehmenRepository(db.executor));
      final Unternehmen before = await company.load();
      expect(before.id, 1);
      final Unternehmen updated = await company.update(<String, dynamic>{'name': 'Stammdaten GmbH'});
      expect(updated.name, 'Stammdaten GmbH');

      final CategoryWorkspaceUseCase categories = CategoryWorkspaceUseCase(KategorienRepository(db.executor));
      final Kategorie category = await categories.create(bezeichnung: 'Büromaterial');
      expect(category.id, greaterThan(0));
      expect(await categories.list(), isNotEmpty);

      final BankAccountWorkspaceUseCase accounts = BankAccountWorkspaceUseCase(BankAccountRepository(db.executor));
      final BankAccount account = await accounts.create(name: 'Geschäftskonto', iban: 'DE02120300000000202051');
      expect(account.id, greaterThan(0));
      expect(await accounts.list(), isNotEmpty);

      final TaxRateWorkspaceUseCase taxRates = TaxRateWorkspaceUseCase(TaxRateRepository(db.executor));
      expect(await taxRates.list(), isNotEmpty);

      final NumberRangeWorkspaceUseCase ranges = NumberRangeWorkspaceUseCase(NumberRangeRepository(db.executor));
      final List<NumberRange> stored = await ranges.list();
      expect(stored.map((NumberRange range) => range.typ), contains('debitor'));
      final NumberRange debitor = await ranges.update('debitor', 42);
      expect(debitor.nextNumber, 42);
    });

    test('test_article_group_actions_use_the_group_service', () async {
      final AppDatabase db = await openDatabase();
      addTearDown(db.close);
      final ArticleGroupWorkspaceUseCase groups = ArticleGroupWorkspaceUseCase(ArtikelRepository(db.executor));
      final ArticleWorkspaceUseCase articles = ArticleWorkspaceUseCase(ArtikelRepository(db.executor));

      final ArtikelGruppe group = await groups.create(name: 'Büro');
      expect(group.name, 'Büro');
      final ArtikelGruppe? reread = await groups.findById(group.id);
      expect(reread, isNotNull);
      expect(reread!.name, 'Büro');
      final ArtikelGruppe renamed = await groups.update(group.id, name: 'Büro & Papier');
      expect(renamed.name, 'Büro & Papier');

      // Group IDs never resolve through the article lookup, even when they collide numerically.
      final Artikel? collision = await articles.findById(group.id);
      expect(collision == null || collision.gruppeId != group.id || collision.id != group.id, isTrue);
      final List<ArtikelGruppe> listed = await groups.list();
      expect(listed.map((ArtikelGruppe row) => row.id), contains(group.id));
    });

    test('test_workspace_has_no_supported_production_data_source', () async {
      final CategoryWorkspaceUseCase broken = CategoryWorkspaceUseCase(KategorienRepository(_FailingExecutor()));
      await expectLater(broken.list(), throwsStateError);

      const MasterDataRouteMatrix matrix = MasterDataRouteMatrix();
      expect(matrix.truthfulBoundary('/settings/categories'), 'ok');
      expect(matrix.truthfulBoundary('/unmapped-nowhere'), 'unavailable');
      expect(matrix.fallbackSqlFor('/settings/categories'), isNull);
    });
  });
}

final class _FailingExecutor extends QueryExecutor {
  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async => true;

  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) {
    throw StateError('Datenbank nicht verfügbar');
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    throw StateError('Datenbank nicht verfügbar');
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    throw StateError('Datenbank nicht verfügbar');
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) {
    throw StateError('Datenbank nicht verfügbar');
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    throw StateError('Datenbank nicht verfügbar');
  }

  @override
  Future<void> runBatched(BatchedStatements statements) {
    throw StateError('Datenbank nicht verfügbar');
  }

  @override
  TransactionExecutor beginTransaction() => throw StateError('Datenbank nicht verfügbar');

  @override
  QueryExecutor beginExclusive() => throw StateError('Datenbank nicht verfügbar');

  @override
  Future<void> close() async {}
}
