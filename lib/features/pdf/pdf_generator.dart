import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:openaccounting/features/pdf/pdf_models.dart';
import 'package:openaccounting/l10n/l10n.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

final class PdfGenerator {
  const PdfGenerator();

  Future<Uint8List> generate(PdfDocumentSnapshot snapshot, {required String locale}) {
    final AppLocalizations l10n = lookupAppLocalizations(Locale(locale.split('_').first));
    final document = pw.Document(compress: false);
    final isCopy = snapshot.copyState == PdfCopyState.copy;
    final pageTheme = pw.PageTheme(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      buildBackground: isCopy
          ? (pw.Context context) => pw.FullPage(ignoreMargins: true, child: pw.Watermark.text('KOPIE'))
          : null,
    );
    document.addPage(pw.MultiPage(pageTheme: pageTheme, build: (_) => _buildPage(snapshot, l10n, locale)));
    return document.save();
  }
}

List<pw.Widget> _buildPage(PdfDocumentSnapshot snapshot, AppLocalizations l10n, String locale) {
  final showTax = snapshot.template == PdfTemplate.standard;
  final isDeliveryNote = snapshot.documentType == PdfDocumentType.lieferschein;
  final isMahnung = snapshot.documentType == PdfDocumentType.mahnung;
  final textSnapshot = snapshot.texts.forType(snapshot.documentType);

  return <pw.Widget>[
    _companyHeader(snapshot.company, _documentLabel(snapshot.documentType, l10n), l10n),
    pw.SizedBox(height: 22),
    _documentHeading(snapshot, l10n, locale),
    pw.SizedBox(height: 16),
    _customerBlock(snapshot.customer, l10n),
    if (snapshot.documentDate != null) ...[
      pw.SizedBox(height: 12),
      pw.Text('${l10n.pdfDate}: ${_formatDate(snapshot.documentDate!, locale)}'),
    ],
    if (isMahnung && snapshot.mahnung != null) ...[
      pw.SizedBox(height: 6),
      pw.Text('${l10n.pdfOriginalInvoice}: ${snapshot.mahnung!.originalInvoiceNumber}'),
      pw.Text('${l10n.pdfInvoiceDate}: ${_formatDate(snapshot.mahnung!.originalInvoiceDate, locale)}'),
      pw.Text('${l10n.pdfDueSince}: ${_formatDate(snapshot.mahnung!.dueDate, locale)}'),
    ],
    if (snapshot.documentType == PdfDocumentType.angebot && snapshot.validUntil != null) ...[
      pw.SizedBox(height: 6),
      pw.Text('${l10n.pdfValidUntil}: ${_formatDate(snapshot.validUntil!, locale)}'),
    ],
    if (snapshot.documentType == PdfDocumentType.auftrag && _hasText(snapshot.orderStatus)) ...[
      pw.SizedBox(height: 6),
      pw.Text('${l10n.pdfOrderStatus}: ${snapshot.orderStatus}'),
    ],
    if (snapshot.template == PdfTemplate.gruen) ...[pw.SizedBox(height: 12), pw.Text(l10n.pdfNoVat)],
    if (_hasText(textSnapshot.einleitungstext)) ...[
      pw.SizedBox(height: 18),
      _markdownText(textSnapshot.einleitungstext!),
    ],
    pw.SizedBox(height: 18),
    _positionTable(snapshot, l10n, locale),
    if (!isDeliveryNote) ...[
      pw.SizedBox(height: 16),
      _totals(snapshot.totals, showTax: showTax, l10n: l10n, locale: locale),
    ],
    if (snapshot.paymentBlock != null) ...[pw.SizedBox(height: 18), _paymentBlock(snapshot.paymentBlock!, l10n)],
    if (_hasText(textSnapshot.schlusstext)) ...[pw.SizedBox(height: 18), _markdownText(textSnapshot.schlusstext!)],
  ];
}

