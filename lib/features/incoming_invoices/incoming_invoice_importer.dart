import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

enum IncomingInvoiceImportStatus { supported, unsupportedProfile, unreadable }

class IncomingInvoiceLineSuggestion {
  const IncomingInvoiceLineSuggestion({
    required this.description,
    required this.quantity,
    required this.netUnitPrice,
    required this.vatRate,
  });

  final String description;
  final String quantity;
  final String netUnitPrice;
  final String vatRate;
}

class IncomingInvoiceImportResult {
  const IncomingInvoiceImportResult({
    required this.status,
    this.sourceInvoiceNumber,
    this.invoiceDate,
    this.dueDate,
    this.currency,
    this.sellerNameHint,
    this.sellerVatIdHint,
    this.lines = const <IncomingInvoiceLineSuggestion>[],
    this.displayTotals = const <String, String>{},
    this.unsupportedValues = const <String>[],
  });

  final IncomingInvoiceImportStatus status;
  final String? sourceInvoiceNumber;
  final String? invoiceDate;
  final String? dueDate;
  final String? currency;
  final String? sellerNameHint;
  final String? sellerVatIdHint;
  final List<IncomingInvoiceLineSuggestion> lines;
  final Map<String, String> displayTotals;
  final List<String> unsupportedValues;

  bool get isReviewable => status != IncomingInvoiceImportStatus.unreadable;
}

/// Reads supported invoice suggestions from XRechnung XML or an embedded CII payload.
class IncomingInvoiceImporter {
  const IncomingInvoiceImporter();

  static const int maxSourceBytes = 2 * 1024 * 1024;

