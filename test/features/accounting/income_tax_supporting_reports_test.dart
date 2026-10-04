import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/income_tax_supporting_reports/income_tax_availability.dart';

/// S/G values require an accepted source contract (income-tax section 1).
void main() {
  group('S/G source contract gate', () {
    const useCase = IncomeTaxScheduleAvailabilityUseCase();

    test('test_s_g_source_mapping_is_not_accepted', () {
      for (final schedule in IncomeTaxSchedule.values) {
        final IncomeTaxAvailability result = useCase.availability(schedule);
        expect(result.available, isFalse);
        expect(result.blockers, contains(IncomeTaxBlocker.formContract));
        expect(result.blockers, contains(IncomeTaxBlocker.accountingSource));
      }
    });

    test('test_schedule_choice_is_explicit', () {
      expect(IncomeTaxScheduleAvailabilityUseCase.parseSchedule(null), isNull);
      expect(IncomeTaxScheduleAvailabilityUseCase.parseSchedule(''), isNull);
      expect(IncomeTaxScheduleAvailabilityUseCase.parseSchedule('x'), isNull);
      expect(IncomeTaxScheduleAvailabilityUseCase.parseSchedule('s'), IncomeTaxSchedule.s);
      expect(IncomeTaxScheduleAvailabilityUseCase.parseSchedule('G'), IncomeTaxSchedule.g);
    });
  });
}
