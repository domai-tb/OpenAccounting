import 'dart:convert';
import 'dart:typed_data';

import 'package:openaccounting/features/pdf/pdf_models.dart';

PdfDocumentSnapshot rechnungSnapshot() {
  return PdfDocumentSnapshot.from(
    documentType: PdfDocumentType.rechnung,
    template: PdfTemplate.standard,
    documentNumber: 'RE-2026-001',
    company: const PdfCompanySnapshot(
      name: 'Muster Studio',
      street: 'Musterstraße 1',
      postalCode: '10115',
      city: 'Berlin',
      phone: '+49 30 123456',
      email: 'rechnung@muster.example',
    ),
    customer: const PdfCustomerSnapshot(
      name: 'Beispiel GmbH',
      street: 'Kundenweg 2',
      postalCode: '20095',
      city: 'Hamburg',
    ),
    positions: const <PdfPositionSnapshot>[
      PdfPositionSnapshot(
        description: 'Website-Design',
        quantity: 2,
        unitPrice: 500,
        netAmount: 1000,
        taxRate: 19,
        taxAmount: 190,
        grossAmount: 1190,
      ),
    ],
    totals: const PdfTotalsSnapshot(netAmount: 1000, taxAmount: 190, grossAmount: 1190),
  );
}

final class ParsedPdf {
  const ParsedPdf({required this.visibleText, required this.pageOperators});

  final String visibleText;
  final List<String> pageOperators;

  List<String> get operators => pageOperators;

  bool containsOperator(String operator) => pageOperators.contains(operator);
}

ParsedPdf parseUncompressedPdf(Uint8List pdfBytes) {
  final source = _decodePdfBytes(pdfBytes);
  final streams = _uncompressedStreams(source);
  if (streams.isEmpty) {
    throw const FormatException('PDF contains no uncompressed content stream');
  }

  final visibleText = StringBuffer();
  final pageOperators = <String>[];
  for (final stream in streams) {
    final tokens = _tokenize(stream);
    _appendVisibleText(tokens, visibleText);
    pageOperators.addAll(
      tokens
          .where((token) => token.kind == _PdfTokenKind.word && _pageOperators.contains(token.value))
          .map((token) => token.value),
    );
  }

  return ParsedPdf(visibleText: visibleText.toString(), pageOperators: List<String>.unmodifiable(pageOperators));
}

ParsedPdf parsePdf(Uint8List pdfBytes) => parseUncompressedPdf(pdfBytes);

String _decodePdfBytes(Uint8List bytes) => String.fromCharCodes(bytes.map((byte) => byte == 0x80 ? 0x20AC : byte));

Uint8List uncompressedPdf(List<int> streamBytes) {
  final prefix = latin1.encode('%PDF-1.4\n1 0 obj\n<< /Length ${streamBytes.length} >>\nstream\n');
  final suffix = latin1.encode('\nendstream\nendobj\n%%EOF\n');
  return Uint8List.fromList(<int>[...prefix, ...streamBytes, ...suffix]);
}

Iterable<String> _uncompressedStreams(String source) sync* {
  final streamPattern = RegExp(r'(<<.*?>>)\s*stream(?:\r\n|\n|\r)(.*?)\r?\nendstream', dotAll: true);
  for (final match in streamPattern.allMatches(source)) {
    final dictionary = match.group(1)!;
    if (!RegExp(r'/Filter\b').hasMatch(dictionary)) {
      yield match.group(2)!;
    }
  }
}

void _appendVisibleText(List<_PdfToken> tokens, StringBuffer output) {
  for (var index = 0; index < tokens.length; index++) {
    final token = tokens[index];
    if (token.kind != _PdfTokenKind.word || !_textOperators.contains(token.value)) {
      continue;
    }

    final text = _textOperandBefore(tokens, index);
    if (text == null || text.isEmpty) {
      continue;
    }
    if (output.isNotEmpty) {
      output.write(' ');
    }
    output.write(text);
  }
}

