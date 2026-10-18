/// Approved typed tax classification for structured e-invoice output.
///
/// Category selection follows an explicit persisted treatment tuple; a rate
/// alone never selects a legal category. Cross-border and margin-scheme values
/// are emitted only when their statutory code and required source evidence are
/// present.
enum EInvoiceTaxCategory {
  /// Standard-rated taxable supply.
  standard('S'),

  /// Legally zero-rated taxable supply (0 %, no exemption reason).
  zeroRated('Z'),

  /// Exempt supply (0 % with the exact statutory reason text).
  exempt('E'),

  /// Intra-community supply under UStG § 4 Nr. 1(b) with § 6a.
  intraCommunitySupply('K'),

  /// Export supply under UStG § 4 Nr. 1(a) with § 6.
  export('G'),

  /// Reverse charge (0 %, with an explicit VATEX reason code and text).
  reverseCharge('AE');

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
enum EInvoiceTaxTreatment {
  standard19('standard_19'),
  reduced7('reduced_7'),
  taxableZero12_3('taxable_zero_12_3'),
  kleinunternehmer19('kleinunternehmer_19'),
  reverseChargeEuService13b1('reverse_charge_eu_service_13b_1'),
  reverseChargeDomesticConstruction13b2_4_5('reverse_charge_domestic_construction_13b_2_4_5'),
  intraCommunitySupply6a('intra_community_supply_6a'),
  exportSupply6('export_supply_6'),
  marginScheme25aSecondHand('margin_scheme_25a_second_hand'),
  marginScheme25aArt('margin_scheme_25a_art'),
  marginScheme25aCollectorsAntiquities('margin_scheme_25a_collectors_antiquities');

  const EInvoiceTaxTreatment(this.code);

  final String code;

  static EInvoiceTaxTreatment? fromCode(String? code) {
    for (final EInvoiceTaxTreatment treatment in EInvoiceTaxTreatment.values) {
      if (treatment.code == code) return treatment;
    }
    return null;
  }
}

enum EInvoiceTaxLegalBasis {
  ustg12_1('ustg_12_1'),
  ustg12_2('ustg_12_2'),
  ustg12_3('ustg_12_3'),
  ustg19('ustg_19'),
  ustg3a2_13b1('ustg_3a_2_13b_1'),
  ustg13b2_4_5('ustg_13b_2_4_5'),
  ustg4_1b_6a('ustg_4_1b_6a'),
  ustg4_1a_6('ustg_4_1a_6'),
  ustg25a('ustg_25a');

  const EInvoiceTaxLegalBasis(this.code);

  final String code;

  static EInvoiceTaxLegalBasis? fromCode(String? code) {
    for (final EInvoiceTaxLegalBasis basis in EInvoiceTaxLegalBasis.values) {
      if (basis.code == code) return basis;
    }
    return null;
  }
}

class EInvoiceTaxClassificationResult {
  const EInvoiceTaxClassificationResult.resolved(this.classification) : fieldDiagnostics = const <String>[];

  const EInvoiceTaxClassificationResult.unresolved(this.fieldDiagnostics) : classification = null;

  final EInvoiceLineClassification? classification;
  final List<String> fieldDiagnostics;

  bool get isResolved => classification != null;
}

class EInvoiceLineClassification {
  const EInvoiceLineClassification({
    required this.treatment,
    required this.legalBasis,
    required this.category,
    this.exemptionReasonCode,
    this.exemptionReason,
    this.invoiceNote,
  });

  final EInvoiceTaxTreatment treatment;
  final EInvoiceTaxLegalBasis legalBasis;
  final EInvoiceTaxCategory category;
  final String? exemptionReasonCode;
  final String? exemptionReason;

  /// Statutory BT-22 note required for this treatment, when applicable.
  final String? invoiceNote;
}

/// Typed source for the approved initial-scope mapping.
///
/// Keys are exact percentages in hundredths (1900 = 19.00 %). A rate that is
/// absent here is unresolved: generation must fail with a field-level
/// diagnostic naming the line, never pick a code from the percentage.
class ApprovedTaxClassification {
  const ApprovedTaxClassification._();

  static const String kleinunternehmerReason = 'Kein Ausweis von Umsatzsteuer, da Kleinunternehmer gemäß § 19 UStG';

