import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart' as drift_native;
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/documents/beleg_repository.dart';
import 'package:openaccounting/features/documents/correction_source_context.dart';
import 'package:openaccounting/features/documents/dokumentenpaket_repository.dart';
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

Future<void> _seedRanges(AppDatabase db) async {
  await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'RE-YY####', naechste_nummer = 1 WHERE typ = 'rechnung_ausgang'",
  );
  await db.executor.runCustom(
    "UPDATE nummernkreise SET format = 'ST-YY####', naechste_nummer = 1 WHERE typ = 'stornorechnung'",
  );
}

Uint8List _pdfBytes(String name) => Uint8List.fromList(utf8.encode('%PDF-1.7\n$name\n'));

void main() {
  group('document-correction-artifacts-and-receipt-intake / documents', () {
    test('test_replacement_draft_retains_source_fields_and_links', () async {
      final AppDatabase db = await _openDb();
      await _seedRanges(db);
      final RechnungenUseCases uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
      final RechnungItem draft = await uc.createDraftRechnung(
        datum: '2026-04-02',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Leistung', menge: 2, einzelpreis: 50, gesamt: 100),
        ],
      );
      final RechnungItem finalized = await uc.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
      await db.executor.runUpdate('UPDATE rechnungen SET einleitungstext = ?, schlusstext = ? WHERE id = ?', <Object?>[
        'Einleitung',
        'Schlusstext',
        finalized.id,
      ]);
      final RechnungItem storno = await uc.stornoRechnung(rechnungId: finalized.id, grund: 'Korrekturbedarf');
      final RechnungItem ersatz = await uc.createErsatzRechnung(vonRechnungId: finalized.id);
      expect(ersatz.istEntwurf, isTrue);
      final List<Map<String, Object?>> links = await db.executor.runSelect(
        'SELECT ersatz_fuer, ersatzrechnung_id, eingabemodus, einleitungstext, schlusstext FROM rechnungen WHERE id = ?',
        <Object?>[ersatz.id],
      );
      expect(links.single['ersatz_fuer'], finalized.id);
      expect(links.single['eingabemodus'], 'netto');
      expect(links.single['einleitungstext'], 'Einleitung');
      expect(links.single['schlusstext'], 'Schlusstext');
      final List<Map<String, Object?>> back = await db.executor.runSelect(
        'SELECT ersatzrechnung_id FROM rechnungen WHERE id = ?',
        <Object?>[finalized.id],
      );
      expect(back.single['ersatzrechnung_id'], ersatz.id);
      final List<Map<String, Object?>> positions = await db.executor.runSelect(
        'SELECT bezeichnung, menge, gesamt FROM rechnungspositionen WHERE rechnung_id = ?',
        <Object?>[ersatz.id],
      );
      expect(positions.single['bezeichnung'], 'Leistung');
      expect(storno.typ, 'storno');
    });

    test('test_ineligible_source_creates_no_partial_target', () async {
      final AppDatabase db = await _openDb();
      await _seedRanges(db);
      final RechnungenUseCases uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
      final RechnungItem draft = await uc.createDraftRechnung(
        datum: '2026-04-02',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 10, gesamt: 10),
        ],
      );
      final RechnungItem finalized = await uc.finalizeRechnung(locale: 'de_DE', rechnungId: draft.id);
      await expectLater(
        uc.createErsatzRechnung(vonRechnungId: finalized.id),
        throwsA(predicate((Object e) => e.toString().contains('storniert'))),
      );
      final List<Map<String, Object?>> count = await db.executor.runSelect(
        'SELECT COUNT(*) AS anzahl FROM rechnungen WHERE ersatz_fuer = ?',
        <Object?>[finalized.id],
      );
      expect((count.single['anzahl']! as num).toInt(), 0);
      // Pure eligibility helper agrees without touching the database.
      expect(CorrectionSourceContext.replacementEligibility(<String, Object?>{'status': 'offen'}), isNotNull);
    });

    test('test_supported_conversion_preserves_source_context', () async {
      final AppDatabase db = await _openDb();
      await _seedRanges(db);
      final RechnungenUseCases uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
      final RechnungItem angebot = await uc.createDokument(
        typ: 'angebot',
        datum: '2026-04-02',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'Beratung', menge: 3, einzelpreis: 100, gesamt: 300),
        ],
      );
      await db.executor.runUpdate('UPDATE rechnungen SET einleitungstext = ?, schlusstext = ? WHERE id = ?', <Object?>[
        'Sehr geehrte Damen und Herren',
        'Mit freundlichen Grüßen',
        angebot.id,
      ]);
      final RechnungItem auftrag = await uc.konvertiereDokument(quelleId: angebot.id, zielTyp: 'auftrag');
      final List<Map<String, Object?>> target = await db.executor.runSelect(
        'SELECT konvertiert_von, eingabemodus, einleitungstext, schlusstext FROM rechnungen WHERE id = ?',
        <Object?>[auftrag.id],
      );
      expect(target.single['konvertiert_von'], angebot.id);
      expect(target.single['eingabemodus'], 'netto');
      expect(target.single['einleitungstext'], 'Sehr geehrte Damen und Herren');
      expect(target.single['schlusstext'], 'Mit freundlichen Grüßen');
      final List<Map<String, Object?>> source = await db.executor.runSelect(
        'SELECT konvertiert_zu FROM rechnungen WHERE id = ?',
        <Object?>[angebot.id],
      );
      expect(source.single['konvertiert_zu'], auftrag.id);
      // Later edits to the draft do not modify the Angebot.
      await db.executor.runUpdate('UPDATE rechnungen SET einleitungstext = ? WHERE id = ?', <Object?>[
        'Geändert',
        auftrag.id,
      ]);
      final List<Map<String, Object?>> unchanged = await db.executor.runSelect(
        'SELECT einleitungstext FROM rechnungen WHERE id = ?',
        <Object?>[angebot.id],
      );
      expect(unchanged.single['einleitungstext'], 'Sehr geehrte Damen und Herren');
    });

    test('test_package_groups_documents_and_receipt_evidence', () async {
      final AppDatabase db = await _openDb();
      await _seedRanges(db);
      final Directory profile = await Directory.systemTemp.createTemp('paket-group-');
      addTearDown(() => profile.delete(recursive: true));
      final BelegRepository belege = BelegRepository(db.executor, profileDir: profile.path);
      final DokumentenpaketRepository pakete = DokumentenpaketRepository(db.executor, profileDir: profile.path);
      final RechnungenUseCases uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
      final RechnungItem invoice = await uc.createDokument(
        typ: 'rechnung',
        datum: '2026-05-01',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 10, gesamt: 10),
        ],
      );
      final RechnungItem lieferschein = await uc.createDokument(
        typ: 'lieferschein',
        datum: '2026-05-01',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'B', menge: 1, einzelpreis: 5, gesamt: 5),
        ],
      );
      final int belegId = await belege.importSource(bytes: _pdfBytes('quittung'), filename: 'quittung.pdf');
      final int paketId = await pakete.createPackage(dokumentIds: <int>[invoice.id, lieferschein.id], name: 'Q2');
      await pakete.addBeleg(paketId: paketId, belegId: belegId);
      final members = await pakete.listMembers(paketId);
      expect(members.dokumente.length, 2);
      expect(members.belege.length, 1);
      final List<Map<String, Object?>> docLinks = await db.executor.runSelect(
        'SELECT dokumentenpaket_id FROM rechnungen WHERE id IN (?, ?)',
        <Object?>[invoice.id, lieferschein.id],
      );
      expect(docLinks.every((Map<String, Object?> row) => row['dokumentenpaket_id'] == paketId), isTrue);
    });

    test('test_package_export_preserves_member_snapshot', () async {
      final AppDatabase db = await _openDb();
      await _seedRanges(db);
      final Directory profile = await Directory.systemTemp.createTemp('paket-export-');
      addTearDown(() => profile.delete(recursive: true));
      final BelegRepository belege = BelegRepository(db.executor, profileDir: profile.path);
      final DokumentenpaketRepository pakete = DokumentenpaketRepository(db.executor, profileDir: profile.path);
      final RechnungenUseCases uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
      final RechnungItem invoice = await uc.createDokument(
        typ: 'rechnung',
        datum: '2026-05-01',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 10, gesamt: 10),
        ],
      );
      final File artifact = File('${profile.path}/rechnung.pdf')..writeAsBytesSync(_pdfBytes('rechnung'));
      await db.executor.runUpdate('UPDATE rechnungen SET original_pdf_pfad = ? WHERE id = ?', <Object?>[
        artifact.path,
        invoice.id,
      ]);
      final int belegId = await belege.importSource(bytes: _pdfBytes('quittung'), filename: 'quittung.pdf');
      final int paketId = await pakete.createPackage(dokumentIds: <int>[invoice.id], name: 'Export');
      await pakete.addBeleg(paketId: paketId, belegId: belegId);
      final PaketExportResult result = await pakete.exportSnapshot(paketId);
      expect(result.complete, isTrue);
      expect(result.manifest, isNotEmpty);
      expect(result.archiveBytes, isNotEmpty);
      // No member record, relationship, or source file changed.
      final List<Map<String, Object?>> doc = await db.executor.runSelect(
        'SELECT original_pdf_pfad FROM rechnungen WHERE id = ?',
        <Object?>[invoice.id],
      );
      expect(doc.single['original_pdf_pfad'], artifact.path);
      expect(artifact.existsSync(), isTrue);
    });

    test('test_legacy_schema_adds_document_package_membership_column', () async {
      final drift_native.NativeDatabase native = drift_native.NativeDatabase.memory();
      final AppDatabase seed = AppDatabase.forTesting(native);
      await seed.ensureOpen();
      final List<Map<String, Object?>> before = await native.runSelect(
        'PRAGMA table_info(rechnungen)',
        const <Object?>[],
      );
      if (before.any((Map<String, Object?> row) => row['name'] == 'dokumentenpaket_id')) {
        await native.runCustom('ALTER TABLE rechnungen DROP COLUMN dokumentenpaket_id');
      }

      final AppDatabase upgraded = AppDatabase.forTesting(native);
      addTearDown(upgraded.close);
      await upgraded.ensureOpen();

      final List<Map<String, Object?>> after = await native.runSelect(
        'PRAGMA table_info(rechnungen)',
        const <Object?>[],
      );
      expect(after.any((Map<String, Object?> row) => row['name'] == 'dokumentenpaket_id'), isTrue);
    });

    test('test_missing_member_cannot_be_added', () async {
      final AppDatabase db = await _openDb();
      final DokumentenpaketRepository pakete = DokumentenpaketRepository(db.executor);
      final int paketId = await db.executor.runInsert(
        "INSERT INTO dokumentenpakete (name, status) VALUES ('Leeres Paket', 'offen')",
        const <Object?>[],
      );
      await expectLater(
        pakete.addBeleg(paketId: paketId, belegId: 999999),
        throwsA(predicate((Object e) => e.toString().contains('nicht verfügbar'))),
      );
      final members = await pakete.listMembers(paketId);
      expect(members.belege, isEmpty);
    });

    test('test_create_package_from_multiple_documents', () async {
      final AppDatabase db = await _openDb();
      await _seedRanges(db);
      final DokumentenpaketRepository pakete = DokumentenpaketRepository(db.executor);
      final RechnungenUseCases uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
      Future<RechnungItem> draft(String typ) => uc.createDokument(
        typ: typ,
        datum: '2026-05-01',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'X', menge: 1, einzelpreis: 1, gesamt: 1),
        ],
      );
      final RechnungItem a = await draft('rechnung');
      final RechnungItem b = await draft('lieferschein');
      final RechnungItem c = await draft('angebot');
      final int paketId = await pakete.createPackage(dokumentIds: <int>[a.id, b.id, c.id], name: 'Alle drei');
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT COUNT(*) AS anzahl FROM rechnungen WHERE dokumentenpaket_id = ?',
        <Object?>[paketId],
      );
      expect((rows.single['anzahl']! as num).toInt(), 3);
    });

    test('test_empty_package_creation_blocked', () async {
      final AppDatabase db = await _openDb();
      final DokumentenpaketRepository pakete = DokumentenpaketRepository(db.executor);
      await expectLater(
        pakete.createPackage(dokumentIds: const <int>[], name: 'Leer'),
        throwsA(predicate((Object e) => e.toString().contains('Mindestens ein Dokument auswählen'))),
      );
    });

    test('test_attach_receipt_to_invoice', () async {
      final AppDatabase db = await _openDb();
      await _seedRanges(db);
      final Directory profile = await Directory.systemTemp.createTemp('beleg-attach-');
      addTearDown(() => profile.delete(recursive: true));
      final BelegRepository belege = BelegRepository(db.executor, profileDir: profile.path);
      final RechnungenUseCases uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
      final int belegId = await belege.importSource(bytes: _pdfBytes('beleg'), filename: 'beleg.pdf');
      final RechnungItem invoice = await uc.createDokument(
        typ: 'rechnung',
        datum: '2026-06-01',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 10, gesamt: 10),
        ],
      );
      await belege.attachToInvoice(belegId: belegId, rechnungId: invoice.id);
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT beleg_id FROM rechnungen WHERE id = ?',
        <Object?>[invoice.id],
      );
      expect(rows.single['beleg_id'], belegId);
    });

    test('test_unsupported_file_type_rejected', () async {
      final AppDatabase db = await _openDb();
      final Directory profile = await Directory.systemTemp.createTemp('beleg-exe-');
      addTearDown(() => profile.delete(recursive: true));
      final BelegRepository belege = BelegRepository(db.executor, profileDir: profile.path);
      final Uint8List exe = Uint8List.fromList(utf8.encode('MZ fake executable'));
      await expectLater(
        belege.importSource(bytes: exe, filename: 'setup.exe'),
        throwsA(predicate((Object e) => e.toString().contains('Dateityp nicht unterstützt'))),
      );
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT COUNT(*) AS anzahl FROM belege',
        const <Object?>[],
      );
      expect((rows.single['anzahl']! as num).toInt(), 0);
    });

    test('test_oversized_or_mislabeled_source_is_rejected', () async {
      final AppDatabase db = await _openDb();
      final Directory profile = await Directory.systemTemp.createTemp('beleg-gross-');
      addTearDown(() => profile.delete(recursive: true));
      final BelegRepository belege = BelegRepository(db.executor, profileDir: profile.path);
      // Mislabeled: .pdf name with plain-text bytes.
      final Uint8List mislabeled = Uint8List.fromList(utf8.encode('Nur Text, kein PDF'));
      await expectLater(
        belege.importSource(bytes: mislabeled, filename: 'falsch.pdf'),
        throwsA(predicate((Object e) => e.toString().contains('Dateityp nicht unterstützt'))),
      );
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT COUNT(*) AS anzahl FROM belege',
        const <Object?>[],
      );
      expect((rows.single['anzahl']! as num).toInt(), 0);
      expect(profile.listSync(recursive: true), isEmpty);
    });

    test('test_linked_evidence_cannot_be_deleted', () async {
      final AppDatabase db = await _openDb();
      await _seedRanges(db);
      final Directory profile = await Directory.systemTemp.createTemp('beleg-linked-');
      addTearDown(() => profile.delete(recursive: true));
      final BelegRepository belege = BelegRepository(db.executor, profileDir: profile.path);
      final RechnungenUseCases uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
      final int belegId = await belege.importSource(bytes: _pdfBytes('beleg'), filename: 'beleg.pdf');
      final RechnungItem invoice = await uc.createDokument(
        typ: 'rechnung',
        datum: '2026-06-01',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 10, gesamt: 10),
        ],
      );
      await belege.attachToInvoice(belegId: belegId, rechnungId: invoice.id);
      await expectLater(belege.deleteBeleg(belegId), throwsA(isA<StateError>()));
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT dateipfad FROM belege WHERE id = ?',
        <Object?>[belegId],
      );
      expect(rows.single['dateipfad'], isNotNull);
      expect(File(rows.single['dateipfad'].toString()).existsSync(), isTrue);
    });

    test('test_customer_association_must_be_removed_before_evidence_deletion', () async {
      final AppDatabase db = await _openDb();
      final Directory profile = await Directory.systemTemp.createTemp('beleg-kunde-');
      addTearDown(() => profile.delete(recursive: true));
      final BelegRepository belege = BelegRepository(db.executor, profileDir: profile.path);
      final int belegId = await belege.importSource(bytes: _pdfBytes('vertrag'), filename: 'vertrag.pdf');
      final int kundeId = await db.executor.runInsert(
        "INSERT INTO kunden (name, strasse, plz, ort) VALUES ('ACME', 'Straße 1', '80331', 'München')",
        const <Object?>[],
      );
      await db.executor.runInsert('INSERT INTO kunden_belege (kunde_id, beleg_id) VALUES (?, ?)', <Object?>[
        kundeId,
        belegId,
      ]);
      // Deletion is rejected while the join-table association exists.
      await expectLater(belege.deleteBeleg(belegId), throwsA(isA<StateError>()));
      // After explicit unlinking the Beleg remains until separately deleted.
      await db.executor.runDelete('DELETE FROM kunden_belege WHERE kunde_id = ? AND beleg_id = ?', <Object?>[
        kundeId,
        belegId,
      ]);
      final List<Map<String, Object?>> stillThere = await db.executor.runSelect(
        'SELECT id FROM belege WHERE id = ?',
        <Object?>[belegId],
      );
      expect(stillThere.length, 1);
      await belege.deleteBeleg(belegId);
      final List<Map<String, Object?>> gone = await db.executor.runSelect(
        'SELECT id FROM belege WHERE id = ?',
        <Object?>[belegId],
      );
      expect(gone, isEmpty);
    });

    test('test_unlinked_evidence_can_be_deleted', () async {
      final AppDatabase db = await _openDb();
      final Directory profile = await Directory.systemTemp.createTemp('beleg-frei-');
      addTearDown(() => profile.delete(recursive: true));
      final BelegRepository belege = BelegRepository(db.executor, profileDir: profile.path);
      final int belegId = await belege.importSource(bytes: _pdfBytes('frei'), filename: 'frei.pdf');
      final List<Map<String, Object?>> before = await db.executor.runSelect(
        'SELECT dateipfad FROM belege WHERE id = ?',
        <Object?>[belegId],
      );
      final String path = before.single['dateipfad'].toString();
      expect(File(path).existsSync(), isTrue);
      await belege.deleteBeleg(belegId);
      final List<Map<String, Object?>> after = await db.executor.runSelect(
        'SELECT id FROM belege WHERE id = ?',
        <Object?>[belegId],
      );
      expect(after, isEmpty);
      expect(File(path).existsSync(), isFalse);
    });

    test('test_scheduled_deletion_date_does_not_silently_purge_evidence', () async {
      final AppDatabase db = await _openDb();
      final Directory profile = await Directory.systemTemp.createTemp('beleg-loesch-');
      addTearDown(() => profile.delete(recursive: true));
      final BelegRepository belege = BelegRepository(db.executor, profileDir: profile.path);
      final int belegId = await belege.importSource(bytes: _pdfBytes('alt'), filename: 'alt.pdf');
      await db.executor.runUpdate('UPDATE belege SET loeschdatum = ? WHERE id = ?', <Object?>['2020-01-01', belegId]);
      // Expired loeschdatum never triggers automatic deletion.
      expect(BelegRepository.loeschdatumStatus('2020-01-01'), 'overdue');
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT dateipfad, loeschdatum FROM belege WHERE id = ?',
        <Object?>[belegId],
      );
      expect(File(rows.single['dateipfad'].toString()).existsSync(), isTrue);
      expect(rows.single['loeschdatum'], '2020-01-01');
    });

    test('test_remove_customer_association_without_deleting_shared_evidence', () async {
      final AppDatabase db = await _openDb();
      await _seedRanges(db);
      final Directory profile = await Directory.systemTemp.createTemp('beleg-shared-');
      addTearDown(() => profile.delete(recursive: true));
      final BelegRepository belege = BelegRepository(db.executor, profileDir: profile.path);
      final RechnungenUseCases uc = RechnungenUseCases(RechnungenRepository(RechnungenDataSource(db.executor)));
      final int belegId = await belege.importSource(bytes: _pdfBytes('shared'), filename: 'shared.pdf');
      final int kundeId = await db.executor.runInsert(
        "INSERT INTO kunden (name, strasse, plz, ort) VALUES ('ACME', 'Straße 1', '80331', 'München')",
        const <Object?>[],
      );
      await db.executor.runInsert('INSERT INTO kunden_belege (kunde_id, beleg_id) VALUES (?, ?)', <Object?>[
        kundeId,
        belegId,
      ]);
      final RechnungItem invoice = await uc.createDokument(
        typ: 'rechnung',
        datum: '2026-06-01',
        positionen: const <RechnungPositionItem>[
          RechnungPositionItem(bezeichnung: 'A', menge: 1, einzelpreis: 10, gesamt: 10),
        ],
      );
      await belege.attachToInvoice(belegId: belegId, rechnungId: invoice.id);
      // Removing the customer association keeps Beleg and other links.
      await db.executor.runDelete('DELETE FROM kunden_belege WHERE kunde_id = ? AND beleg_id = ?', <Object?>[
        kundeId,
        belegId,
      ]);
      final List<Map<String, Object?>> beleg = await db.executor.runSelect(
        'SELECT dateipfad FROM belege WHERE id = ?',
        <Object?>[belegId],
      );
      expect(beleg.length, 1);
      expect(File(beleg.single['dateipfad'].toString()).existsSync(), isTrue);
      final List<Map<String, Object?>> invoiceRows = await db.executor.runSelect(
        'SELECT beleg_id FROM rechnungen WHERE id = ?',
        <Object?>[invoice.id],
      );
      expect(invoiceRows.single['beleg_id'], belegId);
    });

    test('test_customer_document_deletion_date_does_not_purge_shared_evidence', () async {
      final AppDatabase db = await _openDb();
      final Directory profile = await Directory.systemTemp.createTemp('beleg-kunden-loesch-');
      addTearDown(() => profile.delete(recursive: true));
      final BelegRepository belege = BelegRepository(db.executor, profileDir: profile.path);
      final int belegId = await belege.importSource(bytes: _pdfBytes('kunde'), filename: 'kunde.pdf');
      final int kundeId = await db.executor.runInsert(
        "INSERT INTO kunden (name, strasse, plz, ort) VALUES ('ACME', 'Straße 1', '80331', 'München')",
        const <Object?>[],
      );
      await db.executor.runInsert('INSERT INTO kunden_belege (kunde_id, beleg_id) VALUES (?, ?)', <Object?>[
        kundeId,
        belegId,
      ]);
      await db.executor.runUpdate('UPDATE belege SET loeschdatum = ? WHERE id = ?', <Object?>['2020-01-01', belegId]);
      // Due warning is shown; the source remains available without deletion.
      expect(BelegRepository.loeschdatumStatus('2020-01-01'), 'overdue');
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT dateipfad FROM belege WHERE id = ?',
        <Object?>[belegId],
      );
      expect(File(rows.single['dateipfad'].toString()).existsSync(), isTrue);
    });
  });
}
