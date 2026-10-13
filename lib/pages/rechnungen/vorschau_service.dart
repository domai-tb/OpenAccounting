import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

/// Stable validation failure for invoice money at the domain boundary.
class InvoiceMoneyValidationException extends ArgumentError {
  InvoiceMoneyValidationException({
    required this.code,
    required String message,
    this.lineIndex,
    this.position,
    this.fields = const <String>[],
  }) : super(message);

  final String code;
  final int? lineIndex;
  final int? position;
  final List<String> fields;
}

class VorschauResult {
  const VorschauResult({required this.nettoCents, required this.ustCents, required this.bruttoCents, this.rabattCents});

  final int nettoCents;
  final int ustCents;
  final int bruttoCents;
  final int? rabattCents;

  /// Presentation values are produced only after all arithmetic is complete.
  num get nettoBetrag => nettoCents / 100.0;
  num get ustBetrag => ustCents / 100.0;
  num get bruttoBetrag => bruttoCents / 100.0;
  num? get rabattBetrag => rabattCents == null ? null : rabattCents! / 100.0;

  String get nettoBetragString => money.fromCents(nettoCents);
  String get ustBetragString => money.fromCents(ustCents);
  String get bruttoBetragString => money.fromCents(bruttoCents);
  String? get rabattBetragString => rabattCents == null ? null : money.fromCents(rabattCents!);
}

/// One calculator for preview and every invoice persistence path.
class VorschauService {
  static const int _maxCurrencyCents = 999999999999;
  static const int _maxUnitPriceScaled = 999999999999;
  static const int _maxQuantityScaled = 999999999999;

  /// Returns the entered-mode line amount after one cent rounding, applying an optional discount first.
  static num lineTotal({required num quantity, required num unitPrice, num? rabattProzent}) {
    final int quantityScaled = _quantity(quantity, 0, null);
    final int unitPriceScaled = _unitPrice(unitPrice, 0, null);
    final int discountScaled = rabattProzent == null
        ? 0
        : _percent(rabattProzent, field: 'rabattProzent', code: 'invalidPercentage');
    return _lineAmountCents(unitPriceScaled, quantityScaled, discountScaled, 0, null) / 100.0;
  }

