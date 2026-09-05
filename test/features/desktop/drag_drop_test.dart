import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/drop_service.dart';

void main() {
  test('drag drop pdf/csv/image to zones, reject unsupported', () {
    final DropService s = DropService();
    expect(s.isAllowed('/tmp/a.pdf'), isTrue);
    expect(s.isAllowed('/tmp/b.csv'), isTrue);
    expect(s.isAllowed('/tmp/c.jpg'), isTrue);
    expect(s.isAllowed('/tmp/d.png'), isTrue);
    expect(s.isAllowed('/tmp/e.tiff'), isTrue);
    expect(s.isAllowed('/tmp/f.txt'), isFalse);
    expect(s.validate('/tmp/a.pdf'), isNull);
    expect(s.validate('/tmp/f.txt'), isNotNull);
    expect(s.storePath('/tmp/a.pdf'), contains('APP_DATA_DIR'));
  });
}
