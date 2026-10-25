/// Typed lifecycle relationship between persisted documents.
///
/// A relationship always names its [kind] (storno, gutschrift, ersatz,
/// konvertierung), the other document's [documentId], and a short human
/// readable [label] such as the document number. When the target row is
/// missing, [available] is false and the stored [documentId] is still
/// exposed so the UI can show an explicit unavailable state instead of
/// fabricating an unrelated document.
class RechnungBeziehung {
  const RechnungBeziehung({required this.kind, required this.documentId, required this.label, required this.available});

  final String kind;
  final int documentId;
  final String label;
  final bool available;
}

/// Nullable, position-keyed tax evidence stored with an invoice line.
///
/// Values stay explicit and nullable so legacy rows remain unverifiable and
/// exporters never infer a treatment from the tax rate or customer address.
class RechnungPositionTaxEvidence {
  const RechnungPositionTaxEvidence({
    this.taxTreatment,
    this.taxLegalBasis,
    this.eInvoiceTaxCategoryCode,
    this.eInvoiceExemptionReasonCode,
    this.eInvoiceExemptionReasonText,
    this.eInvoiceIntraCommunityDestinationCountryIso,
    this.eInvoiceIntraCommunityAcquisitionTaxTreatment,
    this.eInvoiceIntraCommunitySupplyEvidenceSourceRef,
    this.eInvoiceExportDestinationCountryIso,
    this.eInvoiceExportMovementActor,
    this.eInvoiceExportEvidenceSourceRef,
    this.eInvoiceReverseChargeSupplierEstablishmentCountryIso,
    this.eInvoiceReverseChargeSupplierEstablishmentBasis,
    this.eInvoiceReverseChargeSupplierGermanFixedEstablishmentStatus,
    this.eInvoiceReverseChargeRecipientStatus,
    this.eInvoiceReverseChargeRecipientEstablishmentCountryIso,
    this.eInvoiceReverseChargeServiceKind,
    this.eInvoiceReverseChargePlaceOfSupplyBasis,
    this.eInvoiceReverseChargePlaceOfSupplyCountryIso,
    this.eInvoiceReverseChargeTaxability,
    this.eInvoiceReverseChargeEvidenceSourceRef,
    this.eInvoiceReverseChargeRecipient13b5Basis,
    this.eInvoiceReverseChargeUst1tgCertificateRef,
    this.eInvoiceReverseChargeUst1tgScope,
    this.eInvoiceReverseChargeUst1tgRecipientVatId,
    this.eInvoiceReverseChargeUst1tgIssuedOn,
    this.eInvoiceReverseChargeUst1tgValidThrough,
  });

  static const List<String> databaseColumns = <String>[
    'tax_treatment',
    'tax_legal_basis',
    'e_invoice_tax_category_code',
    'e_invoice_exemption_reason_code',
    'e_invoice_exemption_reason_text',
    'e_invoice_intra_community_destination_country_iso',
    'e_invoice_intra_community_acquisition_tax_treatment',
    'e_invoice_intra_community_supply_evidence_source_ref',
    'e_invoice_export_destination_country_iso',
    'e_invoice_export_movement_actor',
    'e_invoice_export_evidence_source_ref',
    'e_invoice_reverse_charge_supplier_establishment_country_iso',
    'e_invoice_reverse_charge_supplier_establishment_basis',
    'e_invoice_reverse_charge_supplier_german_fixed_establishment_status',
    'e_invoice_reverse_charge_recipient_status',
    'e_invoice_reverse_charge_recipient_establishment_country_iso',
    'e_invoice_reverse_charge_service_kind',
    'e_invoice_reverse_charge_place_of_supply_basis',
    'e_invoice_reverse_charge_place_of_supply_country_iso',
    'e_invoice_reverse_charge_taxability',
    'e_invoice_reverse_charge_evidence_source_ref',
    'e_invoice_reverse_charge_recipient_13b5_basis',
    'e_invoice_reverse_charge_ust1tg_certificate_ref',
    'e_invoice_reverse_charge_ust1tg_scope',
    'e_invoice_reverse_charge_ust1tg_recipient_vat_id',
    'e_invoice_reverse_charge_ust1tg_issued_on',
    'e_invoice_reverse_charge_ust1tg_valid_through',
  ];