String? _textOperandBefore(List<_PdfToken> tokens, int operatorIndex) {
  if (operatorIndex == 0) {
    return null;
  }

  final previous = tokens[operatorIndex - 1];
  if (previous.kind == _PdfTokenKind.string) {
    return previous.value;
  }
  if (previous.kind != _PdfTokenKind.arrayEnd) {
    return null;
  }

  var depth = 0;
  final strings = <String>[];
  for (var index = operatorIndex - 1; index >= 0; index--) {
    final token = tokens[index];
    if (token.kind == _PdfTokenKind.arrayEnd) {
      depth++;
    } else if (token.kind == _PdfTokenKind.arrayStart) {
      depth--;
      if (depth == 0) {
        return strings.reversed.join();
      }
    } else if (depth > 0 && token.kind == _PdfTokenKind.string) {
      strings.add(token.value);
    }
  }
  return null;
}

List<_PdfToken> _tokenize(String source) {
  final tokens = <_PdfToken>[];
  var index = 0;
  while (index < source.length) {
    final character = source[index];
    if (_isWhitespace(character)) {
      index++;
      continue;
    }
    if (character == '%') {
      index = _skipComment(source, index);
      continue;
    }
    if (character == '/') {
      final name = _readName(source, index);
      tokens.add(_PdfToken.name(name.value));
      index = name.nextIndex;
      continue;
    }
    if (character == '(') {
      final literal = _readLiteralString(source, index);
      tokens.add(_PdfToken.string(literal.value));
      index = literal.nextIndex;
      continue;
    }
    if (character == '<' && index + 1 < source.length && source[index + 1] != '<') {
      final hexadecimal = _readHexString(source, index);
      tokens.add(_PdfToken.string(hexadecimal.value));
      index = hexadecimal.nextIndex;
      continue;
    }
    if (character == '[') {
      tokens.add(const _PdfToken.arrayStart());
      index++;
      continue;
    }
    if (character == ']') {
      tokens.add(const _PdfToken.arrayEnd());
      index++;
      continue;
    }
    if (character == '<' && index + 1 < source.length && source[index + 1] == '<') {
      index = _skipDictionary(source, index);
      continue;
    }

    final word = _readWord(source, index);
    if (word.value.isNotEmpty) {
      tokens.add(_PdfToken.word(word.value));
    }
    index = word.nextIndex;
  }
  return tokens;
}

({String value, int nextIndex}) _readLiteralString(String source, int startIndex) {
  final bytes = <int>[];
  var depth = 1;
  var index = startIndex + 1;
  while (index < source.length && depth > 0) {
    final character = source[index];
    if (character == r'\') {
      final escape = _readEscape(source, index);
      bytes.add(escape.value);
      index = escape.nextIndex;
      continue;
    }
    if (character == '(') {
      depth++;
      bytes.add(character.codeUnitAt(0));
    } else if (character == ')') {
      depth--;
      if (depth > 0) {
        bytes.add(character.codeUnitAt(0));
      }
    } else {
      bytes.add(character.codeUnitAt(0));
    }
    index++;
  }
  return (value: String.fromCharCodes(bytes), nextIndex: index);
}

