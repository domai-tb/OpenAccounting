// ignore_for_file: dangling_library_doc_comments
/// Accounting-tax-polish — additive polish für USt/EÜR/EKS (German finance).
/// VM-safe, pure logic, no DB. Reuses money helpers to avoid double drift.
import 'package:openaccounting/features/accounting/money.dart' as money;

const String _kEmptyInput = 'ungültig: leere Eingabe';
const String _kNotANumber = 'ungültig: keine Zahl';

class AccountingTaxPolishService {
  /// Trigger happy path — polierter Betrag via money helpers.
  String trigger(String eingabe) {
    final String? err = validate(eingabe);
    if (err != null) throw FormatException(err);
    return polishBetrag(eingabe);
  }

  /// Validiert Eingabe — null wenn gültig, 'ungültig:...' wenn ungültig.
  String? validate(String? eingabe) {
    if (eingabe == null || eingabe.trim().isEmpty) return _kEmptyInput;
    try {
      // Use the same parser as the formatter so validation and execution
      // cannot disagree about what is a numeric accounting value.
      money.parseScaled(eingabe, scale: 2, field: 'amount', roundExcess: true);
    } on money.MoneyParseException {
      return _kNotANumber;
    }
    return null;
  }

  /// Poliert Betrag-String nach deutschem Finanzformat (2 Dezimalstellen).
  /// Leerer Input liefert Fehlersignal statt still '0.00'.
  String polishBetrag(String raw) {
    if (raw.trim().isEmpty) return _kEmptyInput;
    try {
      return money.formatBetrag(raw);
    } on money.MoneyParseException {
      return _kNotANumber;
    }
  }
}