  static VorschauResult calculate({
    required String eingabemodus,
    required List<RechnungPositionItem> positionen,
    num? rabattProzent,
    num? rabattBetrag,
  }) {
    if (eingabemodus != 'netto' && eingabemodus != 'brutto') {
      throw _error('invalidMode', 'Eingabemodus muss netto oder brutto sein', fields: const <String>['eingabemodus']);
    }

    final int? documentDiscountPercent = rabattProzent == null
        ? null
        : _percent(rabattProzent, field: 'rabattProzent', code: 'invalidPercentage');
    final int? documentDiscountAmount = rabattBetrag == null ? null : _currency(rabattBetrag, field: 'rabattBetrag');
    if ((documentDiscountPercent ?? 0) != 0 && (documentDiscountAmount ?? 0) != 0) {
      throw _error(
        'conflictingDocumentDiscounts',
        'Nur ein Rabatt pro Dokument erlaubt (Prozent ODER Betrag)',
        fields: const <String>['rabattProzent', 'rabattBetrag'],
      );
    }

    final List<int> lineRates = <int>[];
    final List<int> lineAmounts = <int>[];
    final List<int> lineNets = <int>[];
    final Map<int, int> netByRate = <int, int>{};
    for (var index = 0; index < positionen.length; index++) {
      final RechnungPositionItem position = positionen[index];
      if (position.bezeichnung.trim().isEmpty) {
        throw _error(
          'invalidDescription',
          'Bezeichnung darf nicht leer sein',
          lineIndex: index,
          position: position.position,
          fields: const <String>['bezeichnung'],
        );
      }
      final int quantity = _quantity(position.menge, index, position.position);
      final int unitPrice = _unitPrice(position.einzelpreis, index, position.position);
      final int assertedTotal = _currency(
        position.gesamt,
        field: 'gesamt',
        lineIndex: index,
        position: position.position,
      );
      final int rate = _percent(
        position.ustSatz,
        field: 'ustSatz',
        code: 'invalidTaxRate',
        lineIndex: index,
        position: position.position,
      );
      final int lineDiscount = position.rabattProzent == null
          ? 0
          : _percent(
              position.rabattProzent!,
              field: 'rabattProzent',
              code: 'invalidPercentage',
              lineIndex: index,
              position: position.position,
            );
      final int lineAmount = _lineAmountCents(unitPrice, quantity, lineDiscount, index, position.position);
      if (assertedTotal != lineAmount) {
        throw _error(
          'aggregateMismatch',
          'Positionssumme muss dem auf Cent gerundeten Positionswert entsprechen',
          lineIndex: index,
          position: position.position,
          fields: const <String>['gesamt'],
        );
      }
      final int lineNet = eingabemodus == 'netto'
          ? lineAmount
          : _checkedCurrency(
              _roundRatio(BigInt.from(lineAmount) * BigInt.from(10000), BigInt.from(10000 + rate)),
              index,
              position.position,
              const <String>['netto_betrag'],
            );
      lineRates.add(rate);
      lineAmounts.add(lineAmount);
      lineNets.add(lineNet);
      netByRate.update(
        rate,
        (int old) => _addCurrency(old, lineNet, index, position.position, const <String>['netto_betrag']),
        ifAbsent: () => lineNet,
      );
    }

    final int netSubtotal = netByRate.values.fold<int>(
      0,
      (int sum, int amount) => _addCurrency(sum, amount, null, null, const <String>['netto_betrag']),
    );
    int? appliedDiscount;
    if ((documentDiscountPercent ?? 0) != 0) {
      appliedDiscount = _checkedCurrency(
        _roundRatio(BigInt.from(netSubtotal) * BigInt.from(documentDiscountPercent!), BigInt.from(10000)),
        null,
        null,
        const <String>['rabattProzent'],
      );
    } else if ((documentDiscountAmount ?? 0) != 0) {
      appliedDiscount = documentDiscountAmount;
    }

    final int discount = appliedDiscount ?? 0;
    if (discount > netSubtotal) {
      throw _error(
        'excessiveDocumentDiscount',
        'Betragsrabatt darf die Nettosumme nicht überschreiten',
        fields: const <String>['rabattBetrag'],
      );
    }
    final Map<int, int> discountByRate;
    try {
      discountByRate = money.allocateProportionally<int>(
        amount: discount,
        weights: netByRate,
        compareKeys: (int a, int b) => a.compareTo(b),
      );
    } on money.MoneyParseException catch (error) {
      throw _error('excessiveDocumentDiscount', error.message, fields: const <String>['rabattBetrag']);
    }

    var netto = 0;
    var ust = 0;
    var brutto = 0;
    for (final MapEntry<int, int> entry in netByRate.entries) {
      final int rate = entry.key;
      final List<int> lineIndexes = <int>[
        for (var index = 0; index < lineRates.length; index++)
          if (lineRates[index] == rate) index,
      ];
      final Map<int, int> discountByPosition;
      try {
        discountByPosition = money.allocateProportionally<int>(
          amount: discountByRate[rate] ?? 0,
          weights: <int, int>{for (final int index in lineIndexes) index: lineNets[index]},
          compareKeys: (int a, int b) {
            final int positionOrder = (positionen[a].position ?? a).compareTo(positionen[b].position ?? b);
            return positionOrder == 0 ? a.compareTo(b) : positionOrder;
          },
        );
      } on money.MoneyParseException catch (error) {
        throw _error('excessiveDocumentDiscount', error.message, fields: const <String>['rabattBetrag']);
      }
      for (final int index in lineIndexes) {
        final RechnungPositionItem position = positionen[index];
        final int lineNet = lineNets[index] - (discountByPosition[index] ?? 0);
        final int lineVat = eingabemodus == 'brutto' && discount == 0
            ? lineAmounts[index] - lineNets[index]
            : _checkedCurrency(
                _roundRatio(BigInt.from(lineNet) * BigInt.from(rate), BigInt.from(10000)),
                index,
                position.position,
                const <String>['ust_betrag'],
              );
        final int lineGross = _checkedCurrency(
          BigInt.from(lineNet) + BigInt.from(lineVat),
          index,
          position.position,
          const <String>['brutto_betrag'],
        );
        netto = _addCurrency(netto, lineNet, index, position.position, const <String>['netto_betrag']);
        ust = _addCurrency(ust, lineVat, index, position.position, const <String>['ust_betrag']);
        brutto = _addCurrency(brutto, lineGross, index, position.position, const <String>['brutto_betrag']);
      }
    }

    return VorschauResult(nettoCents: netto, ustCents: ust, bruttoCents: brutto, rabattCents: appliedDiscount);
  }

