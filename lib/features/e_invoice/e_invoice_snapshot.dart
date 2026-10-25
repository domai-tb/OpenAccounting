import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/e_invoice/e_invoice_output_format.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_tax_classification.dart';

/// Typed source-data failure: persisted values do not satisfy the canonical
/// money/tax contracts, so no output may be produced from them.
class EInvoiceSourceException implements Exception {
  const EInvoiceSourceException({
    required this.code,
    required this.messageDe,
    required this.messageEn,
    this.fields = const <String>[],
  });

  final String code;
  final String messageDe;
  final String messageEn;
  final List<String> fields;

  String messageFor(String locale) => locale.startsWith('en') ? messageEn : messageDe;

  @override
  String toString() => messageDe;
}

/// Immutable counterparty captured at finalization time.
class EInvoicePartySnapshot {
  const EInvoicePartySnapshot({
    required this.name,
    this.company,
    this.street,
    this.postalCode,
    this.city,
    this.country,
    this.taxNumber,
    this.vatId,
    this.taxRepresentativeVatId,
    this.email,
    this.iban,
    this.endpointId,
    this.endpointScheme,
    this.companyLegalForm,
  });

  final String name;
  final String? company;
  final String? street;
  final String? postalCode;
  final String? city;
  final String? country;
  final String? taxNumber;
  final String? vatId;
  final String? taxRepresentativeVatId;
  final String? email;

  /// Company IBAN for XRechnung payment means (BG-16/BG-17), or null when
  /// the company record carries none. Never invented.
  final String? iban;

  /// Resolved electronic address for XRechnung (BT-34/BT-49), or null when
  /// no approved source exists. Never invented; validation fails closed.
  final String? endpointId;
  final String? endpointScheme;

  /// BT-33 additional legal information required for §19 UStG invoices.
  final String? companyLegalForm;
}

/// Immutable line with canonical cent amounts and explicit classification.
class EInvoiceLineSnapshot {
  const EInvoiceLineSnapshot({
    required this.position,
    required this.description,
    required this.quantityText,
    required this.unitPriceText,
    required this.netUnitPriceText,
    this.priceBaseQuantityText = '1',
    required this.unitPriceIsGross,
    required this.netCents,
    required this.taxCents,
    required this.grossCents,
    required this.taxRateHundredths,
    required this.classification,
    this.lineAllowance,
  });

  final int position;
  final String description;

  /// Quantity rendered from the stored scale-3 value, never recalculated.
  final String quantityText;

  /// The unit-price denominator, currently one billed piece per stored unit price.
  final String priceBaseQuantityText;

  /// Source unit price rendered at scale 4; gross for brutto input.
  final String unitPriceText;

  /// VAT-exclusive unit price serialized in UBL and CII, sourced from canonical position net amounts.
  final String netUnitPriceText;

  final bool unitPriceIsGross;
  final int netCents;
  final int taxCents;
  final int grossCents;

  /// Canonical line-level allowance. Null when no adjustment exists.
  final EInvoiceLineAllowanceSnapshot? lineAllowance;

  /// Exact VAT percentage in hundredths (1900 = 19.00 %).
  final int taxRateHundredths;
  final EInvoiceLineClassification classification;
}

class EInvoiceLineAllowanceSnapshot {
  const EInvoiceLineAllowanceSnapshot({
    required this.amountCents,
    required this.baseAmountCents,
    required this.percentHundredths,
  });

  final int amountCents;
  final int baseAmountCents;
  final int percentHundredths;
}

/// One immutable finalization snapshot.
///
/// Materialized inside the finalization transaction after number allocation
/// and canonical calculation, before artifact generation. Serializers consume
/// only these values; they never calculate, round, or reclassify money.
class FinalizationSnapshot {
  const FinalizationSnapshot({
    required this.documentNumber,
    required this.outputFormat,
    required this.issueDate,
    required this.currency,
    required this.seller,
    required this.buyer,
    required this.lines,
    required this.taxBreakdowns,
    required this.netCents,
    required this.taxCents,
    required this.grossCents,
    this.accountingNetCents,
    this.accountingTaxCents,
    this.accountingGrossCents,
    this.buyerReference,
    this.deliveryDate,
    this.invoiceNotes = const <String>[],
  });

  final String documentNumber;
  final EInvoiceOutputFormat outputFormat;

  /// ISO date (YYYY-MM-DD) of the finalized invoice.
  final String issueDate;

  /// ISO 4217 currency. Initial scope is EUR-only; multi-currency invoices
  /// fail validation instead of being converted.
  final String currency;
  final EInvoicePartySnapshot seller;
  final EInvoicePartySnapshot buyer;
  final List<EInvoiceLineSnapshot> lines;
  final List<EInvoiceTaxBreakdownSnapshot> taxBreakdowns;
  final List<String> invoiceNotes;
  final int netCents;
  final int taxCents;
  final int grossCents;

  /// Original accounting totals captured before the e-invoice disclosure map.
  /// These remain separate when a §25a payable includes internally assessed
  /// margin-scheme tax that must not be disclosed as invoice VAT.
  final int? accountingNetCents;
  final int? accountingTaxCents;
  final int? accountingGrossCents;

  /// Explicit buyer reference (e.g. Leitweg-ID) supplied for XRechnung
  /// export. Null means absent; serializers must not invent one.
  final String? buyerReference;

  /// Optional delivery date (ISO YYYY-MM-DD) for XRechnung BT-72.
  /// Null means absent; serializers must not infer one from other dates.
  final String? deliveryDate;
}

/// Canonical totals owned by the accepted invoice-money calculator.
///
/// Callers map the calculator result into this struct; serializers only ever
/// see these exact cent values.
class EInvoiceCanonicalTotals {
  const EInvoiceCanonicalTotals({
    required this.netCents,
    required this.taxCents,
    required this.grossCents,
    this.positionTotals = const <EInvoiceCanonicalPositionAmounts>[],
    this.disclosureTotals,
  });

  final int netCents;
  final int taxCents;
  final int grossCents;

  /// Position-keyed amounts supplied by the accounting calculator.
  final List<EInvoiceCanonicalPositionAmounts> positionTotals;

  /// EN 16931 totals supplied by the position-keyed disclosure source.
  final EInvoiceDisclosureTotals? disclosureTotals;
}

class EInvoiceDisclosureTotals {
  const EInvoiceDisclosureTotals({required this.netCents, required this.taxCents, required this.grossCents});

  final int netCents;
  final int taxCents;
  final int grossCents;
}

/// Canonical accounting amounts for one persisted invoice position.
class EInvoiceCanonicalPositionAmounts {
  const EInvoiceCanonicalPositionAmounts({
    required this.position,
    required this.netCents,
    required this.taxCents,
    required this.grossCents,
    this.priceBasisNetCents,
    this.lineDiscountCents,
  });

