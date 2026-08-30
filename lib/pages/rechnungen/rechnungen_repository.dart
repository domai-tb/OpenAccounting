import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

class RechnungenRepository {
  const RechnungenRepository(this.dataSource);

  final RechnungenDataSource dataSource;

  Future<RechnungItem> createDraftRechnung({
    required String datum,
    required List<RechnungPositionItem> positionen,
  }) async {
    final id = await dataSource.createDraftRechnung(datum: datum, positionen: positionen);
    final invoice = await dataSource.findRechnungById(id);
    if (invoice == null) {
      throw StateError('Entwurfsrechnung wurde nicht gespeichert');
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
    );
  }
}

int _requiredInt(Map<String, Object?> row, String field) {
  final value = row[field];
  if (value is num) return value.toInt();
  throw StateError('Ungültiger Wert für $field');
}

int? _optionalInt(Object? value) => value is num ? value.toInt() : null;

num _requiredNum(Map<String, Object?> row, String field) {
  final value = row[field];
  if (value is num) return value;
  throw StateError('Ungültiger Wert für $field');
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
