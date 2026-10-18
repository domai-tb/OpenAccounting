import 'package:openaccounting/features/e_invoice/e_invoice_artifacts.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_snapshot.dart';

/// Serializes snapshots to pinned structured-invoice XML.
///
/// Both builders preserve snapshot values only: amounts render from stored
/// cent integers, quantities and unit prices from stored decimal texts.
/// No money is calculated, rounded, or reclassified here.
class EInvoiceXmlSerializer {
  const EInvoiceXmlSerializer();

  /// ZUGFeRD 2.5.2 `EN16931` UN/CEFACT CII D22B invoice for hybrid embedding.
  String zugferdCii(FinalizationSnapshot snapshot) {
    final StringBuffer xml = StringBuffer();
    xml.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    xml.writeln(
      '<rsm:CrossIndustryInvoice xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100" '
      'xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100" '
      'xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100">',
    );
    xml.writeln('  <rsm:ExchangedDocumentContext>');
    xml.writeln('    <ram:GuidelineSpecifiedDocumentContextParameter>');
    xml.writeln('      <ram:ID>${EInvoicePinnedVersions.zugferdContextParameter}</ram:ID>');
    xml.writeln('    </ram:GuidelineSpecifiedDocumentContextParameter>');
    xml.writeln('  </rsm:ExchangedDocumentContext>');
    xml.writeln('  <rsm:ExchangedDocument>');
    xml.writeln('    <ram:ID>${_escape(snapshot.documentNumber)}</ram:ID>');
    xml.writeln('    <ram:TypeCode>380</ram:TypeCode>');
    xml.writeln(
      '    <ram:IssueDateTime><udt:DateTimeString format="102">${_basicDate(snapshot.issueDate)}</udt:DateTimeString></ram:IssueDateTime>',
    );
    for (final String note in snapshot.invoiceNotes) {
      xml.writeln('    <ram:IncludedNote><ram:Content>${_escape(note)}</ram:Content></ram:IncludedNote>');
    }
    xml.writeln('  </rsm:ExchangedDocument>');
    xml.writeln('  <rsm:SupplyChainTradeTransaction>');
    for (final EInvoiceLineSnapshot line in snapshot.lines) {
      _ciiLine(xml, line);
    }
    xml.writeln('    <ram:ApplicableHeaderTradeAgreement>');
    _ciiParty(xml, tag: 'SellerTradeParty', party: snapshot.seller);
    _ciiParty(xml, tag: 'BuyerTradeParty', party: snapshot.buyer);
    xml.writeln('    </ram:ApplicableHeaderTradeAgreement>');
    xml.writeln('    <ram:ApplicableHeaderTradeDelivery/>');
    xml.writeln('    <ram:ApplicableHeaderTradeSettlement>');
    xml.writeln('      <ram:InvoiceCurrencyCode>${snapshot.currency}</ram:InvoiceCurrencyCode>');
    for (final EInvoiceTaxBreakdownSnapshot group in snapshot.taxBreakdowns) {
      xml.writeln('      <ram:ApplicableTradeTax>');
      xml.writeln('        <ram:CalculatedAmount>${_cents(group.taxCents)}</ram:CalculatedAmount>');
      xml.writeln('        <ram:TypeCode>VAT</ram:TypeCode>');
      final String? exemptionCode = group.classification.exemptionReasonCode;
      if (exemptionCode != null && exemptionCode.isNotEmpty) {
        xml.writeln('        <ram:ExemptionReasonCode>${_escape(exemptionCode)}</ram:ExemptionReasonCode>');
      }
      final String? exemptionReason = group.classification.exemptionReason;
      if (exemptionReason != null && exemptionReason.isNotEmpty) {
        xml.writeln('        <ram:ExemptionReason>${_escape(exemptionReason)}</ram:ExemptionReason>');
      }
      xml.writeln('        <ram:BasisAmount>${_cents(group.netCents)}</ram:BasisAmount>');
      xml.writeln('        <ram:CategoryCode>${group.classification.category.code}</ram:CategoryCode>');
      xml.writeln(
        '        <ram:RateApplicablePercent>${_rateText(group.taxRateHundredths)}</ram:RateApplicablePercent>',
      );
      xml.writeln('      </ram:ApplicableTradeTax>');
    }
    xml.writeln('      <ram:SpecifiedTradeSettlementHeaderMonetarySummation>');
    xml.writeln('        <ram:LineTotalAmount>${_cents(snapshot.netCents)}</ram:LineTotalAmount>');
    xml.writeln('        <ram:TaxBasisTotalAmount>${_cents(snapshot.netCents)}</ram:TaxBasisTotalAmount>');
    xml.writeln(
      '        <ram:TaxTotalAmount currencyID="${snapshot.currency}">${_cents(snapshot.taxCents)}</ram:TaxTotalAmount>',
    );
    xml.writeln('        <ram:GrandTotalAmount>${_cents(snapshot.grossCents)}</ram:GrandTotalAmount>');
    xml.writeln('        <ram:DuePayableAmount>${_cents(snapshot.grossCents)}</ram:DuePayableAmount>');
    xml.writeln('      </ram:SpecifiedTradeSettlementHeaderMonetarySummation>');
    xml.writeln('    </ram:ApplicableHeaderTradeSettlement>');
    xml.writeln('  </rsm:SupplyChainTradeTransaction>');
    xml.writeln('</rsm:CrossIndustryInvoice>');
    return xml.toString();
  }