  final int position;
  final int netCents;
  final int taxCents;
  final int grossCents;

  /// VAT-exclusive line amount before the persisted line discount.
  final int? priceBasisNetCents;

  /// VAT-exclusive allowance amount calculated by the accounting preview.
  final int? lineDiscountCents;
}

class EInvoiceTaxBreakdownSnapshot {
  const EInvoiceTaxBreakdownSnapshot({
    required this.taxRateHundredths,
    required this.classification,
    required this.netCents,
    required this.taxCents,
  });

  final int taxRateHundredths;
  final EInvoiceLineClassification classification;
  final int netCents;
  final int taxCents;
}

/// Builds [FinalizationSnapshot] values from transaction-captured rows.
///
/// Canonical totals come from the accepted money calculator result passed in
/// as the `preview` argument. Per-line splits reuse that calculator plus
/// half-up cent rounding; their sums MUST equal the preview totals or the
/// build fails. Nothing here replaces the calculator: a mismatch throws.
class EInvoiceSnapshotBuilder {
  const EInvoiceSnapshotBuilder();

  static const Set<String> _euMemberCountryCodes = <String>{
    'AT',
    'BE',
    'BG',
    'CY',
    'CZ',
    'DE',
    'DK',
    'EE',
    'ES',
    'FI',
    'FR',
    'GR',
    'HR',
    'HU',
    'IE',
    'IT',
    'LT',
    'LU',
    'LV',
    'MT',
    'NL',
    'PL',
    'PT',
    'RO',
    'SE',
    'SI',
    'SK',
  };

  FinalizationSnapshot buildFinalization({
    required String documentNumber,
    required EInvoiceOutputFormat outputFormat,
    required String issueDate,
    required Map<String, Object?> companyRow,
    required Map<String, Object?> customerRow,
    required List<Map<String, Object?>> posRows,
    required EInvoiceCanonicalTotals preview,
    required String eingabemodus,
    String? buyerReference,
    String? deliveryDate,
    num? documentDiscountPercent,
    num? documentDiscountAmount,
  }) {
    if (documentNumber.trim().isEmpty) {
      throw const EInvoiceSourceException(
        code: 'missingDocumentNumber',
        messageDe: 'Rechnungsnummer fehlt im Finalisierungsschnappschuss',
        messageEn: 'Invoice number is missing from the finalization snapshot',
        fields: ['rechnungsnummer'],
      );
    }
    if (posRows.isEmpty) {
      throw const EInvoiceSourceException(
        code: 'missingLines',
        messageDe: 'Rechnung enthält keine Positionen',
        messageEn: 'Invoice contains no lines',
        fields: ['positionen'],
      );
    }
    final List<_PreDiscountLine> prepared = <_PreDiscountLine>[];
    _validateReverseChargeEvidence(
      posRows: posRows,
      companyRow: companyRow,
      customerRow: customerRow,
      deliveryDate: deliveryDate,
    );
    for (var index = 0; index < posRows.length; index++) {
      prepared.add(
        _prepareLine(
          posRows[index],
          index: index,
          eingabemodus: eingabemodus,
          sellerHasTaxRegistration:
              _text(companyRow['ust_idnr']) != null ||
              _text(companyRow['ust_id']) != null ||
              _text(companyRow['steuernummer']) != null ||
              _text(companyRow['tax_representative_vat_id']) != null,
        ),
      );
    }
    if ((documentDiscountPercent ?? 0) != 0 || (documentDiscountAmount ?? 0) != 0) {
      throw const EInvoiceSourceException(
        code: 'missingPriceAdjustmentBasis',
        messageDe: 'Dokumentrabatt kann ohne ausgewiesene Preisbasis nicht exportiert werden',
        messageEn: 'Document discount cannot be exported without an emitted price adjustment basis',
        fields: ['rabattProzent', 'rabattBetrag'],
      );
    }
    final bool hasCanonicalPositionTotals = preview.positionTotals.isNotEmpty;
    if (!hasCanonicalPositionTotals &&
        prepared.any((_PreDiscountLine line) => line.lineDiscountPercentHundredths != 0)) {
      throw _missingPriceAdjustmentBasis(prepared.first.position);
    }
    if (eingabemodus == 'brutto' && !hasCanonicalPositionTotals) {
      throw _missingNetPriceBasis(prepared.first.position);
    }
    final List<EInvoiceLineSnapshot> lines = hasCanonicalPositionTotals
        ? _linesFromCanonicalPositionTotals(prepared, preview.positionTotals)
        : _applyDocumentDiscount(
            prepared,
            eingabemodus: eingabemodus,
            documentDiscountPercent: documentDiscountPercent,
            documentDiscountAmount: documentDiscountAmount,
          );
    _validateCrossBorderEvidence(
      lines: lines,
      posRows: posRows,
      companyRow: companyRow,
      customerRow: customerRow,
      deliveryDate: deliveryDate,
    );
    var netSum = 0;
    var taxSum = 0;
    var grossSum = 0;
    for (final EInvoiceLineSnapshot line in lines) {
      netSum += line.netCents;
      taxSum += line.taxCents;
      grossSum += line.grossCents;
    }
    final EInvoiceDisclosureTotals? disclosureTotals = preview.disclosureTotals;
    final bool totalsMatch = hasCanonicalPositionTotals
        ? disclosureTotals != null &&
              _sumPositionTotals(preview.positionTotals) == (preview.netCents, preview.taxCents, preview.grossCents) &&
              (netSum, taxSum, grossSum) ==
                  (disclosureTotals.netCents, disclosureTotals.taxCents, disclosureTotals.grossCents)
        : netSum == preview.netCents && taxSum == preview.taxCents && grossSum == preview.grossCents;
    if (!totalsMatch) {
      throw const EInvoiceSourceException(
        code: 'snapshotTotalsMismatch',
        messageDe: 'Positionswerte stimmen nicht mit den kanonischen Summen überein',
        messageEn: 'Line values do not match the canonical totals',
        fields: ['netto_betrag', 'ust_betrag', 'brutto_betrag'],
      );
    }
    return FinalizationSnapshot(
      documentNumber: documentNumber,
      outputFormat: outputFormat,
      issueDate: issueDate,
      currency: 'EUR',
      seller: _sellerFromCompany(
        companyRow,
        companyLegalForm:
            lines.any(
              (EInvoiceLineSnapshot line) => line.classification.treatment == EInvoiceTaxTreatment.kleinunternehmer19,
            )
            ? ApprovedTaxClassification.kleinunternehmerReason
            : null,
      ),
      buyer: _buyerFromCustomer(customerRow, buyerReference: buyerReference),
      lines: List<EInvoiceLineSnapshot>.unmodifiable(lines),
      taxBreakdowns: _buildTaxBreakdowns(lines),
      invoiceNotes: List<String>.unmodifiable(<String>{
        for (final EInvoiceLineSnapshot line in lines)
          if (line.classification.invoiceNote != null) line.classification.invoiceNote!,
      }),
      netCents: disclosureTotals?.netCents ?? netSum,
      taxCents: disclosureTotals?.taxCents ?? taxSum,
      grossCents: disclosureTotals?.grossCents ?? grossSum,
      accountingNetCents: preview.netCents,
      accountingTaxCents: preview.taxCents,
      accountingGrossCents: preview.grossCents,
      buyerReference: buyerReference?.trim().isEmpty ?? true ? null : buyerReference!.trim(),
      deliveryDate: deliveryDate?.trim().isEmpty ?? true ? null : deliveryDate!.trim(),
    );
  }

