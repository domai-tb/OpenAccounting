import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/quick_booking/quick_booking_execution.dart';
import 'package:openaccounting/features/quick_booking/quick_booking_repository.dart';
import 'package:openaccounting/features/quick_booking/quick_bookings_view.dart';
import 'package:openaccounting/l10n/l10n.dart';

const QuickBookingPreset _preset = QuickBookingPreset(
  id: 1,
  name: 'Miete',
  beschreibung: null,
  direction: QuickBookingDirection.ausgabe,
  kontoId: 1,
  kategorieId: 1,
  ustSatzId: 1,
  modus: QuickBookingModus.brutto,
  betrag: '100.00',
);

class _PresetRepository extends QuickBookingRepository {
  _PresetRepository(super.executor, this.presets);

  final List<QuickBookingPreset> presets;

  @override
  Future<List<QuickBookingPreset>> list() async => presets;
}

class _FailingRepository extends QuickBookingRepository {
  _FailingRepository(super.executor);

  @override
  Future<List<QuickBookingPreset>> list() async {
    throw StateError('Datenbank nicht verfügbar');
  }
}

Widget _localizedApp(QuickBookingsView view) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: view,
  );
}

QuickBookingsView _view({
  required QuickBookingRepository repository,
  QuickBookingPostingPort executorPort = const UnavailableQuickBookingPosting(),
}) {
  return QuickBookingsView(
    repository: repository,
    executorPort: executorPort,
    konten: const [],
    categories: const [],
    taxRates: const [],
  );
}

Finder _iconButtonWithTooltip(String tooltip) {
  return find.byWidgetPredicate((Widget widget) => widget is IconButton && widget.tooltip == tooltip);
}

AppLocalizations _localizations(WidgetTester tester) {
  return AppLocalizations.of(tester.element(find.byType(QuickBookingsView)))!;
}

Future<void> _expectTabReachable(WidgetTester tester, Finder target) async {
  final FocusNode focusNode = Focus.of(tester.element(target));
  for (int attempt = 0; attempt < 8 && !focusNode.hasFocus; attempt += 1) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  expect(focusNode.hasFocus, isTrue);
}

void main() {
  group('QuickBookingsView', () {
    late AppDatabase database;

    setUp(() async {
      database = AppDatabase.createTestDatabase();
      await database.ensureOpen();
    });

    tearDown(() async {
      await database.close();
    });

    testWidgets('shows database errors instead of the empty state', (WidgetTester tester) async {
      final QuickBookingRepository repository = _FailingRepository(database.executor);
      await tester.pumpWidget(_localizedApp(_view(repository: repository)));
      await tester.pumpAndSettle();

      final AppLocalizations l10n = _localizations(tester);
      expect(find.text(l10n.databaseUnavailable), findsOneWidget);
      expect(find.text(l10n.quickBookingEmpty), findsNothing);
      expect(find.text(l10n.actionRetry), findsOneWidget);
    });

    testWidgets('shows the empty state after a successful empty query', (WidgetTester tester) async {
      final QuickBookingRepository repository = QuickBookingRepository(database.executor);
      await tester.pumpWidget(_localizedApp(_view(repository: repository)));
      await tester.pumpAndSettle();

      final AppLocalizations l10n = _localizations(tester);
      expect(find.text(l10n.quickBookingEmpty), findsOneWidget);
      expect(find.text(l10n.actionRetry), findsNothing);
    });

    testWidgets('test_preset_management_is_keyboard_accessible', (WidgetTester tester) async {
      final QuickBookingsView view = _view(
        repository: _PresetRepository(database.executor, const <QuickBookingPreset>[_preset]),
      );
      await tester.pumpWidget(_localizedApp(view));
      await tester.pumpAndSettle();

      final AppLocalizations l10n = _localizations(tester);
      final Finder newAction = find.widgetWithText(TextButton, l10n.quickBookingNew);
      final Finder editAction = find.byTooltip(l10n.quickBookingEdit);
      final Finder deleteAction = find.byTooltip(l10n.quickBookingDelete);
      final Finder editButton = _iconButtonWithTooltip(l10n.quickBookingEdit);
      final Finder deleteButton = _iconButtonWithTooltip(l10n.quickBookingDelete);

      expect(tester.widget<TextButton>(newAction).onPressed, isNotNull);
      expect(editAction, findsOneWidget);
      expect(deleteAction, findsOneWidget);
      expect(tester.widget<IconButton>(editButton).onPressed, isNotNull);
      expect(tester.widget<IconButton>(deleteButton).onPressed, isNotNull);

      await _expectTabReachable(tester, find.text(l10n.quickBookingNew));
      await _expectTabReachable(tester, find.byIcon(Icons.edit));
      await _expectTabReachable(tester, find.byIcon(Icons.delete));
    });

    testWidgets('test_execution_is_unavailable', (WidgetTester tester) async {
      final QuickBookingRepository repository = _PresetRepository(database.executor, const <QuickBookingPreset>[
        _preset,
      ]);
      await tester.pumpWidget(_localizedApp(_view(repository: repository)));
      await tester.pumpAndSettle();

      final AppLocalizations l10n = _localizations(tester);
      final Finder executeAction = _iconButtonWithTooltip(l10n.quickBookingExecute);

      expect(find.text(l10n.quickBookingUnavailable), findsOneWidget);
      expect(tester.widget<IconButton>(executeAction).onPressed, isNull);
    });
  });
}
