// ignore_for_file: file_names
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/accounting_tax_polish/accounting_tax_polish.dart';

void main() {
  group('accounting-tax-polish', () {
    test('test_happy', () {
      final AccountingTaxPolishService service = AccountingTaxPolishService();

      // Happy path: trigger mit gültiger Eingabe liefert erwartetes Ergebnis.
      final String outcome = service.trigger('100');
      expect(outcome, '100.00', reason: 'USt/EÜR Betrag poliert auf 2 Dezimalstellen');

      // Poliert direkt — deutscher Finanzbetrag.
      final String polished = service.polishBetrag('100');
      expect(polished, '100.00');

      // Validation für gültig → kein Fehler.
      final String? ok = service.validate('19%');
      expect(ok, isNull);
    });

    test('test_failure', () {
      final AccountingTaxPolishService service = AccountingTaxPolishService();

      // Failure path: ungültige Eingabe liefert Validierungsfehler.
      final String? errorEmpty = service.validate('');
      expect(errorEmpty, isNotNull, reason: 'Leere Eingabe muss Validierungsfehler liefern');
      expect(errorEmpty, contains('ungültig'));

      final String? errorNull = service.validate(null);
      expect(errorNull, isNotNull);
      expect(errorNull, contains('ungültig'));

      // Keine Datenkorruption — polieren ungültiger Wert darf nicht als '0.00' durchgehen
      // ohne Fehler, und trigger darf keinen korrupten State setzen.
      final String polishedInvalid = service.polishBetrag('');
      // Bei ungültig sollte polishBetrag nicht still '0.00' liefern ohne Fehlersignal;
      // hier prüfen wir, dass validate vorher Fehler gemeldet hätte (obige asserts).
      // Zusätzlich: trigger mit Fehler darf nicht 'stub' als gültiges Ergebnis tarnen.
      expect(polishedInvalid, isNot('0.00'), reason: 'Ungültiger Betrag darf nicht still zu 0.00 werden');
    });
  });
}
