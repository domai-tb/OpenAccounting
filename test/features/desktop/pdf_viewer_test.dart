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
    await s.open('/tmp/a.pdf');
    expect(s.isOpen, isTrue);
    await s.close();
    expect(s.isOpen, isFalse);
    await s.printPdf();
    await s.saveAs('/tmp/b.pdf');
  });
}