  factory RechnungPositionTaxEvidence.fromDatabaseRow(Map<String, Object?> row) {
    return RechnungPositionTaxEvidence(
      taxTreatment: _text(row['tax_treatment']),
      taxLegalBasis: _text(row['tax_legal_basis']),
      eInvoiceTaxCategoryCode: _text(row['e_invoice_tax_category_code']),
      eInvoiceExemptionReasonCode: _text(row['e_invoice_exemption_reason_code']),
      eInvoiceExemptionReasonText: _text(row['e_invoice_exemption_reason_text']),
      eInvoiceIntraCommunityDestinationCountryIso: _text(row['e_invoice_intra_community_destination_country_iso']),
      eInvoiceIntraCommunityAcquisitionTaxTreatment: _text(row['e_invoice_intra_community_acquisition_tax_treatment']),
      eInvoiceIntraCommunitySupplyEvidenceSourceRef: _text(row['e_invoice_intra_community_supply_evidence_source_ref']),
      eInvoiceExportDestinationCountryIso: _text(row['e_invoice_export_destination_country_iso']),
      eInvoiceExportMovementActor: _text(row['e_invoice_export_movement_actor']),
      eInvoiceExportEvidenceSourceRef: _text(row['e_invoice_export_evidence_source_ref']),
      eInvoiceReverseChargeSupplierEstablishmentCountryIso: _text(
        row['e_invoice_reverse_charge_supplier_establishment_country_iso'],
      ),
      eInvoiceReverseChargeSupplierEstablishmentBasis: _text(
        row['e_invoice_reverse_charge_supplier_establishment_basis'],
      ),
      eInvoiceReverseChargeSupplierGermanFixedEstablishmentStatus: _text(
        row['e_invoice_reverse_charge_supplier_german_fixed_establishment_status'],
      ),
      eInvoiceReverseChargeRecipientStatus: _text(row['e_invoice_reverse_charge_recipient_status']),
      eInvoiceReverseChargeRecipientEstablishmentCountryIso: _text(
        row['e_invoice_reverse_charge_recipient_establishment_country_iso'],
      ),
      eInvoiceReverseChargeServiceKind: _text(row['e_invoice_reverse_charge_service_kind']),
      eInvoiceReverseChargePlaceOfSupplyBasis: _text(row['e_invoice_reverse_charge_place_of_supply_basis']),
      eInvoiceReverseChargePlaceOfSupplyCountryIso: _text(row['e_invoice_reverse_charge_place_of_supply_country_iso']),
      eInvoiceReverseChargeTaxability: _text(row['e_invoice_reverse_charge_taxability']),
      eInvoiceReverseChargeEvidenceSourceRef: _text(row['e_invoice_reverse_charge_evidence_source_ref']),
      eInvoiceReverseChargeRecipient13b5Basis: _text(row['e_invoice_reverse_charge_recipient_13b5_basis']),
      eInvoiceReverseChargeUst1tgCertificateRef: _text(row['e_invoice_reverse_charge_ust1tg_certificate_ref']),
      eInvoiceReverseChargeUst1tgScope: _text(row['e_invoice_reverse_charge_ust1tg_scope']),
      eInvoiceReverseChargeUst1tgRecipientVatId: _text(row['e_invoice_reverse_charge_ust1tg_recipient_vat_id']),
      eInvoiceReverseChargeUst1tgIssuedOn: _text(row['e_invoice_reverse_charge_ust1tg_issued_on']),
      eInvoiceReverseChargeUst1tgValidThrough: _text(row['e_invoice_reverse_charge_ust1tg_valid_through']),
    );
  }

