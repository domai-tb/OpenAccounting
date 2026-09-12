import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

/// Stable validation failure for invoice money at the domain boundary.
class InvoiceMoneyValidationException extends ArgumentError {
  InvoiceMoneyValidationException({required this.code, required String message, this.lineIndex, this.position})
    : super(message);

  final String code;
  final int? lineIndex;
  final int? position;
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
///
/// Unit prices are accepted at four decimals and quantities at three. All
/// line/header money is rounded once at the two-decimal boundary using integer
/// arithmetic. This keeps preview and reload/finalization byte-for-byte aligned.
class VorschauService {
  static VorschauResult calculate({
    required String eingabemodus,
    required List<RechnungPositionItem> positionen,
    num? rabattProzent,
    num? rabattBetrag,
  }) {
    if (eingabemodus != 'netto' && eingabemodus != 'brutto') {
      throw InvoiceMoneyValidationException(code: 'invalidMode', message: 'Eingabemodus muss netto oder brutto sein');
    }

    final int? documentDiscountPercent = rabattProzent == null ? null : _percent(rabattProzent, field: 'rabattProzent');
    final int? documentDiscountAmount = rabattBetrag == null ? null : _currency(rabattBetrag, field: 'rabattBetrag');
    if ((documentDiscountPercent ?? 0) != 0 && (documentDiscountAmount ?? 0) != 0) {
      throw InvoiceMoneyValidationException(
        code: 'conflictingDocumentDiscounts',
        message: 'Nur ein Rabatt pro Dokument erlaubt (Prozent ODER Betrag)',
      );
    }

    final Map<int, int> netByRate = <int, int>{};
    var lineNetCents = 0;
    for (var index = 0; index < positionen.length; index++) {
      final RechnungPositionItem position = positionen[index];
      if (position.bezeichnung.trim().isEmpty) {
        throw _error('invalidDescription', 'Bezeichnung darf nicht leer sein', index, position.position);
      }
      final int quantity = _quantity(position.menge, index, position.position);
      final int unitPrice = _unitPrice(position.einzelpreis, index, position.position);
      final int assertedTotal = _currency(
        position.gesamt,
        field: 'gesamt',
        lineIndex: index,
        position: position.position,
      );
      final int rate = _percent(position.ustSatz, field: 'ustSatz', lineIndex: index, position: position.position);
      final int lineDiscount = position.rabattProzent == null
          ? 0
          : _percent(position.rabattProzent!, field: 'rabattProzent', lineIndex: index, position: position.position);

      // price has four decimals and quantity three, hence product / 100000
      // yields cents. No intermediate double is involved.
      final int undiscountedCents = _roundHalfUp(unitPrice * quantity, 100000);
      final int lineCents = _roundHalfUp(undiscountedCents * (10000 - lineDiscount), 10000);
      if (assertedTotal != lineCents) {
        throw _error(
          'aggregateMismatch',
          'Positionssumme muss dem auf Cent gerundeten Positionswert entsprechen',
          index,
          position.position,
        );
      }

      final int netCents = eingabemodus == 'netto' ? lineCents : _roundHalfUp(lineCents * 10000, 10000 + rate);
      netByRate.update(rate, (int old) => old + netCents, ifAbsent: () => netCents);
      lineNetCents += netCents;
    }

    final Map<int, int> discountedNetByRate = <int, int>{...netByRate};
    int? appliedDiscount;
    if ((documentDiscountPercent ?? 0) != 0) {
      final int percent = documentDiscountPercent!;
      appliedDiscount = 0;
      for (final MapEntry<int, int> entry in netByRate.entries) {
        final int discount = _roundHalfUp(entry.value * percent, 10000);
        discountedNetByRate[entry.key] = entry.value - discount;
        appliedDiscount = (appliedDiscount ?? 0) + discount;
      }
    } else if ((documentDiscountAmount ?? 0) != 0) {
      final int amount = documentDiscountAmount!;
      if (amount > lineNetCents) {
        throw InvoiceMoneyValidationException(
          code: 'excessiveDocumentDiscount',
          message: 'Betragsrabatt darf die Nettosumme nicht überschreiten',
        );
      }
      final Map<int, int> allocations = _allocateByLargestRemainder(netByRate, amount);
      appliedDiscount = amount;
      for (final MapEntry<int, int> allocation in allocations.entries) {
        discountedNetByRate[allocation.key] = netByRate[allocation.key]! - allocation.value;
      }
    }

    var netto = 0;
    var ust = 0;
    for (final MapEntry<int, int> entry in discountedNetByRate.entries) {
      final int bucketNet = entry.value;
      final int bucketUst = _roundHalfUp(bucketNet * entry.key, 10000);
      netto += bucketNet;
      ust += bucketUst;
    }

    return VorschauResult(nettoCents: netto, ustCents: ust, bruttoCents: netto + ust, rabattCents: appliedDiscount);
  }

