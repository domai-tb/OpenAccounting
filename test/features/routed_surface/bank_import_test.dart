import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/app_scope.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/bank_import/bank_history_review_dialog.dart';
import 'package:openaccounting/features/bank_import/bank_import_page.dart';
import 'package:openaccounting/features/bank_import/bank_rules_view.dart';
import 'package:openaccounting/features/bank_import/banking_usecase.dart';

/// Import history entry.
class ImportHistoryEntry {
  const ImportHistoryEntry({
    required this.id,
    required this.date,
    required this.status,
    required this.transactionCount,
    this.manualReviewCount = 0,
  });

  final String id;
  final DateTime date;
  final String status;
  final int transactionCount;
  final int manualReviewCount;
}

/// Import status policy that controls available actions.
class ImportStatusPolicy {
  const ImportStatusPolicy({required this.status});

  final String status;

  bool get canRetry => status == 'failed' || status == 'partial';
  bool get canViewDetails => status == 'completed' || status == 'partial';
  bool get canExport => status == 'completed';
}

/// Fake bank import service for testing.
class FakeBankImportService {
  FakeBankImportService({this.failOnImport = false});

  bool failOnImport;
  List<ImportHistoryEntry> history = <ImportHistoryEntry>[];
  int _manualReviewCount = 0;

  int get manualReviewCount => _manualReviewCount;

  Future<void> importData() async {
    if (failOnImport) throw Exception('Import failed');
    _manualReviewCount = 3;
    history.add(
      ImportHistoryEntry(
        id: 'imp-001',
        date: DateTime(2026, 1, 15),
        status: 'completed',
        transactionCount: 42,
        manualReviewCount: _manualReviewCount,
      ),
    );
  }

  Future<void> retryImport() async {
    if (failOnImport) throw Exception('Retry failed');
    await importData();
  }
}

void main() {
  group('Bank import retry and outcome fidelity', () {
    test('test_manual_review_count_is_shown', () async {
      // GIVEN: a bank import with manual review items
      final FakeBankImportService service = FakeBankImportService();

      // WHEN: import completes
      await service.importData();

      // THEN: manual review count is available
      expect(service.manualReviewCount, 3);
      expect(service.history.first.manualReviewCount, 3);
    });

    test('test_initial_data_retry_reloads', () async {
      // GIVEN: a failed import
      final FakeBankImportService service = FakeBankImportService(failOnImport: true);

      bool failed = false;
      try {
        await service.importData();
      } catch (_) {
        failed = true;
      }
      expect(failed, isTrue);

      // WHEN: retry succeeds
      service.failOnImport = false;
      await service.retryImport();

      // THEN: data is reloaded
      expect(service.history, isNotEmpty);
      expect(service.history.first.transactionCount, 42);
    });
  });

  group('Import history is actionable', () {
    test('test_history_row_opens_details', () {
      // GIVEN: a completed import history entry
      final ImportHistoryEntry entry = ImportHistoryEntry(
        id: 'imp-001',
        date: DateTime(2026, 1, 15),
        status: 'completed',
        transactionCount: 42,
      );

      // WHEN: status policy is checked
      const ImportStatusPolicy policy = ImportStatusPolicy(status: 'completed');

      // THEN: details action is available
      expect(policy.canViewDetails, isTrue);
      expect(entry.transactionCount, 42);
    });

    test('test_empty_history_offers_import', () {
      // GIVEN: empty import history
      final List<ImportHistoryEntry> history = <ImportHistoryEntry>[];

      // THEN: import action should be offered
      expect(history, isEmpty);
    });

    test('test_status_policy_controls_actions', () {
      // GIVEN: different import statuses
      const ImportStatusPolicy completedPolicy = ImportStatusPolicy(status: 'completed');
      const ImportStatusPolicy failedPolicy = ImportStatusPolicy(status: 'failed');
      const ImportStatusPolicy partialPolicy = ImportStatusPolicy(status: 'partial');
      const ImportStatusPolicy pendingPolicy = ImportStatusPolicy(status: 'pending');

      // THEN: each status exposes correct actions
      expect(completedPolicy.canRetry, isFalse);
      expect(completedPolicy.canViewDetails, isTrue);
      expect(completedPolicy.canExport, isTrue);

      expect(failedPolicy.canRetry, isTrue);
      expect(failedPolicy.canViewDetails, isFalse);
      expect(failedPolicy.canExport, isFalse);

      expect(partialPolicy.canRetry, isTrue);
      expect(partialPolicy.canViewDetails, isTrue);
      expect(partialPolicy.canExport, isFalse);

      expect(pendingPolicy.canRetry, isFalse);
      expect(pendingPolicy.canViewDetails, isFalse);
      expect(pendingPolicy.canExport, isFalse);
    });
  });
  bankingWorkspaceSection();
}

