import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart'
    show BatchedStatements, QueryExecutor, QueryExecutorUser, SqlDialect, TransactionExecutor;
import 'package:drift/native.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';
import 'package:openaccounting/features/recurring/buchungsvorlagen_repository.dart';
import 'package:openaccounting/features/recurring/rechnungsvorlagen_repository.dart';
import 'package:openaccounting/features/setup/setup_repository.dart';
import 'package:openaccounting/pages/stammdaten/customer_data_disclosure_export.dart';
import 'package:openaccounting/pages/stammdaten/customer_disclosure_export_action.dart';
import 'package:openaccounting/pages/stammdaten/kunden_repository.dart';
import 'package:path/path.dart' as p;

Future<({AppDatabase db, Directory profileDir, Directory outDir})> _openCustomerDb(String prefix) async {
  final Directory profileDir = await Directory.systemTemp.createTemp(prefix);
  final Directory outDir = await Directory.systemTemp.createTemp('${prefix}out_');
  final AppDatabase db = AppDatabase.createTestDatabase(profileDir: profileDir.path);
  addTearDown(() async {
    try {
      await db.close();
    } catch (_) {}
    if (profileDir.existsSync()) await profileDir.delete(recursive: true);
    if (outDir.existsSync()) await outDir.delete(recursive: true);
  });
  await db.ensureOpen();
  return (db: db, profileDir: profileDir, outDir: outDir);
}

CustomerDataDisclosureExportService _service(AppDatabase db, Directory profileDir) {
  return CustomerDataDisclosureExportService(executor: db.executor, profileDir: profileDir.path);
}

Future<int> _seedCustomer(AppDatabase db, String name) {
  return db.executor.runInsert(
    'INSERT INTO kunden (kundennummer, debitor_nr, anrede, name, strasse, plz, ort, land) '
    "VALUES (?, ?, 'Herr', ?, 'Str 1', '10115', 'Berlin', 'DE')",
    <Object?>['K-$name', 'D-$name', name],
  );
}

Future<int> _seedAddress(AppDatabase db, int customerId) {
  return db.executor.runInsert(
    'INSERT INTO kunden_lieferadressen (kunde_id, bezeichnung, strasse, plz, ort, land) '
    "VALUES (?, 'Lager', 'Str 2', '10115', 'Berlin', 'DE')",
    <Object?>[customerId],
  );
}

Future<int> _seedInvoice(AppDatabase db, {int? customerId, int? addressId, String number = 'RE-1'}) {
  return db.executor.runInsert(
    'INSERT INTO rechnungen (rechnungsnummer, typ, status, kunde_id, lieferadresse_id, datum) VALUES (?, ?, ?, ?, ?, ?)',
    <Object?>[number, 'rechnung', 'final', customerId, addressId, '2026-01-05'],
  );
}

Future<void> _ensureInvoiceColumns(AppDatabase db) async {
  // Arrange-only schema fixture: mirrors RechnungenDataSource extra columns
  // so lineage and evidence fixtures can be inserted without invoice flows.
  const Map<String, String> columns = <String, String>{
    'storno_grund': 'TEXT',
    'storno_datum': 'TEXT',
    'gutschrift_von': 'INTEGER REFERENCES rechnungen(id)',
    'ersatz_fuer': 'INTEGER REFERENCES rechnungen(id)',
    'ersatzrechnung_id': 'INTEGER REFERENCES rechnungen(id)',
    'konvertiert_von': 'INTEGER REFERENCES rechnungen(id)',
    'konvertiert_zu': 'INTEGER REFERENCES rechnungen(id)',
    'original_pdf_pfad': 'TEXT',
    'rabatt_prozent': 'NUMERIC(12,2) DEFAULT 0',
    'rabatt_betrag': 'NUMERIC(12,2) DEFAULT 0',
    'lieferadresse_id': 'INTEGER REFERENCES kunden_lieferadressen(id)',
  };
  final List<Map<String, Object?>> existing = await db.executor.runSelect(
    'PRAGMA table_info(rechnungen)',
    const <Object?>[],
  );
  final Set<String> names = <String>{for (final Map<String, Object?> row in existing) row['name'].toString()};
  for (final MapEntry<String, String> column in columns.entries) {
    if (!names.contains(column.key)) {
      await db.executor.runCustom('ALTER TABLE rechnungen ADD COLUMN ${column.key} ${column.value}');
    }
  }
}

Future<void> _ensureSettlementTables(AppDatabase db) async {
  await db.executor.runCustom('''
CREATE TABLE IF NOT EXISTS settlement_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_kind TEXT NOT NULL,
  source_id TEXT NOT NULL,
  bank_transaction_id INTEGER REFERENCES bank_transaktionen(id),
  signed_amount_cents INTEGER NOT NULL CHECK (signed_amount_cents != 0),
  settlement_date TEXT NOT NULL,
  unapplied_cents INTEGER NOT NULL DEFAULT 0,
  group_root_journal_id INTEGER NOT NULL REFERENCES journal(id),
  reversal_of_group_id INTEGER REFERENCES settlement_groups(id),
  reversed_by_group_id INTEGER REFERENCES settlement_groups(id),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (source_kind, source_id)
)''');
  await db.executor.runCustom('''
CREATE TABLE IF NOT EXISTS settlement_allocations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  group_id INTEGER NOT NULL REFERENCES settlement_groups(id) ON DELETE CASCADE,
  forderung_id INTEGER REFERENCES forderungen(id),
  applied_cents INTEGER NOT NULL CHECK (applied_cents != 0),
  settlement_date TEXT NOT NULL,
  kategorie_id INTEGER REFERENCES kategorien(id),
  euer_zeile INTEGER,
  direction TEXT NOT NULL DEFAULT 'einnahme' CHECK (direction IN ('einnahme', 'ausgabe')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
)''');
}

Future<void> _ensureEmailAttemptTable(AppDatabase db) {
  return db.executor.runCustom('''
CREATE TABLE IF NOT EXISTS dokument_email_versuche (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  dokument_id INTEGER NOT NULL,
  dokument_typ TEXT NOT NULL,
  empfaenger TEXT NOT NULL,
  ergebnis TEXT NOT NULL DEFAULT 'submitting',
  mahnung_id INTEGER,
  idempotenz_schluessel TEXT NOT NULL UNIQUE,
  artefakt_ids TEXT NOT NULL DEFAULT '[]',
  erstellt_am TEXT NOT NULL,
  abgeschlossen_am TEXT,
  fehler_kategorie TEXT
)''');
}

Future<Map<String, int>> _seedLinkedRecords(AppDatabase db, Directory profileDir, int customerId) async {
  await _ensureInvoiceColumns(db);
  final int addressId = await _seedAddress(db, customerId);
  final int invoiceA = await _seedInvoice(db, customerId: customerId, number: 'RE-A-1');
  final int invoiceB = await _seedInvoice(db, addressId: addressId, number: 'RE-A-2');
  final int storno = await _seedInvoice(db, number: 'RE-A-3');
  await db.executor.runUpdate('UPDATE rechnungen SET storno_von = ? WHERE id = ?', <Object?>[invoiceA, storno]);
  final int converted = await _seedInvoice(db, customerId: customerId, number: 'RE-A-4');
  final int target = await _seedInvoice(db, customerId: customerId, number: 'RE-A-5');
  await db.executor.runUpdate('UPDATE rechnungen SET konvertiert_zu = ? WHERE id = ?', <Object?>[target, converted]);
  await db.executor.runUpdate('UPDATE rechnungen SET konvertiert_von = ? WHERE id = ?', <Object?>[converted, target]);
  await db.executor.runInsert(
    'INSERT INTO rechnungspositionen (rechnung_id, bezeichnung, einzelpreis, gesamt) VALUES (?, ?, ?, ?)',
    <Object?>[invoiceA, 'Leistung', '100.00', '100.00'],
  );
  await db.executor.runInsert(
    'INSERT INTO mahnungen (rechnung_id, kunde_id, datum, betrag) VALUES (?, ?, ?, ?)',
    <Object?>[invoiceA, customerId, '2026-02-01', '100.00'],
  );
  final int journalA = await db.executor.runInsert(
    "INSERT INTO journal (datum, betrag, beschreibung, rechnung_id) VALUES ('2026-01-05', '100.00', 'Umsatz', ?)",
    <Object?>[invoiceA],
  );
  final int forderungA = await db.executor.runInsert(
    'INSERT INTO forderungen (kunde_id, rechnung_id, betrag, typ, partner_typ, partner_id) VALUES (?, ?, ?, ?, ?, ?)',
    <Object?>[customerId, invoiceA, '100.00', 'rechnung', 'kunde', customerId],
  );
  final int forderungB = await db.executor.runInsert(
    'INSERT INTO forderungen (betrag, typ, partner_typ, partner_id) VALUES (?, ?, ?, ?)',
    <Object?>['50.00', 'rechnung', 'kunde', customerId],
  );
  final int journalF = await db.executor.runInsert(
    "INSERT INTO journal (datum, betrag, beschreibung) VALUES ('2026-01-06', '100.00', 'Forderung')",
    const <Object?>[],
  );
  await db.executor.runUpdate('UPDATE forderungen SET journal_id = ? WHERE id = ?', <Object?>[journalF, forderungA]);
  final int journalZ = await db.executor.runInsert(
    "INSERT INTO journal (datum, betrag, beschreibung) VALUES ('2026-01-07', '40.00', 'Zahlung')",
    const <Object?>[],
  );
  await db.executor.runInsert(
    "INSERT INTO forderung_zahlungen (forderung_id, journal_id, betrag, typ, datum) VALUES (?, ?, ?, 'zahlung', ?)",
    <Object?>[forderungA, journalZ, '40.00', '2026-01-07'],
  );
  await db.executor.runInsert('INSERT INTO vorsteuer_ansprueche (rechnung_id, betrag) VALUES (?, ?)', <Object?>[
    invoiceA,
    '19.00',
  ]);
  final int sourceInvoice = await _seedInvoice(db, customerId: customerId, number: 'RE-A-0');
  final int vorlage = await db.executor.runInsert(
    "INSERT INTO rechnungsvorlagen (name, kunde_id, intervall, auftrag_id) VALUES ('Monatlich', ?, 'monatlich', ?)",
    <Object?>[customerId, sourceInvoice],
  );
  await RechnungsVorlagenRepository(db.executor).ensureSchema();
  await db.executor.runInsert(
    'INSERT INTO rechnungsvorlagen_occurrences (vorlage_id, faelligkeit, rechnung_id) VALUES (?, ?, ?)',
    <Object?>[vorlage, '2026-03-01', invoiceA],
  );
  final File pdf = File(p.join(profileDir.path, 'rechnung-a.pdf'));
  await pdf.writeAsBytes(<int>[1, 2, 3, 4], flush: true);
  await db.executor.runUpdate('UPDATE rechnungen SET original_pdf_pfad = ? WHERE id = ?', <Object?>[
    'rechnung-a.pdf',
    invoiceA,
  ]);
  const List<int> receiptBytes = <int>[9, 8, 7];
  final File receipt = File(p.join(profileDir.path, 'beleg.pdf'));
  await receipt.writeAsBytes(receiptBytes, flush: true);
  final File receiptPdfa = File(p.join(profileDir.path, 'beleg-pdfa.pdf'));
  await receiptPdfa.writeAsBytes(<int>[6, 5, 4], flush: true);
  final int beleg = await db.executor.runInsert(
    'INSERT INTO belege (datum, betrag, dateipfad, dateiname, original_name, mime_type, dateigroesse, sha256, hochgeladen_am, beleg_pdfa_pfad, loeschdatum) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[
      '2026-01-15',
      '12.34',
      receipt.path,
      '123_beleg.pdf',
      'beleg.pdf',
      'application/pdf',
      receiptBytes.length,
      sha256.convert(receiptBytes).toString(),
      '2026-01-15T10:30:00.000',
      receiptPdfa.path,
      '2027-01-15',
    ],
  );
  await db.executor.runInsert('INSERT INTO kunden_belege (kunde_id, beleg_id) VALUES (?, ?)', <Object?>[
    customerId,
    beleg,
  ]);
  return <String, int>{
    'address': addressId,
    'invoiceA': invoiceA,
    'invoiceB': invoiceB,
    'storno': storno,
    'converted': converted,
    'target': target,
    'journalA': journalA,
    'forderungA': forderungA,
    'forderungB': forderungB,
    'vorlage': vorlage,
    'beleg': beleg,
  };
}