pw.Widget _companyHeader(PdfCompanySnapshot company, String documentLabel, AppLocalizations l10n) {
  final details = <String>[
    if (_hasText(company.street)) company.street!,
    if (_hasText(_location(company.postalCode, company.city))) _location(company.postalCode, company.city)!,
    if (_hasText(company.country)) company.country!,
    if (_hasText(company.phone)) '${l10n.pdfPhone}: ${company.phone}',
    if (_hasText(company.email)) '${l10n.pdfEmail}: ${company.email}',
    if (_hasText(company.website)) company.website!,
    if (_hasText(company.taxNumber)) '${l10n.pdfTaxNumber}: ${company.taxNumber}',
    if (_hasText(company.vatId)) '${l10n.pdfVatId}: ${company.vatId}',
  ];
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: <pw.Widget>[
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(company.name, style: const pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          for (final detail in details) pw.Text(detail),
        ],
      ),
      pw.Text(documentLabel, style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
    ],
  );
}

pw.Widget _documentHeading(PdfDocumentSnapshot snapshot, AppLocalizations l10n, String locale) {
  final title = snapshot.documentType == PdfDocumentType.mahnung && snapshot.mahnung != null
      ? locale.startsWith('en')
            ? '${l10n.pdfReminder} ${snapshot.mahnung!.dunningLevel}'
            : '${snapshot.mahnung!.dunningLevel}. ${l10n.pdfReminder}'
      : _documentLabel(snapshot.documentType, l10n);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Text(title, style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.Text('${l10n.pdfInvoiceNumber}: ${snapshot.documentNumber}'),
    ],
  );
}

pw.Widget _customerBlock(PdfCustomerSnapshot customer, AppLocalizations l10n) {
  final address = <String>[
    customer.name,
    if (_hasText(customer.company)) customer.company!,
    if (_hasText(customer.zHd)) customer.zHd!,
    if (_hasText(customer.street)) customer.street!,
    if (_hasText(_location(customer.postalCode, customer.city))) _location(customer.postalCode, customer.city)!,
    if (_hasText(customer.country) && !_isGermany(customer.country!)) customer.country!,
  ];
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Text(l10n.pdfTo, style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      for (final line in address) pw.Text(line),
    ],
  );
}

pw.Widget _positionTable(PdfDocumentSnapshot snapshot, AppLocalizations l10n, String locale) {
  final isDeliveryNote = snapshot.documentType == PdfDocumentType.lieferschein;
  final showTax = snapshot.template == PdfTemplate.standard && !isDeliveryNote;
  final headers = isDeliveryNote
      ? <String>[l10n.pdfPosition, l10n.pdfDescription, l10n.pdfQuantity]
      : <String>[
          l10n.pdfPosition,
          l10n.pdfDescription,
          l10n.pdfQuantity,
          l10n.pdfUnitPrice,
          l10n.pdfDiscount,
          l10n.pdfNet,
          if (showTax) l10n.pdfVatRate,
          if (showTax) l10n.pdfTax,
          l10n.pdfGross,
        ];
  final alignments = <int, pw.Alignment>{
    0: pw.Alignment.center,
    2: pw.Alignment.centerRight,
    if (!isDeliveryNote) ...<int, pw.Alignment>{
      3: pw.Alignment.centerRight,
      4: pw.Alignment.centerRight,
      5: pw.Alignment.centerRight,
      if (showTax) 6: pw.Alignment.centerRight,
      if (showTax) 7: pw.Alignment.centerRight,
      (showTax ? 8 : 6): pw.Alignment.centerRight,
    },
  };
  final widths = isDeliveryNote
      ? const <int, pw.TableColumnWidth>{
          0: pw.FixedColumnWidth(25),
          1: pw.FlexColumnWidth(2.5),
          2: pw.FixedColumnWidth(50),
        }
      : showTax
      ? const <int, pw.TableColumnWidth>{
          0: pw.FixedColumnWidth(25),
          1: pw.FlexColumnWidth(2.5),
          2: pw.FixedColumnWidth(38),
          3: pw.FixedColumnWidth(58),
          4: pw.FixedColumnWidth(48),
          5: pw.FixedColumnWidth(58),
          6: pw.FixedColumnWidth(48),
          7: pw.FixedColumnWidth(58),
          8: pw.FixedColumnWidth(58),
        }
      : const <int, pw.TableColumnWidth>{
          0: pw.FixedColumnWidth(25),
          1: pw.FlexColumnWidth(2.5),
          2: pw.FixedColumnWidth(38),
          3: pw.FixedColumnWidth(58),
          4: pw.FixedColumnWidth(48),
          5: pw.FixedColumnWidth(58),
          6: pw.FixedColumnWidth(58),
        };

  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: snapshot.positions
        .map((position) => _positionRow(position, isDeliveryNote: isDeliveryNote, showTax: showTax, locale: locale))
        .toList(growable: false),
    border: pw.TableBorder.all(color: pdf.PdfColors.grey, width: 0.5),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
    headerStyle: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    cellStyle: const pw.TextStyle(fontSize: 8),
    headerAlignment: pw.Alignment.centerLeft,
    cellAlignment: pw.Alignment.centerLeft,
    headerAlignments: alignments,
    cellAlignments: alignments,
    columnWidths: widths,
  );
}

