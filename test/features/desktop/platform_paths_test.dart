import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/platform_service.dart';

void main() {
  group('PlatformService — profile paths', () {
    final PlatformService service = PlatformService();

    test('macOS profile path', () {
      final String path = service.profilePath(PlatformType.macos, '/Users/testuser');
      expect(path, '/Users/testuser/Library/Application Support/OpenAccounting');
    });

    test('Linux profile path', () {
      final String path = service.profilePath(PlatformType.linux, '/home/testuser');
      expect(path, '/home/testuser/.config/openaccounting');
    });

    test('Windows profile path', () {
      final String path = service.profilePath(PlatformType.windows, 'C:/Users/testuser');
      expect(path, 'C:/Users/testuser/AppData/Roaming/OpenAccounting');
    });

    test('shouldHideConsole only on Windows release', () {
      expect(service.shouldHideConsole(PlatformType.windows, releaseMode: true), isTrue);
      expect(service.shouldHideConsole(PlatformType.windows, releaseMode: false), isFalse);
      expect(service.shouldHideConsole(PlatformType.macos, releaseMode: true), isFalse);
      expect(service.shouldHideConsole(PlatformType.linux, releaseMode: true), isFalse);
    });
  });
}