Future<int> _count(AppDatabase db, String table) async {
  final List<Map<String, Object?>> rows = await db.executor.runSelect(
    'SELECT COUNT(*) AS c FROM $table',
    const <Object?>[],
  );
  return (rows.single['c']! as num).toInt();
}

void main() {
  group('Customer data disclosure export', () {
    test('test_customer_data_disclosure_export_001_export_an_unambiguous_customer_s_linked_records', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_001_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      final int otherId = await _seedCustomer(env.db, 'Fremd GmbH');
      await _ensureInvoiceColumns(env.db);
      await _seedInvoice(env.db, customerId: otherId, number: 'RE-B-1');
      await _seedLinkedRecords(env.db, env.profileDir, customerId);
      final int kundenBefore = await _count(env.db, 'kunden');
      final int rechnungenBefore = await _count(env.db, 'rechnungen');

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde_ag.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.complete);
      expect(result.archivePath, destination);
      expect(result.complete, isTrue);
      expect(File(destination).existsSync(), isTrue);
      expect(result.message, 'Export abgeschlossen und geprüft.');

      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect(manifest['archive_version'], 1);
      expect(manifest['record_version'], 1);
      expect(manifest['record_projection_version'], 1);
      expect(manifest['schema_version'], MigrationRunner.currentVersion);
      expect((manifest['customer']! as Map)['id'], customerId);
      expect(manifest['complete'], isTrue);
      expect(manifest['outcome'], 'complete');
      expect(manifest['relationship_paths'], isNotEmpty);
      expect(manifest['exclusions'], isEmpty);
      final Map<String, Object?> counts = Map<String, Object?>.from(manifest['record_counts']! as Map);
      expect((counts['kunden']! as num).toInt(), 1);
      expect((counts['kunden_lieferadressen']! as num).toInt(), 1);
      // Seed invoice, address invoice, null-kunde storno child, konvertiert
      // pair, and the template source invoice: only declared links included.
      expect((counts['rechnungen']! as num).toInt(), 6);
      expect((counts['rechnungspositionen']! as num).toInt(), 1);
      expect((counts['mahnungen']! as num).toInt(), 1);
      expect((counts['forderungen']! as num).toInt(), 2);
      expect((counts['forderung_zahlungen']! as num).toInt(), 1);
      expect((counts['journal']! as num).toInt(), 3);
      expect((counts['vorsteuer_ansprueche']! as num).toInt(), 1);
      expect((counts['rechnungsvorlagen']! as num).toInt(), 1);
      expect((counts['rechnungsvorlagen_occurrences']! as num).toInt(), 1);
      expect((counts['kunden_belege']! as num).toInt(), 1);
      expect((counts['belege']! as num).toInt(), 1);
      final List<Object?> evidence = List<Object?>.from(manifest['evidence']! as List);
      expect(evidence, hasLength(3));
      final List<Object?> recordFiles = List<Object?>.from(manifest['record_files']! as List);
      expect(recordFiles, hasLength(14));
      for (final Object? entry in recordFiles) {
        expect((entry! as Map)['sha256'].toString(), hasLength(64));
      }

      final String rechnungenJsonl = utf8.decode(await service.readEntry(destination, 'records/rechnungen.jsonl'));
      expect(rechnungenJsonl, contains('RE-A-1'));
      expect(rechnungenJsonl, isNot(contains('RE-B-1')));
      expect(rechnungenJsonl, isNot(contains('lieferant_id')));
      final String belegeJsonl = utf8.decode(await service.readEntry(destination, 'records/belege.jsonl'));
      final Map<String, Object?> beleg = Map<String, Object?>.from(jsonDecode(belegeJsonl.trim()) as Map);
      expect(beleg['dateiname'], '123_beleg.pdf');
      expect(beleg['original_name'], 'beleg.pdf');
      expect(beleg['mime_type'], 'application/pdf');
      expect(beleg['dateigroesse'], 3);
      expect(beleg['sha256'], sha256.convert(<int>[9, 8, 7]).toString());
      expect(beleg['hochgeladen_am'], '2026-01-15T10:30:00.000');
      expect(beleg['loeschdatum'], '2027-01-15');
      expect(beleg['dateipfad'], startsWith('evidence/'));
      expect(beleg['beleg_pdfa_pfad'], startsWith('evidence/'));
      expect(belegeJsonl, isNot(contains(env.profileDir.path)));

      // Source records remain unchanged and no partial sibling is left behind.
      expect(await _count(env.db, 'kunden'), kundenBefore);
      expect(await _count(env.db, 'rechnungen'), rechnungenBefore);
      expect(
        env.outDir.listSync().map((FileSystemEntity e) => p.basename(e.path)).where((String n) => n != 'kunde_ag.zip'),
        isEmpty,
      );

      // A booking-template occurrence is projected as an event row without
      // its unrelated vorlage_id; the by-design omission is fail-closed.
      await BuchungsVorlagenRepository(env.db.executor).ensureSchema();
      final int bookingTemplate = await env.db.executor.runInsert(
        'INSERT INTO buchungsvorlagen (name) VALUES (?)',
        const <Object?>['B-Vorlage'],
      );
      final List<Map<String, Object?>> journals = await env.db.executor.runSelect(
        'SELECT id FROM journal ORDER BY id LIMIT 1',
        const <Object?>[],
      );
      await env.db.executor.runInsert(
        'INSERT INTO buchungsvorlagen_occurrences (vorlage_id, faelligkeit, journal_id) VALUES (?, ?, ?)',
        <Object?>[bookingTemplate, '2026-04-01', journals.single['id']],
      );
      final CustomerDisclosureResult withOccurrence = await service.exportCustomer(
        customerId: customerId,
        destinationPath: p.join(env.outDir.path, 'kunde_ag_occ.zip'),
      );
      expect(withOccurrence.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> occManifest = await service.readManifest(p.join(env.outDir.path, 'kunde_ag_occ.zip'));
      final List<Object?> omitted = List<Object?>.from(occManifest['omitted_fields']! as List);
      expect(
        omitted.where(
          (Object? e) => (e! as Map)['field'] == 'vorlage_id' && (e as Map)['reason'] == 'omitted_unrelated',
        ),
        hasLength(1),
      );
      final String occJsonl = utf8.decode(
        await service.readEntry(
          p.join(env.outDir.path, 'kunde_ag_occ.zip'),
          'records/buchungsvorlagen_occurrences.jsonl',
        ),
      );
      expect(occJsonl, contains('2026-04-01'));
      expect(occJsonl, isNot(contains('vorlage_id')));
    });

    test('v29 customer disclosure export preserves persisted e-invoice tax tuple', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb(
        'disclosure_tax_v29_',
      );
      final int customerId = await _seedCustomer(env.db, 'Tax Evidence Customer');
      await _ensureInvoiceColumns(env.db);
      final int invoiceId = await _seedInvoice(env.db, customerId: customerId, number: 'RE-TAX-29');
      final int positionId = await env.db.executor.runInsert(
        'INSERT INTO rechnungspositionen (rechnung_id, bezeichnung, einzelpreis, gesamt) VALUES (?, ?, ?, ?)',
        <Object?>[invoiceId, 'Tax evidence line', '100.00', '100.00'],
      );
      await env.db.executor.runUpdate(
        'UPDATE rechnungspositionen SET tax_treatment = ?, tax_legal_basis = ?, e_invoice_tax_category_code = ? '
        'WHERE id = ?',
        <Object?>['standard_19', 'ustg_12_1', 'S', positionId],
      );

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'tax_evidence.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.complete);
      final String jsonl = utf8.decode(await service.readEntry(destination, 'records/rechnungspositionen.jsonl'));
      final Map<String, Object?> position = Map<String, Object?>.from(jsonDecode(jsonl.trim()) as Map);
      expect(position['tax_treatment'], 'standard_19');
      expect(position['tax_legal_basis'], 'ustg_12_1');
      expect(position['e_invoice_tax_category_code'], 'S');
    });

    test('test_customer_data_disclosure_export_002_no_customer_is_selected_or_the_id_is_invalid', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_002_');
      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);

      final CustomerDisclosureResult missing = await service.exportCustomer(
        customerId: null,
        destinationPath: p.join(env.outDir.path, 'a.zip'),
      );
      expect(missing.status, CustomerDisclosureExportStatus.failed);
      expect(missing.archivePath, isNull);
      expect(File(p.join(env.outDir.path, 'a.zip')).existsSync(), isFalse);

      final CustomerDisclosureResult unknown = await service.exportCustomer(
        customerId: 999999,
        destinationPath: p.join(env.outDir.path, 'b.zip'),
      );
      expect(unknown.status, CustomerDisclosureExportStatus.failed);
      expect(unknown.message, contains('nicht gefunden'));
      expect(unknown.archivePath, isNull);
      expect(File(p.join(env.outDir.path, 'b.zip')).existsSync(), isFalse);
    });

    test('test_customer_data_disclosure_export_003_unlinked_data_is_not_guessed', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_003_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await _seedLinkedRecords(env.db, env.profileDir, customerId);
      final int konto = await env.db.executor.runInsert('INSERT INTO konten (name) VALUES (?)', const <Object?>[
        'Giro',
      ]);
      await env.db.executor.runInsert(
        'INSERT INTO bank_transaktionen (konto_id, datum, betrag, verwendungszweck) VALUES (?, ?, ?, ?)',
        <Object?>[konto, '2026-01-20', '25.00', 'Überweisung Kunde AG Rechnung'],
      );
      await env.db.executor.runInsert(
        "INSERT INTO journal (datum, betrag, beschreibung) VALUES ('2026-01-21', '25.00', 'Kunde AG bar erhalten')",
        const <Object?>[],
      );

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.complete);
      final List<String> entries = await service.listEntries(destination);
      expect(entries, isNot(contains('records/bank_transaktionen.jsonl')));
      final String journalJsonl = utf8.decode(await service.readEntry(destination, 'records/journal.jsonl'));
      expect(journalJsonl, isNot(contains('bar erhalten')));
      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect(jsonEncode(manifest), contains('nicht gesucht'));
    });

    test('test_customer_data_disclosure_export_004_unclassified_fields_prevent_a_complete_outcome', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_004_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      final Map<String, int> ids = await _seedLinkedRecords(env.db, env.profileDir, customerId);
      await env.db.executor.runCustom('ALTER TABLE rechnungen ADD COLUMN kunde_spitzname TEXT');
      await env.db.executor.runUpdate('UPDATE rechnungen SET kunde_spitzname = ? WHERE id = ?', <Object?>[
        'Agi',
        ids['invoiceA'],
      ]);

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      expect(result.archivePath, destination);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect(manifest['complete'], isFalse);
      final List<Object?> omitted = List<Object?>.from(manifest['omitted_fields']! as List);
      expect(
        omitted.where(
          (Object? e) => (e! as Map)['field'] == 'kunde_spitzname' && (e as Map)['reason'] == 'unclassified_field',
        ),
        hasLength(1),
      );
      final String jsonl = utf8.decode(await service.readEntry(destination, 'records/rechnungen.jsonl'));
      expect(jsonl, isNot(contains('kunde_spitzname')));
      expect(jsonl, isNot(contains('Agi')));
    });

    test('test_customer_data_disclosure_export_conflicting_receivable_identity_is_excluded', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_conf_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await _seedLinkedRecords(env.db, env.profileDir, customerId);
      final int supplier = await env.db.executor.runInsert(
        "INSERT INTO lieferanten (anrede, name) VALUES ('Herr', 'Lieferant')",
        const <Object?>[],
      );
      await env.db.executor.runInsert(
        'INSERT INTO forderungen (kunde_id, betrag, typ, partner_typ, partner_id) VALUES (?, ?, ?, ?, ?)',
        <Object?>[customerId, '10.00', 'rechnung', 'lieferant', supplier],
      );

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
      expect(
        exclusions.where(
          (Object? e) => (e! as Map)['record_type'] == 'forderungen' && (e as Map)['reason'] == 'conflicting_identity',
        ),
        hasLength(1),
      );
      final Map<String, Object?> counts = Map<String, Object?>.from(manifest['record_counts']! as Map);
      expect((counts['forderungen']! as num).toInt(), 2);
    });

    test('test_customer_data_disclosure_export_005_linked_evidence_is_profile_local_and_readable', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_005_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await _seedLinkedRecords(env.db, env.profileDir, customerId);

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.complete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      final List<Object?> evidence = List<Object?>.from(manifest['evidence']! as List);
      expect(evidence, hasLength(3));
      for (final Object? entry in evidence) {
        final Map<String, Object?> item = Map<String, Object?>.from(entry! as Map);
        final String archivePath = item['archive_path'].toString();
        expect(p.isAbsolute(archivePath), isFalse);
        expect(archivePath, startsWith('evidence/'));
        expect(item['sha256'].toString(), hasLength(64));
        expect(await service.readEntry(destination, archivePath), isNotEmpty);
      }
      expect(jsonEncode(manifest), isNot(contains(env.profileDir.path)));
    });

    test('test_customer_data_disclosure_export_006_linked_evidence_is_missing_or_has_unresolved_thi', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_006_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await _seedLinkedRecords(env.db, env.profileDir, customerId);
      final int missingBeleg = await env.db.executor.runInsert(
        'INSERT INTO belege (datum, betrag, dateipfad) VALUES (?, ?, ?)',
        const <Object?>['2026-01-16', '5.00', 'fehlt.pdf'],
      );
      await env.db.executor.runInsert('INSERT INTO kunden_belege (kunde_id, beleg_id) VALUES (?, ?)', <Object?>[
        customerId,
        missingBeleg,
      ]);
      final int supplier = await env.db.executor.runInsert(
        "INSERT INTO lieferanten (anrede, name) VALUES ('Herr', 'Lieferant')",
        const <Object?>[],
      );
      final File supplierFile = File(p.join(env.profileDir.path, 'lieferant.pdf'));
      await supplierFile.writeAsBytes(<int>[7, 7, 7], flush: true);
      final int supplierBeleg = await env.db.executor.runInsert(
        'INSERT INTO belege (datum, betrag, lieferant_id, dateipfad) VALUES (?, ?, ?, ?)',
        <Object?>['2026-01-17', '9.99', supplier, supplierFile.path],
      );
      await env.db.executor.runInsert('INSERT INTO kunden_belege (kunde_id, beleg_id) VALUES (?, ?)', <Object?>[
        customerId,
        supplierBeleg,
      ]);

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      expect(result.message, 'Export unvollständig gespeichert. Bitte Hinweise prüfen.');
      final Map<String, Object?> manifest = await service.readManifest(destination);
      final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
      expect(exclusions.where((Object? e) => (e! as Map)['reason'] == 'missing'), hasLength(1));
      expect(exclusions.where((Object? e) => (e! as Map)['reason'] == 'unsupported'), hasLength(1));
      final List<Object?> evidence = List<Object?>.from(manifest['evidence']! as List);
      expect(evidence, hasLength(3));
    });

    test('test_customer_data_disclosure_export_007_profile_local_symlink_targets_evidence_outside_t', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_007_');
      final Directory external = await Directory.systemTemp.createTemp('disclosure_007_ext_');
      addTearDown(() async {
        if (external.existsSync()) await external.delete(recursive: true);
      });
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await _seedLinkedRecords(env.db, env.profileDir, customerId);
      final File target = File(p.join(external.path, 'extern.pdf'));
      await target.writeAsBytes(<int>[5, 5, 5], flush: true);
      final String linkPath = p.join(env.profileDir.path, 'verknuepfung.pdf');
      Link(linkPath).createSync(target.path);
      final int beleg = await env.db.executor.runInsert(
        'INSERT INTO belege (datum, betrag, beleg_pdfa_pfad) VALUES (?, ?, ?)',
        <Object?>['2026-01-18', '3.00', linkPath],
      );
      await env.db.executor.runInsert('INSERT INTO kunden_belege (kunde_id, beleg_id) VALUES (?, ?)', <Object?>[
        customerId,
        beleg,
      ]);

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
      expect(
        exclusions.where(
          (Object? e) => (e! as Map)['field'] == 'beleg_pdfa_pfad' && (e as Map)['reason'] == 'outside_profile',
        ),
        hasLength(1),
      );
      final String encoded = jsonEncode(manifest);
      expect(encoded, isNot(contains(external.path)));
      expect(encoded, isNot(contains(env.profileDir.path)));
      final List<Object?> evidence = List<Object?>.from(manifest['evidence']! as List);
      expect(evidence, hasLength(3));
    });

    test('test_customer_data_disclosure_export_008_user_sees_the_export_scope_before_saving', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_008_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      final CustomerDisclosureExportAction action = CustomerDisclosureExportAction(
        customers: KundenRepository(env.db.executor),
        exportService: _service(env.db, env.profileDir),
      );

      final CustomerDisclosureActionOutcome scope = await action.describeScope(customerId);

      expect(scope.status, CustomerDisclosureFlowStatus.confirming);
      expect(scope.message, contains('ausschließlich diesen Kunden'));
      expect(scope.message, contains('verifizierten Verknüpfungen'));
      expect(scope.message, contains('Freitext'));
      expect(scope.message, contains('unvollständig'));
      expect(scope.message, contains('kein Profil-Archiv'));
      expect(scope.message, contains('kein Backup'));
      expect(scope.message, contains('weder gelöscht noch anonymisiert'));
    });

    test('test_customer_data_disclosure_export_009_export_failure_or_cancellation', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_009_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await _seedLinkedRecords(env.db, env.profileDir, customerId);
      final int kundenBefore = await _count(env.db, 'kunden');
      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);

      final CustomerDisclosureResult cancelled = await service.exportCustomer(
        customerId: customerId,
        destinationPath: p.join(env.outDir.path, 'abgebrochen.zip'),
        isCancelled: () => true,
      );
      expect(cancelled.status, CustomerDisclosureExportStatus.cancelled);
      expect(cancelled.message, 'Export abgebrochen. Es wurde kein Archiv erstellt.');
      expect(cancelled.archivePath, isNull);
      expect(File(p.join(env.outDir.path, 'abgebrochen.zip')).existsSync(), isFalse);

      final File blocker = File(p.join(env.outDir.path, 'blocker'));
      await blocker.writeAsString('x', flush: true);
      final CustomerDisclosureResult unwritable = await service.exportCustomer(
        customerId: customerId,
        destinationPath: p.join(blocker.path, 'x.zip'),
      );
      expect(unwritable.status, CustomerDisclosureExportStatus.failed);
      expect(unwritable.archivePath, isNull);

      final File existing = File(p.join(env.outDir.path, 'bestehend.zip'));
      await existing.writeAsString('SENTINEL', flush: true);
      final CustomerDisclosureResult conflict = await service.exportCustomer(
        customerId: customerId,
        destinationPath: existing.path,
      );
      expect(conflict.status, CustomerDisclosureExportStatus.failed);
      expect(conflict.message, contains('existiert bereits'));
      expect(await existing.readAsString(), 'SENTINEL');

      bool staged = false;
      final CustomerDisclosureResult cancelledLate = await service.exportCustomer(
        customerId: customerId,
        destinationPath: p.join(env.outDir.path, 'spaet.zip'),
        isCancelled: () => staged,
        onStaged: (_) {
          staged = true;
        },
      );
      expect(cancelledLate.status, CustomerDisclosureExportStatus.cancelled);
      expect(File(p.join(env.outDir.path, 'spaet.zip')).existsSync(), isFalse);
      expect(
        env.outDir
            .listSync()
            .map((FileSystemEntity e) => p.basename(e.path))
            .where((String n) => n.endsWith('.partial')),
        isEmpty,
      );
      expect(await _count(env.db, 'kunden'), kundenBefore);
    });

    test('test_customer_data_disclosure_export_010_retry_after_interrupted_archive_creation', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_010_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await _seedLinkedRecords(env.db, env.profileDir, customerId);
      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final File stale = File(p.join(env.outDir.path, '.openaccounting-customer-export-$customerId-kunde.zip.partial'));
      await stale.writeAsString('preserve-another-operation', flush: true);
      final File unrelated = File(p.join(env.outDir.path, 'wichtig.txt'));
      await unrelated.writeAsString('bleibt', flush: true);

      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(
        result.status,
        CustomerDisclosureExportStatus.complete,
        reason: result.exclusions
            .map((CustomerDisclosureExclusion e) => '${e.recordType}.${e.field}:${e.reason}')
            .join(', '),
      );
      expect(File(destination).existsSync(), isTrue);
      expect(await stale.readAsString(), 'preserve-another-operation');
      expect(await unrelated.readAsString(), 'bleibt');
    });

    test('test_customer_data_disclosure_export_011_keyboard_operation', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_011_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await _seedLinkedRecords(env.db, env.profileDir, customerId);
      final CustomerDisclosureExportController controller = CustomerDisclosureExportController(
        action: CustomerDisclosureExportAction(
          customers: KundenRepository(env.db.executor),
          exportService: _service(env.db, env.profileDir),
        ),
        customerId: customerId,
      );
      addTearDown(controller.dispose);

      final CustomerDisclosureActionOutcome outcome = await controller.activateViaKeyboard(
        destinationPath: p.join(env.outDir.path, 'tastatur.zip'),
      );

      expect(outcome.status, CustomerDisclosureFlowStatus.complete);
      expect(controller.status, CustomerDisclosureFlowStatus.complete);
      expect(controller.announcedStatus, 'Export abgeschlossen und geprüft.');
      expect(controller.announcedStatus, isNotEmpty);
    });

    testWidgets('test_customer_data_disclosure_export_012_cancel_destination_selection_in_a_narrow_window', (
      WidgetTester tester,
    ) async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = (await tester.runAsync(
        () => _openCustomerDb('disclosure_012_'),
      ))!;
      final int customerId = (await tester.runAsync(() => _seedCustomer(env.db, 'Kunde AG')))!;
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final CustomerDisclosureExportController controller = CustomerDisclosureExportController(
        action: CustomerDisclosureExportAction(
          customers: KundenRepository(env.db.executor),
          exportService: _service(env.db, env.profileDir),
        ),
        customerId: customerId,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: CustomerDisclosureExportButton(controller: controller, selectDestination: () async => null),
          ),
        ),
      );
      expect(MediaQuery.sizeOf(tester.element(find.byType(Scaffold))), const Size(320, 600));

      await tester.tap(find.text('Kundendaten exportieren'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Auskunfts-Export: Umfang'), findsOneWidget);

      await tester.tap(find.text('Abbrechen'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Auskunfts-Export: Umfang'), findsNothing);
      expect(find.text('Export abgebrochen. Es wurde kein Archiv erstellt.'), findsOneWidget);
      expect(controller.status, CustomerDisclosureFlowStatus.cancelled);
      expect(controller.focusTarget, CustomerDisclosureExportController.focusReturnTarget);
      expect(env.outDir.listSync(), isEmpty);
      expect(tester.takeException(), isNull);
    });

    test('test_customer_data_disclosure_export_013_unknown_table_state_prevents_complete_disclosure', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_013_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await _seedLinkedRecords(env.db, env.profileDir, customerId);
      await env.db.executor.runUpdate(
        "UPDATE feature_table_state SET state = 'unknown' WHERE table_name = 'rechnungsvorlagen_occurrences'",
        const <Object?>[],
      );
      await env.db.executor.runCustom('DROP TABLE rechnungsvorlagen_occurrences');

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect((manifest['table_health']! as Map)['rechnungsvorlagen_occurrences'], 'unknown');
      expect((manifest['table_health']! as Map)['mileage_posting_account_mapping'], 'ok');
      final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
      expect(
        exclusions.where((Object? e) => (e! as Map)['record_type'] == 'rechnungsvorlagen_occurrences'),
        isNotEmpty,
      );
      expect(jsonEncode(manifest), isNot(contains(env.profileDir.path)));
      final List<Map<String, Object?>> tables = await env.db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'rechnungsvorlagen_occurrences'",
        const <Object?>[],
      );
      expect(tables, isEmpty, reason: 'Exporter creates or repairs no table');
    });

    test('test_customer_data_disclosure_export_014_pre_v9_profile_remains_valid_but_is_not_a_comple', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_014_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await env.db.executor.runCustom('DROP TABLE feature_table_state');
      await env.db.executor.runCustom('DROP TABLE mileage_trip_corrections');
      await env.db.executor.runCustom('DROP TABLE mileage_trips');
      await env.db.executor.runCustom('DROP TABLE category_mapping_history');
      await env.db.executor.runCustom('PRAGMA user_version = 8');

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect((manifest['table_health']! as Map)['schema_version'], 'version_pending');
      // The older profile itself stays valid and readable.
      expect(env.db.isOpen, isTrue);
      expect(await KundenRepository(env.db.executor).findById(customerId), isNotNull);
    });

    test('test_customer_data_disclosure_export_015_missing_payment_table_is_detected_before_startup', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_015_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await env.db.executor.runCustom('DROP TABLE forderung_zahlungen');
      await env.db.executor.runCustom('PRAGMA user_version = 8');

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, isNot(CustomerDisclosureExportStatus.complete));
      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect((manifest['table_health']! as Map)['forderung_zahlungen'], 'missing');
      final List<Map<String, Object?>> tables = await env.db.executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'forderung_zahlungen'",
        const <Object?>[],
      );
      expect(tables, isEmpty, reason: 'No empty replacement table is created');
    });

    test('v25 disclosure health rejects malformed mileage mapping and closure constraints', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb(
        'disclosure_mileage_schema_',
      );
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      final List<({String table, String sql})> malformedSchemas = <({String table, String sql})>[
        (
          table: 'mileage_posting_account_mapping',
          sql: '''
CREATE TABLE mileage_posting_account_mapping (
  role TEXT NOT NULL CHECK (role IN ('travel_expense', 'private_contribution')),
  konto_id INTEGER NOT NULL REFERENCES konten(id) ON DELETE RESTRICT,
  kategorie_id INTEGER NOT NULL REFERENCES kategorien(id) ON DELETE RESTRICT,
  reviewed_at TEXT NOT NULL CHECK (trim(reviewed_at) <> '')
)''',
        ),
        (
          table: 'mileage_posting_account_mapping',
          sql: '''
CREATE TABLE mileage_posting_account_mapping (
  role TEXT PRIMARY KEY NOT NULL CHECK (role IN ('travel_expense', 'private_contribution')),
  konto_id INTEGER NOT NULL REFERENCES konten(id) ON DELETE RESTRICT,
  kategorie_id INTEGER NOT NULL,
  reviewed_at TEXT NOT NULL CHECK (trim(reviewed_at) <> '')
)''',
        ),
        (
          table: 'mileage_posting_account_mapping',
          sql: '''
CREATE TABLE mileage_posting_account_mapping (
  role TEXT PRIMARY KEY NOT NULL CHECK (role IN ('travel_expense', 'private_contribution', 'unsupported')),
  konto_id INTEGER NOT NULL REFERENCES konten(id) ON DELETE RESTRICT,
  kategorie_id INTEGER NOT NULL REFERENCES kategorien(id) ON DELETE RESTRICT,
  reviewed_at TEXT NOT NULL CHECK (trim(reviewed_at) <> '')
)''',
        ),
        (
          table: 'mileage_posting_period_closures',
          sql: '''
CREATE TABLE mileage_posting_period_closures (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  closed_from TEXT NOT NULL,
  closed_through TEXT NOT NULL CHECK (strftime('%Y-%m-%d', closed_through) IS closed_through),
  closed_at TEXT NOT NULL CHECK (trim(closed_at) <> ''),
  CHECK (closed_from <= closed_through)
)''',
        ),
        (
          table: 'mileage_posting_period_closures',
          sql: '''
CREATE TABLE mileage_posting_period_closures (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  closed_from TEXT NOT NULL CHECK (strftime('%Y-%m-%d', closed_from) IS closed_from),
  closed_through TEXT NOT NULL CHECK (strftime('%Y-%m-%d', closed_through) IS closed_through),
  closed_at TEXT NOT NULL CHECK (trim(closed_at) <> '')
)''',
        ),
      ];
      final List<String?> observedHealth = <String?>[];
      for (var index = 0; index < malformedSchemas.length; index++) {
        final ({String table, String sql}) fixture = malformedSchemas[index];
        await env.db.executor.runCustom('DROP TABLE ${fixture.table}');
        await env.db.executor.runCustom(fixture.sql);
        final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
        final String destination = p.join(env.outDir.path, 'schema-$index.zip');
        final CustomerDisclosureResult result = await service.exportCustomer(
          customerId: customerId,
          destinationPath: destination,
        );
        final Map<String, Object?> manifest = await service.readManifest(destination);
        observedHealth.add((manifest['table_health']! as Map)[fixture.table]?.toString());
        expect(result.status, isNot(CustomerDisclosureExportStatus.complete));
      }
      expect(observedHealth, everyElement('malformed'));
    });

    test('test_v25_customer_disclosure_treats_opening_source_as_pending', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb(
        'disclosure_v25_opening_source_',
      );
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await env.db.executor.runCustom('DROP TABLE account_opening_balance_sources');
      await env.db.executor.runCustom('PRAGMA user_version = 25');

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde_v25.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect((manifest['table_health']! as Map)['account_opening_balance_sources'], 'version_pending');
      expect(await service.listEntries(destination), isNot(contains('records/account_opening_balance_sources.jsonl')));
    });

    test('test_v26_customer_disclosure_checks_but_does_not_project_opening_sources', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb(
        'disclosure_v26_opening_source_',
      );
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      final SetupRepository setup = SetupRepository(env.db.executor);
      await setup.saveUnternehmen(name: 'Opening Source Disclosure Test GmbH');
      await setup.runInTransaction<void>(
        (SetupRepository transactionRepository) => transactionRepository.ensureKassenKonto(betrag: '125.00'),
      );
      await env.db.executor.runCustom('PRAGMA user_version = 26');

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde_v26.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect((manifest['table_health']! as Map)['account_opening_balance_sources'], 'ok');
      expect(await service.listEntries(destination), isNot(contains('records/account_opening_balance_sources.jsonl')));
    });

    test('test_v26_customer_disclosure_rejects_malformed_opening_source_schema', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb(
        'disclosure_v26_malformed_opening_source_',
      );
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await env.db.executor.runCustom('DROP TRIGGER account_opening_balance_sources_no_replace');
      await env.db.executor.runCustom('PRAGMA user_version = 26');

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde_v26_malformed.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect((manifest['table_health']! as Map)['account_opening_balance_sources'], 'malformed');
      expect(await service.listEntries(destination), isNot(contains('records/account_opening_balance_sources.jsonl')));
    });

    test('test_v26_customer_disclosure_rejects_nocase_opening_source_unique_index', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb(
        'disclosure_v26_nocase_opening_source_',
      );
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      final List<Map<String, Object?>> tableRows = await env.db.executor.runSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
        const <Object?>['account_opening_balance_sources'],
      );
      expect(tableRows, hasLength(1));
      final String originalTableSql = tableRows.single['sql']! as String;
      const String sourceReferenceDeclaration = 'source_reference TEXT NOT NULL';
      expect(originalTableSql, contains(sourceReferenceDeclaration));
      final String nocaseTableSql = originalTableSql.replaceFirst(
        sourceReferenceDeclaration,
        'source_reference TEXT COLLATE NOCASE NOT NULL',
      );
      expect(nocaseTableSql, isNot(originalTableSql));

      final List<Map<String, Object?>> triggerRows = await env.db.executor.runSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'trigger' AND tbl_name = ? ORDER BY name",
        const <Object?>['account_opening_balance_sources'],
      );
      expect(triggerRows, hasLength(3));
      await env.db.executor.runCustom('DROP TABLE account_opening_balance_sources');
      await env.db.executor.runCustom(nocaseTableSql);
      for (final Map<String, Object?> trigger in triggerRows) {
        await env.db.executor.runCustom(trigger['sql']! as String);
      }

      final List<Map<String, Object?>> uniqueIndexes = (await env.db.executor.runSelect(
        'PRAGMA index_list(account_opening_balance_sources)',
        const <Object?>[],
      )).where((Map<String, Object?> index) => ((index['unique'] as num?)?.toInt() ?? 0) == 1).toList();
      expect(uniqueIndexes, hasLength(3));
      final List<String> sourceReferenceCollations = <String>[];
      for (final Map<String, Object?> index in uniqueIndexes) {
        final String indexName = (index['name']! as String).replaceAll('"', '""');
        final List<Map<String, Object?>> fields = await env.db.executor.runSelect(
          'PRAGMA index_xinfo("$indexName")',
          const <Object?>[],
        );
        final List<Map<String, Object?>> keyFields = fields
            .where((Map<String, Object?> field) => ((field['key'] as num?)?.toInt() ?? 0) == 1)
            .toList();
        if (keyFields.map((Map<String, Object?> field) => field['name']).join(',') == 'source_reference') {
          sourceReferenceCollations.add(keyFields.single['coll']!.toString());
        }
      }
      expect(sourceReferenceCollations, <String>['NOCASE']);

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde_v26_nocase.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect((manifest['table_health']! as Map)['account_opening_balance_sources'], 'malformed');
      expect(await service.listEntries(destination), isNot(contains('records/account_opening_balance_sources.jsonl')));
    });

    test('test_customer_data_disclosure_export_016_mileage_and_category_tables_remain_outside_custo', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_016_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await _seedLinkedRecords(env.db, env.profileDir, customerId);
      await env.db.executor.runInsert(
        'INSERT INTO mileage_trips (id, trip_date, purpose, business_context, distance_hundredths_km, state, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        const <Object?>[
          'trip-1',
          '2026-01-10',
          'Besuch Kunde AG',
          'Kontext',
          100,
          'unresolved',
          '2026-01-10',
          '2026-01-10',
        ],
      );
      await env.db.executor.runInsert(
        'INSERT OR IGNORE INTO kategorien (id, bezeichnung) VALUES (?, ?)',
        const <Object?>[1, 'Fixture'],
      );
      await env.db.executor.runInsert(
        'INSERT INTO category_mapping_history (kategorie_id, geaendert_am, aktion, nachher_mapping_json) '
        'VALUES (?, ?, ?, ?)',
        <Object?>[1, '2026-01-10', 'migration', '{"mapping_status":"Kunde AG"}'],
      );

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.complete);
      final List<String> entries = await service.listEntries(destination);
      expect(entries, isNot(contains('records/mileage_trips.jsonl')));
      expect(entries, isNot(contains('records/category_mapping_history.jsonl')));
      expect(entries, isNot(contains('records/feature_table_state.jsonl')));
      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect(jsonEncode(manifest), isNot(contains('trip-1')));
      expect(jsonEncode(manifest), isNot(contains('Besuch Kunde AG')));
    });

    test('customer disclosure action exports scoped records directly', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_042_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await _seedLinkedRecords(env.db, env.profileDir, customerId);
      final CustomerDisclosureExportAction action = CustomerDisclosureExportAction(
        customers: KundenRepository(env.db.executor),
        exportService: _service(env.db, env.profileDir),
      );
      final String destination = p.join(env.outDir.path, 'detail.zip');

      final CustomerDisclosureActionOutcome outcome = await action.run(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(outcome.status, CustomerDisclosureFlowStatus.complete);
      expect(outcome.message, isNotEmpty);
      expect(outcome.archivePath, destination);
      expect(File(destination).existsSync(), isTrue);
    });

    test('test_customer_data_disclosure_export_043_export_service_is_unavailable', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_043_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      final CustomerDisclosureExportAction action = CustomerDisclosureExportAction(
        customers: KundenRepository(env.db.executor),
      );

      expect(action.isAvailable, isFalse);
      final CustomerDisclosureActionOutcome scope = await action.describeScope(customerId);
      expect(scope.status, CustomerDisclosureFlowStatus.unavailable);
      expect(scope.message, 'Auskunfts-Export ist nicht verfügbar.');
      final CustomerDisclosureActionOutcome outcome = await action.run(
        customerId: customerId,
        destinationPath: p.join(env.outDir.path, 'detail.zip'),
      );
      expect(outcome.status, CustomerDisclosureFlowStatus.unavailable);
      expect(outcome.archivePath, isNull);
      // No fallback to whole-profile export or raw table output.
      expect(env.outDir.listSync(), isEmpty);
    });

    test('test_customer_data_disclosure_export_044_linked_settlements_are_reported_as_unsupported', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_044_');
      await _ensureSettlementTables(env.db);
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      final Map<String, int> linked = await _seedLinkedRecords(env.db, env.profileDir, customerId);
      final int otherCustomerId = await _seedCustomer(env.db, 'Other AG');
      final int otherReceivableId = await env.db.executor.runInsert(
        'INSERT INTO forderungen (kunde_id, betrag, typ, partner_typ, partner_id) VALUES (?, ?, ?, ?, ?)',
        <Object?>[otherCustomerId, '20.00', 'rechnung', 'kunde', otherCustomerId],
      );
      final int journalId = await env.db.executor.runInsert(
        "INSERT INTO journal (datum, betrag, beschreibung) VALUES ('2026-04-01', '100.00', 'Settlement')",
        const <Object?>[],
      );
      final int groupId = await env.db.executor.runInsert(
        'INSERT INTO settlement_groups (source_kind, source_id, signed_amount_cents, settlement_date, '
        'group_root_journal_id) VALUES (?, ?, ?, ?, ?)',
        <Object?>['test', 'source-044', 10000, '2026-04-01', journalId],
      );
      await env.db.executor.runInsert(
        'INSERT INTO settlement_allocations (group_id, forderung_id, applied_cents, settlement_date) '
        'VALUES (?, ?, ?, ?)',
        <Object?>[groupId, linked['forderungA'], 10000, '2026-04-01'],
      );
      await env.db.executor.runInsert(
        'INSERT INTO settlement_allocations (group_id, forderung_id, applied_cents, settlement_date) '
        'VALUES (?, ?, ?, ?)',
        <Object?>[groupId, otherReceivableId, 2000, '2026-04-01'],
      );

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
      expect(
        exclusions.where(
          (Object? item) =>
              item is Map && item['record_type'] == 'settlement_allocations' && item['reason'] == 'unsupported',
        ),
        hasLength(1),
      );
      final List<String> entries = await service.listEntries(destination);
      expect(entries, isNot(contains('records/settlement_groups.jsonl')));
      expect(entries, isNot(contains('records/settlement_allocations.jsonl')));
    });

    test(
      'test_customer_data_disclosure_export_045_linked_document_email_attempts_are_reported_as_unsupported',
      () async {
        final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_045_');
        final int customerId = await _seedCustomer(env.db, 'Kunde AG');
        final Map<String, int> linked = await _seedLinkedRecords(env.db, env.profileDir, customerId);
        await _ensureEmailAttemptTable(env.db);
        await env.db.executor.runInsert(
          'INSERT INTO dokument_email_versuche '
          '(dokument_id, dokument_typ, empfaenger, ergebnis, idempotenz_schluessel, erstellt_am) '
          'VALUES (?, ?, ?, ?, ?, ?)',
          <Object?>[
            linked['invoiceA'],
            'rechnung',
            'third-party@example.invalid',
            'accepted',
            'attempt-045',
            '2026-04-01T00:00:00Z',
          ],
        );

        final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
        final String destination = p.join(env.outDir.path, 'kunde.zip');
        final CustomerDisclosureResult result = await service.exportCustomer(
          customerId: customerId,
          destinationPath: destination,
        );

        expect(result.status, CustomerDisclosureExportStatus.incomplete);
        final Map<String, Object?> manifest = await service.readManifest(destination);
        final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
        expect(
          exclusions.where(
            (Object? item) =>
                item is Map && item['record_type'] == 'dokument_email_versuche' && item['reason'] == 'unsupported',
          ),
          hasLength(1),
        );
        final List<String> entries = await service.listEntries(destination);
        expect(entries, isNot(contains('records/dokument_email_versuche.jsonl')));
        expect(
          utf8.decode(await service.readEntry(destination, 'manifest.json')),
          isNot(contains('third-party@example.invalid')),
        );
      },
    );

    test('test_customer_data_disclosure_export_061_foreign_invoice_template_reference_is_omitted', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_061_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      final Map<String, int> linked = await _seedLinkedRecords(env.db, env.profileDir, customerId);
      final int otherCustomerId = await _seedCustomer(env.db, 'Other AG');
      final int templateId = await env.db.executor.runInsert(
        'INSERT INTO rechnungsvorlagen (name, kunde_id, intervall) VALUES (?, ?, ?)',
        <Object?>['Private template', otherCustomerId, 'monatlich'],
      );
      await env.db.executor.runUpdate('UPDATE rechnungen SET vorlage_id = ? WHERE id = ?', <Object?>[
        templateId,
        linked['invoiceA'],
      ]);

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final List<Map<String, Object?>> invoices = <Map<String, Object?>>[
        for (final String line
            in utf8.decode(await service.readEntry(destination, 'records/rechnungen.jsonl')).split('\n'))
          if (line.isNotEmpty) Map<String, Object?>.from(jsonDecode(line) as Map),
      ];
      final Map<String, Object?> invoice = invoices.singleWhere(
        (Map<String, Object?> row) => row['id'] == linked['invoiceA'],
      );
      expect(invoice, isNot(contains('vorlage_id')));
      final Map<String, Object?> manifest = await service.readManifest(destination);
      final List<Object?> omissions = List<Object?>.from(manifest['omitted_fields']! as List);
      expect(
        omissions.where(
          (Object? item) =>
              item is Map &&
              item['record_type'] == 'rechnungen' &&
              item['record_id'] == linked['invoiceA'].toString() &&
              item['field'] == 'vorlage_id' &&
              item['reason'] == 'omitted_cross_party',
        ),
        hasLength(1),
      );
    });

    test('test_customer_data_disclosure_export_062_dangling_customer_receipt_link_is_reported', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_062_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await env.db.executor.runCustom('PRAGMA foreign_keys = OFF');
      final int linkId = await env.db.executor.runInsert(
        'INSERT INTO kunden_belege (kunde_id, beleg_id) VALUES (?, ?)',
        <Object?>[customerId, 999999],
      );
      await env.db.executor.runCustom('PRAGMA foreign_keys = ON');

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
      expect(
        exclusions.where(
          (Object? item) =>
              item is Map &&
              item['record_type'] == 'kunden_belege' &&
              item['record_id'] == linkId.toString() &&
              item['field'] == 'beleg_id' &&
              item['reason'] == 'missing',
        ),
        hasLength(1),
      );
      final String links = utf8.decode(await service.readEntry(destination, 'records/kunden_belege.jsonl'));
      expect(links, isNot(contains('"id":$linkId')));
    });

    test('test_customer_data_disclosure_export_063_dangling_receivable_journal_targets_are_reported', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_063_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      final Map<String, int> linked = await _seedLinkedRecords(env.db, env.profileDir, customerId);
      await env.db.executor.runCustom('PRAGMA foreign_keys = OFF');
      await env.db.executor.runUpdate(
        'UPDATE forderungen SET journal_id = ?, ausgleich_journal_id = ? WHERE id = ?',
        <Object?>[999997, 999998, linked['forderungA']],
      );
      await env.db.executor.runUpdate('UPDATE forderung_zahlungen SET journal_id = ? WHERE forderung_id = ?', <Object?>[
        999996,
        linked['forderungA'],
      ]);
      await env.db.executor.runCustom('PRAGMA foreign_keys = ON');

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
      expect(
        exclusions.where(
          (Object? item) =>
              item is Map &&
              item['record_type'] == 'forderungen' &&
              item['record_id'] == linked['forderungA'].toString() &&
              <String?>{'journal_id', 'ausgleich_journal_id'}.contains(item['field'] as String?) &&
              item['reason'] == 'missing',
        ),
        hasLength(2),
      );
      expect(
        exclusions.where(
          (Object? item) =>
              item is Map &&
              item['record_type'] == 'forderung_zahlungen' &&
              item['field'] == 'journal_id' &&
              item['reason'] == 'missing',
        ),
        hasLength(1),
      );
    });

    test('test_customer_data_disclosure_export_047_dangling_invoice_lineage_excludes_the_invoice', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_047_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await _ensureInvoiceColumns(env.db);
      final int invoiceId = await _seedInvoice(env.db, customerId: customerId, number: 'RE-DANGLING-047');
      await env.db.executor.runCustom('PRAGMA foreign_keys = OFF');
      await env.db.executor.runUpdate('UPDATE rechnungen SET ersatz_fuer = ? WHERE id = ?', <Object?>[
        999999,
        invoiceId,
      ]);
      await env.db.executor.runCustom('PRAGMA foreign_keys = ON');

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
      expect(
        exclusions.where(
          (Object? item) =>
              item is Map &&
              item['record_type'] == 'rechnungen' &&
              item['record_id'] == invoiceId.toString() &&
              item['field'] == 'ersatz_fuer' &&
              item['reason'] == 'missing',
        ),
        hasLength(1),
      );
      final String invoices = utf8.decode(await service.readEntry(destination, 'records/rechnungen.jsonl'));
      expect(invoices, isNot(contains('RE-DANGLING-047')));
    });

    test('test_customer_data_disclosure_export_049_foreign_customer_reminder_is_excluded', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_049_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      final int otherCustomerId = await _seedCustomer(env.db, 'Fremd GmbH');
      await _ensureInvoiceColumns(env.db);
      final int invoiceId = await _seedInvoice(env.db, customerId: customerId, number: 'RE-REMINDER-049');
      const String privateReminderNumber = 'PRIVATE-FOREIGN-REMINDER-049';
      final int reminderId = await env.db.executor.runInsert(
        'INSERT INTO mahnungen (rechnung_id, kunde_id, datum, betrag) VALUES (?, ?, ?, ?)',
        <Object?>[invoiceId, otherCustomerId, privateReminderNumber, '987654.32'],
      );

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
      expect(
        exclusions.where(
          (Object? item) =>
              item is Map &&
              item['record_type'] == 'mahnungen' &&
              item['record_id'] == reminderId.toString() &&
              item['field'] == 'kunde_id' &&
              item['reason'] == 'conflicting_identity',
        ),
        hasLength(1),
      );
      final String reminders = utf8.decode(await service.readEntry(destination, 'records/mahnungen.jsonl'));
      expect(reminders, isNot(contains(privateReminderNumber)));
      expect(reminders, isNot(contains('987654.32')));
    });

    test('test_customer_data_disclosure_export_050_publish_does_not_replace_a_concurrent_destination', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_050_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      const String sentinel = 'CREATED-DURING-EXPORT-050';

      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
        onStaged: (_) => File(destination).writeAsStringSync(sentinel, flush: true),
      );

      expect(result.status, CustomerDisclosureExportStatus.failed);
      expect(await File(destination).readAsString(), sentinel);
      expect(
        env.outDir.listSync().where((FileSystemEntity entity) => p.basename(entity.path).endsWith('.partial')),
        isEmpty,
      );
    });

    test('test_customer_data_disclosure_export_051_direct_invoice_lineage_mismatch_is_excluded', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_051_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await _ensureInvoiceColumns(env.db);
      final int sourceId = await _seedInvoice(env.db, customerId: customerId, number: 'RE-MISMATCH-SOURCE-051');
      final int targetId = await _seedInvoice(env.db, customerId: customerId, number: 'RE-MISMATCH-TARGET-051');
      final int unexpectedId = await _seedInvoice(env.db, customerId: customerId, number: 'RE-MISMATCH-UNEXPECTED-051');
      await env.db.executor.runUpdate('UPDATE rechnungen SET konvertiert_zu = ? WHERE id = ?', <Object?>[
        targetId,
        sourceId,
      ]);
      await env.db.executor.runUpdate('UPDATE rechnungen SET konvertiert_von = ? WHERE id = ?', <Object?>[
        unexpectedId,
        targetId,
      ]);

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
      expect(
        exclusions.where(
          (Object? item) =>
              item is Map &&
              item['record_type'] == 'rechnungen' &&
              item['record_id'] == sourceId.toString() &&
              item['field'] == 'konvertiert_zu' &&
              item['reason'] == 'conflicting_identity',
        ),
        hasLength(1),
      );
      final String invoices = utf8.decode(await service.readEntry(destination, 'records/rechnungen.jsonl'));
      expect(invoices, isNot(contains('RE-MISMATCH-SOURCE-051')));
    });

    test('test_customer_data_disclosure_export_052_ambiguous_email_attempt_for_invoice_is_excluded', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_052_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await _ensureInvoiceColumns(env.db);
      const int invoiceId = 100;
      await env.db.executor.runInsert(
        'INSERT INTO rechnungen (id, rechnungsnummer, typ, status, kunde_id, datum) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[invoiceId, 'RE-EMAIL-052', 'rechnung', 'final', customerId, '2026-01-05'],
      );
      const String privateReminderRecipient = 'private-ambiguous-reminder-052@example.invalid';
      const String privateReminderKey = 'private-ambiguous-reminder-attempt-052';
      final int reminderId = await env.db.executor.runInsert(
        'INSERT INTO mahnungen (rechnung_id, kunde_id, datum, betrag) VALUES (?, ?, ?, ?)',
        <Object?>[invoiceId, customerId, '2026-02-01', '100.00'],
      );
      await _ensureEmailAttemptTable(env.db);
      const String privateRecipient = 'private-ambiguous-052@example.invalid';
      const String privateKey = 'private-ambiguous-attempt-052';
      await env.db.executor.runInsert(
        'INSERT INTO dokument_email_versuche (dokument_id, dokument_typ, empfaenger, ergebnis, '
        'idempotenz_schluessel, artefakt_ids, erstellt_am) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[invoiceId, 'unknown-document-type', privateRecipient, 'accepted', privateKey, '[]', '2026-02-01'],
      );
      await env.db.executor.runInsert(
        'INSERT INTO dokument_email_versuche (dokument_id, dokument_typ, empfaenger, ergebnis, '
        'idempotenz_schluessel, artefakt_ids, erstellt_am) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          reminderId,
          'unknown-document-type',
          privateReminderRecipient,
          'accepted',
          privateReminderKey,
          '[]',
          '2026-02-01',
        ],
      );

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
      expect(
        exclusions.where(
          (Object? item) =>
              item is Map && item['record_type'] == 'dokument_email_versuche' && item['reason'] == 'unsupported',
        ),
        hasLength(2),
      );
      final List<String> entries = await service.listEntries(destination);
      expect(entries, isNot(contains('records/dokument_email_versuche.jsonl')));
      expect(jsonEncode(manifest), isNot(contains(privateRecipient)));
      expect(jsonEncode(manifest), isNot(contains(privateKey)));
      expect(jsonEncode(manifest), isNot(contains(privateReminderRecipient)));
      expect(jsonEncode(manifest), isNot(contains(privateReminderKey)));
    });

    test('test_customer_data_disclosure_export_053_foreign_invoice_lineage_excludes_its_source', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_053_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      final int otherCustomerId = await _seedCustomer(env.db, 'Fremd GmbH');
      await _ensureInvoiceColumns(env.db);
      final int sourceId = await _seedInvoice(env.db, customerId: customerId, number: 'RE-SOURCE-053');
      final int foreignTargetId = await _seedInvoice(env.db, customerId: otherCustomerId, number: 'RE-FOREIGN-053');
      await env.db.executor.runUpdate('UPDATE rechnungen SET ersatz_fuer = ? WHERE id = ?', <Object?>[
        foreignTargetId,
        sourceId,
      ]);

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
      expect(
        exclusions.where(
          (Object? item) =>
              item is Map &&
              item['record_type'] == 'rechnungen' &&
              item['record_id'] == sourceId.toString() &&
              item['field'] == 'ersatz_fuer' &&
              item['reason'] == 'conflicting_identity',
        ),
        hasLength(1),
      );
      final String invoices = utf8.decode(await service.readEntry(destination, 'records/rechnungen.jsonl'));
      expect(invoices, isNot(contains('RE-SOURCE-053')));
      expect(invoices, isNot(contains('RE-FOREIGN-053')));
    });

    test('test_customer_data_disclosure_export_054_fails_when_stable_snapshot_cannot_be_created', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_054_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      final _FailingVacuumExecutor executor = _FailingVacuumExecutor(env.db.executor);
      final CustomerDataDisclosureExportService service = CustomerDataDisclosureExportService(
        executor: executor,
        profileDir: env.profileDir.path,
      );
      final String destination = p.join(env.outDir.path, 'kunde.zip');

      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.failed);
      expect(result.message, contains('konsistenten Stand'));
      expect(executor.snapshotPath, isNotNull);
      expect(p.isWithin(env.profileDir.path, executor.snapshotPath!), isTrue);
      expect(Directory(p.dirname(executor.snapshotPath!)).existsSync(), isFalse);
      expect(File(destination).existsSync(), isFalse);
    });

    test('test_customer_data_disclosure_export_055_rejects_extra_lazy_table_markers', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_055_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await _replaceLazyMarkersWithInvalidRows(env.db, duplicate: false);
      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);

      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: p.join(env.outDir.path, 'kunde.zip'),
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      expect(
        result.exclusions.where(
          (CustomerDisclosureExclusion exclusion) =>
              exclusion.recordType == 'feature_table_state' && exclusion.field == 'table_name',
        ),
        hasLength(1),
      );
    });

    test('test_customer_data_disclosure_export_056_rejects_duplicate_lazy_table_markers', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_056_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await _replaceLazyMarkersWithInvalidRows(env.db, duplicate: true);
      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);

      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: p.join(env.outDir.path, 'kunde.zip'),
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      expect(
        result.exclusions.where(
          (CustomerDisclosureExclusion exclusion) =>
              exclusion.recordType == 'feature_table_state' && exclusion.field == 'table_name',
        ),
        hasLength(1),
      );
    });

    test('test_customer_data_disclosure_export_057_concurrent_exports_reserve_distinct_partials', () async {
      final Directory firstProfileDir = await Directory.systemTemp.createTemp('disclosure_057_first_');
      final Directory secondProfileDir = await Directory.systemTemp.createTemp('disclosure_057_second_');
      final Directory outDir = await Directory.systemTemp.createTemp('disclosure_057_out_');
      final AppDatabase firstDb = AppDatabase.forTesting(
        NativeDatabase(File(p.join(firstProfileDir.path, 'profile.db')), enableMigrations: false),
        profileDir: firstProfileDir.path,
      );
      final AppDatabase secondDb = AppDatabase.forTesting(
        NativeDatabase(File(p.join(secondProfileDir.path, 'profile.db')), enableMigrations: false),
        profileDir: secondProfileDir.path,
      );
      addTearDown(() async {
        await firstDb.close();
        await secondDb.close();
        if (firstProfileDir.existsSync()) {
          await firstProfileDir.delete(recursive: true);
        }
        if (secondProfileDir.existsSync()) {
          await secondProfileDir.delete(recursive: true);
        }
        if (outDir.existsSync()) await outDir.delete(recursive: true);
      });
      await firstDb.ensureOpen();
      await secondDb.ensureOpen();
      final int customerId = await _seedCustomer(firstDb, 'Kunde AG');
      await _seedCustomer(secondDb, 'Kunde AG');
      final CustomerDataDisclosureExportService firstService = _service(firstDb, firstProfileDir);
      final CustomerDataDisclosureExportService secondService = _service(secondDb, secondProfileDir);
      final List<String> stagedPaths = <String>[];
      final Completer<void> bothStaged = Completer<void>();

      Future<void> waitForBothStages(String path) async {
        stagedPaths.add(path);
        if (stagedPaths.length == 2) bothStaged.complete();
        await bothStaged.future;
      }

      final List<CustomerDisclosureResult> results = await Future.wait(<Future<CustomerDisclosureResult>>[
        firstService.exportCustomer(
          customerId: customerId,
          destinationPath: p.join(outDir.path, 'kunde.zip'),
          onStaged: waitForBothStages,
        ),
        secondService.exportCustomer(
          customerId: customerId,
          destinationPath: p.join(outDir.path, 'kunde.zip'),
          onStaged: waitForBothStages,
        ),
      ]);

      expect(
        results.where((CustomerDisclosureResult result) => result.status == CustomerDisclosureExportStatus.complete),
        hasLength(1),
      );
      expect(
        results.where((CustomerDisclosureResult result) => result.status == CustomerDisclosureExportStatus.failed),
        hasLength(1),
      );
      expect(stagedPaths, hasLength(2));
      expect(stagedPaths.toSet(), hasLength(2));
      expect(stagedPaths.every((String path) => File(path).existsSync()), isFalse);
      expect(File(p.join(outDir.path, 'kunde.zip')).existsSync(), isTrue);
    });

    test('test_customer_data_disclosure_export_arb_keys_have_german_and_english_text', () {
      const List<String> keys = <String>[
        'customerDisclosureExportAction',
        'customerDisclosureExportScopeTitle',
        'customerDisclosureExportScopeDescription',
        'customerDisclosureExportConfirm',
        'customerDisclosureExportProgress',
        'customerDisclosureExportComplete',
        'customerDisclosureExportIncomplete',
        'customerDisclosureExportFailed',
        'customerDisclosureExportCancelled',
        'customerDisclosureExportUnavailable',
        'customerDisclosureExportNotFound',
        'customerDisclosureExportDestinationExists',
      ];
      for (final String locale in <String>['de', 'en']) {
        final Map<String, Object?> arb =
            jsonDecode(File('assets/l10n/l10n_$locale.arb').readAsStringSync())! as Map<String, Object?>;
        final List<String> missing = <String>[
          for (final String key in keys)
            if (arb[key] is! String || (arb[key]! as String).trim().isEmpty || (arb[key]! as String).trim() == key) key,
        ];
        expect(missing, isEmpty, reason: '$locale is missing disclosure-export keys: $missing');
      }
    });
    test('test_customer_data_disclosure_export_058_unrelated_customer_email_attempt_does_not_affect_export', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_058_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      final int otherCustomerId = await _seedCustomer(env.db, 'Andere GmbH');
      await _ensureInvoiceColumns(env.db);
      final int otherInvoiceId = await _seedInvoice(env.db, customerId: otherCustomerId, number: 'RE-PRIVATE-058');
      await _ensureEmailAttemptTable(env.db);
      const String privateRecipient = 'private-customer-058@example.invalid';
      await env.db.executor.runInsert(
        'INSERT INTO dokument_email_versuche (dokument_id, dokument_typ, empfaenger, ergebnis, '
        'idempotenz_schluessel, artefakt_ids, erstellt_am) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[otherInvoiceId, 'rechnung', privateRecipient, 'accepted', 'private-email-058', '[]', '2026-02-01'],
      );

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.archivePath, destination);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect(jsonEncode(manifest), isNot(contains(privateRecipient)));
      final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
      expect(
        exclusions.where((Object? item) => item is Map && item['record_type'] == 'dokument_email_versuche'),
        isEmpty,
      );
      expect(await service.listEntries(destination), isNot(contains('records/dokument_email_versuche.jsonl')));
    });

    test(
      'test_customer_data_disclosure_export_059_template_source_with_foreign_delivery_address_is_excluded',
      () async {
        final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_059_');
        final int customerId = await _seedCustomer(env.db, 'Kunde AG');
        final int otherCustomerId = await _seedCustomer(env.db, 'Fremd GmbH');
        await _ensureInvoiceColumns(env.db);
        final int foreignAddressId = await _seedAddress(env.db, otherCustomerId);
        final int sourceInvoiceId = await _seedInvoice(
          env.db,
          customerId: customerId,
          addressId: foreignAddressId,
          number: 'RE-FOREIGN-DELIVERY-059',
        );
        await RechnungsVorlagenRepository(env.db.executor).ensureSchema();
        const String privateTemplateName = 'PRIVATE-FOREIGN-DELIVERY-TEMPLATE-059';
        final int templateId = await env.db.executor.runInsert(
          'INSERT INTO rechnungsvorlagen (name, kunde_id, intervall, auftrag_id) VALUES (?, ?, ?, ?)',
          <Object?>[privateTemplateName, customerId, 'monatlich', sourceInvoiceId],
        );

        final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
        final String destination = p.join(env.outDir.path, 'kunde.zip');
        final CustomerDisclosureResult result = await service.exportCustomer(
          customerId: customerId,
          destinationPath: destination,
        );

        expect(result.status, CustomerDisclosureExportStatus.incomplete);
        final Map<String, Object?> manifest = await service.readManifest(destination);
        final List<Object?> exclusions = List<Object?>.from(manifest['exclusions']! as List);
        expect(
          exclusions.where(
            (Object? item) =>
                item is Map &&
                item['record_type'] == 'rechnungsvorlagen' &&
                item['record_id'] == templateId.toString() &&
                item['field'] == 'auftrag_id' &&
                item['reason'] == 'conflicting_identity',
          ),
          hasLength(1),
        );
        final String templates = utf8.decode(await service.readEntry(destination, 'records/rechnungsvorlagen.jsonl'));
        final String invoices = utf8.decode(await service.readEntry(destination, 'records/rechnungen.jsonl'));
        expect(templates, isNot(contains(privateTemplateName)));
        expect(invoices, isNot(contains('RE-FOREIGN-DELIVERY-059')));
      },
    );

    test('test_customer_data_disclosure_export_064_malformed_initialized_occurrence_schema_is_incomplete', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_064_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      await RechnungsVorlagenRepository(env.db.executor).ensureSchema();
      await env.db.executor.runCustom('DROP TABLE rechnungsvorlagen_occurrences');
      await env.db.executor.runCustom('''
CREATE TABLE rechnungsvorlagen_occurrences (
  id INTEGER PRIMARY KEY,
  vorlage_id INTEGER NOT NULL,
  faelligkeit TEXT NOT NULL,
  rechnung_id TEXT NOT NULL
)''');

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final Map<String, Object?> manifest = await service.readManifest(destination);
      expect((manifest['table_health']! as Map)['rechnungsvorlagen_occurrences'], 'malformed');
    });

    test('test_customer_data_disclosure_export_060_template_occurrence_foreign_invoice_is_not_projected', () async {
      final ({AppDatabase db, Directory profileDir, Directory outDir}) env = await _openCustomerDb('disclosure_060_');
      final int customerId = await _seedCustomer(env.db, 'Kunde AG');
      final int otherCustomerId = await _seedCustomer(env.db, 'Fremd GmbH');
      await _ensureInvoiceColumns(env.db);
      final int foreignInvoiceId = await _seedInvoice(
        env.db,
        customerId: otherCustomerId,
        number: 'RE-FOREIGN-OCCURRENCE-060',
      );
      await RechnungsVorlagenRepository(env.db.executor).ensureSchema();
      const String ownedTemplateName = 'OWNED-TEMPLATE-060';
      final int templateId = await env.db.executor.runInsert(
        'INSERT INTO rechnungsvorlagen (name, kunde_id, intervall) VALUES (?, ?, ?)',
        <Object?>[ownedTemplateName, customerId, 'monatlich'],
      );
      await env.db.executor.runInsert(
        'INSERT INTO rechnungsvorlagen_occurrences (vorlage_id, faelligkeit, rechnung_id) VALUES (?, ?, ?)',
        <Object?>[templateId, '2026-06-01', foreignInvoiceId],
      );

      final CustomerDataDisclosureExportService service = _service(env.db, env.profileDir);
      final String destination = p.join(env.outDir.path, 'kunde.zip');
      final CustomerDisclosureResult result = await service.exportCustomer(
        customerId: customerId,
        destinationPath: destination,
      );

      expect(result.status, CustomerDisclosureExportStatus.incomplete);
      final String templates = utf8.decode(await service.readEntry(destination, 'records/rechnungsvorlagen.jsonl'));
      final String occurrences = utf8.decode(
        await service.readEntry(destination, 'records/rechnungsvorlagen_occurrences.jsonl'),
      );
      final String invoices = utf8.decode(await service.readEntry(destination, 'records/rechnungen.jsonl'));
      expect(templates, contains(ownedTemplateName));
      expect(occurrences, isEmpty);
      expect(occurrences, isNot(contains('2026-06-01')));
      expect(invoices, isNot(contains('RE-FOREIGN-OCCURRENCE-060')));
    });
  });
}

