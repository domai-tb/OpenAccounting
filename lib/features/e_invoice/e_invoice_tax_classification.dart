/// Approved typed tax classification for structured e-invoice output.
///
/// Initial supported scope (ordinary domestic invoices): standard-rated lines
/// at exactly 19.00 % or 7.00 % map to EN 16931 category `S`. Every other
/// treatment (zero rate, exemption, reverse charge, intra-community supply,
/// margin scheme) has no approved mapping yet and fails closed with a typed
/// diagnostic instead of being inferred from the percentage. Extending the
/// scope requires an explicit map entry reviewed with the owning tax
/// capability; never add rate-only guesses here.
enum EInvoiceTaxCategory {
  /// Standard-rated sale.
  standard('S');

  const EInvoiceTaxCategory(this.code);

  /// EN 16931 / CII `CategoryCode` and UBL `TaxCategory/ID`.
  final String code;

  static EInvoiceTaxCategory? fromCode(String? code) {
    for (final EInvoiceTaxCategory category in EInvoiceTaxCategory.values) {
      if (category.code == code) return category;
    }
    return null;
  }
}

/// Explicit per-line classification consumed by serialization.
class EInvoiceLineClassification {
  const EInvoiceLineClassification({required this.category, this.exemptionReason});

  final EInvoiceTaxCategory category;

  /// Required reason text for exempt-type categories; unused in the initial
  /// scope but carried so the contract stays stable when it grows.
  final String? exemptionReason;
}

/// Typed source for the approved initial-scope mapping.
///
/// Keys are exact percentages in hundredths (1900 = 19.00 %). A rate that is
/// absent here is unresolved: generation must fail with a field-level
/// diagnostic naming the line, never pick a code from the percentage.
class ApprovedTaxClassification {
  const ApprovedTaxClassification._();

  static const Map<int, EInvoiceTaxCategory> _byRateHundredths = <int, EInvoiceTaxCategory>{
    1900: EInvoiceTaxCategory.standard,
    700: EInvoiceTaxCategory.standard,
  };

  /// Resolves the approved category for an exact stored rate, or null when
  /// the treatment has no approved mapping.
  static EInvoiceLineClassification? resolve(num ustSatz) {
    final int hundredths = (ustSatz * 100).round();
    // Reject non-exact decimals instead of coercing them into the map.
    if ((hundredths / 100 - ustSatz).abs() > 0.000001) return null;
    final EInvoiceTaxCategory? category = _byRateHundredths[hundredths];
    if (category == null) return null;
    return EInvoiceLineClassification(category: category);
  }
}
