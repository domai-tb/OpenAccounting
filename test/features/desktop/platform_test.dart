import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/platform_service.dart';

void main() {
  test('platform profile paths, console hide, GPU config', () {
    final PlatformService s = PlatformService();
    expect(s.profilePath(PlatformType.windows, '/home/u'), contains('AppData'));
    expect(s.profilePath(PlatformType.macos, '/home/u'), contains('Application Support'));
    expect(s.profilePath(PlatformType.linux, '/home/u'), contains('.config'));
    expect(s.shouldHideConsole(PlatformType.windows, releaseMode: true), isTrue);
    expect(s.shouldHideConsole(PlatformType.linux, releaseMode: true), isFalse);
    expect(s.gpuConfig(isWayland: true), 'disable-gpu');
    expect(s.gpuConfig(isWayland: false), 'enable-gpu');
  });
}