  Map<String, Object?> toDatabaseColumns() => <String, Object?>{
    'tax_treatment': taxTreatment,
    'tax_legal_basis': taxLegalBasis,
    'e_invoice_tax_category_code': eInvoiceTaxCategoryCode,
    'e_invoice_exemption_reason_code': eInvoiceExemptionReasonCode,
    'e_invoice_exemption_reason_text': eInvoiceExemptionReasonText,
    'e_invoice_intra_community_destination_country_iso': eInvoiceIntraCommunityDestinationCountryIso,
    'e_invoice_intra_community_acquisition_tax_treatment': eInvoiceIntraCommunityAcquisitionTaxTreatment,
    'e_invoice_intra_community_supply_evidence_source_ref': eInvoiceIntraCommunitySupplyEvidenceSourceRef,
    'e_invoice_export_destination_country_iso': eInvoiceExportDestinationCountryIso,
    'e_invoice_export_movement_actor': eInvoiceExportMovementActor,
    'e_invoice_export_evidence_source_ref': eInvoiceExportEvidenceSourceRef,
    'e_invoice_reverse_charge_supplier_establishment_country_iso': eInvoiceReverseChargeSupplierEstablishmentCountryIso,
    'e_invoice_reverse_charge_supplier_establishment_basis': eInvoiceReverseChargeSupplierEstablishmentBasis,
    'e_invoice_reverse_charge_supplier_german_fixed_establishment_status':
        eInvoiceReverseChargeSupplierGermanFixedEstablishmentStatus,
    'e_invoice_reverse_charge_recipient_status': eInvoiceReverseChargeRecipientStatus,
    'e_invoice_reverse_charge_recipient_establishment_country_iso':
        eInvoiceReverseChargeRecipientEstablishmentCountryIso,
    'e_invoice_reverse_charge_service_kind': eInvoiceReverseChargeServiceKind,
    'e_invoice_reverse_charge_place_of_supply_basis': eInvoiceReverseChargePlaceOfSupplyBasis,
    'e_invoice_reverse_charge_place_of_supply_country_iso': eInvoiceReverseChargePlaceOfSupplyCountryIso,
    'e_invoice_reverse_charge_taxability': eInvoiceReverseChargeTaxability,
    'e_invoice_reverse_charge_evidence_source_ref': eInvoiceReverseChargeEvidenceSourceRef,
    'e_invoice_reverse_charge_recipient_13b5_basis': eInvoiceReverseChargeRecipient13b5Basis,
    'e_invoice_reverse_charge_ust1tg_certificate_ref': eInvoiceReverseChargeUst1tgCertificateRef,
    'e_invoice_reverse_charge_ust1tg_scope': eInvoiceReverseChargeUst1tgScope,
    'e_invoice_reverse_charge_ust1tg_recipient_vat_id': eInvoiceReverseChargeUst1tgRecipientVatId,
    'e_invoice_reverse_charge_ust1tg_issued_on': eInvoiceReverseChargeUst1tgIssuedOn,
    'e_invoice_reverse_charge_ust1tg_valid_through': eInvoiceReverseChargeUst1tgValidThrough,
  };

  static String? _text(Object? value) => value?.toString();

  final String? taxTreatment;
  final String? taxLegalBasis;
  final String? eInvoiceTaxCategoryCode;
  final String? eInvoiceExemptionReasonCode;
  final String? eInvoiceExemptionReasonText;
  final String? eInvoiceIntraCommunityDestinationCountryIso;
  final String? eInvoiceIntraCommunityAcquisitionTaxTreatment;
  final String? eInvoiceIntraCommunitySupplyEvidenceSourceRef;
  final String? eInvoiceExportDestinationCountryIso;
  final String? eInvoiceExportMovementActor;
  final String? eInvoiceExportEvidenceSourceRef;
  final String? eInvoiceReverseChargeSupplierEstablishmentCountryIso;
  final String? eInvoiceReverseChargeSupplierEstablishmentBasis;
  final String? eInvoiceReverseChargeSupplierGermanFixedEstablishmentStatus;
  final String? eInvoiceReverseChargeRecipientStatus;
  final String? eInvoiceReverseChargeRecipientEstablishmentCountryIso;
  final String? eInvoiceReverseChargeServiceKind;
  final String? eInvoiceReverseChargePlaceOfSupplyBasis;
  final String? eInvoiceReverseChargePlaceOfSupplyCountryIso;
  final String? eInvoiceReverseChargeTaxability;
  final String? eInvoiceReverseChargeEvidenceSourceRef;
  final String? eInvoiceReverseChargeRecipient13b5Basis;
  final String? eInvoiceReverseChargeUst1tgCertificateRef;
  final String? eInvoiceReverseChargeUst1tgScope;
  final String? eInvoiceReverseChargeUst1tgRecipientVatId;
  final String? eInvoiceReverseChargeUst1tgIssuedOn;
  final String? eInvoiceReverseChargeUst1tgValidThrough;
}

