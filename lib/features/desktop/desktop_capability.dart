/// Sealed type for desktop capability availability.
sealed class DesktopCapability<T> {
  const DesktopCapability();
}

class SupportedDesktopCapability<T> extends DesktopCapability<T> {
  SupportedDesktopCapability(this.value);
  final T value;
}

class UnavailableDesktopCapability<T> extends DesktopCapability<T> {
  const UnavailableDesktopCapability(this.reason);
  final String reason;
}

/// Registry of desktop capabilities, constructed during bootstrap.
/// Registration is idempotent — registering the same type twice is a no-op.
class DesktopCapabilityRegistry {
  final Map<Type, DesktopCapability<dynamic>> _capabilities = <Type, DesktopCapability<dynamic>>{};

  void register<T>(DesktopCapability<T> capability) {
    if (_capabilities.containsKey(T)) return; // idempotent
    _capabilities[T] = capability;
  }

  bool isAvailable<T>() => _capabilities[T] is SupportedDesktopCapability<T>;

  DesktopCapability<T> get<T>() => _capabilities[T]! as DesktopCapability<T>;
}

/// Drop capability with an onEvent callback injected at bootstrap.
/// Profile-aware routing is the callback's responsibility.
class DropCapability extends DesktopCapability<void> {
  DropCapability({required this.onFileDropped});
  final void Function(String path) onFileDropped;
}