  /// Standalone XRechnung 3.0 UBL 2.1 invoice. Never wrapped in PDF/A-3.
  String xrechnungUbl(FinalizationSnapshot snapshot) {
    final StringBuffer xml = StringBuffer();
    xml.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    xml.writeln(
      '<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2" '
      'xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2" '
      'xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">',
    );
    // Normative format identity only; the validator bundle version is release
    // metadata and must not be presented as the format version.
    xml.writeln(
      '  <cbc:CustomizationID>urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_${EInvoicePinnedVersions.xrechnungVersion}</cbc:CustomizationID>',
    );
    // BT-23 business process for XRechnung (PEPPOL-EN16931-R001).
    xml.writeln('  <cbc:ProfileID>urn:fdc:peppol.eu:2017:poacc:billing:01:1.0</cbc:ProfileID>');
    xml.writeln('  <cbc:ID>${_escape(snapshot.documentNumber)}</cbc:ID>');
    xml.writeln('  <cbc:IssueDate>${_escape(snapshot.issueDate)}</cbc:IssueDate>');
    xml.writeln('  <cbc:InvoiceTypeCode>380</cbc:InvoiceTypeCode>');
    for (final String note in snapshot.invoiceNotes) {
      xml.writeln('  <cbc:Note>${_escape(note)}</cbc:Note>');
    }
    xml.writeln('  <cbc:DocumentCurrencyCode>${snapshot.currency}</cbc:DocumentCurrencyCode>');
    xml.writeln('  <cbc:BuyerReference>${_escape(snapshot.buyerReference ?? '')}</cbc:BuyerReference>');
    final String? deliveryDate = snapshot.deliveryDate;
    _ublParty(xml, tag: 'AccountingSupplierParty', party: snapshot.seller);
    _ublParty(xml, tag: 'AccountingCustomerParty', party: snapshot.buyer);
    if (deliveryDate != null && deliveryDate.isNotEmpty) {
      xml.writeln('  <cac:Delivery>');
      xml.writeln('    <cbc:ActualDeliveryDate>${_escape(deliveryDate)}</cbc:ActualDeliveryDate>');
      xml.writeln('  </cac:Delivery>');
    }
    final String? payeeIban = snapshot.seller.iban;
    if (payeeIban != null && payeeIban.isNotEmpty) {
      // BT-81 58 SEPA transfer with BG-17 credit transfer account.
      // Absent IBAN emits no block; validation fails closed instead.
      xml.writeln('  <cac:PaymentMeans>');
      xml.writeln('    <cbc:PaymentMeansCode>58</cbc:PaymentMeansCode>');
      xml.writeln('    <cac:PayeeFinancialAccount>');
      xml.writeln('      <cbc:ID>${_escape(payeeIban)}</cbc:ID>');
      xml.writeln('    </cac:PayeeFinancialAccount>');
      xml.writeln('  </cac:PaymentMeans>');
    }
    xml.writeln('  <cac:TaxTotal>');
    xml.writeln('    <cbc:TaxAmount currencyID="${snapshot.currency}">${_cents(snapshot.taxCents)}</cbc:TaxAmount>');
    for (final EInvoiceTaxBreakdownSnapshot group in snapshot.taxBreakdowns) {
      xml.writeln('    <cac:TaxSubtotal>');
      xml.writeln(
        '      <cbc:TaxableAmount currencyID="${snapshot.currency}">${_cents(group.netCents)}</cbc:TaxableAmount>',
      );
      xml.writeln('      <cbc:TaxAmount currencyID="${snapshot.currency}">${_cents(group.taxCents)}</cbc:TaxAmount>');
      xml.writeln('      <cac:TaxCategory>');
      xml.writeln('        <cbc:ID>${group.classification.category.code}</cbc:ID>');
      xml.writeln('        <cbc:Percent>${_rateText(group.taxRateHundredths)}</cbc:Percent>');
      final String? exemptionCode = group.classification.exemptionReasonCode;
      if (exemptionCode != null && exemptionCode.isNotEmpty) {
        xml.writeln('        <cbc:TaxExemptionReasonCode>${_escape(exemptionCode)}</cbc:TaxExemptionReasonCode>');
      }
      final String? exemptionReason = group.classification.exemptionReason;
      if (exemptionReason != null && exemptionReason.isNotEmpty) {
        xml.writeln('        <cbc:TaxExemptionReason>${_escape(exemptionReason)}</cbc:TaxExemptionReason>');
      }
      xml.writeln('        <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>');
      xml.writeln('      </cac:TaxCategory>');
      xml.writeln('    </cac:TaxSubtotal>');
    }
    xml.writeln('  </cac:TaxTotal>');
    xml.writeln('  <cac:LegalMonetaryTotal>');
    xml.writeln(
      '    <cbc:LineExtensionAmount currencyID="${snapshot.currency}">${_cents(snapshot.netCents)}</cbc:LineExtensionAmount>',
    );
    xml.writeln(
      '    <cbc:TaxExclusiveAmount currencyID="${snapshot.currency}">${_cents(snapshot.netCents)}</cbc:TaxExclusiveAmount>',
    );
    xml.writeln(
      '    <cbc:TaxInclusiveAmount currencyID="${snapshot.currency}">${_cents(snapshot.grossCents)}</cbc:TaxInclusiveAmount>',
    );
    xml.writeln(
      '    <cbc:PayableAmount currencyID="${snapshot.currency}">${_cents(snapshot.grossCents)}</cbc:PayableAmount>',
    );
    xml.writeln('  </cac:LegalMonetaryTotal>');
    for (final EInvoiceLineSnapshot line in snapshot.lines) {
      xml.writeln('  <cac:InvoiceLine>');
      xml.writeln('    <cbc:ID>${line.position}</cbc:ID>');
      // Positions carry no unit of measure; H87 (piece) is the documented
      // fallback until the invoice model captures units.
      xml.writeln('    <cbc:InvoicedQuantity unitCode="H87">${_escape(line.quantityText)}</cbc:InvoicedQuantity>');
      xml.writeln(
        '    <cbc:LineExtensionAmount currencyID="${snapshot.currency}">${_cents(line.netCents)}</cbc:LineExtensionAmount>',
      );
      xml.writeln('    <cac:Item><cbc:Name>${_escape(line.description)}</cbc:Name>');
      xml.writeln('      <cac:ClassifiedTaxCategory>');
      xml.writeln('        <cbc:ID>${line.classification.category.code}</cbc:ID>');
      xml.writeln('        <cbc:Percent>${_rateText(line.taxRateHundredths)}</cbc:Percent>');
      final String? itemReasonCode = line.classification.exemptionReasonCode;
      if (itemReasonCode != null && itemReasonCode.isNotEmpty) {
        xml.writeln('        <cbc:TaxExemptionReasonCode>${_escape(itemReasonCode)}</cbc:TaxExemptionReasonCode>');
      }
      final String? itemReason = line.classification.exemptionReason;
      if (itemReason != null && itemReason.isNotEmpty) {
        xml.writeln('        <cbc:TaxExemptionReason>${_escape(itemReason)}</cbc:TaxExemptionReason>');
      }
      xml.writeln('        <cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme>');
      xml.writeln('      </cac:ClassifiedTaxCategory>');
      xml.writeln('    </cac:Item>');
      xml.writeln('    <cac:Price>');
      xml.writeln(
        '      <cbc:PriceAmount currencyID="${snapshot.currency}">${_escape(line.unitPriceText)}</cbc:PriceAmount>',
      );
      xml.writeln('    </cac:Price>');
      xml.writeln('  </cac:InvoiceLine>');
    }
    xml.writeln('</Invoice>');
    return xml.toString();
  }

