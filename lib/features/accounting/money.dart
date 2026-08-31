/// Shared money helpers for accounting — string cents to avoid double drift.
/// ponytail: pure functions, trunc to 2 decimals, no abstraction beyond needed.
int toCents(String raw) {
  final String t = raw.trim();
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
  final String dec = '${decRaw}00'.substring(0, 2);
  final int cents = int.parse(effInt) * 100 + int.parse(dec);
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
  final String t = raw.trim();
  if (t.isEmpty) {
    return '0.00';
  }
  final bool isNeg = t.startsWith('-');
  final String unsigned = isNeg ? t.substring(1) : t;
  final List<String> parts = unsigned.split('.');
  final String intPart = parts[0].isEmpty ? '0' : parts[0];
  final String decRaw = parts.length > 1 ? parts[1] : '';
  final String dec = '${decRaw}00'.substring(0, 2);
  return '${isNeg ? '-' : ''}$intPart.$dec';
}

String add(String a, String b) {
  return fromCents(toCents(a) + toCents(b));
}
