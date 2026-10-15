import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/reporting/datev_export_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/report_export_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/reporting_workspace_use_case.dart';
import 'package:openaccounting/features/accounting/reporting/report_workspace_result.dart';

void main() {
  group('report export lifecycle', () {
    late AppDatabase db;
    late ReportExportUseCase useCase;

    const DatevExportConfig config = DatevExportConfig(
      sachkontenlaenge: '4',
      chartCode: '03',
      buSchluessel: <String, String>{'19': '1'},
    );

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      useCase = ReportExportUseCase(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> seedDatevSource() async {
      await db.executor.runInsert(
        'INSERT INTO unternehmen (id, name, datev_beraternummer, datev_mandantennummer) VALUES (?, ?, ?, ?)',
        <Object?>[1, 'Testfirma', '6512345', 'M4711'],
      );
      await db.executor.runInsert('INSERT INTO konten (id, name, datev_kontonummer) VALUES (?, ?, ?)', <Object?>[
        81,
        'Konto 81',
        '4000',
      ]);
      await db.executor.runInsert('INSERT INTO konten (id, name, datev_kontonummer) VALUES (?, ?, ?)', <Object?>[
        82,
        'Konto 82',
        '1200',
      ]);
      await db.executor.runInsert(
        'INSERT INTO journal (id, datum, beschreibung, betrag, beleg_typ, immutable, beleg_nr, '
        'soll_konto_id, haben_konto_id, ust_satz, source_kind) VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?, ?, ?)',
        <Object?>[1, '2025-07-15', 'Testbuchung', '1000.00', 'Einnahme', 'RE-1', 81, 82, '19', 'invoice_event'],
      );
    }

    String tempDestination() {
      final Directory dir = Directory.systemTemp.createTempSync('datev_export_lifecycle');
      addTearDown(() {
        if (dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      });
      return '${dir.path}/buchungsstapel_2025-07.csv';
    }

    test('test_datev_export_uses_the_maintained_artifact_lifecycle', () async {
      await seedDatevSource();
      final String dest = tempDestination();

      final ReportWorkspaceResult<ReportExportOutcome> result = await useCase.export(
        selection: const ReportSelection.datev(month: '2025-07', datevConfig: config),
        format: 'csv',
        destinationPath: dest,
      );

      // Written, reopened, validated, and recorded in history — success only
      // after validation completes.
      expect(result.availability, ReportAvailability.available);
      final ReportExportOutcome outcome = result.value!;
      expect(outcome.validated, isTrue);
      expect(outcome.path, dest);
      expect(outcome.bookingRowCount, 1);

      final File written = File(dest);
      expect(written.existsSync(), isTrue);
      final List<String> lines = written.readAsStringSync().split('\r\n');
      expect(lines.first.split(';').sublist(0, 5), <String>['EXTF', '700', '21', 'Buchungsstapel', '13']);
      expect(lines, hasLength(2));

      final List<Map<String, Object?>> log = await db.executor.runSelect(
        'SELECT status, datei_pfad, anzahl_buchungen FROM datev_export_log',
        const <Object?>[],
      );
      expect(log, hasLength(1));
      expect(log.single['status'], 'erfolg');
      expect(log.single['datei_pfad'], dest);
      expect((log.single['anzahl_buchungen']! as num).toInt(), 1);
      expect(outcome.exportLogId, isNotNull);
    });

    test('test_preview_only_report_has_no_file_export', () async {
      await seedDatevSource();
      final String dest = tempDestination();

      final ReportWorkspaceResult<ReportExportOutcome> result = await useCase.export(
        selection: const ReportSelection.euer(jahr: 2025),
        format: 'csv',
        destinationPath: dest,
      );

      // Preview-only report: no file-export action, no file, no history row.
      expect(result.availability, ReportAvailability.unavailable);
      expect(result.reasonCode, contains('previewOnlyReport'));
      expect(result.value, isNull);
      expect(File(dest).existsSync(), isFalse);
      final List<Map<String, Object?>> log = await db.executor.runSelect(
        'SELECT id FROM datev_export_log',
        const <Object?>[],
      );
      expect(log, isEmpty);
    });

    test('test_unsupported_export_format_remains_unavailable', () async {
      await seedDatevSource();
      final String dest = tempDestination();

      final ReportWorkspaceResult<ReportExportOutcome> result = await useCase.export(
        selection: const ReportSelection.zm(month: '2025-09'),
        format: 'pdf',
        destinationPath: dest,
      );

      // Explains that no accepted file-format contract exists in this change;
      // no file written, no successful export recorded.
      expect(result.availability, ReportAvailability.unavailable);
      expect(result.reasonCode, contains('no accepted file-format contract'));
      expect(result.value, isNull);
      expect(File(dest).existsSync(), isFalse);
      final List<Map<String, Object?>> log = await db.executor.runSelect(
        'SELECT id FROM datev_export_log',
        const <Object?>[],
      );
      expect(log, isEmpty);
    });
  });
}