  void _ciiLine(StringBuffer xml, EInvoiceLineSnapshot line) {
    xml.writeln('    <ram:IncludedSupplyChainTradeLineItem>');
    xml.writeln(
      '      <ram:AssociatedDocumentLineDocument><ram:LineID>${line.position}</ram:LineID></ram:AssociatedDocumentLineDocument>',
    );
    xml.writeln(
      '      <ram:SpecifiedTradeProduct><ram:Name>${_escape(line.description)}</ram:Name></ram:SpecifiedTradeProduct>',
    );
    xml.writeln('      <ram:SpecifiedLineTradeAgreement>');
    // Stored unit price: net block for netto input, gross block for brutto.
    if (line.unitPriceIsGross) {
      xml.writeln(
        '        <ram:GrossPriceProductTradePrice><ram:ChargeAmount>${_escape(line.unitPriceText)}</ram:ChargeAmount></ram:GrossPriceProductTradePrice>',
      );
    } else {
      xml.writeln(
        '        <ram:NetPriceProductTradePrice><ram:ChargeAmount>${_escape(line.unitPriceText)}</ram:ChargeAmount></ram:NetPriceProductTradePrice>',
      );
    }
    xml.writeln('      </ram:SpecifiedLineTradeAgreement>');
    xml.writeln(
      '      <ram:SpecifiedLineTradeDelivery><ram:BilledQuantity unitCode="H87">${_escape(line.quantityText)}</ram:BilledQuantity></ram:SpecifiedLineTradeDelivery>',
    );
    xml.writeln('      <ram:SpecifiedLineTradeSettlement>');
    final String? lineReasonCode = line.classification.exemptionReasonCode;
    final String? lineReason = line.classification.exemptionReason;
    final String exemptionCodeXml = lineReasonCode == null
        ? ''
        : '<ram:ExemptionReasonCode>${_escape(lineReasonCode)}</ram:ExemptionReasonCode>';
    final String exemptionReasonXml = lineReason == null
        ? ''
        : '<ram:ExemptionReason>${_escape(lineReason)}</ram:ExemptionReason>';
    xml.writeln(
      '        <ram:ApplicableTradeTax><ram:TypeCode>VAT</ram:TypeCode>$exemptionCodeXml$exemptionReasonXml<ram:CategoryCode>${line.classification.category.code}</ram:CategoryCode><ram:RateApplicablePercent>${_rateText(line.taxRateHundredths)}</ram:RateApplicablePercent></ram:ApplicableTradeTax>',
    );
    xml.writeln(
      '        <ram:SpecifiedTradeSettlementLineMonetarySummation><ram:LineTotalAmount>${_cents(line.netCents)}</ram:LineTotalAmount></ram:SpecifiedTradeSettlementLineMonetarySummation>',
    );
    xml.writeln('      </ram:SpecifiedLineTradeSettlement>');
    xml.writeln('    </ram:IncludedSupplyChainTradeLineItem>');
  }

