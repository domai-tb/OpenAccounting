import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:openaccounting/features/incoming_invoices/incoming_invoice_importer.dart';

const String _supportedInvoice = '''
<Invoice xmlns="urn:oasis:names:specification:ubl:schema:xsd:Invoice-2"
  xmlns:cac="urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2"
  xmlns:cbc="urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2">
  <cbc:CustomizationID>urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0</cbc:CustomizationID>
  <cbc:ID>RE-2026-42</cbc:ID><cbc:IssueDate>2026-10-10</cbc:IssueDate>
  <cbc:DueDate>2026-10-24</cbc:DueDate><cbc:DocumentCurrencyCode>EUR</cbc:DocumentCurrencyCode>
  <cac:AccountingSupplierParty><cac:Party><cac:PartyName><cbc:Name>Beispiel GmbH</cbc:Name></cac:PartyName>
    <cac:PartyTaxScheme><cbc:CompanyID>DE123456789</cbc:CompanyID><cac:TaxScheme><cbc:ID>VAT</cbc:ID></cac:TaxScheme></cac:PartyTaxScheme>
  </cac:Party></cac:AccountingSupplierParty>
  <cac:InvoiceLine><cbc:InvoicedQuantity>2</cbc:InvoicedQuantity><cbc:LineExtensionAmount>20.00</cbc:LineExtensionAmount>
    <cac:Item><cbc:Name>Beratung</cbc:Name><cac:ClassifiedTaxCategory><cbc:Percent>19</cbc:Percent></cac:ClassifiedTaxCategory></cac:Item>
    <cac:Price><cbc:PriceAmount>10.00</cbc:PriceAmount></cac:Price>
  </cac:InvoiceLine>
  <cac:TaxTotal><cbc:TaxAmount>3.80</cbc:TaxAmount><cac:TaxSubtotal><cbc:TaxableAmount>20.00</cbc:TaxableAmount></cac:TaxSubtotal></cac:TaxTotal>
  <cac:LegalMonetaryTotal><cbc:TaxExclusiveAmount>20.00</cbc:TaxExclusiveAmount>
    <cbc:TaxInclusiveAmount>23.80</cbc:TaxInclusiveAmount><cbc:PayableAmount>23.80</cbc:PayableAmount>
  </cac:LegalMonetaryTotal>
</Invoice>
''';