List<String> _positionRow(
  PdfPositionSnapshot position, {
  required bool isDeliveryNote,
  required bool showTax,
  required String locale,
}) {
  if (isDeliveryNote) {
    return <String>[
      position.position?.toString() ?? '',
      position.description,
      _formatDecimal(position.quantity, locale),
    ];
  }

  final row = <String>[
    position.position?.toString() ?? '',
    position.description,
    _formatDecimal(position.quantity, locale),
    _formatCurrency(position.unitPrice, locale),
    _formatDiscount(position, locale),
    _formatCurrency(position.netAmount, locale),
  ];
  if (showTax) {
    row
      ..add('${_formatDecimal(position.taxRate, locale)} %')
      ..add(_formatCurrency(position.taxAmount, locale));
  }
  row.add(_formatCurrency(position.grossAmount, locale));
  return row;
}

String _formatDiscount(PdfPositionSnapshot position, String locale) {
  if (position.discountPercent != null) {
    return '${_formatDecimal(position.discountPercent!, locale)} %';
  }
  if (position.discountAmount != null) {
    return _formatCurrency(position.discountAmount!, locale);
  }
  return '';
}

pw.Widget _totals(
  PdfTotalsSnapshot totals, {
  required bool showTax,
  required AppLocalizations l10n,
  required String locale,
}) {
  final rows = <List<String>>[
    if (totals.subtotal != null) <String>[l10n.pdfSubtotal, _formatCurrency(totals.subtotal!, locale)],
    if (totals.discountAmount != null)
      <String>[l10n.pdfDiscountAmount, _formatCurrency(totals.discountAmount!, locale)],
    <String>[l10n.pdfNet, _formatCurrency(totals.netAmount, locale)],
    if (showTax) <String>[l10n.pdfTax, _formatCurrency(totals.taxAmount, locale)],
    <String>[l10n.pdfGrossTotal, _formatCurrency(totals.grossAmount, locale)],
  ];
  return pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.SizedBox(
      width: 230,
      child: pw.Column(
        children: <pw.Widget>[
          for (final row in rows)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: <pw.Widget>[pw.Text(row[0]), pw.Text(row[1])],
            ),
        ],
      ),
    ),
  );
}

pw.Widget _paymentBlock(PdfPaymentBlockSnapshot payment, AppLocalizations l10n) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Text(l10n.pdfPaymentDetails, style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Text('${l10n.pdfIban}: ${payment.iban}'),
      if (_hasText(payment.bic)) pw.Text('${l10n.pdfBic}: ${payment.bic}'),
      if (_hasText(payment.bankName)) pw.Text('${l10n.pdfBank}: ${payment.bankName}'),
      if (_hasText(payment.paymentTerms)) ...[pw.SizedBox(height: 6), _markdownText(payment.paymentTerms!)],
    ],
  );
}

// Built-in WinAnsi fonts encode the Euro sign as byte 0x80, avoiding a font file dependency.
const _winAnsiEuro = '\u0080';

String _formatCurrency(num value, String locale) => '${_formatDecimal(value, locale)} $_winAnsiEuro';

String _formatDecimal(num value, String locale) {
  if (!value.isFinite) {
    throw ArgumentError.value(value, 'value', 'Muss endlich sein.');
  }
  final fixed = value.toStringAsFixed(2);
  final separator = fixed.indexOf('.');
  final integerPart = separator == -1 ? fixed : fixed.substring(0, separator);
  final fraction = separator == -1 ? '00' : fixed.substring(separator + 1).padRight(2, '0');
  final isNegative = integerPart.startsWith('-');
  final digits = isNegative ? integerPart.substring(1) : integerPart;
  final bool english = locale.startsWith('en');
  final grouped = _groupDigits(digits, english ? ',' : '.');
  return '${isNegative ? '-' : ''}$grouped${english ? '.' : ','}$fraction';
}

