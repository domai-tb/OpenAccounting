// ignore_for_file: dangling_library_doc_comments
/// PlatformWorkarounds — profile paths, console hide, GPU config.
enum PlatformType { windows, macos, linux }

class PlatformService {
  String profilePath(PlatformType p, String home) {
    switch (p) {
      case PlatformType.windows:
        return '$home/AppData/Roaming/OpenAccounting';
      case PlatformType.macos:
        return '$home/Library/Application Support/OpenAccounting';
      case PlatformType.linux:
        return '$home/.config/openaccounting';
    }
  }

  bool shouldHideConsole(PlatformType p, {required bool releaseMode}) => p == PlatformType.windows && releaseMode;

  String gpuConfig({required bool isWayland}) => isWayland ? 'disable-gpu' : 'enable-gpu';
}