  IncomingInvoiceImportResult parse({required Uint8List bytes, required String filename}) {
    if (bytes.isEmpty || bytes.length > maxSourceBytes) return _unreadable();
    try {
      final String lowerName = filename.toLowerCase();
      final bool isPdf = _hasPdfHeader(bytes);
      final String xmlText;
      if (lowerName.endsWith('.xml')) {
        xmlText = utf8.decode(bytes);
      } else if (isPdf) {
        final String? embedded = _embeddedInvoiceXml(bytes);
        if (embedded == null) return _unreadable();
        xmlText = embedded;
      } else {
        return _unreadable();
      }
      if (RegExp(r'<!\s*(?:DOCTYPE|ENTITY)\b', caseSensitive: false).hasMatch(xmlText)) return _unreadable();

      final XmlDocument document = XmlDocument.parse(xmlText);
      final XmlElement root = document.rootElement;
      final bool isUbl =
          root.name.local == 'Invoice' &&
          root.name.namespaceUri == 'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2';
      final bool isCii =
          isPdf &&
          root.name.local == 'CrossIndustryInvoice' &&
          root.name.namespaceUri == 'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100';
      if (!isUbl && !isCii) return _unreadable();

      final String profile = _value(
        document,
        isUbl ? 'CustomizationID' : 'ID',
        within: isUbl ? null : _first(document, 'GuidelineSpecifiedDocumentContextParameter'),
      ).toLowerCase();
      final bool supportedProfile = isUbl
          ? profile.contains('xrechnung_3.0')
          : profile.contains('factur-x.eu:1p0:en16931') ||
                profile.contains('zugferd.de:2p5:en16931') ||
                profile.contains('zugferd:2p5:en16931') ||
                profile.contains('xrechnung_3.0');
      if (!supportedProfile) {
        return const IncomingInvoiceImportResult(status: IncomingInvoiceImportStatus.unsupportedProfile);
      }

      final List<String> unsupported = _unsupportedFields(document, isUbl: isUbl);
      for (final XmlElement line in _elements(document, isUbl ? 'InvoiceLine' : 'IncludedSupplyChainTradeLineItem')) {
        final String quantity = _lineValue(line, isUbl ? 'InvoicedQuantity' : 'BilledQuantity');
        final String price = _lineValue(
          line,
          isUbl ? 'PriceAmount' : 'ChargeAmount',
          within: _first(line, isUbl ? 'Price' : 'NetPriceProductTradePrice'),
        );
        final String vat = _lineValue(
          line,
          isUbl ? 'Percent' : 'RateApplicablePercent',
          within: _first(line, isUbl ? 'ClassifiedTaxCategory' : 'ApplicableTradeTax'),
        );
        if (!_isDecimal(quantity)) unsupported.add('BT-129 quantity $quantity');
        if (!_isDecimal(price)) unsupported.add('BT-146 net unit price $price');
        if (!_isDecimal(vat)) unsupported.add('BT-152 VAT rate $vat');
      }
      final String currency = _value(
        document,
        isUbl ? 'DocumentCurrencyCode' : 'InvoiceCurrencyCode',
        within: isUbl ? null : _first(document, 'ApplicableHeaderTradeSettlement'),
      );
      if (currency != 'EUR') unsupported.add('BT-5 currency $currency');
      if (unsupported.isNotEmpty) {
        return IncomingInvoiceImportResult(
          status: IncomingInvoiceImportStatus.supported,
          currency: currency,
          unsupportedValues: List<String>.unmodifiable(unsupported),
        );
      }

      final XmlElement? seller = _first(document, isUbl ? 'AccountingSupplierParty' : 'SellerTradeParty');
      final Iterable<XmlElement> sourceLines = _elements(
        document,
        isUbl ? 'InvoiceLine' : 'IncludedSupplyChainTradeLineItem',
      );
      final List<IncomingInvoiceLineSuggestion> lines = <IncomingInvoiceLineSuggestion>[
        for (final XmlElement line in sourceLines)
          IncomingInvoiceLineSuggestion(
            description: _lineValue(line, 'Name', within: _first(line, isUbl ? 'Item' : 'SpecifiedTradeProduct')),
            quantity: _lineValue(line, isUbl ? 'InvoicedQuantity' : 'BilledQuantity'),
            netUnitPrice: _lineValue(
              line,
              isUbl ? 'PriceAmount' : 'ChargeAmount',
              within: _first(line, isUbl ? 'Price' : 'NetPriceProductTradePrice'),
            ),
            vatRate: _lineValue(
              line,
              isUbl ? 'Percent' : 'RateApplicablePercent',
              within: _first(line, isUbl ? 'ClassifiedTaxCategory' : 'ApplicableTradeTax'),
            ),
          ),
      ];
      if (lines.any(
        (IncomingInvoiceLineSuggestion line) =>
            line.description.isEmpty || line.quantity.isEmpty || line.netUnitPrice.isEmpty || line.vatRate.isEmpty,
      )) {
        return _unreadable();
      }

      return IncomingInvoiceImportResult(
        status: IncomingInvoiceImportStatus.supported,
        sourceInvoiceNumber: _value(document, 'ID', within: isUbl ? null : _first(document, 'ExchangedDocument')),
        invoiceDate: _dateValue(document, isUbl),
        dueDate: _dueDate(document, isUbl),
        currency: currency,
        sellerNameHint: _sellerName(seller, isUbl),
        sellerVatIdHint: _sellerVatId(seller, isUbl),
        lines: List<IncomingInvoiceLineSuggestion>.unmodifiable(lines),
        displayTotals: Map<String, String>.unmodifiable(_displayTotals(document, isUbl)),
      );
    } catch (_) {
      return _unreadable();
    }
  }

