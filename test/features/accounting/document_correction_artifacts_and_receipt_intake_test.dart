import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/accounting/gobd_export_service.dart';
import 'package:openaccounting/features/documents/zip_codec.dart';

Future<AppDatabase> _openDb() async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  addTearDown(db.close);
  await db.ensureOpen();
  return db;
}

Future<int> _journal(AppDatabase db, String datum, {int? belegId}) {
  return db.executor.runInsert(
    'INSERT INTO journal (datum, beschreibung, betrag, beleg_id) VALUES (?, ?, ?, ?)',
    <Object?>[datum, 'Buchung $datum', '100', belegId],
  );
}

Future<int> _finalizedDoc(AppDatabase db, {required String datum, String? artifactPath, String nummer = 'RE-260001'}) {
  return db.executor.runInsert(
    'INSERT INTO rechnungen (rechnungsnummer, typ, status, datum, ist_entwurf, eingabemodus, original_pdf_pfad) VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[nummer, 'rechnung', 'offen', datum, 0, 'netto', artifactPath],
  );
}

File _artifact(Directory dir, String name, List<int> bytes) {
  final File file = File('${dir.path}/$name')..writeAsBytesSync(bytes);
  return file;
}

({Uint8List archive, Map<String, String> manifest}) _buildZip(Map<String, List<int>> files) {
  final Map<String, String> manifest = <String, String>{
    for (final MapEntry<String, List<int>> file in files.entries) file.key: sha256.convert(file.value).toString(),
  };
  final Uint8List archive = encodeZip(<ZipEntry>[
    for (final MapEntry<String, List<int>> file in files.entries) ZipEntry(name: file.key, data: file.value),
    ZipEntry(name: 'manifest.json', data: utf8.encode(jsonEncode(manifest))),
    ZipEntry(name: 'inventar.json', data: utf8.encode('{}')),
  ]);
  return (archive: archive, manifest: manifest);
}

Uint8List _withSymlinkFlag(Uint8List archive) {
  final Uint8List bytes = Uint8List.fromList(archive);
  final ByteData view = ByteData.sublistView(bytes);
  var eocd = -1;
  for (var i = bytes.length - 22; i >= 0 && i >= bytes.length - 65557; i--) {
    if (view.getUint32(i, Endian.little) == 0x06054b50) {
      eocd = i;
      break;
    }
  }
  expect(eocd, isNonNegative);
  final int centralOffset = view.getUint32(eocd + 16, Endian.little);
  // External file attributes at central header +38: mark as symlink.
  view.setUint32(centralOffset + 38, 0xA0800000, Endian.little);
  return bytes;
}

