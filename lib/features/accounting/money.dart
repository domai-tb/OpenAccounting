/// Shared money helpers for accounting — string cents to avoid double drift.
/// ponytail: pure functions, round half-up on 3rd decimal to match normalize.
int toCents(String raw) {
  final String t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) {
    return 0;
  }
  final bool isNeg = t.startsWith('-');
  final String unsigned = isNeg ? t.substring(1) : t;
  final List<String> parts = unsigned.split('.');
  final String intPartRaw = parts[0].isEmpty ? '0' : parts[0];
  final String intNoLead = intPartRaw.replaceFirst(RegExp('^0+'), '');
  final String effInt = intNoLead.isEmpty ? '0' : intNoLead;
  final String decRaw = parts.length > 1 ? parts[1] : '';
  int decCents = 0;
  bool carry = false;
  if (decRaw.length <= 2) {
    final String dec = '${decRaw}00'.substring(0, 2);
    decCents = int.parse(dec);
  } else {
    final int firstTwo = int.parse(decRaw.substring(0, 2));
    final int third = int.tryParse(decRaw[2]) ?? 0;
    if (third >= 5) {
      decCents = firstTwo + 1;
      if (decCents == 100) {
        decCents = 0;
        carry = true;
      }
    } else {
      decCents = firstTwo;
    }
  }
  int cents = int.parse(effInt) * 100 + decCents;
  if (carry) cents += 100;
  return isNeg ? -cents : cents;
}

String fromCents(int cents) {
  final bool isNeg = cents < 0;
  final int abs = cents.abs();
  final String intPart = (abs ~/ 100).toString();
  final String dec = (abs % 100).toString().padLeft(2, '0');
  return '${isNeg ? '-' : ''}$intPart.$dec';
}

String formatBetrag(String raw) {
  final String t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) {
    return '0.00';
  }
  final bool isNeg = t.startsWith('-');
  final String unsigned = isNeg ? t.substring(1) : t;
  final List<String> parts = unsigned.split('.');
  final String intPart = parts[0].isEmpty ? '0' : parts[0];
  final String decRaw = parts.length > 1 ? parts[1] : '';
  // ponytail: round half-up for display, same as toCents.
  if (decRaw.length <= 2) {
    final String dec = '${decRaw}00'.substring(0, 2);
    return '${isNeg ? '-' : ''}$intPart.$dec';
  }
  final int firstTwo = int.parse(decRaw.substring(0, 2).padRight(2, '0'));
  final int third = int.tryParse(decRaw.length > 2 ? decRaw[2] : '0') ?? 0;
  var decCents = firstTwo;
  var carryInt = 0;
  if (third >= 5) {
    decCents += 1;
    if (decCents == 100) {
      decCents = 0;
      carryInt = 1;
    }
  }
  final int intVal = int.parse(intPart) + carryInt;
  final String dec = decCents.toString().padLeft(2, '0');
  return '${isNeg ? '-' : ''}$intVal.$dec';
}

String add(String a, String b) {
  return fromCents(toCents(a) + toCents(b));
}