  List<String> _unsupportedFields(XmlDocument document, {required bool isUbl}) {
    final List<String> fields = <String>[];
    if (isUbl) {
      for (final XmlElement allowance in document.rootElement.childElements.where(
        (XmlElement e) => e.name.local == 'AllowanceCharge',
      )) {
        final bool charge = _value(allowance, 'ChargeIndicator').toLowerCase() == 'true';
        fields.add(charge ? 'BG-21 document charges' : 'BG-20 document allowances');
      }
      if (_has(document, 'AllowanceTotalAmount')) {
        fields.add('document-level rabatt');
      }
      if (_has(document, 'PaymentTerms')) fields.add('BT-20 payment terms');
      if (_hasAny(document, const <String>[
        'BuyerReference',
        'OrderReference',
        'DespatchDocumentReference',
        'ReceiptDocumentReference',
        'ContractDocumentReference',
      ])) {
        fields.add('BT-10 / BT-13 references');
      }
      if (_has(document, 'ActualDeliveryDate')) {
        fields.add('BT-72 delivery date');
      }
      if (_has(document, 'TaxExemptionReason')) {
        fields.add('BT-121 exemption reason');
      }
      if (_elements(document, 'TaxSubtotal').length > 1) fields.add('multiple VAT breakdowns');
      if (_hasAny(document, const <String>['SettlementDiscountPercent', 'SettlementDiscountAmount'])) {
        fields.add('Skonto terms');
      }
    } else {
      final Iterable<XmlElement> allowances = _elements(document, 'SpecifiedTradeAllowanceCharge').where((
        XmlElement e,
      ) {
        XmlElement? parent = e.parentElement;
        while (parent != null && parent.name.local != 'ApplicableHeaderTradeSettlement') {
          parent = parent.parentElement;
        }
        return parent != null;
      });
      for (final XmlElement allowance in allowances) {
        final bool charge =
            _value(allowance, 'Indicator', within: _first(allowance, 'ChargeIndicator')).toLowerCase() == 'true';
        fields.add(charge ? 'BG-21 document charges' : 'BG-20 document allowances');
      }
      if (_has(document, 'Description', within: _first(document, 'SpecifiedTradePaymentTerms'))) {
        fields.add('BT-20 payment terms');
      }
      if (_hasAny(document, const <String>[
        'BuyerReference',
        'BuyerOrderReferencedDocument',
        'AdditionalReferencedDocument',
      ])) {
        fields.add('BT-10 / BT-13 references');
      }
      if (_has(document, 'ActualDeliverySupplyChainEvent')) {
        fields.add('BT-72 delivery date');
      }
      if (_hasAny(document, const <String>['ExemptionReason', 'ExemptionReasonCode'])) {
        fields.add('BT-121 exemption reason');
      }
      if (_elements(_first(document, 'ApplicableHeaderTradeSettlement'), 'ApplicableTradeTax').length > 1) {
        fields.add('multiple VAT breakdowns');
      }
      if (_has(document, 'ApplicableTradePaymentDiscountTerms')) {
        fields.add('Skonto terms');
      }
    }
    return fields.toSet().toList(growable: true);
  }

  Map<String, String> _displayTotals(XmlDocument document, bool isUbl) {
    final Map<String, String> totals = <String, String>{};
    if (isUbl) {
      _put(totals, 'net', _value(document, 'TaxExclusiveAmount'));
      _put(totals, 'gross', _value(document, 'TaxInclusiveAmount'));
      _put(totals, 'payable', _value(document, 'PayableAmount'));
    } else {
      final XmlElement? summation = _first(document, 'SpecifiedTradeSettlementHeaderMonetarySummation');
      _put(totals, 'net', _value(document, 'TaxBasisTotalAmount', within: summation));
      _put(totals, 'gross', _value(document, 'GrandTotalAmount', within: summation));
      _put(totals, 'payable', _value(document, 'DuePayableAmount', within: summation));
    }
    return totals;
  }

  String _dateValue(XmlDocument document, bool isUbl) {
    if (isUbl) return _value(document, 'IssueDate');
    final XmlElement? date = _first(_first(document, 'IssueDateTime'), 'DateTimeString');
    return _formattedDate(date?.innerText.trim() ?? '', _attribute(date, 'format'));
  }

  String _dueDate(XmlDocument document, bool isUbl) {
    if (isUbl) return _value(document, 'DueDate');
    final XmlElement? due = _first(document, 'DueDateDateTime');
    final XmlElement? value = _first(due, 'DateTimeString');
    return _formattedDate(value?.innerText.trim() ?? '', _attribute(value, 'format'));
  }

