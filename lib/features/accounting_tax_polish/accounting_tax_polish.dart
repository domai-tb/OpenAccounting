// ignore_for_file: dangling_library_doc_comments
/// Accounting-tax-polish — additive polish für USt/EÜR/EKS (German finance).
/// VM-safe, pure logic, no DB. Reuses money helpers to avoid double drift.
import 'package:openaccounting/features/accounting/money.dart';

class AccountingTaxPolishService {
  /// Trigger happy path — polierter Betrag via money helpers.
  String trigger(String eingabe) => polishBetrag(eingabe);

  /// Validiert Eingabe — null wenn gültig, 'ungültig:...' wenn ungültig.
  String? validate(String? eingabe) {
    if (eingabe == null || eingabe.trim().isEmpty) {
      return 'ungültig: leere Eingabe';
    }
    return null;
  }

  /// Poliert Betrag-String nach deutschem Finanzformat (2 Dezimalstellen).
  /// Leerer Input liefert Fehlersignal statt still '0.00'.
  String polishBetrag(String raw) {
    if (raw.trim().isEmpty) {
      return 'ungültig';
    }
    return formatBetrag(raw);
  }
}