  List<EInvoiceLineSnapshot> _linesFromCanonicalPositionTotals(
    List<_PreDiscountLine> prepared,
    List<EInvoiceCanonicalPositionAmounts> positionTotals,
  ) {
    final Map<int, EInvoiceCanonicalPositionAmounts> amountsByPosition = <int, EInvoiceCanonicalPositionAmounts>{};
    for (final EInvoiceCanonicalPositionAmounts amounts in positionTotals) {
      final bool hasPriceBasis = amounts.priceBasisNetCents != null;
      final bool hasLineDiscount = amounts.lineDiscountCents != null;
      if (amountsByPosition.containsKey(amounts.position) ||
          amounts.netCents < 0 ||
          amounts.taxCents < 0 ||
          amounts.grossCents < 0 ||
          amounts.netCents + amounts.taxCents != amounts.grossCents ||
          hasPriceBasis != hasLineDiscount ||
          (amounts.priceBasisNetCents ?? 0) < 0 ||
          (amounts.lineDiscountCents ?? 0) < 0 ||
          (amounts.lineDiscountCents ?? 0) > (amounts.priceBasisNetCents ?? 0)) {
        _throwCanonicalPositionTotalsMismatch();
      }
      amountsByPosition[amounts.position] = amounts;
    }
    final Set<int> linePositions = <int>{};
    final List<EInvoiceLineSnapshot> lines = <EInvoiceLineSnapshot>[];
    for (final _PreDiscountLine line in prepared) {
      if (!linePositions.add(line.position)) _throwCanonicalPositionTotalsMismatch();
      final EInvoiceCanonicalPositionAmounts? amounts = amountsByPosition.remove(line.position);
      if (amounts == null) _throwCanonicalPositionTotalsMismatch();
      final bool section25a = switch (line.classification.treatment) {
        EInvoiceTaxTreatment.marginScheme25aSecondHand ||
        EInvoiceTaxTreatment.marginScheme25aArt ||
        EInvoiceTaxTreatment.marginScheme25aCollectorsAntiquities => true,
        _ => false,
      };
      final int netCents = section25a ? amounts.grossCents : amounts.netCents;
      if (netCents != line.netBeforeDocumentDiscountCents) {
        throw EInvoiceSourceException(
          code: 'unreconciledPriceBasis',
          messageDe: 'Position ${line.position + 1}: BT-131 stimmt nicht mit Einzelpreis × Menge überein',
          messageEn: 'Line ${line.position + 1}: BT-131 does not reconcile to unit price × quantity',
          fields: ['position[${line.position}].einzelpreis', 'position[${line.position}].menge'],
        );
      }
      EInvoiceLineAllowanceSnapshot? lineAllowance;
      if (line.lineDiscountPercentHundredths != 0) {
        final int? basisCents = amounts.priceBasisNetCents;
        final int? canonicalAllowanceCents = amounts.lineDiscountCents;
        if (basisCents == null || canonicalAllowanceCents == null) {
          throw _missingPriceAdjustmentBasis(line.position);
        }
        if (basisCents != line.priceBasisNetCents || basisCents - canonicalAllowanceCents != netCents) {
          throw EInvoiceSourceException(
            code: 'unreconciledPriceBasis',
            messageDe:
                'Position ${line.position + 1}: Rabattbasis stimmt nicht mit dem gespeicherten Einzelpreis überein',
            messageEn: 'Line ${line.position + 1}: discount basis does not reconcile to the stored unit price',
            fields: ['position[${line.position}].einzelpreis', 'position[${line.position}].menge'],
          );
        }
        final int expectedAllowance = _roundHalfUp(
          BigInt.from(basisCents) * BigInt.from(line.lineDiscountPercentHundredths),
          BigInt.from(10000),
        );
        if (canonicalAllowanceCents <= 0 || canonicalAllowanceCents != expectedAllowance) {
          throw EInvoiceSourceException(
            code: 'unreconciledPriceAdjustment',
            messageDe: 'Position ${line.position + 1}: Rabattbetrag stimmt nicht mit Prozent und Preisbasis überein',
            messageEn:
                'Line ${line.position + 1}: discount amount does not reconcile to its percentage and price basis',
            fields: ['position[${line.position}].rabattProzent'],
          );
        }
        lineAllowance = EInvoiceLineAllowanceSnapshot(
          amountCents: canonicalAllowanceCents,
          baseAmountCents: basisCents,
          percentHundredths: line.lineDiscountPercentHundredths,
        );
      } else if ((amounts.lineDiscountCents ?? 0) != 0 ||
          (amounts.priceBasisNetCents != null && amounts.priceBasisNetCents != line.priceBasisNetCents)) {
        _throwCanonicalPositionTotalsMismatch();
      }
      final int unitPriceBasisCents = lineAllowance?.baseAmountCents ?? netCents;
      final String netUnitPriceText = line.unitPriceIsGross
          ? _canonicalNetUnitPriceText(
              position: line.position,
              netCents: unitPriceBasisCents,
              quantityScaled: line.quantityScaled,
            )
          : line.unitPriceText;
      final int taxCents = section25a ? 0 : amounts.taxCents;
      lines.add(
        EInvoiceLineSnapshot(
          position: line.position,
          description: line.description,
          quantityText: line.quantityText,
          unitPriceText: line.unitPriceText,
          netUnitPriceText: netUnitPriceText,
          unitPriceIsGross: line.unitPriceIsGross,
          netCents: netCents,
          taxCents: taxCents,
          grossCents: netCents + taxCents,
          taxRateHundredths: line.taxRateHundredths,
          classification: line.classification,
          lineAllowance: lineAllowance,
        ),
      );
    }
    if (amountsByPosition.isNotEmpty) _throwCanonicalPositionTotalsMismatch();
    lines.sort((a, b) => a.position.compareTo(b.position));
    return List<EInvoiceLineSnapshot>.unmodifiable(lines);
  }