  String _sellerName(XmlElement? seller, bool isUbl) {
    if (seller == null) return '';
    return isUbl ? _value(seller, 'Name', within: _first(seller, 'PartyName')) : _value(seller, 'Name');
  }

  String _sellerVatId(XmlElement? seller, bool isUbl) {
    if (seller == null) return '';
    if (isUbl) {
      final XmlElement? vatScheme = _elements(seller, 'PartyTaxScheme').where((XmlElement scheme) {
        return _value(scheme, 'ID', within: _first(scheme, 'TaxScheme')).toUpperCase() == 'VAT';
      }).firstOrNull;
      return _value(vatScheme, 'CompanyID');
    }
    final XmlElement? taxRegistration = _elements(seller, 'SpecifiedTaxRegistration').where((XmlElement registration) {
      final String scheme = _attribute(_first(registration, 'ID'), 'schemeID').toUpperCase();
      return scheme.isEmpty || scheme == 'VA';
    }).firstOrNull;
    return _value(taxRegistration, 'ID');
  }

  String _lineValue(XmlElement line, String localName, {XmlElement? within}) => _value(line, localName, within: within);

  String _value(XmlNode? root, String localName, {XmlNode? within}) {
    final Iterable<XmlElement> elements = (within ?? root)?.descendants.whereType<XmlElement>() ?? const <XmlElement>[];
    return elements.where((XmlElement e) => e.name.local == localName).firstOrNull?.innerText.trim() ?? '';
  }

  Iterable<XmlElement> _elements(XmlNode? root, String localName) =>
      (root?.descendants.whereType<XmlElement>() ?? const <XmlElement>[]).where(
        (XmlElement element) => element.name.local == localName,
      );

  XmlElement? _first(XmlNode? root, String localName) => _elements(root, localName).firstOrNull;

  bool _has(XmlNode root, String localName, {XmlNode? within}) => _first(within ?? root, localName) != null;

  bool _hasAny(XmlNode root, List<String> names) => names.any((String name) => _has(root, name));

  String _attribute(XmlElement? element, String name) =>
      element?.attributes.where((XmlAttribute a) => a.name.local == name).firstOrNull?.value ?? '';

  String _formattedDate(String value, String format) {
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return value;
    if (format == '102' && RegExp(r'^\d{8}$').hasMatch(value)) {
      return '${value.substring(0, 4)}-${value.substring(4, 6)}-${value.substring(6)}';
    }
    return '';
  }

  bool _isDecimal(String value) => RegExp(r'^[+-]?\d+(?:\.\d+)?$').hasMatch(value);

  bool _hasPdfHeader(Uint8List bytes) => bytes.length >= 5 && ascii.decode(bytes.take(5).toList()) == '%PDF-';

  // shortcut: scans raw PDF bytes, upgrade to stream decoding for compressed attachments.
  String? _embeddedInvoiceXml(Uint8List bytes) {
    final String decodedBytes = latin1.decode(bytes);
    final RegExp startTag = RegExp(r'<((?:[A-Za-z_][\w.-]*:)?CrossIndustryInvoice)\b');
    final RegExpMatch? start = startTag.firstMatch(decodedBytes);
    if (start == null) return null;
    final String rootName = start.group(1)!;
    final RegExp closingTag = RegExp('</${RegExp.escape(rootName)}\\s*>');
    final RegExpMatch? end = closingTag.firstMatch(decodedBytes.substring(start.end));
    if (end == null) return null;
    return utf8.decode(bytes.sublist(start.start, start.end + end.end));
  }

  void _put(Map<String, String> values, String key, String value) {
    if (value.isNotEmpty) values[key] = value;
  }

  IncomingInvoiceImportResult _unreadable() =>
      const IncomingInvoiceImportResult(status: IncomingInvoiceImportStatus.unreadable);
}
