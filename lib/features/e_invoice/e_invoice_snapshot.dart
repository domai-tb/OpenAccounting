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
    this.email,
    this.endpointId,
    this.endpointScheme,
  });

  final String name;
  final String? company;
  final String? street;
  final String? postalCode;
  final String? city;
  final String? country;
  final String? taxNumber;
  final String? vatId;
  final String? email;

  /// Resolved electronic address for XRechnung (BT-34/BT-49), or null when
  /// no approved source exists. Never invented; validation fails closed.
  final String? endpointId;
  final String? endpointScheme;
}

/// Immutable line with canonical cent amounts and explicit classification.
class EInvoiceLineSnapshot {
  const EInvoiceLineSnapshot({
    required this.position,
    required this.description,
    required this.quantityText,
    required this.unitPriceText,
    required this.unitPriceIsGross,
    required this.netCents,
    required this.taxCents,
    required this.grossCents,
    required this.taxRateHundredths,
    required this.classification,
  });

  final int position;
  final String description;

  /// Quantity rendered from the stored scale-3 value, never recalculated.
  final String quantityText;

  /// Stored unit price rendered at scale 4. For netto input it is the net
  /// unit price, for brutto input the gross unit price ([unitPriceIsGross]).
  final String unitPriceText;
  final bool unitPriceIsGross;
  final int netCents;
  final int taxCents;
  final int grossCents;

  /// Exact VAT percentage in hundredths (1900 = 19.00 %).
  final int taxRateHundredths;
  final EInvoiceLineClassification classification;
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
    required this.netCents,
    required this.taxCents,
    required this.grossCents,
    this.buyerReference,
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
  final int netCents;
  final int taxCents;
  final int grossCents;

  /// Explicit buyer reference (e.g. Leitweg-ID) supplied for XRechnung
  /// export. Null means absent; serializers must not invent one.
  final String? buyerReference;
}

/// Canonical totals owned by the accepted invoice-money calculator.
///
/// Callers map the calculator result into this struct; serializers only ever
/// see these exact cent values.
class EInvoiceCanonicalTotals {
  const EInvoiceCanonicalTotals({required this.netCents, required this.taxCents, required this.grossCents});

  final int netCents;
  final int taxCents;
  final int grossCents;
}

/// Builds [FinalizationSnapshot] values from transaction-captured rows.
///
/// Canonical totals come from the accepted money calculator result passed in
/// as the `preview` argument. Per-line splits reuse that calculator plus
/// half-up cent rounding; their sums MUST equal the preview totals or the
/// build fails. Nothing here replaces the calculator: a mismatch throws.
class EInvoiceSnapshotBuilder {
  const EInvoiceSnapshotBuilder();

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
    for (var index = 0; index < posRows.length; index++) {
      prepared.add(_prepareLine(posRows[index], index: index, eingabemodus: eingabemodus));
    }
    final List<EInvoiceLineSnapshot> lines = _applyDocumentDiscount(
      prepared,
      eingabemodus: eingabemodus,
      documentDiscountPercent: documentDiscountPercent,
      documentDiscountAmount: documentDiscountAmount,
    );
    var netSum = 0;
    var taxSum = 0;
    var grossSum = 0;
    for (final EInvoiceLineSnapshot line in lines) {
      netSum += line.netCents;
      taxSum += line.taxCents;
      grossSum += line.grossCents;
    }
    if (netSum != preview.netCents || taxSum != preview.taxCents || grossSum != preview.grossCents) {
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
      seller: _sellerFromCompany(companyRow),
      buyer: _buyerFromCustomer(customerRow, buyerReference: buyerReference),
      lines: List<EInvoiceLineSnapshot>.unmodifiable(lines),
      netCents: preview.netCents,
      taxCents: preview.taxCents,
      grossCents: preview.grossCents,
      buyerReference: buyerReference?.trim().isEmpty ?? true ? null : buyerReference!.trim(),
    );
  }

  _PreDiscountLine _prepareLine(Map<String, Object?> row, {required int index, required String eingabemodus}) {
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
    final EInvoiceLineClassification? classification = ApprovedTaxClassification.resolve(ustSatz);
    if (classification == null) {
      throw EInvoiceSourceException(
        code: 'unresolvedTaxClassification',
        messageDe: 'Position ${index + 1}: keine freigegebene Steuerklassifizierung für $ustSatz %',
        messageEn: 'Line ${index + 1}: no approved tax classification for $ustSatz %',
        fields: ['position[$index].ustSatz'],
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
    final int enteredCents = _roundHalfUp(product * BigInt.from(10000 - discountScaled), BigInt.from(1000000000));
    // Pre-discount net; document discounts are distributed below with the
    // canonical proportional allocator, mirroring the calculator's order.
    final int preDiscountNet;
    final int preDiscountEntered;
    if (eingabemodus == 'brutto') {
      preDiscountNet = _roundHalfUp(
        BigInt.from(enteredCents) * BigInt.from(10000),
        BigInt.from(10000 + rateHundredths),
      );
      preDiscountEntered = enteredCents;
    } else {
      preDiscountNet = enteredCents;
      preDiscountEntered = enteredCents;
    }
    return _PreDiscountLine(
      position: _asInt(row['position']) ?? index,
      description: description,
      quantityText: _quantityText(menge),
      unitPriceText: _scaledText(einzelpreis, 4),
      unitPriceIsGross: eingabemodus == 'brutto',
      enteredCents: preDiscountEntered,
      preDiscountNet: preDiscountNet,
      taxRateHundredths: rateHundredths,
      classification: classification,
    );
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
      netSubtotal += line.preDiscountNet;
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
      netByRate.update(line.taxRateHundredths, (old) => old + line.preDiscountNet, ifAbsent: () => line.preDiscountNet);
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
            weights: <int, int>{for (final int index in lineIndexes) index: prepared[index].preDiscountNet},
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
        final int netCents = pre.preDiscountNet - (discountByPosition[index] ?? 0);
        final int taxCents = eingabemodus == 'brutto' && discount == 0
            ? pre.enteredCents - pre.preDiscountNet
            : _roundHalfUp(BigInt.from(netCents) * BigInt.from(rate), BigInt.from(10000));
        lines.add(
          EInvoiceLineSnapshot(
            position: pre.position,
            description: pre.description,
            quantityText: pre.quantityText,
            unitPriceText: pre.unitPriceText,
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

  EInvoicePartySnapshot _sellerFromCompany(Map<String, Object?> row) {
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
      email: _text(row['email']),
      endpointId: vatId,
      endpointScheme: vatId == null ? null : '9930',
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
    required this.unitPriceText,
    required this.unitPriceIsGross,
    required this.enteredCents,
    required this.preDiscountNet,
    required this.taxRateHundredths,
    required this.classification,
  });

  final int position;
  final String description;
  final String quantityText;
  final String unitPriceText;
  final bool unitPriceIsGross;
  final int enteredCents;
  final int preDiscountNet;
  final int taxRateHundredths;
  final EInvoiceLineClassification classification;
}
