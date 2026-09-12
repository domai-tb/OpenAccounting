import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';

class RechnungenUseCases {
  const RechnungenUseCases(this.repository);

  final RechnungenRepository repository;

  Future<RechnungItem> createDraftRechnung({
    required String datum,
    required List<RechnungPositionItem> positionen,
    String typ = 'rechnung',
    String eingabemodus = 'netto',
    int? lieferadresseId,
    num? rabattProzent,
    num? rabattBetrag,
  }) async {
    _validateDraftInput(
      datum: datum,
      positionen: positionen,
      eingabemodus: eingabemodus,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
    return repository.createDraftRechnung(
      datum: datum,
      positionen: positionen,
      typ: typ,
      eingabemodus: eingabemodus,
      lieferadresseId: lieferadresseId,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
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
    _validateDraftInput(
      datum: datum,
      positionen: positionen,
      eingabemodus: eingabemodus,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
    const allowed = {'rechnung', 'angebot', 'auftrag', 'proforma', 'lieferschein', 'gutschrift', 'storno'};
    if (!allowed.contains(typ)) {
      throw StateError('Unbekannter Dokumenttyp');
    }
    return repository.createDokument(
      typ: typ,
      datum: datum,
      positionen: positionen,
      eingabemodus: eingabemodus,
      lieferadresseId: lieferadresseId,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
  }

  Future<RechnungItem> finalizeRechnung({required int rechnungId}) {
    return repository.finalizeRechnung(rechnungId: rechnungId);
  }

  Future<RechnungItem> stornoRechnung({required int rechnungId, required String grund}) async {
    if (grund.trim().isEmpty) {
      throw StateError('Stornogrund ist Pflicht');
    }
    return repository.stornoRechnung(rechnungId: rechnungId, grund: grund);
  }

  Future<RechnungItem> createGutschrift({
    int? vonRechnungId,
    String? datum,
    List<RechnungPositionItem>? positionen,
    String grund = '',
  }) async {
    if (vonRechnungId == null) {
      if (datum == null || positionen == null || positionen.isEmpty) {
        throw ArgumentError('datum und positionen erforderlich für standalone Gutschrift');
      }
      _validateDraftInput(datum: datum, positionen: positionen);
    }
    return repository.createGutschrift(
      vonRechnungId: vonRechnungId,
      datum: datum,
      positionen: positionen,
      grund: grund,
    );
  }

  Future<RechnungItem> createErsatzRechnung({required int vonRechnungId}) async {
    return repository.createErsatzRechnung(vonRechnungId: vonRechnungId);
  }

  Future<RechnungItem> konvertiereDokument({required int quelleId, required String zielTyp}) async {
    const allowedTarget = {'rechnung', 'angebot', 'auftrag', 'proforma', 'lieferschein', 'gutschrift', 'storno'};
    if (!allowedTarget.contains(zielTyp)) {
      throw StateError('Unbekannter Dokumenttyp');
    }
    return repository.konvertiereDokument(quelleId: quelleId, zielTyp: zielTyp);
  }
}

void _validateDraftInput({
  required String datum,
  required List<RechnungPositionItem> positionen,
  String eingabemodus = 'netto',
  num? rabattProzent,
  num? rabattBetrag,
}) {
  if (!_isValidIsoDate(datum)) {
    throw ArgumentError.value(datum, 'datum', 'Erwartet ein gültiges ISO-Datum (YYYY-MM-DD).');
  }
  VorschauService.calculate(
    eingabemodus: eingabemodus,
    positionen: positionen,
    rabattProzent: rabattProzent,
    rabattBetrag: rabattBetrag,
  );
}

bool _isValidIsoDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return false;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return false;
  return parsed.year == int.parse(value.substring(0, 4)) &&
      parsed.month == int.parse(value.substring(5, 7)) &&
      parsed.day == int.parse(value.substring(8, 10));
}