void main() {
  const IncomingInvoiceImporter importer = IncomingInvoiceImporter();

  test('parses_supported_ubl_fields_without_calculating_amounts', () {
    final IncomingInvoiceImportResult result = importer.parse(
      bytes: Uint8List.fromList(utf8.encode(_supportedInvoice)),
      filename: 'rechnung.xml',
    );

    expect(result.status, IncomingInvoiceImportStatus.supported);
    expect(result.sourceInvoiceNumber, 'RE-2026-42');
    expect(result.invoiceDate, '2026-10-10');
    expect(result.dueDate, '2026-10-24');
    expect(result.currency, 'EUR');
    expect(result.sellerNameHint, 'Beispiel GmbH');
    expect(result.sellerVatIdHint, 'DE123456789');
    expect(result.lines, hasLength(1));
    expect(result.lines.single.description, 'Beratung');
    expect(result.lines.single.quantity, '2');
    expect(result.lines.single.netUnitPrice, '10.00');
    expect(result.lines.single.vatRate, '19');
    expect(result.displayTotals, <String, String>{'net': '20.00', 'gross': '23.80', 'payable': '23.80'});
  });

  test('parsing_suggestions_does_not_persist_an_invoice', () {
    final IncomingInvoiceImportResult result = importer.parse(
      bytes: Uint8List.fromList(utf8.encode(_supportedInvoice)),
      filename: 'rechnung.xml',
    );

    expect(result.isReviewable, isTrue);
    expect(result.sourceInvoiceNumber, 'RE-2026-42');
  });

  test('test_unreadable_structured_data_falls_back_to_manual_entry', () {
    final IncomingInvoiceImportResult result = importer.parse(
      bytes: Uint8List.fromList(utf8.encode('<Invoice>')),
      filename: 'kaputt.xml',
    );

    expect(result.status, IncomingInvoiceImportStatus.unreadable);
    expect(result.sourceInvoiceNumber, isNull);
    expect(result.lines, isEmpty);
  });

  test('test_unrepresentable_value_is_not_silently_mapped', () {
    final String invoice = _supportedInvoice.replaceFirst(
      '<cac:InvoiceLine>',
      '<cac:AllowanceCharge><cbc:ChargeIndicator>false</cbc:ChargeIndicator><cbc:Amount>5.00</cbc:Amount></cac:AllowanceCharge><cac:InvoiceLine>',
    );
    final IncomingInvoiceImportResult result = importer.parse(
      bytes: Uint8List.fromList(utf8.encode(invoice)),
      filename: 'rechnung.xml',
    );

    expect(result.unsupportedValues, contains('BG-20 document allowances'));
    expect(result.sourceInvoiceNumber, isNull);
  });

  test('test_unsupported_profile_falls_back_to_manual_entry', () {
    final String invoice = _supportedInvoice.replaceFirst('xrechnung_3.0', 'zugferd:basicwl');
    final IncomingInvoiceImportResult result = importer.parse(
      bytes: Uint8List.fromList(utf8.encode(invoice)),
      filename: 'rechnung.xml',
    );

    expect(result.status, IncomingInvoiceImportStatus.unsupportedProfile);
    expect(result.sourceInvoiceNumber, isNull);
    expect(result.lines, isEmpty);
  });

  test('rejects XML with DTD before parsing', () {
    final String invoice = _supportedInvoice.replaceFirst(
      '<Invoice ',
      '<!DOCTYPE Invoice [<!ENTITY secret SYSTEM "file:///etc/passwd">]><Invoice ',
    );
    final IncomingInvoiceImportResult result = importer.parse(
      bytes: Uint8List.fromList(utf8.encode(invoice)),
      filename: 'rechnung.xml',
    );

    expect(result.status, IncomingInvoiceImportStatus.unreadable);
    expect(result.sourceInvoiceNumber, isNull);
  });

  test('extracts the supported Factur-X CII payload from a PDF attachment', () async {
    const String cii = '''
<rsm:CrossIndustryInvoice xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100"
 xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100"
 xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100">
 <rsm:ExchangedDocumentContext><ram:GuidelineSpecifiedDocumentContextParameter><ram:ID>urn:factur-x.eu:1p0:en16931</ram:ID></ram:GuidelineSpecifiedDocumentContextParameter></rsm:ExchangedDocumentContext>
 <rsm:ExchangedDocument><ram:ID>CII-42</ram:ID><ram:IssueDateTime><udt:DateTimeString format="102">20261010</udt:DateTimeString></ram:IssueDateTime></rsm:ExchangedDocument>
 <rsm:SupplyChainTradeTransaction>
  <ram:IncludedSupplyChainTradeLineItem>
   <ram:SpecifiedTradeProduct><ram:Name>Consulting</ram:Name></ram:SpecifiedTradeProduct>
   <ram:SpecifiedLineTradeAgreement><ram:NetPriceProductTradePrice><ram:ChargeAmount>12.50</ram:ChargeAmount></ram:NetPriceProductTradePrice></ram:SpecifiedLineTradeAgreement>
   <ram:SpecifiedLineTradeDelivery><ram:BilledQuantity>2.5</ram:BilledQuantity></ram:SpecifiedLineTradeDelivery>
   <ram:SpecifiedLineTradeSettlement><ram:ApplicableTradeTax><ram:RateApplicablePercent>19.00</ram:RateApplicablePercent></ram:ApplicableTradeTax></ram:SpecifiedLineTradeSettlement>
  </ram:IncludedSupplyChainTradeLineItem>
  <ram:ApplicableHeaderTradeAgreement><ram:SellerTradeParty><ram:Name>Seller GmbH</ram:Name><ram:SpecifiedTaxRegistration><ram:ID>DE123456789</ram:ID></ram:SpecifiedTaxRegistration></ram:SellerTradeParty></ram:ApplicableHeaderTradeAgreement>
  <ram:ApplicableHeaderTradeSettlement><ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>
   <ram:SpecifiedTradePaymentTerms><ram:DueDateDateTime><udt:DateTimeString format="102">20261110</udt:DateTimeString></ram:DueDateDateTime></ram:SpecifiedTradePaymentTerms>
   <ram:SpecifiedTradeSettlementHeaderMonetarySummation><ram:TaxBasisTotalAmount>31.25</ram:TaxBasisTotalAmount><ram:GrandTotalAmount>37.19</ram:GrandTotalAmount><ram:DuePayableAmount>37.19</ram:DuePayableAmount></ram:SpecifiedTradeSettlementHeaderMonetarySummation>
  </ram:ApplicableHeaderTradeSettlement>
 </rsm:SupplyChainTradeTransaction>
</rsm:CrossIndustryInvoice>
''';
    final pw.Document pdfDocument = pw.Document(deflate: (List<int> data) => ZLibEncoder().convert(data));
    pdfDocument.addPage(pw.Page(build: (_) => pw.Text('Invoice')));
    pdf.PdfaAttachedFiles(pdfDocument.document, <pdf.PdfaAttachedFile>[
      pdf.PdfaAttachedFile(name: 'factur-x.xml', data: cii),
    ]);
    final Uint8List pdfBytes = await pdfDocument.save();
    final IncomingInvoiceImportResult result = importer.parse(bytes: pdfBytes, filename: 'rechnung.pdf');

    expect(result.status, IncomingInvoiceImportStatus.supported);
    expect(result.sourceInvoiceNumber, 'CII-42');
    expect(result.invoiceDate, '2026-10-10');
    expect(result.dueDate, '2026-11-10');
    expect(result.sellerNameHint, 'Seller GmbH');
    expect(result.sellerVatIdHint, 'DE123456789');
    expect(result.lines.single.quantity, '2.5');
    expect(result.lines.single.netUnitPrice, '12.50');
    expect(result.displayTotals, <String, String>{'net': '31.25', 'gross': '37.19', 'payable': '37.19'});
  });

  test('rejects source files larger than two mebibytes', () {
    final IncomingInvoiceImportResult result = importer.parse(
      bytes: Uint8List(IncomingInvoiceImporter.maxSourceBytes + 1),
      filename: 'rechnung.xml',
    );

    expect(result.status, IncomingInvoiceImportStatus.unreadable);
    expect(result.sourceInvoiceNumber, isNull);
  });
}
