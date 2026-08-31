import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';

const int _centsPerUnit = 100;

class RechnungenUseCases {
  const RechnungenUseCases(this.repository);

  final RechnungenRepository repository;

  Future<RechnungItem> createDraftRechnung({
    required String datum,
    required List<RechnungPositionItem> positionen,
  }) async {
    _validateDraftInput(datum: datum, positionen: positionen);
    return repository.createDraftRechnung(datum: datum, positionen: positionen);
  }
}

void _validateDraftInput({required String datum, required List<RechnungPositionItem> positionen}) {
  if (!_isValidIsoDate(datum)) {
    throw ArgumentError.value(datum, 'datum', 'Erwartet ein gültiges ISO-Datum (YYYY-MM-DD).');
  }

  for (final position in positionen) {
    if (position.bezeichnung.trim().isEmpty) {
      throw ArgumentError.value(position.bezeichnung, 'bezeichnung', 'Darf nicht leer sein.');
    }

    final einzelpreisCents = _currencyCents(position.einzelpreis, 'einzelpreis');
    final gesamtCents = _currencyCents(position.gesamt, 'gesamt');
    if (!position.menge.isFinite || position.menge <= 0) {
      throw ArgumentError.value(position.menge, 'menge', 'Muss endlich und positiv sein.');
    }
    final mengeCents = _currencyCents(position.menge, 'menge');
    if (!position.ustSatz.isFinite) {
      throw ArgumentError.value(position.ustSatz, 'ustSatz', 'Muss zwischen 0 und 100 liegen.');
    }
    final ustSatzCents = _fixedPointCents(position.ustSatz, 'ustSatz');
    if (ustSatzCents < 0 || ustSatzCents > 10000) {
      throw ArgumentError.value(position.ustSatz, 'ustSatz', 'Muss zwischen 0 und 100 liegen.');
    }

    final lineTotalCents = (einzelpreisCents * mengeCents + 50) ~/ _centsPerUnit;
    if (gesamtCents != lineTotalCents) {
      throw ArgumentError.value(position.gesamt, 'gesamt', 'Muss dem auf Cent gerundeten Positionswert entsprechen.');
    }
  }
}

bool _isFiniteNonNegative(num value) => value.isFinite && value >= 0;

int _currencyCents(num value, String name) {
  if (!_isFiniteNonNegative(value)) {
    throw ArgumentError.value(value, name, 'Muss endlich und nicht negativ sein.');
  }

  return _fixedPointCents(value, name);
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