  (int, int, int) _sumPositionTotals(List<EInvoiceCanonicalPositionAmounts> positionTotals) {
    var net = 0;
    var tax = 0;
    var gross = 0;
    for (final EInvoiceCanonicalPositionAmounts amounts in positionTotals) {
      net += amounts.netCents;
      tax += amounts.taxCents;
      gross += amounts.grossCents;
    }
    return (net, tax, gross);
  }

  Never _throwCanonicalPositionTotalsMismatch() {
    throw const EInvoiceSourceException(
      code: 'canonicalPositionTotalsMismatch',
      messageDe: 'Kanonische Positionssummen fehlen, sind doppelt oder widersprechen sich',
      messageEn: 'Canonical position totals are missing, duplicated, or inconsistent',
      fields: ['positionen', 'netto_betrag', 'ust_betrag', 'brutto_betrag'],
    );
  }

  _PreDiscountLine _prepareLine(
    Map<String, Object?> row, {
    required int index,
    required String eingabemodus,
    required bool sellerHasTaxRegistration,
  }) {
    final String description = row['bezeichnung']?.toString().trim() ?? '';
    if (description.isEmpty) {
      throw EInvoiceSourceException(
        code: 'missingLineDescription',
        messageDe: 'Position ${index + 1}: Bezeichnung fehlt',
        messageEn: 'Line ${index + 1}: description is missing',
        fields: ['position[$index].bezeichnung'],
      );
    }
    final num menge = _asNum(row['menge'], field: 'menge', index: index);
    final num einzelpreis = _asNum(row['einzelpreis'], field: 'einzelpreis', index: index);
    final num ustSatz = _asNum(row['ust_satz'], field: 'ust_satz', index: index);
    final int rateHundredths = (ustSatz * 100).round();
    if ((rateHundredths / 100 - ustSatz).abs() > 0.000001 || rateHundredths < 0 || rateHundredths > 10000) {
      throw EInvoiceSourceException(
        code: 'invalidTaxRate',
        messageDe: 'Position ${index + 1}: ungültiger Steuersatz',
        messageEn: 'Line ${index + 1}: invalid tax rate',
        fields: ['position[$index].ustSatz'],
      );
    }
    final EInvoiceTaxClassificationResult taxClassification = ApprovedTaxClassification.resolve(
      treatmentCode: row['tax_treatment']?.toString(),
      legalBasisCode: row['tax_legal_basis']?.toString(),
      categoryCode: row['e_invoice_tax_category_code']?.toString(),
      exemptionReasonCode: row['e_invoice_exemption_reason_code']?.toString(),
      exemptionReasonText: row['e_invoice_exemption_reason_text']?.toString(),
      taxRateHundredths: rateHundredths,
      sellerHasTaxRegistration: sellerHasTaxRegistration,
    );
    final EInvoiceLineClassification? classification = taxClassification.classification;
    if (classification == null) {
      throw EInvoiceSourceException(
        code: 'unresolvedTaxClassification',
        messageDe: 'Position ${index + 1}: Steuerklassifizierung fehlt oder ist nicht freigegeben',
        messageEn: 'Line ${index + 1}: tax classification is missing or unsupported',
        fields: <String>[for (final String field in taxClassification.fieldDiagnostics) 'position[$index].$field'],
      );
    }
    // Canonical per-line split with the accepted money scales and half-up
    // cent rounding (same rules as the invoice calculator); the builder only
    // distributes exact cent results, it never re-rounds stored money.
    final num? rabatt = row['rabatt_prozent'] == null
        ? null
        : _asNum(row['rabatt_prozent'], field: 'rabatt_prozent', index: index);
    final int quantityScaled = money.scaledFromNum(menge, scale: 3, field: 'menge', allowNegative: false);
    final int unitPriceScaled = money.scaledFromNum(einzelpreis, scale: 4, field: 'einzelpreis');
    final int discountScaled = rabatt == null || rabatt == 0
        ? 0
        : money.scaledFromNum(rabatt, scale: 2, field: 'rabattProzent');
    if (discountScaled < 0 || discountScaled > 10000) {
      throw EInvoiceSourceException(
        code: 'invalidLineDiscount',
        messageDe: 'Position ${index + 1}: ungültiger Positionsrabatt',
        messageEn: 'Line ${index + 1}: invalid line discount',
        fields: ['position[$index].rabattProzent'],
      );
    }
    final BigInt product = BigInt.from(unitPriceScaled) * BigInt.from(quantityScaled);
    final int priceBasisEntered = _roundHalfUp(product, BigInt.from(100000));
    final int priceBasisNet = eingabemodus == 'brutto'
        ? _roundHalfUp(BigInt.from(priceBasisEntered) * BigInt.from(10000), BigInt.from(10000 + rateHundredths))
        : priceBasisEntered;
    final int enteredCents = _roundHalfUp(product * BigInt.from(10000 - discountScaled), BigInt.from(1000000000));
    // Net after the line discount, before document discounts; document discounts
    // are distributed below with the canonical proportional allocator.
    final int netBeforeDocumentDiscountCents;
    final int preDiscountEntered;
    if (eingabemodus == 'brutto') {
      netBeforeDocumentDiscountCents = _roundHalfUp(
        BigInt.from(enteredCents) * BigInt.from(10000),
        BigInt.from(10000 + rateHundredths),
      );
      preDiscountEntered = enteredCents;
    } else {
      netBeforeDocumentDiscountCents = enteredCents;
      preDiscountEntered = enteredCents;
    }
    return _PreDiscountLine(
      position: _asInt(row['position']) ?? index,
      description: description,
      quantityText: _quantityText(menge),
      quantityScaled: quantityScaled,
      unitPriceText: _scaledText(einzelpreis, 4),
      unitPriceIsGross: eingabemodus == 'brutto',
      enteredCents: preDiscountEntered,
      netBeforeDocumentDiscountCents: netBeforeDocumentDiscountCents,
      priceBasisNetCents: priceBasisNet,
      lineDiscountPercentHundredths: discountScaled,
      taxRateHundredths: rateHundredths,
      classification: classification,
    );
  }

