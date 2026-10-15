import 'package:flutter_test/flutter_test.dart';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/accounting/reporting/accounting_period_summary_service.dart';
import 'package:openaccounting/features/accounting/reporting/euer_report_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/reporting_workspace_use_case.dart';

void main() {
  group('reporting workspace dispatch', () {
    late AppDatabase db;
    late ReportingWorkspaceUseCase useCase;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      useCase = ReportingWorkspaceUseCase(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> insertKunde({required int id, required String land, String? ustIdNr}) async {
      await db.executor.runInsert(
        'INSERT INTO kunden (id, name, strasse, plz, ort, land, ust_idnr) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[id, 'Kunde $id', 'Str 1', '10115', 'Berlin', land, ustIdNr],
      );
      return id;
    }

    test('test_generate_a_supported_report_preview', () async {
      final int fr = await insertKunde(id: 51, land: 'FR', ustIdNr: 'FR123');
      await db.executor.runInsert(
        'INSERT INTO rechnungen (id, typ, status, ist_entwurf, kunde_id, datum) VALUES (?, ?, ?, 0, ?, ?)',
        <Object?>[71, 'rechnung', 'final', fr, '2025-09-05'],
      );
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, immutable, rechnung_id, ist_eu_lieferung) '
        'VALUES (?, ?, ?, ?, 0, 71, 1)',
        <Object?>['2025-09-01', 'ig Lieferung', '1000.00', 'Einnahme'],
      );

      final ReportWorkspaceResult<ReportWorkspaceValue> result = await useCase.resolve(
        const ReportSelection.zm(month: '2025-09'),
      );

      // The matching typed service receives the exact period; the result
      // carries version, period, and provenance.
      expect(result.availability, ReportAvailability.available);
      final ZmWorkspaceValue value = result.value! as ZmWorkspaceValue;
      expect(value.periodStart, '2025-09-01');
      expect(value.periodEnd, '2025-10-01');
      expect(value.sourceVersions.values, contains('ustg-18a-2026'));
      expect(value.preview.recipients.single.ustIdNr, 'FR123');
    });

    test('test_financial_prerequisite_is_still_unapproved', () async {
      // Simulate the balanced-posting prerequisite not being approved.
      await db.executor.runCustom('DROP TABLE settlement_groups', const <Object?>[]);

      final ReportWorkspaceResult<ReportWorkspaceValue> result = await useCase.resolve(
        const ReportSelection.euer(jahr: 2025),
      );

      // Unavailable state names the unapproved prerequisite and carries no
      // complete or estimated total from any substitute source.
      expect(result.availability, ReportAvailability.unavailable);
      expect(result.reasonCode, contains('balanced-journal-postings-and-settlement-events'));
      expect(result.reasonCode, contains('invoice-money-contract'));
      expect(result.value, isNull);
    });

    test('test_unsupported_e_r_year_does_not_reuse_2025', () async {
      final ReportWorkspaceResult<ReportWorkspaceValue> result = await useCase.resolve(
        const ReportSelection.euer(jahr: 2026),
      );

      // Missing year-specific form version identified; the 2025 line layout
      // is not used as a fallback.
      expect(result.availability, ReportAvailability.unavailable);
      expect(result.reasonCode, contains('unsupportedFormYear'));
      expect(result.value, isNull);
    });

    test('test_eks_period_contract_is_unavailable', () async {
      final ReportWorkspaceResult<ReportWorkspaceValue> result = await useCase.resolve(const ReportSelection.eks());

      // Unavailable until the form-version and benefit-period contracts are
      // accepted; no calendar-year surrogate result exists.
      expect(result.availability, ReportAvailability.unavailable);
      expect(result.reasonCode, contains('Bewilligungszeitraum'));
      expect(result.value, isNull);
    });

    test('test_unsupported_zm_transaction_prevents_a_false_empty_report', () async {
      final int fr = await insertKunde(id: 51, land: 'FR', ustIdNr: 'FR123');
      final int at = await insertKunde(id: 54, land: 'AT', ustIdNr: 'AT789');
      await db.executor.runInsert(
        'INSERT INTO rechnungen (id, typ, status, ist_entwurf, kunde_id, datum) VALUES (?, ?, ?, 0, ?, ?)',
        <Object?>[77, 'rechnung', 'final', fr, '2025-10-08'],
      );
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, immutable, rechnung_id, ist_eu_lieferung) '
        'VALUES (?, ?, ?, ?, 0, 77, 1)',
        <Object?>['2025-10-01', 'ig Lieferung', '400.00', 'Einnahme'],
      );
      // Potentially reportable unsupported direction without goods posting.
      await db.executor.runInsert(
        'INSERT INTO rechnungen (id, typ, status, ist_entwurf, kunde_id, datum) VALUES (?, ?, ?, 0, ?, ?)',
        <Object?>[76, 'rechnung', 'final', at, '2025-10-10'],
      );

      final ReportWorkspaceResult<ReportWorkspaceValue> result = await useCase.resolve(
        const ReportSelection.zm(month: '2025-10'),
      );

      // Unavailable, linking the affected source; never an empty report.
      expect(result.availability, ReportAvailability.unavailable);
      expect(result.reasonCode, contains('Direction'));
      expect(result.reasonCode, contains('76'));
      expect(result.value, isNull);
    });
  });

  group('reporting workspace: annual accounting period summary', () {
    late AppDatabase db;
    late AccountingPeriodSummaryService service;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      service = AccountingPeriodSummaryService(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertKategorie({required int id, required int zeile}) async {
      await db.executor.runInsert(
        'INSERT OR REPLACE INTO kategorien (id, bezeichnung, konto_skr03, konto_skr04, euer_zeile, aktiv, '
        'mapping_status, catalog_source_reference, catalog_source_version) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)',
        <Object?>[id, 'Kat $id', '800$zeile', '400$zeile', zeile, 'catalog_verified', 'TEST-EUER', '2025-form.1'],
      );
    }

    Future<void> insertJournal({
      required int kategorieId,
      required String betrag,
      required String datum,
      String art = 'Einnahme',
    }) async {
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, immutable) VALUES (?, ?, ?, ?, ?, 0)',
        <Object?>[datum, 'Test $kategorieId', kategorieId, betrag, art],
      );
    }

    test('test_return_a_complete_supported_annual_summary', () async {
      await insertKategorie(id: 922, zeile: 15);
      await insertKategorie(id: 930, zeile: 36);
      await insertJournal(kategorieId: 922, betrag: '2000.00', datum: '2025-03-10');
      await insertJournal(kategorieId: 922, betrag: '300.00', datum: '2025-04-20');
      await insertJournal(kategorieId: 930, betrag: '500.00', datum: '2025-05-05', art: 'Ausgabe');

      final ReportWorkspaceResult<AccountingPeriodSummary> result = await service.summary(jahr: 2025);

      // Exact January 1 through next-January-1 period, canonical totals,
      // monthly series, distributions, source versions, and unresolved count.
      expect(result.availability, ReportAvailability.available);
      final AccountingPeriodSummary s = result.value!;
      expect(s.periodStart, '2025-01-01');
      expect(s.periodEnd, '2026-01-01');
      expect(s.incomeCents, 230000);
      expect(s.expenseCents, 50000);
      expect(s.unresolvedCount, 0);
      expect(s.sourceVersions['euerFormVersion'], 'anlage-euer-2025');
      expect(s.monthlyTrend, hasLength(12));
      expect(s.monthlyTrend[2].incomeCents, 200000); // March only.
      expect(s.monthlyTrend[4].expenseCents, 50000); // May only.
      // Expense distribution is grouped from journaled source facts.
      expect(s.expenseDistribution.single.amountCents, 50000);

      // Income, expense and profit totals equal the matching report results.
      final ReportWorkspaceResult<EuerPreview> euer = await EuerReportUseCase(db.executor).preview(jahr: 2025);
      expect(euer.availability, ReportAvailability.available);
      expect(s.profitCents, money.parseScaled(euer.value!.gewinn, scale: 2));
      expect(s.incomeCents - s.expenseCents, s.profitCents);
      // Margin is profit / income * 100.
      expect(s.marginPercent, isNotNull);
      expect(s.marginPercent, closeTo(s.profitCents / s.incomeCents * 100, 0.0001));
    });

    test('test_unsupported_annual_period_has_no_summary', () async {
      final ReportWorkspaceResult<AccountingPeriodSummary> result = await service.summary(jahr: 2026);

      // Unavailable with the missing version identified; no month/quarter
      // estimate or complete annual total is produced.
      expect(result.availability, ReportAvailability.unavailable);
      expect(result.reasonCode, contains('FormVersion'));
      expect(result.value, isNull);
    });

    test('test_empty_or_zero_income_supported_year', () async {
      final ReportWorkspaceResult<AccountingPeriodSummary> result = await service.summary(jahr: 2025);

      // Complete source, no events: zero totals, margin unavailable rather
      // than infinity or a fabricated percentage.
      expect(result.availability, ReportAvailability.available);
      final AccountingPeriodSummary s = result.value!;
      expect(s.incomeCents, 0);
      expect(s.expenseCents, 0);
      expect(s.profitCents, 0);
      expect(s.marginPercent, isNull);
      expect(s.unresolvedCount, 0);
    });
  });
}