  void _ciiParty(StringBuffer xml, {required String tag, required EInvoicePartySnapshot party}) {
    xml.writeln('      <ram:$tag>');
    xml.writeln('        <ram:Name>${_escape(party.company ?? party.name)}</ram:Name>');
    xml.writeln('        <ram:PostalTradeAddress>');
    xml.writeln('          <ram:PostcodeCode>${_escape(party.postalCode ?? '')}</ram:PostcodeCode>');
    xml.writeln('          <ram:LineOne>${_escape(party.street ?? '')}</ram:LineOne>');
    xml.writeln('          <ram:CityName>${_escape(party.city ?? '')}</ram:CityName>');
    xml.writeln('          <ram:CountryID>${_escape(party.country ?? '')}</ram:CountryID>');
    xml.writeln('        </ram:PostalTradeAddress>');
    if (party.vatId != null) {
      xml.writeln(
        '        <ram:SpecifiedTaxRegistration><ram:ID schemeID="VA">${_escape(party.vatId!)}</ram:ID></ram:SpecifiedTaxRegistration>',
      );
    }
    xml.writeln('      </ram:$tag>');
  }

  void _ublParty(StringBuffer xml, {required String tag, required EInvoicePartySnapshot party}) {
    xml.writeln('  <cac:$tag>');
    xml.writeln('    <cac:Party>');
    if (party.endpointId != null && party.endpointScheme != null) {
      xml.writeln(
        '      <cbc:EndpointID schemeID="${party.endpointScheme}">${_escape(party.endpointId!)}</cbc:EndpointID>',
      );
    }
    xml.writeln('      <cac:PartyName><cbc:Name>${_escape(party.company ?? party.name)}</cbc:Name></cac:PartyName>');
    xml.writeln('      <cac:PostalAddress>');
    xml.writeln('        <cbc:StreetName>${_escape(party.street ?? '')}</cbc:StreetName>');
    xml.writeln('        <cbc:CityName>${_escape(party.city ?? '')}</cbc:CityName>');
    xml.writeln('        <cbc:PostalZone>${_escape(party.postalCode ?? '')}</cbc:PostalZone>');
    xml.writeln(
      '        <cac:Country><cbc:IdentificationCode>${_escape(party.country ?? '')}</cbc:IdentificationCode></cac:Country>',
    );
    xml.writeln('      </cac:PostalAddress>');
    if (party.vatId != null) {
      xml.writeln(
        '      <cac:PartyTaxScheme><cbc:CompanyID>${_escape(party.vatId!)}</cbc:CompanyID><cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme></cac:PartyTaxScheme>',
      );
    }
    final String companyLegalForm = party.companyLegalForm == null
        ? ''
        : '<cbc:CompanyLegalForm>${_escape(party.companyLegalForm!)}</cbc:CompanyLegalForm>';
    xml.writeln(
      '      <cac:PartyLegalEntity><cbc:RegistrationName>${_escape(party.name)}</cbc:RegistrationName>'
      '$companyLegalForm</cac:PartyLegalEntity>',
    );
    xml.writeln('    </cac:Party>');
    xml.writeln('  </cac:$tag>');
  }

  String _cents(int value) {
    final bool negative = value < 0;
    final String digits = value.abs().toString().padLeft(3, '0');
    return '${negative ? '-' : ''}${digits.substring(0, digits.length - 2)}.${digits.substring(digits.length - 2)}';
  }

  String _rateText(int hundredths) {
    final String digits = hundredths.toString().padLeft(3, '0');
    return '${digits.substring(0, digits.length - 2)}.${digits.substring(digits.length - 2)}';
  }

  String _basicDate(String iso) => iso.replaceAll('-', '');

  String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
