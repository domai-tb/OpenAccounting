import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

class RechnungenRepository {
  const RechnungenRepository(this.dataSource);

  final RechnungenDataSource dataSource;

  Future<RechnungItem> createDraftRechnung({
    required String datum,
    required List<RechnungPositionItem> positionen,
    String typ = 'rechnung',
    String eingabemodus = 'netto',
    int? lieferadresseId,
    num? rabattProzent,
    num? rabattBetrag,
  }) async {
    final id = await dataSource.createDraftRechnung(
      datum: datum,
      positionen: positionen,
      typ: typ,
      eingabemodus: eingabemodus,
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
    int? lieferadresseId,
    num? rabattProzent,
    num? rabattBetrag,
  }) async {
    final id = await dataSource.createDokument(
      typ: typ,
      datum: datum,
      positionen: positionen,
      eingabemodus: eingabemodus,
      lieferadresseId: lieferadresseId,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
    return _loadRechnung(id, missingMessage: 'Dokument wurde nicht gespeichert');
  }

  Future<RechnungItem> finalizeRechnung({required int rechnungId}) async {
    final id = await dataSource.finalizeRechnung(rechnungId: rechnungId);
    return _loadRechnung(id, missingMessage: 'Finalisierte Rechnung wurde nicht gespeichert');
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
    return RechnungItem(
      id: _requiredInt(invoice, 'id'),
      rechnungsnummer: invoice['rechnungsnummer'] as String?,
      typ: _requiredString(invoice, 'typ'),
      status: _requiredString(invoice, 'status'),
      istEntwurf: _asBool(invoice['ist_entwurf']),
      eingabemodus: _requiredString(invoice, 'eingabemodus'),
      datum: _requiredString(invoice, 'datum'),
      positionen: storedPositions.map(_positionFromRow).toList(growable: false),
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
