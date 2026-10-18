// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/src/pdf/format/base.dart' show PdfDataType;
import 'package:pdf/src/pdf/format/dict.dart' show PdfDict;
import 'package:pdf/src/pdf/format/dict_stream.dart' show PdfDictStream;
import 'package:pdf/src/pdf/format/name.dart' show PdfName;
import 'package:pdf/src/pdf/format/num.dart' show PdfNum;
import 'package:pdf/src/pdf/format/string.dart' show PdfString;
import 'package:pdf/src/pdf/obj/object.dart' show PdfObject;
import 'package:pdf/src/pdf/format/object_base.dart' show PdfObjectBase;
import 'package:pdf/src/pdf/obj/pdfa/pdfa_date_format.dart' show PdfaDateFormat;

/// Adds a PDF/A attachment whose declared size matches its UTF-8 stream bytes.
///
/// `pdf` 3.13.0's [pdf.PdfaAttachedFiles] helper writes UTF-8 bytes but declares
/// `/Params/Size` using UTF-16 code-unit length. Keep its file specification
/// and catalog wiring, then replace only the generated embedded-file stream
/// object with one that records the actual encoded byte length.
void addUtf8PdfaAttachment({
  required pdf.PdfDocument document,
  required String name,
  required String content,
  String subType = '/text/xml',
  String relationship = '/Alternative',
}) {
  final Set<PdfObjectBase<PdfDataType>> existingObjects = document.objects.cast<PdfObjectBase<PdfDataType>>().toSet();
  pdf.PdfaAttachedFiles(document, <pdf.PdfaAttachedFile>[
    pdf.PdfaAttachedFile(name: name, data: content, subType: subType, afRelationship: relationship),
  ]);

  final List<PdfObjectBase<PdfDataType>> newStreams = document.objects
      .cast<PdfObjectBase<PdfDataType>>()
      .where((PdfObjectBase<PdfDataType> object) => !existingObjects.contains(object) && object.params is PdfDictStream)
      .toList();
  if (newStreams.length != 1 || newStreams.single is! PdfObject<PdfDictStream>) {
    throw StateError('Expected one new PDF/A embedded-file stream');
  }

  final PdfObject<PdfDictStream> original = newStreams.single as PdfObject<PdfDictStream>;
  document.objects.remove(original);
  _Utf8PdfaAttachedFile(document, content: content, subType: subType, objser: original.objser, objgen: original.objgen);
}

class _Utf8PdfaAttachedFile extends PdfObject<PdfDictStream> {
  _Utf8PdfaAttachedFile(
    super.document, {
    required this.content,
    required this.subType,
    required super.objser,
    required super.objgen,
  }) : super(params: PdfDictStream(compress: false, encrypt: false));

  final String content;
  final String subType;

  @override
  void prepare() {
    super.prepare();
    final String modDate = PdfaDateFormat().format(dt: DateTime.now());
    params['/Type'] = const PdfName('/EmbeddedFile');
    params['/Subtype'] = PdfName(subType);
    params['/Params'] = PdfDict<PdfDataType>(<String, PdfDataType>{
      '/Size': PdfNum(utf8.encode(content).length),
      '/ModDate': PdfString(Uint8List.fromList("D:$modDate+00'00'".codeUnits)),
    });
    params.data = Uint8List.fromList(utf8.encode(content));
  }
}