({int value, int nextIndex}) _readEscape(String source, int slashIndex) {
  final nextIndex = slashIndex + 1;
  if (nextIndex >= source.length) {
    return (value: r'\'.codeUnitAt(0), nextIndex: nextIndex);
  }
  final escaped = source[nextIndex];
  const escapedCharacters = <String, int>{'n': 10, 'r': 13, 't': 9, 'b': 8, 'f': 12};
  final escapedValue = escapedCharacters[escaped];
  if (escapedValue != null) {
    return (value: escapedValue, nextIndex: nextIndex + 1);
  }
  if (escaped == '\r' || escaped == '\n') {
    var continuationIndex = nextIndex + 1;
    if (escaped == '\r' && continuationIndex < source.length && source[continuationIndex] == '\n') {
      continuationIndex++;
    }
    return (value: 0, nextIndex: continuationIndex);
  }
  if (escaped.codeUnitAt(0) >= 48 && escaped.codeUnitAt(0) <= 55) {
    var value = 0;
    var index = nextIndex;
    var digits = 0;
    while (index < source.length && digits < 3) {
      final digit = source[index].codeUnitAt(0);
      if (digit < 48 || digit > 55) {
        break;
      }
      value = value * 8 + digit - 48;
      index++;
      digits++;
    }
    return (value: value, nextIndex: index);
  }
  return (value: escaped.codeUnitAt(0), nextIndex: nextIndex + 1);
}

({String value, int nextIndex}) _readHexString(String source, int startIndex) {
  final bytes = <int>[];
  var index = startIndex + 1;
  var highNibble = -1;
  while (index < source.length && source[index] != '>') {
    final character = source[index];
    index++;
    if (_isWhitespace(character)) {
      continue;
    }
    final nibble = int.tryParse(character, radix: 16);
    if (nibble == null) {
      continue;
    }
    if (highNibble == -1) {
      highNibble = nibble;
    } else {
      bytes.add(highNibble * 16 + nibble);
      highNibble = -1;
    }
  }
  if (highNibble != -1) {
    bytes.add(highNibble * 16);
  }
  return (value: String.fromCharCodes(bytes), nextIndex: index + 1);
}

({String value, int nextIndex}) _readWord(String source, int startIndex) {
  if (_isDelimiter(source[startIndex])) {
    return (value: source[startIndex], nextIndex: startIndex + 1);
  }
  var index = startIndex;
  while (index < source.length && !_isDelimiter(source[index])) {
    index++;
  }
  return (value: source.substring(startIndex, index), nextIndex: index);
}

({String value, int nextIndex}) _readName(String source, int startIndex) {
  var index = startIndex + 1;
  while (index < source.length && !_isDelimiter(source[index])) {
    index++;
  }
  return (value: source.substring(startIndex, index), nextIndex: index);
}

int _skipComment(String source, int startIndex) {
  var index = startIndex;
  while (index < source.length && source[index] != '\r' && source[index] != '\n') {
    index++;
  }
  return index;
}

int _skipDictionary(String source, int startIndex) {
  var depth = 0;
  var index = startIndex;
  while (index + 1 < source.length) {
    if (source[index] == '<' && source[index + 1] == '<') {
      depth++;
      index += 2;
    } else if (source[index] == '>' && source[index + 1] == '>') {
      depth--;
      index += 2;
      if (depth == 0) {
        return index;
      }
    } else {
      index++;
    }
  }
  return source.length;
}

bool _isWhitespace(String character) => character.codeUnitAt(0) <= 32;

bool _isDelimiter(String character) => _isWhitespace(character) || '[]()<>/%'.contains(character);

enum _PdfTokenKind { word, name, string, arrayStart, arrayEnd }

final class _PdfToken {
  const _PdfToken.arrayEnd() : kind = _PdfTokenKind.arrayEnd, value = '';

  const _PdfToken.arrayStart() : kind = _PdfTokenKind.arrayStart, value = '';

  const _PdfToken.string(this.value) : kind = _PdfTokenKind.string;

  const _PdfToken.name(this.value) : kind = _PdfTokenKind.name;

  const _PdfToken.word(this.value) : kind = _PdfTokenKind.word;

  final _PdfTokenKind kind;
  final String value;
}

const _textOperators = <String>{'Tj', 'TJ', "'", '"'};

const _pageOperators = <String>{
  'BT',
  'ET',
  'Tj',
  'TJ',
  "'",
  '"',
  'Td',
  'TD',
  'Tm',
  'T*',
  'Tc',
  'Tw',
  'Tz',
  'TL',
  'Tf',
  'Tr',
  'Ts',
  'q',
  'Q',
  'cm',
  'Do',
  're',
  'm',
  'l',
  'c',
  'v',
  'y',
  'h',
  'S',
  's',
  'f',
  'F',
  'f*',
  'B',
  'B*',
  'b',
  'b*',
  'n',
  'W',
  'W*',
  'G',
  'g',
  'RG',
  'rg',
  'K',
  'k',
  'CS',
  'cs',
  'SC',
  'sc',
  'SCN',
  'scn',
  'sh',
  'gs',
  'w',
  'd',
  'ri',
  'i',
  'j',
  'J',
  'M',
  'BI',
  'ID',
  'EI',
};