class RechnungPositionItem {
  const RechnungPositionItem({
    required this.bezeichnung,
    required this.menge,
    required this.einzelpreis,
    required this.gesamt,
    this.ustSatz = 19,
    this.artikelId,
    this.position,
    this.id,
    this.rabattProzent,
    this.taxEvidence,
  });

  final int? id;
  final int? artikelId;
  final String bezeichnung;
  final num menge;
  final num einzelpreis;
  final num gesamt;
  final num ustSatz;
  final int? position;
  final num? rabattProzent;
  final RechnungPositionTaxEvidence? taxEvidence;
}

class RechnungItem {
  RechnungItem({
    required this.id,
    required this.rechnungsnummer,
    required this.typ,
    required this.status,
    required this.istEntwurf,
    required this.eingabemodus,
    required this.datum,
    this.kundeName,
    this.kundeFirma,
    this.kundeStrasse,
    this.kundePlz,
    this.kundeOrt,
    this.originalPdfPath,
    this.rabattProzent,
    this.rabattBetrag,
    this.ausgabeformat,
    this.kundeId,
    this.lieferantId,
    this.belegId,
    this.faelligkeit,
    this.leistungsdatum,
    this.fremdRechnungsnummer,
    required List<RechnungPositionItem> positionen,
    List<RechnungBeziehung> beziehungen = const <RechnungBeziehung>[],
  }) : positionen = List<RechnungPositionItem>.unmodifiable(positionen),
       beziehungen = List<RechnungBeziehung>.unmodifiable(beziehungen);

  final int id;
  final String? rechnungsnummer;
  final String typ;
  final String status;
  final bool istEntwurf;
  final String eingabemodus;
  final String datum;
  final String? kundeName;
  final String? kundeFirma;
  final String? kundeStrasse;
  final String? kundePlz;
  final String? kundeOrt;
  final String? originalPdfPath;
  final num? rabattProzent;
  final num? rabattBetrag;

  /// Linked customer/supplier rows. Null for walk-in documents.
  final int? kundeId;
  final int? lieferantId;
  final int? belegId;
  final String? faelligkeit;
  final String? leistungsdatum;
  final String? fremdRechnungsnummer;

  /// Explicit per-invoice output choice persisted at finalization
  /// (`pdf`, `zugferd`, or `xrechnung`). Null for legacy rows and drafts.
  final String? ausgabeformat;
  final List<RechnungPositionItem> positionen;

  /// Typed source/target references (storno, gutschrift, ersatz,
  /// konvertierung). Empty when the document has no persisted links.
  final List<RechnungBeziehung> beziehungen;

  bool get istStorniert => status.toLowerCase() == 'storniert';
  bool get istEntwurfDokument => istEntwurf || status.toLowerCase() == 'entwurf';

  /// Effective output format. Legacy finalized rows and drafts without a
  /// saved choice resolve to PDF; the customer's current preference is never
  /// consulted for finalized invoices.
  String get effektivesAusgabeformat {
    final String normalized = ausgabeformat?.trim().toLowerCase() ?? '';
    return switch (normalized) {
      'zugferd' => 'zugferd',
      'xrechnung' => 'xrechnung',
      _ => 'pdf',
    };
  }
}
