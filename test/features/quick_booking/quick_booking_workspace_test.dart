import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/quick_booking/quick_booking_execution.dart';
import 'package:openaccounting/features/quick_booking/quick_booking_repository.dart';
import 'package:openaccounting/features/quick_booking/quick_bookings_view.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Preset lifecycle: explicit semantics, no inference, gate decisions.
class _MustNotSubmitPort implements QuickBookingPostingPort {
  const _MustNotSubmitPort();

  @override
  bool get isAvailable => true;

  @override
  Future<String> submit({
    required QuickBookingPreset preset,
    required String businessDate,
    required String betrag,
  }) async => throw StateError('A stale preset must not be submitted');
}

Finder _iconButtonWithTooltip(String tooltip) =>
    find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton));

Widget _quickBookingsApp({
  required QuickBookingRepository repository,
  required QuickBookingPostingPort executorPort,
  List<({int id, String name})> konten = const <({int id, String name})>[],
  List<({int id, String name})> categories = const <({int id, String name})>[],
  List<({int id, String label})> taxRates = const <({int id, String label})>[],
}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: QuickBookingsView(
    repository: repository,
    executorPort: executorPort,
    konten: konten,
    categories: categories,
    taxRates: taxRates,
  ),
);

void main() {
  group('Quick-booking presets', () {
    late AppDatabase db;
    late QuickBookingRepository repo;
    late int kontoId;
    late int kategorieId;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      repo = QuickBookingRepository(db.executor);
      kontoId = await db.executor.runInsert('INSERT INTO konten (name, iban) VALUES (?, ?)', const <Object?>[
        'Giro',
        'DE001',
      ]);
      kategorieId = await db.executor.runInsert(
        "INSERT INTO kategorien (bezeichnung, aktiv) VALUES ('Schnellkat', 1)",
        const <Object?>[],
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('test_create_a_complete_preset', () async {
      final preset = await repo.create(
        name: 'Miete',
        direction: QuickBookingDirection.ausgabe,
        kontoId: kontoId,
        kategorieId: kategorieId,
        ustSatzId: 2,
        modus: QuickBookingModus.brutto,
        betrag: '850.00',
        beschreibung: 'Monatsmiete',
      );
      expect(preset.needsReview, isFalse);
      expect(preset.direction, QuickBookingDirection.ausgabe);
      final stored = await repo.findById(preset.id);
      expect(num.parse(stored?.betrag ?? '0'), 850);
      expect(stored?.ustSatzId, 2);
    });

    test('test_legacy_preset_requires_review', () async {
      final legacy = await repo.create(name: 'Alt');
      expect(legacy.needsReview, isTrue);
      final stored = await repo.findById(legacy.id);
      expect(stored?.direction, isNull);
      expect(stored?.ustSatzId, isNull);
      expect(stored?.modus, isNull);
    });

    test('test_referenced_configuration_is_no_longer_active', () async {
      await expectLater(repo.create(name: 'Falsch', kategorieId: 99999), throwsA(isA<QuickBookingException>()));
      final preset = await repo.create(name: 'Ok', kategorieId: kategorieId);
      await db.executor.runUpdate('UPDATE kategorien SET aktiv = 0 WHERE id = ?', <Object?>[kategorieId]);
      final execution = await executePreset(
        executor: db.executor,
        repository: repo,
        port: const UnavailableQuickBookingPosting(),
        presetId: preset.id,
        businessDate: '2026-05-10',
        betrag: '10.00',
      );
      expect(execution.executed, isFalse);
      expect(execution.unavailableReason, contains('Kategorie'));
    });

    test('test_invalid_references_are_rejected_on_save', () async {
      await expectLater(repo.create(name: 'No account', kontoId: 99999), throwsA(isA<QuickBookingException>()));
      await expectLater(repo.create(name: 'No tax rate', ustSatzId: 99999), throwsA(isA<QuickBookingException>()));

      final preset = await repo.create(name: 'Valid', kontoId: kontoId, kategorieId: kategorieId, ustSatzId: 2);
      await expectLater(repo.update(preset.id, kontoId: 99999), throwsA(isA<QuickBookingException>()));
      await expectLater(repo.update(preset.id, ustSatzId: 99999), throwsA(isA<QuickBookingException>()));

      await db.executor.runUpdate('UPDATE kategorien SET aktiv = 0 WHERE id = ?', <Object?>[kategorieId]);
      await expectLater(
        repo.create(name: 'Inactive category', kategorieId: kategorieId),
        throwsA(isA<QuickBookingException>()),
      );
      await expectLater(repo.update(preset.id, name: 'Still inactive'), throwsA(isA<QuickBookingException>()));
    });

    test('test_stale_references_require_review_and_cannot_execute', () async {
      final preset = await repo.create(
        name: 'Miete',
        direction: QuickBookingDirection.ausgabe,
        kontoId: kontoId,
        kategorieId: kategorieId,
        ustSatzId: 2,
        modus: QuickBookingModus.brutto,
        betrag: '850.00',
      );
      await db.executor.runCustom('PRAGMA foreign_keys = OFF');
      try {
        await db.executor.runUpdate(
          'UPDATE schnellbuchungen SET konto_id = ?, kategorie_id = ?, ust_satz_id = ? WHERE id = ?',
          <Object?>[99991, 99992, 99993, preset.id],
        );
      } finally {
        await db.executor.runCustom('PRAGMA foreign_keys = ON');
      }

      expect((await repo.findById(preset.id))?.needsReview, isTrue);
      final execution = await executePreset(
        executor: db.executor,
        repository: repo,
        port: const _MustNotSubmitPort(),
        presetId: preset.id,
        businessDate: '2026-05-10',
      );
      expect(execution.executed, isFalse);
      expect(execution.unavailableReason, contains('Konto'));
      expect(execution.unavailableReason, contains('Kategorie'));
      expect(execution.unavailableReason, contains('Steuersatz'));
    });

    test('test_incomplete_legacy_preset_remains_editable_without_inference', () async {
      final legacy = await repo.create(name: 'Legacy');
      final updated = await repo.update(legacy.id, name: 'Reviewed name');

      expect(updated.name, 'Reviewed name');
      expect(updated.direction, isNull);
      expect(updated.kontoId, isNull);
      expect(updated.kategorieId, isNull);
      expect(updated.ustSatzId, isNull);
      expect(updated.modus, isNull);
      expect(updated.needsReview, isTrue);
    });

    testWidgets('test_workspace_propagates_execution_unavailable_status', (WidgetTester tester) async {
      await repo.create(
        name: 'Miete',
        direction: QuickBookingDirection.ausgabe,
        kontoId: kontoId,
        kategorieId: kategorieId,
        ustSatzId: 2,
        modus: QuickBookingModus.brutto,
        betrag: '850.00',
      );
      await tester.pumpWidget(
        _quickBookingsApp(
          repository: repo,
          executorPort: const UnavailableQuickBookingPosting(),
          konten: <({int id, String name})>[(id: kontoId, name: 'Giro')],
          categories: <({int id, String name})>[(id: kategorieId, name: 'Schnellkat')],
          taxRates: const <({int id, String label})>[(id: 2, label: '19 %')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Execution unavailable'), findsOneWidget);
      expect(tester.widget<IconButton>(_iconButtonWithTooltip('Execute')).onPressed, isNull);
    });

    testWidgets('test_stale_references_remain_visible_for_review', (WidgetTester tester) async {
      await repo.create(
        name: 'Miete',
        direction: QuickBookingDirection.ausgabe,
        kontoId: kontoId,
        kategorieId: kategorieId,
        ustSatzId: 2,
        modus: QuickBookingModus.brutto,
        betrag: '850.00',
      );
      await tester.pumpWidget(_quickBookingsApp(repository: repo, executorPort: const _MustNotSubmitPort()));
      await tester.pumpAndSettle();
      expect(find.text('Review required'), findsAtLeastNWidgets(1));
      expect(tester.widget<IconButton>(_iconButtonWithTooltip('Execute')).onPressed, isNull);

      await tester.tap(find.byTooltip('Edit quick booking'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Review required ('), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('test_editing_a_preset_can_clear_optional_fields', (WidgetTester tester) async {
      final preset = await repo.create(
        name: 'Miete',
        direction: QuickBookingDirection.ausgabe,
        kontoId: kontoId,
        kategorieId: kategorieId,
        ustSatzId: 2,
        modus: QuickBookingModus.brutto,
        betrag: '850.00',
        beschreibung: 'Monatsmiete',
      );
      await tester.pumpWidget(
        _quickBookingsApp(
          repository: repo,
          executorPort: const UnavailableQuickBookingPosting(),
          konten: <({int id, String name})>[(id: kontoId, name: 'Giro')],
          categories: <({int id, String name})>[(id: kategorieId, name: 'Schnellkat')],
          taxRates: const <({int id, String label})>[(id: 2, label: '19 %')],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit quick booking'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '');
      await tester.enterText(find.byType(TextField).at(2), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final updated = await repo.findById(preset.id);
      expect(updated?.betrag, isNull);
      expect(updated?.beschreibung, isEmpty);
    });
  });
}
