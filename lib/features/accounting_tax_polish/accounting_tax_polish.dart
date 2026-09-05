/// Accounting-tax-polish — additive polish für USt/EÜR/EKS (German finance).
/// VM-safe, pure logic, no DB. Ponytail ultra: stub fails RED phase.
class AccountingTaxPolishService {
  /// Trigger happy path — soll polierten Betrag liefern.
  /// Stub liefert absichtlich falschen Wert für RED.
  String trigger(String eingabe) {
    return 'stub';
  }

  /// Validiert Eingabe — soll Fehler bei ungültig liefern.
  /// Stub liefert absichtlich null (kein Fehler) für RED.
  String? validate(String? eingabe) {
    return null;
  }

  /// Poliert Betrag-String nach deutschem Finanzformat (2 Dezimalstellen).
  /// Stub liefert absichtlich '0.00' für RED.
  String polishBetrag(String raw) {
    return '0.00';
  }
}
