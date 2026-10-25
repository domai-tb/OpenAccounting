import 'package:openaccounting/features/e_invoice/e_invoice_snapshot.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';

class RechnungenRepository {
  const RechnungenRepository(this.dataSource);

  final RechnungenDataSource dataSource;

  Future<RechnungItem> createDraftRechnung({
    required String datum,
    required List<RechnungPositionItem> positionen,
    String typ = 'rechnung',
    String eingabemodus = 'netto',
    int? kundeId,
    int? lieferantId,
    int? belegId,
    String? faelligkeit,
    String? leistungsdatum,
    String? fremdRechnungsnummer,
    int? lieferadresseId,
    num? rabattProzent,
    num? rabattBetrag,
  }) async {
    final id = await dataSource.createDraftRechnung(
      datum: datum,
      positionen: positionen,
      typ: typ,
      eingabemodus: eingabemodus,
      kundeId: kundeId,
      lieferantId: lieferantId,
      belegId: belegId,
      faelligkeit: faelligkeit,
      leistungsdatum: leistungsdatum,
      fremdRechnungsnummer: fremdRechnungsnummer,
      lieferadresseId: lieferadresseId,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
    return _loadRechnung(id, missingMessage: 'Entwurfsrechnung wurde nicht gespeichert');
  }

  Future<RechnungItem> createDokument({
    required String typ,
    required String datum,
    required List<RechnungPositionItem> positionen,
    String eingabemodus = 'netto',
    int? kundeId,
    int? lieferadresseId,
    num? rabattProzent,
    num? rabattBetrag,
  }) async {
    final id = await dataSource.createDokument(
      typ: typ,
      datum: datum,
      positionen: positionen,
      eingabemodus: eingabemodus,
      kundeId: kundeId,
      lieferadresseId: lieferadresseId,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
    return _loadRechnung(id, missingMessage: 'Dokument wurde nicht gespeichert');
  }

  Future<RechnungItem> finalizeRechnung({
    required int rechnungId,
    required String locale,
    String ausgabeformat = 'pdf',
  }) async {
    final id = await dataSource.finalizeRechnung(rechnungId: rechnungId, locale: locale, ausgabeformat: ausgabeformat);
    return _loadRechnung(id, missingMessage: 'Finalisierte Rechnung wurde nicht gespeichert');
  }

  /// Reads the committed immutable snapshot for standalone XRechnung export.
  /// The export path never mutates the invoice.
  Future<FinalizationSnapshot> readCommittedEInvoiceSnapshot(int rechnungId, {String? buyerReference}) {
    return dataSource.readCommittedEInvoiceSnapshot(rechnungId, buyerReference: buyerReference);
  }

  Future<RechnungItem> updateDraftRechnung({
    required int rechnungId,
    required String datum,
    required List<RechnungPositionItem> positionen,
    String? leistungsdatum,
    String? eingabemodus,
    int? kundeId,
    int? lieferadresseId,
    num? rabattProzent,
    num? rabattBetrag,
  }) async {
    final id = await dataSource.updateDraftRechnung(
      rechnungId: rechnungId,
      datum: datum,
      positionen: positionen,
      leistungsdatum: leistungsdatum,
      eingabemodus: eingabemodus,
      kundeId: kundeId,
      lieferadresseId: lieferadresseId,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
    return _loadRechnung(id, missingMessage: 'Entwurfsänderung wurde nicht gespeichert');
  }

  /// Authoritative domain preview for the current form values.
  ///
  /// The workspace displays only fields copied from this result; widgets
  /// must not sum position aggregates or calculate money themselves.
  VorschauResult previewRechnung({
    required String eingabemodus,
    required List<RechnungPositionItem> positionen,
    num? rabattProzent,
    num? rabattBetrag,
  }) {
    return VorschauService.calculate(
      eingabemodus: eingabemodus,
      positionen: positionen,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
  }

  /// Whether correction/conversion actions may be offered.
  ///
  /// True when the data source has a profile directory and a wired artifact writer.
  /// Actions stay unavailable until both are configured.
  bool get correctionArtifactTransactionAvailable => dataSource.correctionArtifactTransactionAvailable;

  /// Loads one invoice for a routed detail surface without exposing raw rows.
  Future<RechnungItem?> findById(int id) async {
    final Map<String, Object?>? invoice = await dataSource.findRechnungById(id);
    if (invoice == null) return null;
    final List<Map<String, Object?>> storedPositions = await dataSource.findPositionenByRechnungId(id);
    final List<Map<String, Object?>> links = await dataSource.findBeziehungen(id);
    return _toItem(invoice, storedPositions, links);
  }

  Future<RechnungItem> stornoRechnung({required int rechnungId, required String grund}) async {
    final id = await dataSource.stornoRechnung(rechnungId: rechnungId, grund: grund);
    return _loadRechnung(id, missingMessage: 'Storno wurde nicht gespeichert');
  }

  Future<RechnungItem> createGutschrift({
    int? vonRechnungId,
    String? datum,
    List<RechnungPositionItem>? positionen,
    String grund = '',
  }) async {
    final id = await dataSource.createGutschrift(
      vonRechnungId: vonRechnungId,
      datum: datum,
      positionen: positionen,
      grund: grund,
    );
    return _loadRechnung(id, missingMessage: 'Gutschrift wurde nicht gespeichert');
  }

  Future<RechnungItem> createErsatzRechnung({required int vonRechnungId}) async {
    final id = await dataSource.createErsatzRechnung(vonRechnungId: vonRechnungId);
    return _loadRechnung(id, missingMessage: 'Ersatzrechnung wurde nicht gespeichert');
  }

  Future<RechnungItem> konvertiereDokument({required int quelleId, required String zielTyp}) async {
    final id = await dataSource.konvertiereDokument(quelleId: quelleId, zielTyp: zielTyp);
    return _loadRechnung(id, missingMessage: 'Konvertiertes Dokument wurde nicht gespeichert');
  }

  Future<RechnungItem> _loadRechnung(int id, {required String missingMessage}) async {
    final invoice = await dataSource.findRechnungById(id);
    if (invoice == null) {
      throw StateError(missingMessage);
    }
    final storedPositions = await dataSource.findPositionenByRechnungId(id);
    final links = await dataSource.findBeziehungen(id);
    return _toItem(invoice, storedPositions, links);
  }

  RechnungItem _toItem(
    Map<String, Object?> invoice,
    List<Map<String, Object?>> storedPositions, [
    List<Map<String, Object?>> links = const <Map<String, Object?>>[],
  ]) {
    return RechnungItem(
      id: _requiredInt(invoice, 'id'),
      rechnungsnummer: invoice['rechnungsnummer'] as String?,
      typ: _requiredString(invoice, 'typ'),
      status: _requiredString(invoice, 'status'),
      istEntwurf: _asBool(invoice['ist_entwurf']),
      eingabemodus: _requiredString(invoice, 'eingabemodus'),
      datum: _requiredString(invoice, 'datum'),
      kundeName: invoice['kunde_name'] as String?,
      kundeFirma: invoice['kunde_firma'] as String?,
      kundeStrasse: invoice['kunde_strasse'] as String?,
      kundePlz: invoice['kunde_plz'] as String?,
      kundeOrt: invoice['kunde_ort'] as String?,
      originalPdfPath: invoice['original_pdf_pfad'] as String?,
      rabattProzent: _optionalNum(invoice['rabatt_prozent']),
      rabattBetrag: _optionalNum(invoice['rabatt_betrag']),
      ausgabeformat: invoice['ausgabeformat'] as String?,
      kundeId: _optionalInt(invoice['kunde_id']),
      lieferantId: _optionalInt(invoice['lieferant_id']),
      belegId: _optionalInt(invoice['beleg_id']),
      faelligkeit: invoice['faelligkeit'] as String?,
      leistungsdatum: invoice['leistungsdatum'] as String?,
      fremdRechnungsnummer: invoice['fremd_rechnungsnummer'] as String?,
      positionen: storedPositions.map(_positionFromRow).toList(growable: false),
      beziehungen: links
          .map(
            (link) => RechnungBeziehung(
              kind: link['kind']?.toString() ?? 'Verknüpfung',
              documentId: (link['documentId']! as num).toInt(),
              label: link['label']?.toString() ?? '',
              available: (link['available']! as num) != 0,
            ),
          )
          .toList(growable: false),
    );
  }

  RechnungPositionItem _positionFromRow(Map<String, Object?> row) {
    return RechnungPositionItem(
      id: _requiredInt(row, 'id'),
      artikelId: _optionalInt(row['artikel_id']),
      bezeichnung: _requiredString(row, 'bezeichnung'),
      menge: _requiredNum(row, 'menge'),
      einzelpreis: _requiredNum(row, 'einzelpreis'),
      gesamt: _requiredNum(row, 'gesamt'),
      ustSatz: _requiredNum(row, 'ust_satz'),
      position: _requiredInt(row, 'position'),
      rabattProzent: row['rabatt_prozent'] == null ? null : _requiredNum(row, 'rabatt_prozent'),
      taxEvidence: RechnungPositionTaxEvidence.fromDatabaseRow(row),
    );
  }
}

int _requiredInt(Map<String, Object?> row, String field) {
  final value = row[field];
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = num.tryParse(value);
    if (parsed != null) return parsed.toInt();
  }
  throw StateError('Ungültiger Wert für $field: $value');
}

int? _optionalInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

num? _optionalNum(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

num _requiredNum(Map<String, Object?> row, String field) {
  final value = row[field];
  if (value is num) return value;
  if (value is String) {
    final parsed = num.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw StateError('Ungültiger Wert für $field: $value');
}

String _requiredString(Map<String, Object?> row, String field) {
  final value = row[field];
  if (value is String) return value;
  throw StateError('Ungültiger Wert für $field');
}

bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value == '1';
}