  static int _quantity(num value, int lineIndex, int? position) {
    return _scaledNonNegative(
      value,
      scale: 3,
      field: 'menge',
      code: 'invalidQuantityScale',
      lineIndex: lineIndex,
      position: position,
    );
  }

  static int _unitPrice(num value, int lineIndex, int? position) {
    return _scaledNonNegative(
      value,
      scale: 4,
      field: 'einzelpreis',
      code: 'invalidMoneyScale',
      lineIndex: lineIndex,
      position: position,
    );
  }

  static int _currency(num value, {required String field, int? lineIndex, int? position}) {
    return _scaledNonNegative(
      value,
      scale: 2,
      field: field,
      code: 'invalidMoneyScale',
      lineIndex: lineIndex,
      position: position,
    );
  }

  static int _percent(num value, {required String field, int? lineIndex, int? position}) {
    final int result = _scaledNonNegative(
      value,
      scale: 2,
      field: field,
      code: 'invalidPercentage',
      lineIndex: lineIndex,
      position: position,
    );
    if (result > 10000) {
      throw _error(field, '$field muss zwischen 0 und 100 liegen', lineIndex, position);
    }
    return result;
  }

  static int _scaledNonNegative(
    num value, {
    required int scale,
    required String field,
    required String code,
    int? lineIndex,
    int? position,
  }) {
    if (!value.isFinite) {
      throw _error('invalidInput', '$field muss endlich sein', lineIndex, position);
    }
    if (value < 0) {
      throw _error('negativeInput', '$field darf nicht negativ sein', lineIndex, position);
    }
    try {
      return money.scaledFromNum(value, scale: scale, field: field, allowNegative: false);
    } on money.MoneyParseException catch (error) {
      throw _error(code, error.message, lineIndex, position);
    }
  }

  static InvoiceMoneyValidationException _error(String code, String message, int? lineIndex, int? position) {
    return InvoiceMoneyValidationException(code: code, message: message, lineIndex: lineIndex, position: position);
  }

  static int _roundHalfUp(int numerator, int denominator) {
    if (numerator < 0 || denominator <= 0) {
      throw ArgumentError('Only non-negative values can be rounded here');
    }
    return (numerator + denominator ~/ 2) ~/ denominator;
  }

  static Map<int, int> _allocateByLargestRemainder(Map<int, int> buckets, int amount) {
    if (amount == 0 || buckets.isEmpty) {
      return <int, int>{for (final int rate in buckets.keys) rate: 0};
    }
    final int total = buckets.values.fold(0, (int sum, int value) => sum + value);
    if (total == 0) {
      return <int, int>{for (final int rate in buckets.keys) rate: 0};
    }
    final Map<int, int> result = <int, int>{};
    final List<_Remainder> remainders = <_Remainder>[];
    var allocated = 0;
    for (final MapEntry<int, int> entry in buckets.entries) {
      final int numerator = entry.value * amount;
      final int base = numerator ~/ total;
      result[entry.key] = base;
      allocated += base;
      remainders.add(_Remainder(rate: entry.key, remainder: numerator % total));
    }
    remainders.sort((_Remainder a, _Remainder b) {
      final int remainderOrder = b.remainder.compareTo(a.remainder);
      return remainderOrder == 0 ? a.rate.compareTo(b.rate) : remainderOrder;
    });
    var remaining = amount - allocated;
    for (var index = 0; index < remainders.length && remaining > 0; index++) {
      result[remainders[index].rate] = result[remainders[index].rate]! + 1;
      remaining--;
      if (index == remainders.length - 1 && remaining > 0) index = -1;
    }
    return result;
  }
}

class _Remainder {
  const _Remainder({required this.rate, required this.remainder});

  final int rate;
  final int remainder;
}
