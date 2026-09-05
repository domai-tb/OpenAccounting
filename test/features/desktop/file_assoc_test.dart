import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/file_assoc_service.dart';

void main() {
  test('file assoc register and route pdf/csv, unsupported no-op', () async {
    final FakeFileAssocBackend backend = FakeFileAssocBackend();
    final DesktopFileAssocService s = DesktopFileAssocService(backend);
    expect(await s.registerPdfHandler(), isTrue);
    expect(await s.registerCsvHandler(), isTrue);
    expect(s.route('/tmp/invoice.pdf'), 'viewer');
    expect(s.route('/tmp/data.csv'), 'import');
    expect(s.route('/tmp/notes.txt'), isNull);
    expect(s.route('/tmp/image.exe'), isNull);
  });
}