  void _validateCrossBorderEvidence({
    required List<EInvoiceLineSnapshot> lines,
    required List<Map<String, Object?>> posRows,
    required Map<String, Object?> companyRow,
    required Map<String, Object?> customerRow,
    required String? deliveryDate,
  }) {
    final bool intraCommunity = lines.any(
      (EInvoiceLineSnapshot line) => line.classification.treatment == EInvoiceTaxTreatment.intraCommunitySupply6a,
    );
    final bool export = lines.any(
      (EInvoiceLineSnapshot line) => line.classification.treatment == EInvoiceTaxTreatment.exportSupply6,
    );
    if (!intraCommunity && !export) return;

    final List<String> fields = <String>[];
    final Map<int, List<Map<String, Object?>>> sourceRowsByPosition = <int, List<Map<String, Object?>>>{};
    for (var index = 0; index < posRows.length; index++) {
      final Map<String, Object?> row = posRows[index];
      final int position = _asInt(row['position']) ?? index;
      sourceRowsByPosition.putIfAbsent(position, () => <Map<String, Object?>>[]).add(row);
    }

    for (final EInvoiceLineSnapshot line in lines) {
      final EInvoiceTaxTreatment treatment = line.classification.treatment;
      if (intraCommunity && treatment != EInvoiceTaxTreatment.intraCommunitySupply6a) {
        fields.add('position[${line.position}].tax_treatment');
      }
      if (export && treatment != EInvoiceTaxTreatment.exportSupply6) {
        fields.add('position[${line.position}].tax_treatment');
      }
    }

    final String? sellerCountry = _text(companyRow['land'])?.toUpperCase();
    final String? buyerCountry = _text(customerRow['land'])?.toUpperCase();
    if (sellerCountry != 'DE') fields.add('unternehmen.land');
    if (buyerCountry == null || !RegExp(r'^[A-Z]{2}$').hasMatch(buyerCountry)) {
      fields.add('kunden.land');
    }

    if (intraCommunity) {
      if (_text(companyRow['ust_idnr']) == null && _text(companyRow['ust_id']) == null) {
        fields.add('unternehmen.ust_idnr');
      }
      if (_text(customerRow['ust_idnr']) == null) fields.add('kunden.ust_idnr');
      if (deliveryDate?.trim().isNotEmpty != true) fields.add('leistungsdatum');

      for (final EInvoiceLineSnapshot line in lines) {
        if (line.classification.treatment != EInvoiceTaxTreatment.intraCommunitySupply6a) continue;
        final String prefix = 'position[${line.position}].';
        final List<Map<String, Object?>>? sourceRows = sourceRowsByPosition[line.position];
        final String? destinationCountry = sourceRows?.length == 1
            ? _text(sourceRows!.single['e_invoice_intra_community_destination_country_iso'])?.toUpperCase()
            : null;
        if (destinationCountry == null ||
            !RegExp(r'^[A-Z]{2}$').hasMatch(destinationCountry) ||
            destinationCountry == 'DE' ||
            !_euMemberCountryCodes.contains(destinationCountry)) {
          fields.add('${prefix}e_invoice_intra_community_destination_country_iso');
        }

        // A source-reference string is not eligibility evidence. This boundary has no resolver yet,
        // so all §6a output stays fail-closed until v28 binds a real record to this invoice line.
        fields.add('${prefix}e_invoice_intra_community_supply_evidence_source_ref');
      }
    }

    if (export) {
      if (_text(companyRow['ust_idnr']) == null &&
          _text(companyRow['ust_id']) == null &&
          _text(companyRow['steuernummer']) == null &&
          _text(companyRow['tax_representative_vat_id']) == null) {
        fields.add('unternehmen.ust_idnr');
      }
      for (final EInvoiceLineSnapshot line in lines) {
        if (line.classification.treatment != EInvoiceTaxTreatment.exportSupply6) continue;
        final String prefix = 'position[${line.position}].';
        final List<Map<String, Object?>>? sourceRows = sourceRowsByPosition[line.position];
        final String? destinationCountry = sourceRows?.length == 1
            ? _text(sourceRows!.single['e_invoice_export_destination_country_iso'])?.toUpperCase()
            : null;
        if (destinationCountry == null ||
            !RegExp(r'^[A-Z]{2}$').hasMatch(destinationCountry) ||
            destinationCountry == 'ZZ' ||
            _euMemberCountryCodes.contains(destinationCountry)) {
          fields.add('${prefix}e_invoice_export_destination_country_iso');
        }

        // No v28 movement actor or evidence resolver exists, so even a nonempty reference cannot enable G.
        fields.add('${prefix}e_invoice_export_evidence_source_ref');
      }
    }

    if (fields.isNotEmpty) {
      throw EInvoiceSourceException(
        code: 'incompleteCrossBorderTaxEvidence',
        messageDe: 'Steuerangaben für die grenzüberschreitende Lieferung sind unvollständig oder widersprüchlich',
        messageEn: 'Cross-border tax evidence is incomplete or contradictory',
        fields: List<String>.unmodifiable(fields.toSet()),
      );
    }
  }

