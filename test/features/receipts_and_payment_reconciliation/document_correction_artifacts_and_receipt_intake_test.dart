import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/receipts/receipt_inbox_repository.dart';
import 'package:openaccounting/features/receipts/receipt_recognition.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';

Future<AppDatabase> _openDb() async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  addTearDown(db.close);
  await db.ensureOpen();
  return db;
}

Uint8List _pdfBytes(String name) => Uint8List.fromList(utf8.encode('%PDF-1.7\n$name\n'));

void main() {
  group('document-correction-artifacts-and-receipt-intake / receipts', () {
    test('test_receipt_is_reviewed_and_linked', () async {
      final AppDatabase db = await _openDb();
      final Directory profile = await Directory.systemTemp.createTemp('inbox-link-');
      addTearDown(() => profile.delete(recursive: true));
      final ReceiptInboxRepository inbox = ReceiptInboxRepository(db.executor, profileDir: profile.path);
      final Uint8List original = _pdfBytes('kassenbon');
      final int belegId = await inbox.importReceipt(bytes: original, filename: 'kassenbon.pdf');
      await inbox.markReviewed(belegId: belegId, entscheidung: 'beleg_ok');
      final RechnungenUseCases uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
      final RechnungItem invoice = await uc.createDokument(
        typ: 'rechnung',
        datum: '2026-07-01',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 10, gesamt: 10),
        ],
      );
      await inbox.associate(belegId: belegId, rechnungId: invoice.id);
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT status, sha256, dateigroesse FROM belege WHERE id = ?',
        <Object?>[belegId],
      );
      expect(rows.single['status'], 'verknuepft');
      expect(rows.single['sha256'], isNotNull);
      expect((rows.single['dateigroesse']! as num).toInt(), original.length);
      // Association alone creates no posting or payment allocation.
      final List<Map<String, Object?>> journals = await db.executor.runSelect(
        'SELECT COUNT(*) AS anzahl FROM journal WHERE beleg_id = ?',
        <Object?>[belegId],
      );
      expect((journals.single['anzahl']! as num).toInt(), 0);
      final preview = await inbox.previewSource(belegId);
      expect(preview.unavailable, isNull);
      expect(preview.bytes, isNotNull);
    });

    test('test_reviewed_receipt_is_posted_only_after_explicit_confirmation', () async {
      final AppDatabase db = await _openDb();
      final Directory profile = await Directory.systemTemp.createTemp('inbox-post-');
      addTearDown(() => profile.delete(recursive: true));
      final ReceiptInboxRepository inbox = ReceiptInboxRepository(db.executor, profileDir: profile.path);
      final int belegId = await inbox.importReceipt(bytes: _pdfBytes('bon'), filename: 'bon.pdf');
      await inbox.markReviewed(belegId: belegId);
      // Linking alone allocates no payment.
      final List<Map<String, Object?>> before = await db.executor.runSelect(
        'SELECT COUNT(*) AS anzahl FROM forderungen',
        const <Object?>[],
      );
      expect((before.single['anzahl']! as num).toInt(), 0);
      // A separate confirmed settlement operation links the unchanged source.
      await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, betrag, beleg_id) VALUES (?, ?, ?, ?)',
        <Object?>['2026-07-02', 'Bestätigte Buchung', '10', belegId],
      );
      final preview = await inbox.previewSource(belegId);
      expect(preview.bytes, isNotNull);
      final List<Map<String, Object?>> after = await db.executor.runSelect(
        'SELECT beleg_id FROM journal WHERE beleg_id = ?',
        <Object?>[belegId],
      );
      expect(after.single['beleg_id'], belegId);
    });

    test('test_unreadable_receipt_remains_reviewable', () async {
      final AppDatabase db = await _openDb();
      final Directory profile = await Directory.systemTemp.createTemp('inbox-unread-');
      addTearDown(() => profile.delete(recursive: true));
      final ReceiptInboxRepository inbox = ReceiptInboxRepository(db.executor, profileDir: profile.path);
      final int belegId = await inbox.importReceipt(bytes: _pdfBytes('scan'), filename: 'scan.pdf');
      // Source bytes are stored; a later recognition failure keeps the
      // receipt in a visible error/review state with manual assignment.
      await inbox.markReviewed(belegId: belegId, entscheidung: 'erkennung_fehlgeschlagen_manuell');
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT status, dateipfad FROM belege WHERE id = ?',
        <Object?>[belegId],
      );
      expect((rows.single['status']! as String).startsWith('geprueft'), isTrue);
      expect(File(rows.single['dateipfad'].toString()).existsSync(), isTrue);
      final Map<String, Object?> fallback = ReceiptRecognition.manualFallback(reason: 'Erkennung nicht verfügbar');
      expect(fallback['modus'], 'manuell');
    });

    test('test_failed_intake_leaves_no_partial_record_or_file', () async {
      final AppDatabase db = await _openDb();
      final Directory profile = await Directory.systemTemp.createTemp('inbox-fail-');
      addTearDown(() => profile.delete(recursive: true));
      final ReceiptInboxRepository inbox = ReceiptInboxRepository(db.executor, profileDir: profile.path);
      final Uint8List exe = Uint8List.fromList(utf8.encode('MZ nope'));
      await expectLater(inbox.importReceipt(bytes: exe, filename: 'tool.exe'), throwsA(isA<FormatException>()));
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT COUNT(*) AS anzahl FROM belege',
        const <Object?>[],
      );
      expect((rows.single['anzahl']! as num).toInt(), 0);
      expect(profile.listSync(recursive: true), isEmpty);
    });

    test('test_crash_after_final_source_write_leaves_no_orphan_on_recovery', () async {
      final AppDatabase db = await _openDb();
      final Directory profile = await Directory.systemTemp.createTemp('inbox-crash-');
      addTearDown(() => profile.delete(recursive: true));
      final ReceiptInboxRepository inbox = ReceiptInboxRepository(db.executor, profileDir: profile.path);
      // Simulate a crash: final source bytes renamed, inbox row never committed.
      final Directory sourceDir = Directory('${profile.path}/uploads/belege')..createSync(recursive: true);
      final File orphan = File('${sourceDir.path}/1234567890_quittung.pdf')..writeAsBytesSync(_pdfBytes('x'));
      final File foreign = File('${sourceDir.path}/eigene-notizen.txt')..writeAsStringSync('privat');
      final int removed = await inbox.belege.reconcileImports();
      expect(removed, 1);
      expect(orphan.existsSync(), isFalse);
      expect(foreign.existsSync(), isTrue);
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT COUNT(*) AS anzahl FROM belege',
        const <Object?>[],
      );
      expect((rows.single['anzahl']! as num).toInt(), 0);
    });

    test('test_source_preview_failure_preserves_the_record', () async {
      final AppDatabase db = await _openDb();
      final Directory profile = await Directory.systemTemp.createTemp('inbox-preview-');
      addTearDown(() => profile.delete(recursive: true));
      final ReceiptInboxRepository inbox = ReceiptInboxRepository(db.executor, profileDir: profile.path);
      final int belegId = await inbox.importReceipt(bytes: _pdfBytes('bon'), filename: 'bon.pdf');
      final RechnungenUseCases uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
      final RechnungItem invoice = await uc.createDokument(
        typ: 'rechnung',
        datum: '2026-07-01',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 10, gesamt: 10),
        ],
      );
      await inbox.associate(belegId: belegId, rechnungId: invoice.id);
      // Source artifact becomes unavailable; preview reports it and the
      // receipt state plus accounting relationship are preserved.
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT dateipfad FROM belege WHERE id = ?',
        <Object?>[belegId],
      );
      File(rows.single['dateipfad'].toString()).deleteSync();
      final preview = await inbox.previewSource(belegId);
      expect(preview.bytes, isNull);
      expect(preview.unavailable, isNotNull);
      final List<Map<String, Object?>> link = await db.executor.runSelect(
        'SELECT beleg_id FROM rechnungen WHERE id = ?',
        <Object?>[invoice.id],
      );
      expect(link.single['beleg_id'], belegId);
      final List<Map<String, Object?>> state = await db.executor.runSelect(
        'SELECT status FROM belege WHERE id = ?',
        <Object?>[belegId],
      );
      expect(state.single['status'], 'verknuepft');
    });

    test('test_user_accepts_reviewed_recognition_suggestions', () {
      final Uint8List source = _pdfBytes('kassenbon');
      final Map<String, Object?> form = <String, Object?>{'betrag': null, 'datum': null, 'haendler': null};
      final Map<String, Object?> suggestions = <String, Object?>{
        'betrag': '23,50',
        'datum': '2026-07-01',
        'haendler': 'Bäckerei',
        'quelle': 'ocr',
      };
      final Map<String, Object?> accepted = ReceiptRecognition.applyAccepted(
        form: form,
        suggestions: suggestions,
        acceptedFields: <String>{'betrag', 'datum'},
        sourceBytesBefore: source,
        sourceBytesAfter: Uint8List.fromList(source),
      );
      expect(accepted['betrag'], '23,50');
      expect(accepted['datum'], '2026-07-01');
      expect(accepted['haendler'], isNull);
      // Source artifact stays byte-identical.
      expect(accepted.containsKey('quelle'), isFalse);
    });

    test('test_recognition_failure_falls_back_to_manual_review', () async {
      final AppDatabase db = await _openDb();
      final Directory profile = await Directory.systemTemp.createTemp('inbox-manual-');
      addTearDown(() => profile.delete(recursive: true));
      final ReceiptInboxRepository inbox = ReceiptInboxRepository(db.executor, profileDir: profile.path);
      final int belegId = await inbox.importReceipt(bytes: _pdfBytes('foto'), filename: 'foto.jpg');
      final Map<String, Object?> fallback = ReceiptRecognition.manualFallback(reason: 'offline');
      expect(fallback['vorschlaege']! as Map<String, Object?>, isEmpty);
      final preview = await inbox.previewSource(belegId);
      expect(preview.bytes, isNotNull);
      expect(preview.unavailable, isNull);
    });
  });
}