  static int _lineAmountCents(int unitPrice, int quantity, int discountPercent, int lineIndex, int? position) {
    final BigInt product = BigInt.from(unitPrice) * BigInt.from(quantity);
    _checkedCurrency(_roundRatio(product, BigInt.from(100000)), lineIndex, position, const <String>['gesamt']);
    return _checkedCurrency(
      _roundRatio(product * BigInt.from(10000 - discountPercent), BigInt.from(1000000000)),
      lineIndex,
      position,
      const <String>['gesamt'],
    );
  }

  static int _quantity(num value, int lineIndex, int? position) => _scaledNonNegative(
    value,
    scale: 3,
    field: 'menge',
    code: 'invalidQuantityScale',
    maximum: _maxQuantityScaled,
    lineIndex: lineIndex,
    position: position,
  );

  static int _unitPrice(num value, int lineIndex, int? position) => _scaledNonNegative(
    value,
    scale: 4,
    field: 'einzelpreis',
    code: 'invalidMoneyScale',
    maximum: _maxUnitPriceScaled,
    lineIndex: lineIndex,
    position: position,
  );

  static int _currency(num value, {required String field, int? lineIndex, int? position}) => _scaledNonNegative(
    value,
    scale: 2,
    field: field,
    code: 'invalidMoneyScale',
    maximum: _maxCurrencyCents,
    lineIndex: lineIndex,
    position: position,
  );

  static int _percent(num value, {required String field, required String code, int? lineIndex, int? position}) {
    final int result = _scaledNonNegative(
      value,
      scale: 2,
      field: field,
      code: code,
      maximum: 9223372036854775807,
      lineIndex: lineIndex,
      position: position,
    );
    if (result > 10000) {
      throw _error(
        code,
        '$field muss zwischen 0 und 100 liegen',
        lineIndex: lineIndex,
        position: position,
        fields: <String>[field],
      );
    }
    return result;
  }

  static int _scaledNonNegative(
    num value, {
    required int scale,
    required String field,
    required String code,
    required int maximum,
    int? lineIndex,
    int? position,
  }) {
    if (!value.isFinite) {
      throw _error(
        'invalidInput',
        '$field muss endlich sein',
        lineIndex: lineIndex,
        position: position,
        fields: <String>[field],
      );
    }
    if (value < 0) {
      throw _error(
        'negativeInput',
        '$field darf nicht negativ sein',
        lineIndex: lineIndex,
        position: position,
        fields: <String>[field],
      );
    }
    try {
      final int scaled = money.scaledFromNum(value, scale: scale, field: field, allowNegative: false);
      if (scaled > maximum) {
        throw _error(
          'valueOutOfRange',
          '$field liegt außerhalb des unterstützten Wertebereichs',
          lineIndex: lineIndex,
          position: position,
          fields: <String>[field],
        );
      }
      return scaled;
    } on money.MoneyParseException catch (error) {
      final String errorCode = error.message.contains('outside the supported integer range') ? 'valueOutOfRange' : code;
      throw _error(errorCode, error.message, lineIndex: lineIndex, position: position, fields: <String>[field]);
    }
  }

  static int _addCurrency(int a, int b, int? lineIndex, int? position, List<String> fields) =>
      _checkedCurrency(BigInt.from(a) + BigInt.from(b), lineIndex, position, fields);

  static int _checkedCurrency(BigInt value, int? lineIndex, int? position, List<String> fields) {
    if (value < BigInt.zero || value > BigInt.from(_maxCurrencyCents)) {
      throw _error(
        'valueOutOfRange',
        'Berechneter Betrag liegt außerhalb des unterstützten Wertebereichs',
        lineIndex: lineIndex,
        position: position,
        fields: fields,
      );
    }
    return value.toInt();
  }

  static BigInt _roundRatio(BigInt numerator, BigInt denominator) =>
      (numerator + denominator ~/ BigInt.two) ~/ denominator;

  static InvoiceMoneyValidationException _error(
    String code,
    String message, {
    int? lineIndex,
    int? position,
    List<String> fields = const <String>[],
  }) => InvoiceMoneyValidationException(
    code: code,
    message: message,
    lineIndex: lineIndex,
    position: position,
    fields: fields,
  );
}