  void _validateReverseChargeEvidence({
    required List<Map<String, Object?>> posRows,
    required Map<String, Object?> companyRow,
    required Map<String, Object?> customerRow,
    required String? deliveryDate,
  }) {
    const Set<String> reverseChargeTreatments = <String>{
      'reverse_charge_eu_service_13b_1',
      'reverse_charge_domestic_construction_13b_2_4_5',
    };
    final bool hasReverseCharge = posRows.any(
      (Map<String, Object?> row) => reverseChargeTreatments.contains(_text(row['tax_treatment'])),
    );
    if (!hasReverseCharge) return;

    final List<String> fields = <String>[];
    void requireOneOf(int index, Map<String, Object?> row, String field, Set<String> accepted) {
      final String? value = _text(row[field]);
      if (value == null || !accepted.contains(value)) fields.add('position[$index].$field');
    }

    void requireText(int index, Map<String, Object?> row, String field) {
      if (_text(row[field]) == null) fields.add('position[$index].$field');
    }

    void requireCountry(int index, Map<String, Object?> row, String field, String expected) {
      final String? value = _text(row[field])?.toUpperCase();
      if (value != expected) fields.add('position[$index].$field');
    }

    void requireCountryCode(int index, Map<String, Object?> row, String field) {
      final String? value = _text(row[field])?.toUpperCase();
      if (value == null || !RegExp(r'^[A-Z]{2}$').hasMatch(value)) fields.add('position[$index].$field');
    }

    final String? sellerCountry = _text(companyRow['land'])?.toUpperCase();
    final String? buyerCountry = _text(customerRow['land'])?.toUpperCase();
    final String? buyerVatId = _text(customerRow['ust_idnr']);
    final String? sellerVatId = _text(companyRow['ust_idnr']) ?? _text(companyRow['ust_id']);
    for (var index = 0; index < posRows.length; index++) {
      final Map<String, Object?> row = posRows[index];
      final String? treatment = _text(row['tax_treatment']);
      if (!reverseChargeTreatments.contains(treatment)) {
        fields.add('position[$index].tax_treatment');
        continue;
      }

      if (treatment == 'reverse_charge_eu_service_13b_1') {
        final String? supplierCountry = _text(row['e_invoice_reverse_charge_supplier_establishment_country_iso'])
            ?.toUpperCase();
        requireOneOf(index, row, 'e_invoice_reverse_charge_supplier_establishment_basis', <String>{
          'seat_or_management',
          'fixed_establishment',
        });
        requireOneOf(index, row, 'e_invoice_reverse_charge_supplier_german_fixed_establishment_status', <String>{
          'none',
          'exists_not_involved',
        });
        requireOneOf(index, row, 'e_invoice_reverse_charge_recipient_status', <String>{'entrepreneur_for_business'});
        requireCountry(index, row, 'e_invoice_reverse_charge_recipient_establishment_country_iso', 'DE');
        requireOneOf(index, row, 'e_invoice_reverse_charge_service_kind', <String>{
          'general_b2b_service_3a_2_no_exception',
        });
        requireOneOf(index, row, 'e_invoice_reverse_charge_place_of_supply_basis', <String>{
          'recipient_business_establishment_3a_2',
          'recipient_fixed_establishment_3a_2',
        });
        requireCountry(index, row, 'e_invoice_reverse_charge_place_of_supply_country_iso', 'DE');
        requireOneOf(index, row, 'e_invoice_reverse_charge_taxability', <String>{'taxable_in_germany_under_3a_2'});
        requireText(index, row, 'e_invoice_reverse_charge_evidence_source_ref');
        // No persisted assessment resolver is supplied in this serializer
        // slice. A non-empty reference is not proof that a source record
        // exists or matches the captured eligibility facts.
        fields.add('position[$index].e_invoice_reverse_charge_evidence_source_ref');
        if (supplierCountry == null || !_euMemberCountryCodes.contains(supplierCountry) || supplierCountry == 'DE') {
          fields.add('position[$index].e_invoice_reverse_charge_supplier_establishment_country_iso');
        }
        if (sellerCountry == null || sellerCountry != supplierCountry) fields.add('unternehmen.land');
        if (buyerCountry != 'DE') fields.add('kunden.land');
        if (sellerVatId == null) fields.add('unternehmen.ust_idnr');
        if (buyerVatId == null) fields.add('kunden.ust_idnr');
      } else {
        requireCountryCode(index, row, 'e_invoice_reverse_charge_supplier_establishment_country_iso');
        requireOneOf(index, row, 'e_invoice_reverse_charge_supplier_establishment_basis', <String>{
          'seat_or_management',
          'fixed_establishment',
        });
        requireOneOf(index, row, 'e_invoice_reverse_charge_supplier_german_fixed_establishment_status', <String>{
          'none',
          'exists_not_involved',
          'exists_participating',
          'unknown',
        });
        requireOneOf(index, row, 'e_invoice_reverse_charge_recipient_status', <String>{'entrepreneur'});
        requireCountry(index, row, 'e_invoice_reverse_charge_recipient_establishment_country_iso', 'DE');
        requireOneOf(index, row, 'e_invoice_reverse_charge_service_kind', <String>{'construction_service_13b_2_4'});
        requireOneOf(index, row, 'e_invoice_reverse_charge_place_of_supply_basis', <String>{
          'german_immovable_property_13b_2_4',
        });
        requireCountry(index, row, 'e_invoice_reverse_charge_place_of_supply_country_iso', 'DE');
        requireOneOf(index, row, 'e_invoice_reverse_charge_taxability', <String>{'taxable_in_germany_under_13b_2_4'});
        requireText(index, row, 'e_invoice_reverse_charge_evidence_source_ref');
        // Assessment/certificate resolution belongs to the later v28 input
        // persistence slice; block output until those real records are wired.
        fields.add('position[$index].e_invoice_reverse_charge_evidence_source_ref');
        requireOneOf(index, row, 'e_invoice_reverse_charge_recipient_13b5_basis', <String>{'valid_ust1tg_certificate'});
        requireText(index, row, 'e_invoice_reverse_charge_ust1tg_certificate_ref');
        fields.add('position[$index].e_invoice_reverse_charge_ust1tg_certificate_ref');
        requireOneOf(index, row, 'e_invoice_reverse_charge_ust1tg_scope', <String>{'construction_13b_2_4'});
        requireText(index, row, 'e_invoice_reverse_charge_ust1tg_recipient_vat_id');
        requireText(index, row, 'e_invoice_reverse_charge_ust1tg_issued_on');
        requireText(index, row, 'e_invoice_reverse_charge_ust1tg_valid_through');
        if (buyerCountry != 'DE') fields.add('kunden.land');
        if (sellerVatId == null) fields.add('unternehmen.ust_idnr');
        if (buyerVatId == null) fields.add('kunden.ust_idnr');
        if (_text(row['e_invoice_reverse_charge_ust1tg_recipient_vat_id']) != buyerVatId || buyerVatId == null) {
          fields.add('position[$index].e_invoice_reverse_charge_ust1tg_recipient_vat_id');
        }
        final DateTime? serviceDay = _isoDay(deliveryDate);
        final DateTime? issuedOn = _isoDay(row['e_invoice_reverse_charge_ust1tg_issued_on']);
        final DateTime? validThrough = _isoDay(row['e_invoice_reverse_charge_ust1tg_valid_through']);
        if (serviceDay == null) fields.add('leistungsdatum');
        if (issuedOn == null ||
            validThrough == null ||
            serviceDay == null ||
            issuedOn.isAfter(serviceDay) ||
            validThrough.isBefore(serviceDay)) {
          fields.add('position[$index].e_invoice_reverse_charge_ust1tg_issued_on');
          fields.add('position[$index].e_invoice_reverse_charge_ust1tg_valid_through');
        }
      }
    }

    if (fields.isNotEmpty) {
      throw EInvoiceSourceException(
        code: 'unresolvedTaxClassification',
        messageDe: 'Steuerangaben für die Steuerschuldnerschaft sind unvollständig oder widersprüchlich',
        messageEn: 'Reverse-charge evidence is incomplete or contradictory',
        fields: List<String>.unmodifiable(fields.toSet()),
      );
    }
  }

