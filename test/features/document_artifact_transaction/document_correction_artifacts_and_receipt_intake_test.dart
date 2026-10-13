import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/documents/artifact_transaction.dart';
import 'package:openaccounting/features/documents/correction_artifact_writer.dart';

import '../pdf/pdf_test_helpers.dart';

import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';

Future<AppDatabase> _openDb(Directory profileDir) async {
  final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDir.path);
  addTearDown(db.close);
  await db.ensureOpen();
  return db;
}

Future<void> _seedBasics(AppDatabase db) async {
  await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
  );
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
  );
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'GS-YY####', naechste_nummer = 1 WHERE typ = 'gutschrift'",
  );
}

RechnungenUseCases _useCases(AppDatabase db, Directory profileDir) {
  return RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor, profileDir: profileDir.path)));
}

Future<RechnungItem> _finalizedInvoice(RechnungenUseCases uc) async {
  final RechnungItem draft = await uc.createDraftRechnung(
    datum: '2026-03-10',
    positionen: const <RechnungPositionItem>[
      RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
    ],
  );
  return uc.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
}

void main() {
  group('document-correction-artifacts-and-receipt-intake / artifact-transaction', () {
    test('test_finalized_invoice_commits_artifact_and_effects', () async {
      final Directory profile = await Directory.systemTemp.createTemp('artifact-commit-');
      addTearDown(() => profile.delete(recursive: true));
      final AppDatabase db = await _openDb(profile);
      await _seedBasics(db);
      final RechnungenUseCases uc = _useCases(db, profile);
      final RechnungItem finalized = await _finalizedInvoice(uc);
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT original_pdf_pfad FROM rechnungen WHERE id = ?',
        <Object?>[finalized.id],
      );
      final String? path = rows.single['original_pdf_pfad']?.toString();
      expect(path, isNotNull);
      expect(File(path!).existsSync(), isTrue);
      expect(File(path).readAsBytesSync(), isNotEmpty);
      final List<Map<String, Object?>> journals = await db.executor.runSelect(
        'SELECT id FROM journal WHERE rechnung_id = ?',
        <Object?>[finalized.id],
      );
      expect(journals, isNotEmpty);
    });

    test('test_writer_failure_rolls_back', () async {
      const ArtifactTransaction transaction = ArtifactTransaction();
      final Directory dir = await Directory.systemTemp.createTemp('artifact-fail-');
      addTearDown(() => profileDelete(dir));
      // Empty bytes fail readability verification; no file remains.
      await expectLater(
        transaction.writeArtifact(directory: dir, baseName: '1.pdf', bytes: <int>[]),
        throwsA(isA<FileSystemException>()),
      );
      expect(dir.listSync(), isEmpty);
      // Existing target blocks a second writer; the committed file is untouched.
      File('${dir.path}/2.pdf').writeAsBytesSync(<int>[1, 2, 3]);
      await expectLater(
        transaction.writeArtifact(directory: dir, baseName: '2.pdf', bytes: <int>[9]),
        throwsA(isA<FileSystemException>()),
      );
      expect(File('${dir.path}/2.pdf').readAsBytesSync(), <int>[1, 2, 3]);
    });

    test('test_process_crash_before_artifact_rename_is_reconciled', () async {
      const ArtifactTransaction transaction = ArtifactTransaction();
      final Directory dir = await Directory.systemTemp.createTemp('artifact-crash-before-');
      addTearDown(() => profileDelete(dir));
      // Crash left a staging file behind; no document references it.
      File('${dir.path}/7.pdf.tmp.123').writeAsBytesSync(<int>[1]);
      final int removed = await transaction.reconcile(directory: dir, referencedNames: <String>{});
      expect(removed, 1);
      expect(dir.listSync(), isEmpty);
    });

    test('test_process_crash_after_rename_but_before_database_commit_is_reconciled', () async {
      const ArtifactTransaction transaction = ArtifactTransaction();
      final Directory dir = await Directory.systemTemp.createTemp('artifact-crash-after-');
      addTearDown(() => profileDelete(dir));
      // Renamed but uncommitted owned artifact; an unrelated file survives.
      File('${dir.path}/42.pdf').writeAsBytesSync(<int>[1, 2]);
      File('${dir.path}/notizen.txt').writeAsStringSync('unrelated');
      final int removed = await transaction.reconcile(directory: dir, referencedNames: <String>{});
      expect(removed, 1);
      expect(File('${dir.path}/42.pdf').existsSync(), isFalse);
      expect(File('${dir.path}/notizen.txt').existsSync(), isTrue);
    });

    test('test_missing_committed_artifact_is_reported', () {
      const ArtifactTransaction transaction = ArtifactTransaction();
      expect(transaction.checkCommitted('/profile/pdfs/documents/999.pdf'), 'Artifact fehlt — zur Reparatur vormerken');
      expect(transaction.checkCommitted(null), 'Artifact fehlt — zur Reparatur vormerken');
      expect(transaction.checkCommitted(''), 'Artifact fehlt — zur Reparatur vormerken');
    });

    test('test_finalized_correction_has_a_readable_artifact', () async {
      final Directory profile = await Directory.systemTemp.createTemp('artifact-storno-');
      addTearDown(() => profile.delete(recursive: true));
      final AppDatabase db = await _openDb(profile);
      await _seedBasics(db);
      final RechnungenUseCases uc = _useCases(db, profile);
      final RechnungItem draft = await uc.createDraftRechnung(
        datum: '2026-03-10',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Beratung', menge: 1, einzelpreis: 100, gesamt: 100),
          RechnungPositionItem(bezeichnung: 'Support', menge: 1, einzelpreis: 50, gesamt: 50),
        ],
      );
      final RechnungItem finalized = await uc.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
      final RechnungItem storno = await uc.stornoRechnung(rechnungId: finalized.id, grund: 'Falsch berechnet');
      final List<Map<String, Object?>> sourceAmounts = await db.executor.runSelect(
        'SELECT netto_betrag, ust_betrag, brutto_betrag FROM rechnungen WHERE id = ?',
        <Object?>[finalized.id],
      );
      final List<Map<String, Object?>> stornoRows = await db.executor.runSelect(
        'SELECT original_pdf_pfad, storno_von, storno_datum, netto_betrag, ust_betrag, brutto_betrag '
        'FROM rechnungen WHERE id = ?',
        <Object?>[storno.id],
      );
      final String? stornoPath = stornoRows.single['original_pdf_pfad']?.toString();
      expect(stornoRows.single['storno_von'], finalized.id);
      expect(
        num.parse(stornoRows.single['netto_betrag'].toString()),
        -num.parse(sourceAmounts.single['netto_betrag'].toString()),
      );
      expect(
        num.parse(stornoRows.single['ust_betrag'].toString()),
        -num.parse(sourceAmounts.single['ust_betrag'].toString()),
      );
      expect(
        num.parse(stornoRows.single['brutto_betrag'].toString()),
        -num.parse(sourceAmounts.single['brutto_betrag'].toString()),
      );
      expect(stornoPath, isNotNull);
      expect(File(stornoPath!).existsSync(), isTrue);
      expect(File(stornoPath).readAsBytesSync(), isNotEmpty);

      final String stornoPdfText = parsePdf(File(stornoPath).readAsBytesSync()).visibleText;
      final DateTime stornoDate = DateTime.parse(stornoRows.single['storno_datum'].toString());
      final String formattedStornoDate =
          '${stornoDate.day.toString().padLeft(2, '0')}.${stornoDate.month.toString().padLeft(2, '0')}.${stornoDate.year}';
      expect(stornoPdfText, contains('Stornorechnung'));
      expect(stornoPdfText, contains(formattedStornoDate));
      expect(stornoPdfText, contains('10.03.2026'), reason: 'Storno-PDF must show the original invoice date');
      expect(
        stornoPdfText,
        contains(num.parse(stornoRows.single['netto_betrag'].toString()).toStringAsFixed(2).replaceAll('.', ',')),
      );
      expect(
        stornoPdfText,
        contains(num.parse(stornoRows.single['ust_betrag'].toString()).toStringAsFixed(2).replaceAll('.', ',')),
      );
      expect(
        stornoPdfText,
        contains(num.parse(stornoRows.single['brutto_betrag'].toString()).toStringAsFixed(2).replaceAll('.', ',')),
      );
      expect(stornoPdfText, contains('-100,00'));
      expect(stornoPdfText, contains('-19,00'));
      expect(stornoPdfText, contains('-119,00'));
      expect(stornoPdfText, isNot(contains('Zahlungsdaten')));
      expect(
        stornoPdfText,
        contains('Beratung 1,00 100,00 € 0,00 % -100,00 € 19,00 % -19,00 € -119,00 €'),
        reason: 'Storno position amounts must keep the reversal sign',
      );

      final RechnungItem credit = await uc.createGutschrift(vonRechnungId: finalized.id);
      final List<Map<String, Object?>> creditRows = await db.executor.runSelect(
        'SELECT original_pdf_pfad, netto_betrag FROM rechnungen WHERE id = ?',
        <Object?>[credit.id],
      );
      final String? creditPath = creditRows.single['original_pdf_pfad']?.toString();
      expect(num.parse(creditRows.single['netto_betrag'].toString()), lessThan(0));
      expect(creditPath, isNotNull);
      expect(File(creditPath!).existsSync(), isTrue);
      expect(File(creditPath).readAsBytesSync(), isNotEmpty);
      final String creditPdfText = parsePdf(File(creditPath).readAsBytesSync()).visibleText;
      expect(
        creditPdfText,
        contains('Beratung 1,00 100,00 € 0,00 % -100,00 € 19,00 % -19,00 € -119,00 €'),
        reason: 'Gutschrift position amounts must be negative',
      );

      expect(creditPdfText, contains('-100,00'));
      expect(creditPdfText, contains('-19,00'));
      expect(creditPdfText, contains('-119,00'));

      final RechnungItem creditStorno = await uc.stornoRechnung(
        rechnungId: credit.id,
        grund: 'Gutschrift zurücknehmen',
      );
      final List<Map<String, Object?>> creditStornoRows = await db.executor.runSelect(
        'SELECT original_pdf_pfad, netto_betrag FROM rechnungen WHERE id = ?',
        <Object?>[creditStorno.id],
      );
      final String? creditStornoPath = creditStornoRows.single['original_pdf_pfad']?.toString();
      expect(num.parse(creditStornoRows.single['netto_betrag'].toString()), greaterThan(0));
      expect(creditStornoPath, isNotNull);
      expect(File(creditStornoPath!).existsSync(), isTrue);
      expect(File(creditStornoPath).readAsBytesSync(), isNotEmpty);
      final String creditStornoPdfText = parsePdf(File(creditStornoPath).readAsBytesSync()).visibleText;
      expect(
        creditStornoPdfText,
        contains('Beratung 1,00 100,00 € 0,00 % 100,00 € 19,00 % 19,00 € 119,00 €'),
        reason: 'Storno of a Gutschrift must show positive position amounts',
      );

      expect(creditStornoPdfText, contains('100,00'));
      expect(creditStornoPdfText, contains('19,00'));
      expect(creditStornoPdfText, contains('119,00'));
    });

    test('test_finalized_conversion_has_a_readable_artifact', () async {
      const CorrectionArtifactWriter writer = CorrectionArtifactWriter();
      final Directory dir = await Directory.systemTemp.createTemp('artifact-conversion-');
      addTearDown(() => profileDelete(dir));
      final Uint8List bytes = Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46, 0x2D, 0x31]);
      final File committed = await writer.commitFinalizedArtifact(documentsDir: dir, documentId: 11, pdfBytes: bytes);
      expect(committed.existsSync(), isTrue);
      expect(committed.readAsBytesSync(), isNotEmpty);
      // Draft results never claim a finalized artifact path.
      expect(const ArtifactTransaction().checkCommitted(null), isNotNull);
    });

    test('test_correction_artifact_failure_leaves_no_false_finalization', () async {
      const CorrectionArtifactWriter writer = CorrectionArtifactWriter();
      final Directory dir = await Directory.systemTemp.createTemp('artifact-nofalse-');
      addTearDown(() => profileDelete(dir));
      await expectLater(
        writer.commitFinalizedArtifact(documentsDir: dir, documentId: 5, pdfBytes: Uint8List(0)),
        throwsA(isA<StateError>()),
      );
      expect(dir.listSync(), isEmpty);
    });
  });
}

Future<void> profileDelete(Directory dir) async {
  try {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  } catch (_) {}
}
