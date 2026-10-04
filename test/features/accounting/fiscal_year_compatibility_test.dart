import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/euer_entity.dart';
import 'package:openaccounting/features/accounting/euer_service.dart';
import 'package:openaccounting/features/fiscal_year/fiscal_calendar_service.dart';

/// Business-year report availability guards (fiscal-year section 1).
void main() {
  group('Fiscal report availability', () {
    late AppDatabase db;
    late EuerService euer;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      euer = EuerService(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    test('test_accounting_dashboard_business_fiscal_filter_remains_unavailable', () async {
      const FiscalCalendarService april = FiscalCalendarService(startMonth: 4);
      final FiscalPeriod range = april.fiscalYearFor(DateTime(2026, 8, 15));
      expect(range.label, '2026');
      await expectLater(
        euer.generateForFiscalYear(fiscalYearLabel: 2026, startMonth: 4),
        throwsA(isA<EuerException>()),
      );
    });

    test('test_accounting_eur_does_not_relabel_a_calendar_year', () async {
      await expectLater(
        euer.generateForFiscalYear(fiscalYearLabel: 2026, startMonth: 4),
        throwsA(
          isA<EuerException>().having((e) => e.toString(), 'message', allOf(contains('2026'), contains('unverfügbar'))),
        ),
      );
    });

    test('test_accounting_explicit_calendar_year_eur_remains_available', () async {
      final EuerResult result = await euer.generateForFiscalYear(fiscalYearLabel: 2026, startMonth: 1);
      expect(result.jahr, 2026);
      expect(result.zeile(12), '0.00');
    });

    test('test_fiscal_year_calendar_calendar_only_eur_is_unavailable_for_an_alternate_fiscal_year', () async {
      await db.executor.runInsert(
        'INSERT INTO kategorien (bezeichnung, konto_skr03, euer_zeile, aktiv, mapping_status) VALUES (?, ?, ?, ?, ?)',
        const <Object?>['Aprilkat', '8400', 14, 1, 'catalog_verified'],
      );
      final cats = await db.executor.runSelect('SELECT id FROM kategorien LIMIT 1', const []);
      final int katId = (cats.single['id']! as num).toInt();
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>['2026-05-10', 'Mai', katId, '100.00', 'Einnahme'],
      );
      await expectLater(
        euer.generateForFiscalYear(fiscalYearLabel: 2026, startMonth: 4),
        throwsA(isA<EuerException>()),
      );
      final EuerResult calendar = await euer.generate(jahr: 2026);
      expect(calendar.zeile(14), '100.00');
    });

    test('test_fiscal_year_calendar_eur_consumes_the_configured_fiscal_boundary', () async {
      const FiscalCalendarService april = FiscalCalendarService(startMonth: 4);
      final FiscalPeriod range = april.fiscalYearFor(DateTime(2026, 8, 15));
      expect(range.start, '2026-04-01');
      expect(range.endExclusive, '2027-04-01');
      expect(range.label, '2026');
    });
  });
}
