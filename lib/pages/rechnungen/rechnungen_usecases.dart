import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_repository.dart';

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
    if (!position.ustSatz.isFinite || position.ustSatz < 0 || position.ustSatz > 100) {
      throw ArgumentError.value(position.ustSatz, 'ustSatz', 'Muss zwischen 0 und 100 liegen.');
    }

    final lineTotalCents = einzelpreisCents * position.menge;
    if (!lineTotalCents.isFinite || gesamtCents != lineTotalCents.round()) {
      throw ArgumentError.value(position.gesamt, 'gesamt', 'Muss dem auf Cent gerundeten Positionswert entsprechen.');
    }
  }
}

bool _isFiniteNonNegative(num value) => value.isFinite && value >= 0;

int _currencyCents(num value, String name) {
  if (!_isFiniteNonNegative(value)) {
    throw ArgumentError.value(value, name, 'Muss endlich und nicht negativ sein.');
  }

  const scale = 100;
  // `scaled` is cents; allow only 1e-9 cent of binary representation noise.
  const binaryRepresentationToleranceInCents = 1e-9;
  final scaled = value * scale;
  if (!scaled.isFinite) {
    throw ArgumentError.value(value, name, 'Muss endlich und nicht negativ sein.');
  }

  final cents = scaled.round();
  if ((scaled - cents).abs() > binaryRepresentationToleranceInCents) {
    throw ArgumentError.value(value, name, 'Darf höchstens zwei Nachkommastellen haben.');
  }
  return cents;
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
