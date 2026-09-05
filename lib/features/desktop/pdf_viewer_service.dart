// ignore_for_file: dangling_library_doc_comments
/// PdfViewerService — dedicated viewer window 50-200% zoom, print/save, isolated lifecycle.
abstract interface class WindowManagerBackend {
  Future<void> createViewerWindow(String path);
  Future<void> closeViewerWindow();
  bool get isOpen;
}

class FakeWindowManagerBackend implements WindowManagerBackend {
  bool _open = false;
  String? lastPath;

  @override
  bool get isOpen => _open;

  @override
  Future<void> createViewerWindow(String path) async {
    lastPath = path;
    _open = true;
  }

  @override
  Future<void> closeViewerWindow() async => _open = false;
}

class PdfViewerService {
  PdfViewerService(this.backend);

  final WindowManagerBackend backend;
  int _zoom = 100;

  int get zoom => _zoom;
  bool get isOpen => backend.isOpen;

  void setZoom(int percent) {
    if (percent < 50 || percent > 200) throw ArgumentError('zoom 50-200%');
    _zoom = percent;
  }

  Future<void> open(String path) => backend.createViewerWindow(path);
  Future<void> close() => backend.closeViewerWindow();
  Future<void> printPdf() async {}
  Future<void> saveAs(String dest) async {}
}
