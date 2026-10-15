import 'package:flutter_test/flutter_test.dart';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/reporting/reporting_workspace_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/report_workspace_result.dart';

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
}