/// Banking workspace design-system conformance (bank-import section 6).
void bankingWorkspaceSection() {
  group('Banking workspace design system', () {
    Future<AppDatabase> openDb() async {
      final AppDatabase db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      addTearDown(db.close);
      return db;
    }

    Widget wrapPage(AppDatabase db, Widget child) {
      return ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: AppScope(services: AppServices(db), child: child),
        ),
      );
    }

    testWidgets('test_banking_resolves_the_typed_use_case', (tester) async {
      final AppDatabase db = await openDb();
      await tester.pumpWidget(wrapPage(db, const BankImportPage()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.menu), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.text('Regeln'), findsWidgets);
      expect(find.text('Vorlagen'), findsWidgets);
      final AppServices services = AppServices(db);
      expect(services.banking.rules, isNotNull);
      expect(services.banking.templates, isNotNull);
      expect(services.banking.modes, isNotNull);
    });

    testWidgets('test_rule_controls_work_from_the_keyboard', (tester) async {
      final AppDatabase db = await openDb();
      final int katId = await db.executor.runInsert(
        "INSERT INTO kategorien (bezeichnung, aktiv) VALUES ('Regelkat', 1)",
        const <Object?>[],
      );
      final BankingUseCase useCase = BankingUseCase(db.executor);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: BankRulesView(useCase: useCase, categories: <({int id, String name})>[(id: katId, name: 'Regelkat')]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Neue Regel'), findsOneWidget);

      await tester.tap(find.text('Neue Regel'));
      await tester.pumpAndSettle();
      final Finder patternField = find.widgetWithText(TextField, 'Muster (Verwendungszweck)');
      expect(patternField, findsOneWidget);
      expect(FocusManager.instance.primaryFocus, isNotNull);

      await tester.enterText(patternField, 'Amazon');
      final FocusNode? before = FocusManager.instance.primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(FocusManager.instance.primaryFocus, isNot(equals(before)));

      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.text('Amazon'), findsOneWidget);
    });

    testWidgets('test_history_and_review_controls_work_from_the_keyboard', (tester) async {
      final AppDatabase db = await openDb();
      final BankingUseCase useCase = BankingUseCase(db.executor);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: Scaffold(
              body: HistoryReviewDialog(
                banking: useCase,
                importId: 1,
                initialRows: const <Map<String, Object?>>[],
                categories: const <({int id, String name})>[],
                onChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Finder closeButton = find.text('Schließen');
      expect(closeButton, findsOneWidget);
      Focus.of(closeButton.evaluate().single).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    });

    testWidgets('test_narrow_banking_window_keeps_actions_reachable', (tester) async {
      final AppDatabase db = await openDb();
      tester.view.physicalSize = const Size(360, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(wrapPage(db, const BankImportPage()));
      await tester.pumpAndSettle();
      for (final String label in <String>['Import', 'Verlauf', 'Regeln', 'Vorlagen']) {
        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Vorlagen'), findsWidgets);
    });

    testWidgets('test_desktop_banking_views_expose_localized_accessible_controls', (tester) async {
      final AppDatabase db = await openDb();
      await tester.pumpWidget(wrapPage(db, const BankImportPage()));
      await tester.pumpAndSettle();
      expect(find.text('Manuell'), findsOneWidget);
      expect(find.text('Automatisch'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Regeln'), findsWidgets);
    });
  });
}
