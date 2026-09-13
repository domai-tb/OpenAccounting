import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/desktop/desktop_capability.dart';

void main() {
  group('DesktopCapabilityRegistry', () {
    test('register and retrieve supported capability', () {
      final DesktopCapabilityRegistry registry = DesktopCapabilityRegistry();
      final DesktopCapability<String> cap = SupportedDesktopCapability<String>('test');
      registry.register<String>(cap);
      expect(registry.isAvailable<String>(), isTrue);
    });

    test('unsupported capability reports unavailable with reason', () {
      final DesktopCapabilityRegistry registry = DesktopCapabilityRegistry();
      registry.register<String>(const UnavailableDesktopCapability<String>('not supported on this target'));
      expect(registry.isAvailable<String>(), isFalse);
      final UnavailableDesktopCapability<String> cap = registry.get<String>() as UnavailableDesktopCapability<String>;
      expect(cap.reason, 'not supported on this target');
    });

    test('empty registry reports capability as unavailable', () {
      final DesktopCapabilityRegistry registry = DesktopCapabilityRegistry();
      expect(registry.isAvailable<String>(), isFalse);
    });

    test('register is idempotent', () {
      final DesktopCapabilityRegistry registry = DesktopCapabilityRegistry();
      final DesktopCapability<String> cap = SupportedDesktopCapability<String>('first');
      registry.register<String>(cap);
      registry.register<String>(SupportedDesktopCapability<String>('second'));
      final DesktopCapability<String> retrieved = registry.get<String>();
      expect((retrieved as SupportedDesktopCapability<String>).value, 'first');
    });
  });

  group('DropCapability callback', () {
    test('drop callback fires with file path', () {
      String? receivedPath;
      final DropCapability cap = DropCapability(
        onFileDropped: (String path) {
          receivedPath = path;
        },
      );
      cap.onFileDropped('/tmp/document.pdf');
      expect(receivedPath, '/tmp/document.pdf');
    });
  });
}
