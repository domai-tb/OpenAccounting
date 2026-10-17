// ignore_for_file: file_names

import 'dart:io';

import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_artifacts.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_output_format.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_service.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_snapshot.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

/// Simulates an available bundle for application-boundary tests only.
const EInvoiceService eInvoiceTestService = EInvoiceService(bundle: PinnedArtifactBundle(available: true));

Map<String, Object?> validCompany() => <String, Object?>{
  'name': 'Muster GmbH',
  'strasse': 'Musterstraße',
  'hausnummer': '1',
  'plz': '10115',
  'ort': 'Berlin',
  'land': 'DE',
  'steuernummer': '13/123/12345',
  'ust_idnr': 'DE123456789',
  'iban': 'DE89370400440532013000',
};

Map<String, Object?> validCustomer() => <String, Object?>{
  'name': 'Kunde GmbH',
  'firma': 'Kunde GmbH',
  'strasse': 'Kundenweg',
  'hausnummer': '5',
  'plz': '20095',
  'ort': 'Hamburg',
  'land': 'DE',
};

List<Map<String, Object?>> standardPositions() => <Map<String, Object?>>[
  <String, Object?>{
    'bezeichnung': 'Beratung',
    'menge': 2,
    'einzelpreis': 100,
    'gesamt': 200,
    'ust_satz': 19,
    'rabatt_prozent': 0,
    'position': 0,
  },
];

EInvoiceCanonicalTotals standardTotals() =>
    const EInvoiceCanonicalTotals(netCents: 20000, taxCents: 3800, grossCents: 23800);

FinalizationSnapshot validSnapshot({
  String? buyerReference,
  EInvoiceOutputFormat format = EInvoiceOutputFormat.pdf,
  String? deliveryDate = '2026-03-10',
}) {
  return const EInvoiceSnapshotBuilder().buildFinalization(
    documentNumber: 'RE-2026-0001',
    outputFormat: format,
    issueDate: '2026-03-15',
    companyRow: validCompany(),
    customerRow: validCustomer(),
    posRows: standardPositions(),
    preview: standardTotals(),
    eingabemodus: 'netto',
    buyerReference: buyerReference,
    deliveryDate: deliveryDate,
  );
}

final List<int> fakePdfBytes = <int>[37, 80, 68, 70, 45, 49, 46, 52, 10, 37, 10];

/// Opens an isolated in-memory database with the category, company, and
/// number-range seeds e-invoice finalization requires.
Future<AppDatabase> openEInvoiceDatabase() async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  await db.kategorienRepository.create(bezeichnung: 'Fixture-Kategorie');
  await db.executor.runInsert(
    'INSERT INTO unternehmen (name, strasse, plz, ort, land, steuernummer, ust_idnr, iban) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    const <Object?>[
      'Muster GmbH',
      'Musterstraße 1',
      '10115',
      'Berlin',
      'DE',
      '13/123/12345',
      'DE123456789',
      'DE89370400440532013000',
    ],
  );
  return db;
}

/// Inserts a complete buyer. Missing address parts simulate invalid sources.
Future<int> addEInvoiceCustomer(
  AppDatabase db, {
  String name = 'Kunde GmbH',
  String? street = 'Kundenweg 5',
  String? postalCode = '20095',
  String? city = 'Hamburg',
  String? country = 'DE',
  bool zugferdAktiv = false,
}) async {
  return db.executor.runInsert(
    'INSERT INTO kunden (name, strasse, plz, ort, land, zugferd_aktiv) VALUES (?, ?, ?, ?, ?, ?)',
    <Object?>[name, street ?? '', postalCode, city, country, if (zugferdAktiv) 1 else 0],
  );
}

/// Creates a draft with one standard-rated line (2 x 100 netto, 19 %).
Future<int> createEInvoiceDraft(
  RechnungenDataSource ds, {
  int? kundeId,
  List<RechnungPositionItem>? positionen,
  String? leistungsdatum,
}) async {
  return ds.createDraftRechnung(
    datum: '2026-03-15',
    leistungsdatum: leistungsdatum,
    kundeId: kundeId,
    positionen:
        positionen ??
        <RechnungPositionItem>[
          const RechnungPositionItem(bezeichnung: 'Beratung', menge: 2, einzelpreis: 100, gesamt: 200),
        ],
  );
}

Future<Map<String, Object?>> eInvoiceRow(AppDatabase db, int id) async {
  return (await db.executor.runSelect('SELECT * FROM rechnungen WHERE id = ?', <Object?>[id])).single;
}

Future<int> eInvoiceSequence(AppDatabase db) async {
  final Object? value = (await db.executor.runSelect(
    "SELECT naechste_nummer FROM nummernkreise WHERE typ = 'rechnung_ausgang' AND aktiv = 1",
    const <Object?>[],
  )).single['naechste_nummer'];
  return (value! as num).toInt();
}

Future<List<File>> eInvoiceArtifacts(Directory profileDir, int id) async {
  final Directory directory = Directory('${profileDir.path}/pdfs/documents');
  if (!directory.existsSync()) return <File>[];
  return directory.listSync().whereType<File>().where((file) => file.path.contains('/$id.')).toList(growable: false);
}