String _groupDigits(String digits, String separator) {
  final result = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      result.write(separator);
    }
    result.write(digits[index]);
  }
  return result.toString();
}

String _formatDate(DateTime date, String locale) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  if (locale.startsWith('en')) {
    return '$month/$day/${date.year.toString().padLeft(4, '0')}';
  }
  return '$day.$month.${date.year.toString().padLeft(4, '0')}';
}

String _documentLabel(PdfDocumentType type, AppLocalizations l10n) {
  return switch (type) {
    PdfDocumentType.gutschrift => l10n.pdfCreditNote,
    PdfDocumentType.rechnung => l10n.pdfInvoice,
    PdfDocumentType.storno => l10n.pdfStorno,
    PdfDocumentType.angebot => l10n.pdfQuote,
    PdfDocumentType.auftrag => l10n.pdfOrder,
    PdfDocumentType.proforma => l10n.pdfProforma,
    PdfDocumentType.lieferschein => l10n.pdfDelivery,
    PdfDocumentType.mahnung => l10n.pdfReminder,
  };
}

String? _location(String? postalCode, String? city) {
  final parts = <String>[if (_hasText(postalCode)) postalCode!, if (_hasText(city)) city!];
  return parts.isEmpty ? null : parts.join(' ');
}

pw.Widget _markdownText(String value) {
  final tokens = <({int start, int length})>[];
  for (var index = 0; index < value.length;) {
    if (value[index] != '*') {
      index++;
      continue;
    }
    var end = index + 1;
    while (end < value.length && value[end] == '*') {
      end++;
    }
    final length = end - index;
    if ((length == 1 || length == 2) && !_isEscaped(value, index)) {
      tokens.add((start: index, length: length));
    }
    index = end;
  }

  final stack = <({int index, int length})>[];
  final pairs = <({int opening, int closing})>[];
  for (var index = 0; index < tokens.length; index++) {
    final token = tokens[index];
    if (stack.isNotEmpty && stack.last.length == token.length) {
      final opening = stack.removeLast();
      pairs.add((opening: opening.index, closing: index));
    } else {
      stack.add((index: index, length: token.length));
    }
  }

  final validPairs = pairs.where((pair) {
    final opening = tokens[pair.opening];
    final closing = tokens[pair.closing];
    if (closing.start <= opening.start + opening.length) {
      return false;
    }
    final isNested = pairs.any((other) {
      if (other == pair) {
        return false;
      }
      final otherOpening = tokens[other.opening];
      final otherClosing = tokens[other.closing];
      return otherOpening.start < opening.start && closing.start < otherClosing.start ||
          opening.start < otherOpening.start && otherClosing.start < closing.start;
    });
    return !isNested && !stack.any((unmatched) => unmatched.index < pair.opening);
  }).toList()..sort((left, right) => tokens[left.opening].start.compareTo(tokens[right.opening].start));

  final spans = <pw.TextSpan>[];
  var cursor = 0;
  for (final pair in validPairs) {
    final opening = tokens[pair.opening];
    final closing = tokens[pair.closing];
    if (opening.start > cursor) {
      spans.add(pw.TextSpan(text: value.substring(cursor, opening.start)));
    }
    spans.add(
      pw.TextSpan(
        text: value.substring(opening.start + opening.length, closing.start),
        style: opening.length == 2
            ? const pw.TextStyle(fontWeight: pw.FontWeight.bold)
            : const pw.TextStyle(fontStyle: pw.FontStyle.italic),
      ),
    );
    cursor = closing.start + closing.length;
  }
  if (cursor < value.length) {
    spans.add(pw.TextSpan(text: value.substring(cursor)));
  }
  return pw.RichText(text: pw.TextSpan(children: spans));
}

bool _isEscaped(String value, int markerIndex) {
  var backslashCount = 0;
  for (var index = markerIndex - 1; index >= 0 && value[index] == r'\'; index--) {
    backslashCount++;
  }
  return backslashCount.isOdd;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

bool _isGermany(String value) {
  final normalized = value.trim().toUpperCase();
  return normalized == 'DE' || normalized == 'DEUTSCHLAND';
}
