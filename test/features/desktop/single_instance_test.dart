import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/single_instance_service.dart';

void main() {
  test('single instance lock, second foreground, deep-link forwarding', () {
    final SingleInstanceService s = SingleInstanceService();
    expect(s.tryLock(), isTrue);
    expect(s.isLocked, isTrue);
    expect(s.tryLock(), isFalse);
    s.onSecondInstance('openaccounting://invoice/123');
    expect(s.forwarded, contains('openaccounting://invoice/123'));
    expect(s.shouldExitSecondInstance(), isTrue);
    s.unlock();
    expect(s.isLocked, isFalse);
  });
}