  DateTime? _isoDay(Object? value) {
    final String? text = _text(value);
    if (text == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return null;
    final DateTime? parsed = DateTime.tryParse(text);
    return parsed != null && parsed.toIso8601String().substring(0, 10) == text ? parsed : null;
  }

  /// Distributes an optional document discount across lines with the
  /// canonical proportional allocator and derives final per-line tax.
  ///
  /// The distribution order mirrors the accepted calculator (rate groups in
  /// first-seen order, lines by stored position); the resulting sums MUST
  /// equal the canonical totals or the build fails, so any drift can never
  /// be serialized silently.
  List<EInvoiceLineSnapshot> _applyDocumentDiscount(
    List<_PreDiscountLine> prepared, {
    required String eingabemodus,
    num? documentDiscountPercent,
    num? documentDiscountAmount,
  }) {
    final int discountPercent;
    final int discountFixed;
    try {
      discountPercent = documentDiscountPercent == null || documentDiscountPercent == 0
          ? 0
          : money.scaledFromNum(documentDiscountPercent, scale: 2, field: 'rabattProzent');
      discountFixed = documentDiscountAmount == null || documentDiscountAmount == 0
          ? 0
          : money.scaledFromNum(documentDiscountAmount, scale: 2, field: 'rabattBetrag');
    } on money.MoneyParseException {
      throw const EInvoiceSourceException(
        code: 'invalidStoredValue',
        messageDe: 'Gespeicherter Dokumentrabatt ist ungültig',
        messageEn: 'Stored document discount is invalid',
        fields: ['rabattProzent', 'rabattBetrag'],
      );
    }
    if (discountPercent != 0 && discountFixed != 0) {
      throw const EInvoiceSourceException(
        code: 'conflictingDocumentDiscounts',
        messageDe: 'Nur ein Rabatt pro Dokument erlaubt (Prozent ODER Betrag)',
        messageEn: 'Only one discount per document is allowed (percent OR amount)',
        fields: ['rabattProzent', 'rabattBetrag'],
      );
    }
    var netSubtotal = 0;
    for (final _PreDiscountLine line in prepared) {
      netSubtotal += line.netBeforeDocumentDiscountCents;
    }
    final int discount = discountPercent != 0
        ? _roundHalfUp(BigInt.from(netSubtotal) * BigInt.from(discountPercent), BigInt.from(10000))
        : discountFixed;
    if (discount < 0 || discount > netSubtotal) {
      throw const EInvoiceSourceException(
        code: 'excessiveDocumentDiscount',
        messageDe: 'Betragsrabatt darf die Nettosumme nicht überschreiten',
        messageEn: 'Amount discount must not exceed the net subtotal',
        fields: ['rabattBetrag'],
      );
    }
    final Map<int, int> netByRate = <int, int>{};
    for (final _PreDiscountLine line in prepared) {
      netByRate.update(
        line.taxRateHundredths,
        (old) => old + line.netBeforeDocumentDiscountCents,
        ifAbsent: () => line.netBeforeDocumentDiscountCents,
      );
    }
    Map<int, int> discountByRate = <int, int>{};
    if (discount != 0) {
      try {
        discountByRate = money.allocateProportionally<int>(
          amount: discount,
          weights: netByRate,
          compareKeys: (a, b) => a.compareTo(b),
        );
      } on money.MoneyParseException catch (error) {
        throw EInvoiceSourceException(
          code: 'excessiveDocumentDiscount',
          messageDe: error.message,
          messageEn: error.message,
          fields: const ['rabattBetrag'],
        );
      }
    }
    final List<EInvoiceLineSnapshot> lines = <EInvoiceLineSnapshot>[];
    for (final MapEntry<int, int> entry in netByRate.entries) {
      final int rate = entry.key;
      final List<int> lineIndexes = <int>[
        for (var index = 0; index < prepared.length; index++)
          if (prepared[index].taxRateHundredths == rate) index,
      ];
      Map<int, int> discountByPosition = <int, int>{};
      final int rateDiscount = discountByRate[rate] ?? 0;
      if (rateDiscount != 0) {
        try {
          discountByPosition = money.allocateProportionally<int>(
            amount: rateDiscount,
            weights: <int, int>{
              for (final int index in lineIndexes) index: prepared[index].netBeforeDocumentDiscountCents,
            },
            compareKeys: (int a, int b) {
              final int order = prepared[a].position.compareTo(prepared[b].position);
              return order == 0 ? a.compareTo(b) : order;
            },
          );
        } on money.MoneyParseException catch (error) {
          throw EInvoiceSourceException(
            code: 'excessiveDocumentDiscount',
            messageDe: error.message,
            messageEn: error.message,
            fields: const ['rabattBetrag'],
          );
        }
      }
      for (final int index in lineIndexes) {
        final _PreDiscountLine pre = prepared[index];
        final int netCents = pre.netBeforeDocumentDiscountCents - (discountByPosition[index] ?? 0);
        final int taxCents = eingabemodus == 'brutto' && discount == 0
            ? pre.enteredCents - pre.netBeforeDocumentDiscountCents
            : _roundHalfUp(BigInt.from(netCents) * BigInt.from(rate), BigInt.from(10000));
        lines.add(
          EInvoiceLineSnapshot(
            position: pre.position,
            description: pre.description,
            quantityText: pre.quantityText,
            unitPriceText: pre.unitPriceText,
            netUnitPriceText: pre.unitPriceText,
            unitPriceIsGross: pre.unitPriceIsGross,
            netCents: netCents,
            taxCents: taxCents,
            grossCents: netCents + taxCents,
            taxRateHundredths: rate,
            classification: pre.classification,
          ),
        );
      }
    }
    lines.sort((a, b) {
      final int order = a.position.compareTo(b.position);
      return order;
    });
    return List<EInvoiceLineSnapshot>.unmodifiable(lines);
  }

  List<EInvoiceTaxBreakdownSnapshot> _buildTaxBreakdowns(List<EInvoiceLineSnapshot> lines) {
    final Map<String, EInvoiceTaxBreakdownSnapshot> groups = <String, EInvoiceTaxBreakdownSnapshot>{};
    for (final EInvoiceLineSnapshot line in lines) {
      final EInvoiceLineClassification classification = line.classification;
      final String key = <String>[
        line.taxRateHundredths.toString(),
        classification.treatment.code,
        classification.legalBasis.code,
        classification.category.code,
        classification.exemptionReasonCode ?? '',
        classification.exemptionReason ?? '',
      ].join('|');
      final EInvoiceTaxBreakdownSnapshot? existing = groups[key];
      groups[key] = EInvoiceTaxBreakdownSnapshot(
        taxRateHundredths: line.taxRateHundredths,
        classification: classification,
        netCents: (existing?.netCents ?? 0) + line.netCents,
        taxCents: (existing?.taxCents ?? 0) + line.taxCents,
      );
    }
    final List<EInvoiceTaxBreakdownSnapshot> sorted = groups.values.toList(growable: false)
      ..sort((EInvoiceTaxBreakdownSnapshot a, EInvoiceTaxBreakdownSnapshot b) {
        final int categoryOrder = a.classification.category.code.compareTo(b.classification.category.code);
        return categoryOrder != 0 ? categoryOrder : a.taxRateHundredths.compareTo(b.taxRateHundredths);
      });
    return List<EInvoiceTaxBreakdownSnapshot>.unmodifiable(sorted);
  }

  EInvoicePartySnapshot _sellerFromCompany(Map<String, Object?> row, {String? companyLegalForm}) {
    final String? street = row['strasse']?.toString().trim().isEmpty ?? true
        ? null
        : [
            row['strasse']?.toString().trim(),
            row['hausnummer']?.toString().trim(),
          ].where((part) => part != null && part.isNotEmpty).join(' ');
    final String? vatId = _text(row['ust_idnr']) ?? _text(row['ust_id']);
    return EInvoicePartySnapshot(
      name: row['name']?.toString().trim() ?? '',
      street: street,
      postalCode: _text(row['plz']),
      city: _text(row['ort']),
      country: _text(row['land']),
      taxNumber: _text(row['steuernummer']),
      vatId: vatId,
      taxRepresentativeVatId: _text(row['tax_representative_vat_id']),
      email: _text(row['email']),
      iban: _text(row['iban']),
      endpointId: vatId,
      endpointScheme: vatId == null ? null : '9930',
      companyLegalForm: companyLegalForm,
    );
  }

  EInvoicePartySnapshot _buyerFromCustomer(Map<String, Object?> row, {String? buyerReference}) {
    final String? street = row['strasse']?.toString().trim().isEmpty ?? true
        ? null
        : [
            row['strasse']?.toString().trim(),
            row['hausnummer']?.toString().trim(),
          ].where((part) => part != null && part.isNotEmpty).join(' ');
    final String? email = _text(row['email']);
    final String? reference = buyerReference?.trim().isEmpty ?? true ? null : buyerReference!.trim();
    return EInvoicePartySnapshot(
      name: row['name']?.toString().trim() ?? '',
      company: _text(row['firma']),
      street: street,
      postalCode: _text(row['plz']),
      city: _text(row['ort']),
      country: _text(row['land']),
      vatId: _text(row['ust_idnr']),
      email: email,
      endpointId: email ?? reference,
      endpointScheme: email != null ? 'EM' : (reference == null ? null : '0204'),
    );
  }

  num _asNum(Object? value, {required String field, required int index}) {
    if (value is num && value.isFinite) return value;
    final num? parsed = num.tryParse(value?.toString() ?? '');
    if (parsed == null || !parsed.isFinite) {
      throw EInvoiceSourceException(
        code: 'invalidStoredValue',
        messageDe: 'Position ${index + 1}: ungültiger gespeicherter Wert ($field)',
        messageEn: 'Line ${index + 1}: invalid stored value ($field)',
        fields: ['position[$index].$field'],
      );
    }
    return parsed;
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String? _text(Object? value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String _quantityText(num menge) {
    // Render the stored scale-3 quantity without binary-float artifacts.
    final int thousandths = money.scaledFromNum(menge, scale: 3, field: 'menge', allowNegative: false);
    final String digits = thousandths.toString().padLeft(4, '0');
    final String integer = digits.substring(0, digits.length - 3);
    String fraction = digits.substring(digits.length - 3);
    while (fraction.endsWith('0') && fraction.length > 1) {
      fraction = fraction.substring(0, fraction.length - 1);
    }
    return fraction == '0' ? integer : '$integer.$fraction';
  }

  String _canonicalNetUnitPriceText({required int position, required int netCents, required int quantityScaled}) {
    if (quantityScaled <= 0) throw _missingNetPriceBasis(position);
    final int priceScaled = _roundHalfUp(BigInt.from(netCents) * BigInt.from(100000), BigInt.from(quantityScaled));
    final int representedNetCents = _roundHalfUp(
      BigInt.from(priceScaled) * BigInt.from(quantityScaled),
      BigInt.from(100000),
    );
    if (representedNetCents != netCents) throw _missingNetPriceBasis(position);
    final String digits = priceScaled.abs().toString().padLeft(5, '0');
    final String integer = digits.substring(0, digits.length - 4);
    final String fraction = digits.substring(digits.length - 4);
    return '${priceScaled < 0 ? '-' : ''}$integer.$fraction';
  }

  EInvoiceSourceException _missingNetPriceBasis(int position) => EInvoiceSourceException(
    code: 'missingNetPriceBasis',
    messageDe: 'Position ${position + 1}: kanonischer Nettopreis kann nicht ausgewiesen werden',
    messageEn: 'Line ${position + 1}: canonical VAT-exclusive unit price is unavailable',
    fields: ['position[$position].einzelpreis', 'position[$position].menge'],
  );

  EInvoiceSourceException _missingPriceAdjustmentBasis(int position) => EInvoiceSourceException(
    code: 'missingPriceAdjustmentBasis',
    messageDe: 'Position ${position + 1}: Rabatt kann ohne ausgewiesene Preisbasis nicht exportiert werden',
    messageEn: 'Line ${position + 1}: discount cannot be exported without an emitted price adjustment basis',
    fields: ['position[$position].rabattProzent'],
  );

  /// Renders a stored decimal at [scale] places without float formatting.
  String _scaledText(num value, int scale) {
    final int scaled = money.scaledFromNum(value, scale: scale, field: 'betrag');
    final bool negative = scaled < 0;
    final String digits = scaled.abs().toString().padLeft(scale + 1, '0');
    final String integer = digits.substring(0, digits.length - scale);
    final String fraction = digits.substring(digits.length - scale);
    return '${negative ? '-' : ''}$integer.$fraction';
  }

  int _roundHalfUp(BigInt numerator, BigInt denominator) {
    return ((numerator + denominator ~/ BigInt.two) ~/ denominator).toInt();
  }
}

/// Validated per-line input before document-discount distribution.
class _PreDiscountLine {
  const _PreDiscountLine({
    required this.position,
    required this.description,
    required this.quantityText,
    required this.quantityScaled,
    required this.unitPriceText,
    required this.unitPriceIsGross,
    required this.enteredCents,
    required this.netBeforeDocumentDiscountCents,
    required this.priceBasisNetCents,
    required this.lineDiscountPercentHundredths,
    required this.taxRateHundredths,
    required this.classification,
  });

  final int position;
  final String description;
  final String quantityText;
  final int quantityScaled;
  final String unitPriceText;
  final bool unitPriceIsGross;
  final int enteredCents;
  final int netBeforeDocumentDiscountCents;
  final int priceBasisNetCents;
  final int lineDiscountPercentHundredths;
  final int taxRateHundredths;
  final EInvoiceLineClassification classification;
}
