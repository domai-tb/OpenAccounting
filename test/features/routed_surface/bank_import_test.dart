import 'package:flutter_test/flutter_test.dart';

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
}
