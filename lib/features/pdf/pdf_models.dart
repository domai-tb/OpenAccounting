enum PdfDocumentType { rechnung, storno, gutschrift, angebot, auftrag, proforma, lieferschein }

enum PdfTemplate { standard, gruen }

enum PdfCopyState { original, copy }

final class PdfCompanySnapshot {
  /// Const construction is available for snapshots whose optional byte lists are already immutable.
  const PdfCompanySnapshot({
    required this.name,
    this.street,
    this.postalCode,
    this.city,
    this.country,
    this.phone,
    this.email,
    this.website,
    this.taxNumber,
    this.vatId,
    this.iban,
    this.bic,
    this.accountHolder,
    this.logoBytes,
    this.signatureBytes,
  });

  /// Copies collection inputs before exposing them through the immutable snapshot.
  factory PdfCompanySnapshot.from({
    required String name,
    String? street,
    String? postalCode,
    String? city,
    String? country,
    String? phone,
    String? email,
    String? website,
    String? taxNumber,
    String? vatId,
    String? iban,
    String? bic,
    String? accountHolder,
    List<int>? logoBytes,
    List<int>? signatureBytes,
  }) {
    return PdfCompanySnapshot._(
      name: name,
      street: street,
      postalCode: postalCode,
      city: city,
      country: country,
      phone: phone,
      email: email,
      website: website,
      taxNumber: taxNumber,
      vatId: vatId,
      iban: iban,
      bic: bic,
      accountHolder: accountHolder,
      logoBytes: _immutableBytes(logoBytes),
      signatureBytes: _immutableBytes(signatureBytes),
    );
  }

  const PdfCompanySnapshot._({
    required this.name,
    this.street,
    this.postalCode,
    this.city,
    this.country,
    this.phone,
    this.email,
    this.website,
    this.taxNumber,
    this.vatId,
    this.iban,
    this.bic,
    this.accountHolder,
    this.logoBytes,
    this.signatureBytes,
  });

  final String name;
  final String? street;
  final String? postalCode;
  final String? city;
  final String? country;
  final String? phone;
  final String? email;
  final String? website;
  final String? taxNumber;
  final String? vatId;
  final String? iban;
  final String? bic;
  final String? accountHolder;
  final List<int>? logoBytes;
  final List<int>? signatureBytes;
}

final class PdfCustomerSnapshot {
  const PdfCustomerSnapshot({
    required this.name,
    this.company,
    this.zHd,
    this.street,
    this.postalCode,
    this.city,
    this.country,
  });

  final String name;
  final String? company;
  final String? zHd;
  final String? street;
  final String? postalCode;
  final String? city;
  final String? country;
}

final class PdfPositionSnapshot {
  const PdfPositionSnapshot({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.netAmount,
    required this.taxRate,
    required this.taxAmount,
    required this.grossAmount,
    this.position,
    this.discountPercent,
    this.discountAmount,
    this.marginScheme = false,
    this.purchaseNetAmount,
  });

  final int? position;
  final String description;
  final num quantity;
  final num unitPrice;
  final num? discountPercent;
  final num? discountAmount;
  final num netAmount;
  final num taxRate;
  final num taxAmount;
  final num grossAmount;
  final bool marginScheme;
  final num? purchaseNetAmount;
}

final class PdfTotalsSnapshot {
  const PdfTotalsSnapshot({
    required this.netAmount,
    required this.taxAmount,
    required this.grossAmount,
    this.subtotal,
    this.discountAmount,
    this.marginGrossAmount,
    this.marginTaxableBase,
  });

  final num? subtotal;
  final num? discountAmount;
  final num netAmount;
  final num taxAmount;
  final num grossAmount;
  final num? marginGrossAmount;
  final num? marginTaxableBase;
}

final class PdfTypeTextSnapshot {
  const PdfTypeTextSnapshot({this.einleitungstext, this.schlusstext});

  final String? einleitungstext;
  final String? schlusstext;
}

final class PdfDocumentTextsSnapshot {
  const PdfDocumentTextsSnapshot({
    this.rechnung = const PdfTypeTextSnapshot(),
    this.storno = const PdfTypeTextSnapshot(),
    this.gutschrift = const PdfTypeTextSnapshot(),
    this.angebot = const PdfTypeTextSnapshot(),
    this.auftrag = const PdfTypeTextSnapshot(),
    this.proforma = const PdfTypeTextSnapshot(),
    this.lieferschein = const PdfTypeTextSnapshot(),
  });

  final PdfTypeTextSnapshot rechnung;
  final PdfTypeTextSnapshot storno;
  final PdfTypeTextSnapshot gutschrift;
  final PdfTypeTextSnapshot angebot;
  final PdfTypeTextSnapshot auftrag;
  final PdfTypeTextSnapshot proforma;
  final PdfTypeTextSnapshot lieferschein;

  PdfTypeTextSnapshot forType(PdfDocumentType type) => switch (type) {
    PdfDocumentType.rechnung => rechnung,
    PdfDocumentType.storno => storno,
    PdfDocumentType.gutschrift => gutschrift,
    PdfDocumentType.angebot => angebot,
    PdfDocumentType.auftrag => auftrag,
    PdfDocumentType.proforma => proforma,
    PdfDocumentType.lieferschein => lieferschein,
  };
}

final class PdfDocumentSnapshot {
  /// Const construction is available when [positions] is already immutable.
  const PdfDocumentSnapshot({
    required this.documentType,
    required this.template,
    required this.documentNumber,
    required this.company,
    required this.customer,
    required this.positions,
    required this.totals,
    this.texts = const PdfDocumentTextsSnapshot(),
    this.copyState = PdfCopyState.original,
    this.documentDate,
    this.serviceFrom,
    this.serviceTo,
    this.validUntil,
    this.orderStatus,
  });

  /// Copies position inputs before exposing them through the immutable snapshot.
  factory PdfDocumentSnapshot.from({
    required PdfDocumentType documentType,
    required PdfTemplate template,
    required String documentNumber,
    required PdfCompanySnapshot company,
    required PdfCustomerSnapshot customer,
    required List<PdfPositionSnapshot> positions,
    required PdfTotalsSnapshot totals,
    PdfDocumentTextsSnapshot texts = const PdfDocumentTextsSnapshot(),
    PdfCopyState copyState = PdfCopyState.original,
    DateTime? documentDate,
    DateTime? serviceFrom,
    DateTime? serviceTo,
    DateTime? validUntil,
    String? orderStatus,
  }) {
    return PdfDocumentSnapshot(
      documentType: documentType,
      template: template,
      documentNumber: documentNumber,
      company: company,
      customer: customer,
      positions: List<PdfPositionSnapshot>.unmodifiable(positions),
      totals: totals,
      texts: texts,
      copyState: copyState,
      documentDate: documentDate,
      serviceFrom: serviceFrom,
      serviceTo: serviceTo,
      validUntil: validUntil,
      orderStatus: orderStatus,
    );
  }

  final PdfDocumentType documentType;
  final PdfTemplate template;
  final String documentNumber;
  final PdfCompanySnapshot company;
  final PdfCustomerSnapshot customer;
  final List<PdfPositionSnapshot> positions;
  final PdfTotalsSnapshot totals;
  final PdfDocumentTextsSnapshot texts;
  final PdfCopyState copyState;
  final DateTime? documentDate;
  final DateTime? serviceFrom;
  final DateTime? serviceTo;
  final DateTime? validUntil;
  final String? orderStatus;
}

List<int>? _immutableBytes(List<int>? bytes) => bytes == null ? null : List<int>.unmodifiable(bytes);