void main() {
  group('document-correction-artifacts-and-receipt-intake / gobd-export', () {
    test('test_gobd_zip_generation', () async {
      final AppDatabase db = await _openDb();
      final Directory profile = await Directory.systemTemp.createTemp('gobd-gen-');
      addTearDown(() => profile.delete(recursive: true));
      await _journal(db, '2026-03-10');
      final File pdf = _artifact(profile, 'rechnung.pdf', utf8.encode('%PDF-1.7\nRechnung\n'));
      await _finalizedDoc(db, datum: '2026-03-11', artifactPath: pdf.path);
      final GobdExportService service = GobdExportService(db.executor, profileDir: profile.path);
      final GobdInventory inventory = await service.buildInventory(periodStart: '2026-01-01', periodEnd: '2026-12-31');
      expect(inventory.complete, isTrue);
      expect(inventory.records.length, 2);
      final GobdExportResult result = await service.generate(inventory);
      expect(result.complete, isTrue);
      expect(result.manifest, isNotEmpty);
      expect(result.archiveBytes, isNotEmpty);
      final GobdVerification verification = GobdExportService.verifyArchive(result.archiveBytes, result.manifest);
      expect(verification.valid, isTrue);
    });

    test('test_gobd_integrity_verification', () async {
      final Map<String, List<int>> files = <String, List<int>>{
        'belege/dokument_1.pdf': utf8.encode('%PDF-1.7\nA\n'),
        'belege/beleg_2.pdf': utf8.encode('%PDF-1.7\nB\n'),
      };
      final ({Uint8List archive, Map<String, String> manifest}) built = _buildZip(files);
      final GobdVerification verification = GobdExportService.verifyArchive(built.archive, built.manifest);
      expect(verification.valid, isTrue);
      expect(verification.problem, isNull);
    });

    test('test_gobd_export_with_missing_documents', () async {
      final AppDatabase db = await _openDb();
      await _journal(db, '2026-04-01');
      // Finalized record whose artifact is missing.
      await _finalizedDoc(db, datum: '2026-04-02', artifactPath: '/profile/pdfs/documents/404.pdf');
      // Record without a valid effective date blocks a complete result.
      await db.executor.runInsert(
        "INSERT INTO journal (datum, beschreibung, betrag) VALUES ('', 'Ohne Datum', '5')",
        const <Object?>[],
      );
      final GobdExportService service = GobdExportService(db.executor);
      final GobdInventory inventory = await service.buildInventory(periodStart: '2026-01-01', periodEnd: '2026-12-31');
      expect(inventory.complete, isFalse);
      expect(inventory.missing.length, 2);
      final GobdExportResult result = await service.generate(inventory);
      expect(result.complete, isFalse);
      expect(result.missing, isNotEmpty);
    });

    test('test_gobd_verification_detects_a_changed_file', () {
      final Map<String, List<int>> files = <String, List<int>>{'belege/dokument_1.pdf': utf8.encode('%PDF-1.7\nA\n')};
      final ({Uint8List archive, Map<String, String> manifest}) built = _buildZip(files);
      final Uint8List tampered = Uint8List.fromList(built.archive);
      // Flip a byte inside the file data segment (local header is 30 bytes
      // plus the 21-byte name, so index 55 is file content).
      tampered[55] = tampered[55] ^ 0xFF;
      final GobdVerification verification = GobdExportService.verifyArchive(tampered, built.manifest);
      expect(verification.valid, isFalse);
      expect(verification.problem, contains('belege/dokument_1.pdf'));
    });

    test('test_gobd_verification_rejects_unsafe_or_oversized_zip_content', () {
      // Absolute path.
      final absolute = _buildZip(<String, List<int>>{'/etc/passwd': utf8.encode('x')});
      expect(GobdExportService.verifyArchive(absolute.archive, absolute.manifest).valid, isFalse);
      // Parent traversal.
      final traversal = _buildZip(<String, List<int>>{'belege/../../evil.pdf': utf8.encode('x')});
      expect(GobdExportService.verifyArchive(traversal.archive, traversal.manifest).valid, isFalse);
      // Duplicate normalized paths.
      final Uint8List dupes = encodeZip(<ZipEntry>[
        ZipEntry(name: 'belege/a.pdf', data: utf8.encode('1')),
        ZipEntry(name: 'belege/a.pdf', data: utf8.encode('1')),
        ZipEntry(name: 'manifest.json', data: utf8.encode('{}')),
        ZipEntry(name: 'inventar.json', data: utf8.encode('{}')),
      ]);
      final Map<String, String> dupeManifest = <String, String>{
        'belege/a.pdf': sha256.convert(utf8.encode('1')).toString(),
      };
      expect(GobdExportService.verifyArchive(dupes, dupeManifest).valid, isFalse);
      // Symlink entry.
      final linked = _buildZip(<String, List<int>>{'belege/link.pdf': utf8.encode('x')});
      final Uint8List symlink = _withSymlinkFlag(linked.archive);
      expect(GobdExportService.verifyArchive(symlink, linked.manifest).valid, isFalse);
      // Entry-count and archive bounds (scaled-down overrides of the 20k/2GiB rules).
      final many = _buildZip(<String, List<int>>{'a.pdf': utf8.encode('1'), 'b.pdf': utf8.encode('2')});
      expect(GobdExportService.verifyArchive(many.archive, many.manifest, limitEntries: 1).valid, isFalse);
      expect(GobdExportService.verifyArchive(many.archive, many.manifest, limitArchiveBytes: 10).valid, isFalse);
    });

    test('test_gobd_verification_rejects_manifest_mismatch_and_streamed_size_overflow', () {
      final Map<String, List<int>> files = <String, List<int>>{'belege/a.pdf': utf8.encode('0123456789ABCDEF')};
      final ({Uint8List archive, Map<String, String> manifest}) built = _buildZip(files);
      // Omitted manifest entry.
      final Map<String, String> missing = Map<String, String>.from(built.manifest)
        ..['belege/fehlt.pdf'] = sha256.convert(utf8.encode('x')).toString();
      final GobdVerification omitted = GobdExportService.verifyArchive(built.archive, missing);
      expect(omitted.valid, isFalse);
      expect(omitted.problem, contains('Manifest-Eintrag fehlt'));
      // Unmanifested entry.
      final Uint8List extra = encodeZip(<ZipEntry>[
        ZipEntry(name: 'belege/a.pdf', data: utf8.encode('0123456789ABCDEF')),
        ZipEntry(name: 'belege/extra.pdf', data: utf8.encode('y')),
        ZipEntry(name: 'manifest.json', data: utf8.encode(jsonEncode(built.manifest))),
        ZipEntry(name: 'inventar.json', data: utf8.encode('{}')),
      ]);
      final GobdVerification unmanifested = GobdExportService.verifyArchive(extra, built.manifest);
      expect(unmanifested.valid, isFalse);
      expect(unmanifested.problem, contains('Nicht manifestierter Eintrag'));
      // Declared-vs-actual streamed overflow (scaled-down override of 5 GiB).
      final GobdVerification overflow = GobdExportService.verifyArchive(
        built.archive,
        built.manifest,
        limitContentBytes: 4,
      );
      expect(overflow.valid, isFalse);
      expect(overflow.problem, contains('Inhalt zu groß'));
    });
  });
}
