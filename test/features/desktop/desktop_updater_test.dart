import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/desktop_updater.dart';

void main() {
  group('DesktopUpdaterService — fail-closed', () {
    test('updater reports unavailable when disabled (default)', () {
      final DesktopUpdaterService updater = createDesktopUpdaterService();
      expect(updater.isEnabled, isFalse);
    });

    test('checkForUpdate returns null when disabled', () async {
      final DesktopUpdaterService updater = createDesktopUpdaterService();
      final UpdateInfo? result = await updater.checkForUpdate();
      expect(result, isNull);
    });

    test('updater reports available when explicitly enabled', () {
      final DesktopUpdaterService updater = createDesktopUpdaterService(enabled: true);
      expect(updater.isEnabled, isTrue);
    });

    test('verifySignature always returns false (no trust root)', () async {
      final DesktopUpdaterService updater = createDesktopUpdaterService(enabled: true);
      final bool result = await updater.verifySignature(
        const UpdateInfo(version: '1.0.0', url: 'https://example.com/update', signature: 'test'),
      );
      expect(result, isFalse);
    });

    test('installAndRestart throws when no verified artifact', () async {
      final DesktopUpdaterService updater = createDesktopUpdaterService(enabled: true);
      expect(updater.installAndRestart, throwsStateError);
    });

    test('dismiss schedules next check 4 hours ahead', () async {
      final DateTime now = DateTime(2026, 1, 1, 12);
      final DesktopUpdaterService updater = createDesktopUpdaterService(enabled: true, clock: () => now);
      await updater.dismiss();
      expect(updater.nextCheck, now.add(const Duration(hours: 4)));
    });
  });

  group('isNewerVersion', () {
    test('detects newer version', () {
      expect(isNewerVersion('1.0.0', '1.0.1'), isTrue);
      expect(isNewerVersion('1.0.0', '2.0.0'), isTrue);
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.1', '1.0.0'), isFalse);
    });

    test('handles v prefix', () {
      expect(isNewerVersion('v1.0.0', 'v1.0.1'), isTrue);
      expect(isNewerVersion('1.0.0', 'v2.0.0'), isTrue);
    });

    test('handles malformed input', () {
      expect(isNewerVersion('abc', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.0', ''), isFalse);
    });
  });
}
