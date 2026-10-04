import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/income_tax_supporting_reports/income_tax_availability.dart';
import 'package:openaccounting/features/income_tax_supporting_reports/income_tax_schedules_view.dart';

/// S/G availability surface: no guessed values, keyboard reviewable.
void main() {
  group('S/G availability surface', () {
    const useCase = IncomeTaxScheduleAvailabilityUseCase();

    test('test_supported_schedule_fields_have_traceable_values', () {
      for (final schedule in IncomeTaxSchedule.values) {
        final IncomeTaxAvailability result = useCase.availability(schedule);
        expect(result.available, isFalse, reason: 'no accepted contract exists');
        expect(result.blockers, hasLength(4));
      }
    });

    test('test_unsupported_tax_year_form_edition', () {
      final IncomeTaxAvailability result = useCase.availability(IncomeTaxSchedule.g);
      expect(result.available, isFalse);
      expect(result.blockers, contains(IncomeTaxBlocker.formContract));
    });

    test('test_accounting_source_or_classification_is_incomplete', () {
      final IncomeTaxAvailability result = useCase.availability(IncomeTaxSchedule.s);
      expect(result.available, isFalse);
      expect(
        result.blockers,
        containsAll(<IncomeTaxBlocker>[
          IncomeTaxBlocker.periodContract,
          IncomeTaxBlocker.classification,
          IncomeTaxBlocker.accountingSource,
        ]),
      );
    });

    test('test_workpaper_is_not_filed', () {
      for (final schedule in IncomeTaxSchedule.values) {
        expect(useCase.availability(schedule).available, isFalse);
      }
    });

    testWidgets('test_workpaper_can_be_reviewed_by_keyboard', (tester) async {
      IncomeTaxSchedule? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncomeTaxSchedulesView(
              useCase: useCase,
              initialSchedule: null,
              onScheduleChanged: (IncomeTaxSchedule value) => selected = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Anlage für die Verfügbarkeitsprüfung wählen'), findsWidgets);
      expect(find.text('Anlage S'), findsOneWidget);
      expect(find.text('Anlage G'), findsOneWidget);

      await tester.tap(find.text('Anlage S'));
      await tester.pumpAndSettle();
      expect(selected, IncomeTaxSchedule.s);
      expect(find.text('Noch nicht verfügbar'), findsOneWidget);

      final FocusNode? before = FocusManager.instance.primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(FocusManager.instance.primaryFocus, isNot(equals(before)));
    });
  });
}
