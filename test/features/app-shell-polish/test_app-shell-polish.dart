// ignore_for_file: file_names
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/app_shell_polish/app_shell_polish.dart';

void main() {
  group('app-shell-polish', () {
    test('test_happy', () {
      final AppShellPolishService s = AppShellPolishService();
      expect(s.trigger('100'), '100.00');
      expect(s.polish('100'), '100.00');
      expect(s.validate('100'), isNull);
    });
    test('test_failure', () {
      final AppShellPolishService s = AppShellPolishService();
      expect(s.validate(''), isNotNull);
      expect(s.validate('')!, contains('ungültig'));
      expect(s.validate(null), isNotNull);
      expect(s.polish(''), isNot('0.00'));
      expect(s.polish(''), contains('ungültig'));
    });
  });
}