Future<void> _replaceLazyMarkersWithInvalidRows(AppDatabase db, {required bool duplicate}) async {
  final List<Map<String, Object?>> markers = await db.executor.runSelect(
    'SELECT table_name, state FROM feature_table_state ORDER BY table_name',
    const <Object?>[],
  );
  await db.executor.runCustom('DROP TABLE feature_table_state');
  await db.executor.runCustom('CREATE TABLE feature_table_state (table_name TEXT, state TEXT)');
  for (final Map<String, Object?> marker in markers) {
    await db.executor.runInsert('INSERT INTO feature_table_state (table_name, state) VALUES (?, ?)', <Object?>[
      marker['table_name'],
      marker['state'],
    ]);
  }
  final Map<String, Object?> marker = markers.first;
  await db.executor.runInsert(
    'INSERT INTO feature_table_state (table_name, state) VALUES (?, ?)',
    duplicate
        ? <Object?>[marker['table_name'], marker['state']]
        : const <Object?>['unknown_feature_table', 'initialized'],
  );
}

class _FailingVacuumExecutor extends QueryExecutor {
  _FailingVacuumExecutor(this.delegate);

  final QueryExecutor delegate;
  String? snapshotPath;

  @override
  SqlDialect get dialect => delegate.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => delegate.ensureOpen(user);

  @override
  Future<List<Map<String, Object?>>> runSelect(String statement, List<Object?> args) =>
      delegate.runSelect(statement, args);

  @override
  Future<int> runInsert(String statement, List<Object?> args) => delegate.runInsert(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) => delegate.runUpdate(statement, args);

  @override
  Future<int> runDelete(String statement, List<Object?> args) => delegate.runDelete(statement, args);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    if (statement.trim().toUpperCase().startsWith('VACUUM INTO')) {
      snapshotPath = args?.single as String?;
      throw StateError('forced snapshot failure');
    }
    return delegate.runCustom(statement, args);
  }

  @override
  Future<void> runBatched(BatchedStatements statements) => delegate.runBatched(statements);

  @override
  TransactionExecutor beginTransaction() => delegate.beginTransaction();

  @override
  QueryExecutor beginExclusive() => delegate.beginExclusive();

  @override
  Future<void> close() => delegate.close();
}
