// ponytail: string constants — Dart enum if >3 call sites diverge.
class BelegTyp {
  const BelegTyp._();

  static const String einnahme = 'Einnahme';
  static const String ausgabe = 'Ausgabe';
  static const String zahlung = 'Zahlung';
  static const String ueberzahlung = 'Ueberzahlung';
  static const String ausbuchung = 'Ausbuchung';
  static const String eroeffnung = 'Eroeffnung';

  /// Only these affect Gewinn/EÜR. All others are cash-movement only.
  static const Set<String> revenue = <String>{einnahme};
  static const Set<String> expense = <String>{ausgabe};

  /// Explicit non-revenue set — opening cash, payments, overpayments, write-offs.
  static const Set<String> nonRevenue = <String>{zahlung, ueberzahlung, ausbuchung, eroeffnung};

  static const Set<String> all = <String>{einnahme, ausgabe, zahlung, ueberzahlung, ausbuchung, eroeffnung};

  static bool isRevenue(String? raw) => (raw?.trim().toLowerCase() ?? '') == einnahme.toLowerCase();

  static bool isExpense(String? raw) => (raw?.trim().toLowerCase() ?? '') == ausgabe.toLowerCase();

  static bool isNonRevenue(String? raw) {
    final String v = raw?.trim().toLowerCase() ?? '';
    return nonRevenue.map((String e) => e.toLowerCase()).contains(v);
  }
}
