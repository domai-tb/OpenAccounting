import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';

class VorschauResult {
  const VorschauResult({
    required this.nettoBetrag,
    required this.ustBetrag,
    required this.bruttoBetrag,
    this.rabattBetrag,
  });
  final num nettoBetrag;
  final num ustBetrag;
  final num bruttoBetrag;
  final num? rabattBetrag;
}

class VorschauService {
  static VorschauResult calculate({
    required String eingabemodus,
    required List<RechnungPositionItem> positionen,
    num? rabattProzent,
    num? rabattBetrag,
  }) {
    if (rabattProzent != null && rabattProzent != 0 && rabattBetrag != null && rabattBetrag != 0) {
      throw ArgumentError('Nur ein Rabatt pro Dokument erlaubt (Prozent ODER Betrag)');
    }
    if (eingabemodus != 'netto' && eingabemodus != 'brutto') {
      throw ArgumentError.value(eingabemodus, 'eingabemodus', 'Muss netto oder brutto sein');
    }
    var sumNettoCents = 0;
    var sumUstCents = 0;
    var sumBruttoCents = 0;
    for (final p in positionen) {
      final baseCents = (p.einzelpreis * p.menge * 100).round();
      var lineCents = baseCents;
      if (p.rabattProzent != null && p.rabattProzent != 0) {
        final rabatt = _toCents(p.rabattProzent!);
        // rabatt percent is e.g. 10 => 1000 cents (10.00)
        lineCents = (lineCents * (10000 - rabatt) + 5000) ~/ 10000;
      }
      final ustSatzCents = _toCents(p.ustSatz);
      if (eingabemodus == 'netto') {
        final netto = lineCents;
        final ust = (netto * ustSatzCents + 5000) ~/ 10000;
        final brutto = netto + ust;
        sumNettoCents += netto;
        sumUstCents += ust;
        sumBruttoCents += brutto;
      } else {
        final brutto = lineCents;
        // netto = brutto / (1+ust/100) => brutto*10000/(10000+ust)
        final netto = (brutto * 10000 + (10000 + ustSatzCents) ~/ 2) ~/ (10000 + ustSatzCents);
        final ust = brutto - netto;
        sumNettoCents += netto;
        sumUstCents += ust;
        sumBruttoCents += brutto;
      }
    }
    var netto = sumNettoCents;
    var ust = sumUstCents;
    var brutto = sumBruttoCents;
    num? rabattAppliedCents;
    if (rabattProzent != null && rabattProzent != 0) {
      final rabattCents = _toCents(rabattProzent);
      final discount = (netto * rabattCents + 5000) ~/ 10000;
      netto -= discount;
      // recalc ust proportionally? simplified: keep ust ratio, but spec says doc rabatt applied after summing position totals before USt? For now discount netto, ust recalculated proportionally
      // ponytail: simple proportional ust reduction
      final ustDiscount = (ust * rabattCents + 5000) ~/ 10000;
      ust -= ustDiscount;
      brutto = netto + ust;
      rabattAppliedCents = discount;
    } else if (rabattBetrag != null && rabattBetrag != 0) {
      final discount = _toCents(rabattBetrag);
      netto -= discount;
      // adjust ust proportionally: keep same effective rate
      if (sumNettoCents != 0) {
        ust = (ust * netto + sumNettoCents ~/ 2) ~/ sumNettoCents;
      }
      brutto = netto + ust;
      rabattAppliedCents = discount;
    }
    return VorschauResult(
      nettoBetrag: netto / 100.0,
      ustBetrag: ust / 100.0,
      bruttoBetrag: brutto / 100.0,
      rabattBetrag: rabattAppliedCents != null ? rabattAppliedCents / 100.0 : null,
    );
  }

  static int _toCents(num v) {
    if (!v.isFinite) throw ArgumentError.value(v, 'value', 'Muss endlich sein');
    // ponytail: round to cents, allow 4 decimals for vk_netto cases; strict 2-dec check moved to usecase validation for plain inputs
    return (v * 100).round();
  }
}
