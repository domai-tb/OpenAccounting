import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/documents/beleg_repository.dart';
import 'package:openaccounting/features/documents/kunden_beleg_repository.dart';

Future<AppDatabase> _openDb() async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  addTearDown(db.close);
  await db.ensureOpen();
  return db;
}

Uint8List _pdfBytes(String name) => Uint8List.fromList(utf8.encode('%PDF-1.7\n$name\n'));

Future<int> _kunde(AppDatabase db) {
  return db.executor.runInsert(
    "INSERT INTO kunden (name, strasse, plz, ort) VALUES ('ACME GmbH', 'Straße 1', '80331', 'München')",
    const <Object?>[],
  );
}

void main() {
  group('document-correction-artifacts-and-receipt-intake / stammdaten', () {
    test('test_customer_document_is_unlinked_without_deleting_evidence', () async {
      final AppDatabase db = await _openDb();
      final Directory profile = await Directory.systemTemp.createTemp('stamm-unlink-');
      addTearDown(() => profile.delete(recursive: true));
      final BelegRepository belege = BelegRepository(db.executor, profileDir: profile.path);
      final KundenBelegRepository links = KundenBelegRepository(db.executor);
      final int belegId = await belege.importSource(bytes: _pdfBytes('vertrag'), filename: 'vertrag.pdf');
      final int kundeId = await _kunde(db);
      await links.link(kundeId: kundeId, belegId: belegId, rolle: 'vertrag');
      // Deletion checks query kunden_belege: the present row blocks deletion.
      expect(await links.hasCustomerLink(belegId), isTrue);
      await links.unlink(kundeId: kundeId, belegId: belegId);
      expect(await links.hasCustomerLink(belegId), isFalse);
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT dateipfad FROM belege WHERE id = ?',
        <Object?>[belegId],
      );
      expect(rows.length, 1);
      expect(File(rows.single['dateipfad'].toString()).existsSync(), isTrue);
    });

    test('test_customer_document_remains_after_its_due_date', () async {
      final AppDatabase db = await _openDb();
      final Directory profile = await Directory.systemTemp.createTemp('stamm-due-');
      addTearDown(() => profile.delete(recursive: true));
      final BelegRepository belege = BelegRepository(db.executor, profileDir: profile.path);
      final KundenBelegRepository links = KundenBelegRepository(db.executor);
      final int belegId = await belege.importSource(bytes: _pdfBytes('nachweis'), filename: 'nachweis.pdf');
      final int kundeId = await _kunde(db);
      await links.link(kundeId: kundeId, belegId: belegId);
      await db.executor.runUpdate('UPDATE belege SET loeschdatum = ? WHERE id = ?', <Object?>['2020-05-01', belegId]);
      // Overdue warning is shown; the source remains available.
      expect(BelegRepository.loeschdatumStatus('2020-05-01'), 'overdue');
      final List<Map<String, Object?>> docs = await links.listForCustomer(kundeId);
      expect(docs.length, 1);
      expect(File(docs.single['dateipfad'].toString()).existsSync(), isTrue);
    });

    test('test_dsgvo_expiry_warning', () {
      // loeschdatum = 2026-02-15, today 2026-02-10 → yellow badge.
      expect(KundenBelegRepository.dsgvoBadge('2026-02-15', today: DateTime(2026, 2, 10)), 'Löschen in 5 Tagen');
      expect(BelegRepository.loeschdatumStatus('2026-02-15', today: DateTime(2026, 2, 10)), 'due_soon');
    });

    test('test_dsgvo_overdue_flag', () {
      // loeschdatum = 2026-02-15, today 2026-02-20 → red overdue badge.
      expect(
        KundenBelegRepository.dsgvoBadge('2026-02-15', today: DateTime(2026, 2, 20)),
        'Überfällig zur Löschung vorgesehen',
      );
      expect(BelegRepository.loeschdatumStatus('2026-02-15', today: DateTime(2026, 2, 20)), 'overdue');
    });
  });
}
