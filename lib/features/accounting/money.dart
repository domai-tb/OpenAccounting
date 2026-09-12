/// A malformed or out-of-range decimal at an accounting boundary.
class MoneyParseException implements Exception {
  const MoneyParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Parse a decimal into an integer at [scale] decimal places.
///
/// The decimal text is parsed before any arithmetic is performed. Values with
/// additional digits are rounded half-up only when [roundExcess] is true;
/// otherwise they are rejected. This keeps quantity (scale 3) separate from
/// currency (scale 2) and avoids converting through a binary double.
int parseScaled(
  String raw, {
  required int scale,
  String field = 'value',
  bool allowNegative = true,
  bool roundExcess = false,
}) {
  if (scale < 0) {
    throw ArgumentError.value(scale, 'scale', 'Scale must not be negative');
  }
  final String text = raw.trim().replaceAll(',', '.');
  if (text.isEmpty) {
    throw MoneyParseException('$field must not be empty');
  }
  final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$').firstMatch(text);
  if (match == null) {
    throw MoneyParseException('$field is not a valid decimal');
  }
  final bool negative = match.group(1) == '-';
  if (negative && !allowNegative) {
    throw MoneyParseException('$field must not be negative');
  }
  final String integerPart = match.group(2)!;
  final String fraction = match.group(3) ?? '';
  final int exponent = int.tryParse(match.group(4) ?? '0') ?? 0;
  final int decimalPlaces = fraction.length - exponent;
  final BigInt digits = BigInt.parse('$integerPart$fraction');
  final BigInt magnitude;
  if (decimalPlaces <= scale) {
    magnitude = digits * BigInt.from(10).pow(scale - decimalPlaces);
  } else {
    final BigInt divisor = BigInt.from(10).pow(decimalPlaces - scale);
    final BigInt remainder = digits.remainder(divisor);
    if (remainder != BigInt.zero && !roundExcess) {
      throw MoneyParseException('$field has more than $scale decimal places');
    }
    var rounded = digits ~/ divisor;
    if (roundExcess && remainder * BigInt.two >= divisor) {
      rounded += BigInt.one;
    }
    magnitude = rounded;
  }
  final BigInt signed = negative ? -magnitude : magnitude;
  if (signed < BigInt.from(-9223372036854775807) || signed > BigInt.from(9223372036854775807)) {
    throw MoneyParseException('$field is outside the supported integer range');
  }
  // Keep this local so a malformed/excess value never reaches int.parse.
  return signed.toInt();
}

int scaledFromNum(
  num value, {
  required int scale,
  String field = 'value',
  bool allowNegative = true,
  bool roundExcess = false,
}) {
  if (!value.isFinite) {
    throw MoneyParseException('$field must be finite');
  }
  return parseScaled(
    value.toString(),
    scale: scale,
    field: field,
    allowNegative: allowNegative,
    roundExcess: roundExcess,
  );
}

int toCents(String raw) {
  final String text = raw.trim();
  if (text.isEmpty) return 0;
  return parseScaled(text, scale: 2, roundExcess: true, field: 'amount');
}

int toCurrencyCents(num value, {String field = 'amount'}) => scaledFromNum(value, scale: 2, field: field);

int toQuantityThousandths(num value, {String field = 'quantity'}) =>
    scaledFromNum(value, scale: 3, field: field, allowNegative: false);

String fromCents(int cents) {
  final bool isNeg = cents < 0;
  final int abs = cents.abs();
  final String intPart = (abs ~/ 100).toString();
  final String dec = (abs % 100).toString().padLeft(2, '0');
  return '${isNeg ? '-' : ''}$intPart.$dec';
}

String formatBetrag(String raw) {
  final String text = raw.trim();
  if (text.isEmpty) return '0.00';
  return fromCents(parseScaled(text, scale: 2, roundExcess: true, field: 'amount'));
}

String add(String a, String b) {
  return fromCents(toCents(a) + toCents(b));
}
