import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/pdf_viewer_service.dart';

void main() {
  test('pdf viewer window zoom/print/save isolated lifecycle', () async {
    final FakeWindowManagerBackend backend = FakeWindowManagerBackend();
    final PdfViewerService s = PdfViewerService(backend);
    expect(s.zoom, 100);
    expect(s.isOpen, isFalse);
    s.setZoom(150);
    expect(s.zoom, 150);
    expect(() => s.setZoom(10), throwsArgumentError);
    expect(() => s.setZoom(300), throwsArgumentError);
    final tmp = await Directory.systemTemp.createTemp('viewer-test-');
    final a = File('${tmp.path}/a.pdf')..writeAsBytesSync([0x25, 0x50, 0x44, 0x46]);
    await s.open(a.path);
    expect(s.isOpen, isTrue);
    await s.close();
    expect(s.isOpen, isFalse);
    await expectLater(s.printPdf(), throwsA(isA<StateError>()));
    await expectLater(s.saveAs('${tmp.path}/b.pdf'), throwsA(isA<StateError>()));
    await s.open(a.path);
    final bPath = '${tmp.path}/b.pdf';
    await s.saveAs(bPath);
    expect(File(bPath).existsSync(), isTrue);
    await expectLater(s.printPdf(), throwsA(isA<UnsupportedError>()));
    await s.close();
    await tmp.delete(recursive: true);
  });
}
