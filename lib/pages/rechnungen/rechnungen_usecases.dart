import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';
import 'package:openaccounting/pages/rechnungen/vorschau_service.dart';

const int _centsPerUnit = 100;

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
  if (rabattProzent != null && rabattProzent != 0 && rabattBetrag != null && rabattBetrag != 0) {
    throw ArgumentError('Nur ein Rabatt pro Dokument erlaubt (Prozent ODER Betrag)');
  }
  // strict 2-decimal check for money before preview rounding
  for (final p in positionen) {
    if (p.bezeichnung.trim().isEmpty) throw ArgumentError.value(p.bezeichnung, 'bezeichnung', 'Darf nicht leer sein.');
    _strictCurrency(p.einzelpreis, 'einzelpreis');
    _strictCurrency(p.gesamt.abs(), 'gesamt');
    _strictCurrency(p.menge, 'menge');
    if (!p.ustSatz.isFinite) throw ArgumentError.value(p.ustSatz, 'ustSatz', 'Muss zwischen 0 und 100 liegen.');
    final ustCents = _fixedPointCents(p.ustSatz, 'ustSatz');
    if (ustCents < 0 || ustCents > 10000) {
      throw ArgumentError.value(p.ustSatz, 'ustSatz', 'Muss zwischen 0 und 100 liegen.');
    }
  }
  // preview validation for logic consistency (allow rounding)
  try {
    VorschauService.calculate(
      eingabemodus: eingabemodus,
      positionen: positionen,
      rabattProzent: rabattProzent,
      rabattBetrag: rabattBetrag,
    );
  } catch (e) {
    if (e.toString().contains('Nur ein Rabatt')) {
      throw ArgumentError('Nur ein Rabatt pro Dokument erlaubt (Prozent ODER Betrag)');
    }
    rethrow;
  }
  for (final position in positionen) {
    if (position.rabattProzent != null && position.rabattProzent != 0) continue; // preview already handled
    final einzelpreisCents = _currencyCents(position.einzelpreis, 'einzelpreis');
    final gesamtCents = _currencyCents(position.gesamt.abs(), 'gesamt');
    final mengeCents = _currencyCents(position.menge, 'menge');
    final lineTotalCents = (einzelpreisCents * mengeCents + 50) ~/ _centsPerUnit;
    if (gesamtCents != lineTotalCents) {
      throw ArgumentError.value(position.gesamt, 'gesamt', 'Muss dem auf Cent gerundeten Positionswert entsprechen.');
    }
  }
}

void _strictCurrency(num v, String name) {
  if (!v.isFinite) throw ArgumentError.value(v, name, 'Muss endlich sein.');
  final s = v.toString();
  final m = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$').firstMatch(s);
  if (m == null) throw ArgumentError.value(v, name, 'Ungültige Zahl');
  final dec = (m.group(3)?.length ?? 0) - int.parse(m.group(4) ?? '0');
  if (dec > 2) {
    final digits = '${m.group(2)}${m.group(3) ?? ''}';
    final excess = dec - 2;
    final zeros = ''.padRight(excess, '0');
    if (!digits.endsWith(zeros)) {
      throw ArgumentError.value(v, name, 'Darf höchstens zwei Nachkommastellen haben.');
    }
  }
}

bool _isFiniteNonNegative(num value) => value.isFinite && value >= 0;

int _currencyCents(num value, String name) {
  if (!_isFiniteNonNegative(value.abs())) {
    throw ArgumentError.value(value, name, 'Muss endlich und nicht negativ sein.');
  }
  return _fixedPointCents(value.abs(), name);
}

int _fixedPointCents(num value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, name, 'Muss endlich und nicht negativ sein.');
  }
  final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$').firstMatch(value.toString());
  if (match == null) {
    throw ArgumentError.value(value, name, 'Darf höchstens zwei Nachkommastellen haben.');
  }
  final sign = match.group(1) == '-' ? -1 : 1;
  final digits = '${match.group(2)}${match.group(3) ?? ''}';
  final decimalPlaces = (match.group(3)?.length ?? 0) - int.parse(match.group(4) ?? '0');
  var centDigits = digits;
  if (decimalPlaces > 2) {
    final excessPlaces = decimalPlaces - 2;
    final trailingZeroes = ''.padRight(excessPlaces, '0');
    if (!centDigits.endsWith(trailingZeroes)) {
      throw ArgumentError.value(value, name, 'Darf höchstens zwei Nachkommastellen haben.');
    }
    centDigits = centDigits.substring(0, centDigits.length - excessPlaces);
  } else if (decimalPlaces < 2) {
    centDigits = centDigits.padRight(centDigits.length + 2 - decimalPlaces, '0');
  }
  return sign * int.parse(centDigits);
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