  /// Resolves only explicit, persisted treatment tuples in the supported scope.
  /// Percentages never select a treatment or category.
  static EInvoiceTaxClassificationResult resolve({
    required String? treatmentCode,
    required String? legalBasisCode,
    required String? categoryCode,
    required String? exemptionReasonCode,
    required String? exemptionReasonText,
    required int taxRateHundredths,
    required bool sellerHasTaxRegistration,
  }) {
    final EInvoiceTaxTreatment? treatment = EInvoiceTaxTreatment.fromCode(treatmentCode);
    if (treatment == null) {
      return const EInvoiceTaxClassificationResult.unresolved(<String>['tax_treatment']);
    }

    final EInvoiceTaxLegalBasis? legalBasis = EInvoiceTaxLegalBasis.fromCode(legalBasisCode);
    if (legalBasis == null) {
      return const EInvoiceTaxClassificationResult.unresolved(<String>['tax_legal_basis']);
    }

    final EInvoiceTaxCategory expectedCategory;
    final EInvoiceTaxLegalBasis expectedBasis;
    final int expectedRate;
    final String? expectedReason;
    final String? expectedReasonCode;
    String? invoiceNote;
    switch (treatment) {
      case EInvoiceTaxTreatment.standard19:
        expectedCategory = EInvoiceTaxCategory.standard;
        expectedBasis = EInvoiceTaxLegalBasis.ustg12_1;
        expectedRate = 1900;
        expectedReason = null;
        expectedReasonCode = null;
      case EInvoiceTaxTreatment.reduced7:
        expectedCategory = EInvoiceTaxCategory.standard;
        expectedBasis = EInvoiceTaxLegalBasis.ustg12_2;
        expectedRate = 700;
        expectedReason = null;
        expectedReasonCode = null;
      case EInvoiceTaxTreatment.taxableZero12_3:
        expectedCategory = EInvoiceTaxCategory.zeroRated;
        expectedBasis = EInvoiceTaxLegalBasis.ustg12_3;
        expectedRate = 0;
        expectedReason = null;
        expectedReasonCode = null;
      case EInvoiceTaxTreatment.kleinunternehmer19:
        expectedCategory = EInvoiceTaxCategory.exempt;
        expectedBasis = EInvoiceTaxLegalBasis.ustg19;
        expectedRate = 0;
        expectedReason = kleinunternehmerReason;
        expectedReasonCode = null;
      case EInvoiceTaxTreatment.intraCommunitySupply6a:
        expectedCategory = EInvoiceTaxCategory.intraCommunitySupply;
        expectedBasis = EInvoiceTaxLegalBasis.ustg4_1b_6a;
        expectedRate = 0;
        expectedReasonCode = 'VATEX-EU-IC';
        expectedReason = exemptionReasonText;
        if (exemptionReasonText != 'Steuerfreie innergemeinschaftliche Lieferung' &&
            exemptionReasonText != 'Steuerfrei nach § 4 Nr. 1 Buchst. b i. V. m. § 6a UStG') {
          return const EInvoiceTaxClassificationResult.unresolved(<String>['e_invoice_exemption_reason_text']);
        }
      case EInvoiceTaxTreatment.exportSupply6:
        expectedCategory = EInvoiceTaxCategory.export;
        expectedBasis = EInvoiceTaxLegalBasis.ustg4_1a_6;
        expectedRate = 0;
        expectedReason = null;
        expectedReasonCode = 'VATEX-EU-G';
      case EInvoiceTaxTreatment.marginScheme25aSecondHand:
        expectedCategory = EInvoiceTaxCategory.exempt;
        expectedBasis = EInvoiceTaxLegalBasis.ustg25a;
        expectedRate = 0;
        expectedReason = 'Gebrauchtgegenstände/Sonderregelung';
        expectedReasonCode = 'VATEX-EU-F';
        invoiceNote = expectedReason;
      case EInvoiceTaxTreatment.marginScheme25aArt:
        expectedCategory = EInvoiceTaxCategory.exempt;
        expectedBasis = EInvoiceTaxLegalBasis.ustg25a;
        expectedRate = 0;
        expectedReason = 'Kunstgegenstände/Sonderregelung';
        expectedReasonCode = 'VATEX-EU-I';
        invoiceNote = expectedReason;
      case EInvoiceTaxTreatment.marginScheme25aCollectorsAntiquities:
        expectedCategory = EInvoiceTaxCategory.exempt;
        expectedBasis = EInvoiceTaxLegalBasis.ustg25a;
        expectedRate = 0;
        expectedReason = 'Sammlungsstücke und Antiquitäten/Sonderregelung';
        expectedReasonCode = 'VATEX-EU-J';
        invoiceNote = expectedReason;
      case EInvoiceTaxTreatment.reverseChargeEuService13b1:
        expectedCategory = EInvoiceTaxCategory.reverseCharge;
        expectedBasis = EInvoiceTaxLegalBasis.ustg3a2_13b1;
        expectedRate = 0;
        expectedReason = 'Steuerschuldnerschaft des Leistungsempfängers';
        expectedReasonCode = 'VATEX-EU-AE';
      case EInvoiceTaxTreatment.reverseChargeDomesticConstruction13b2_4_5:
        expectedCategory = EInvoiceTaxCategory.reverseCharge;
        expectedBasis = EInvoiceTaxLegalBasis.ustg13b2_4_5;
        expectedRate = 0;
        expectedReason = 'Steuerschuldnerschaft des Leistungsempfängers';
        expectedReasonCode = 'VATEX-EU-AE';
    }

    final List<String> fields = <String>[];
    if (legalBasis != expectedBasis) fields.add('tax_legal_basis');
    if (categoryCode != expectedCategory.code) fields.add('e_invoice_tax_category_code');
    if (taxRateHundredths != expectedRate) fields.add('ust_satz');
    if (exemptionReasonCode != expectedReasonCode) fields.add('e_invoice_exemption_reason_code');
    if (exemptionReasonText != expectedReason) fields.add('e_invoice_exemption_reason_text');
    if (treatment == EInvoiceTaxTreatment.taxableZero12_3 && !sellerHasTaxRegistration) {
      fields.addAll(<String>['ust_idnr', 'steuernummer', 'tax_representative_vat_id']);
    }
    if (fields.isNotEmpty) {
      return EInvoiceTaxClassificationResult.unresolved(List<String>.unmodifiable(fields));
    }

    return EInvoiceTaxClassificationResult.resolved(
      EInvoiceLineClassification(
        treatment: treatment,
        legalBasis: legalBasis,
        category: expectedCategory,
        exemptionReasonCode: exemptionReasonCode,
        exemptionReason: exemptionReasonText,
        invoiceNote: invoiceNote,
      ),
    );
  }
}
