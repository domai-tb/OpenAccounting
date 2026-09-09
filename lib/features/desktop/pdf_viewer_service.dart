import 'dart:io';

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
  String? _lastPath;

  int get zoom => _zoom;
  bool get isOpen => backend.isOpen;

  void setZoom(int percent) {
    if (percent < 50 || percent > 200) throw ArgumentError('zoom 50-200%');
    _zoom = percent;
  }

  Future<void> open(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('PDF artifact not found at $path — retry finalization or check profile storage');
    }
    _lastPath = path;
    await backend.createViewerWindow(path);
  }

  Future<void> close() async {
    _lastPath = null;
    await backend.closeViewerWindow();
  }

  Future<void> printPdf() async {
    final path = _lastPath;
    if (path == null || !backend.isOpen) {
      throw StateError('No document open — open a finalized PDF first');
    }
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('Artifact missing at $path — recreate or save again');
    }
    // ponytail: platform print not implemented in VM; report actionable instead of silent success
    throw UnsupportedError('Print not supported in this environment — use Save as to export PDF');
  }

  Future<void> saveAs(String dest) async {
    final source = _lastPath;
    if (source == null || !backend.isOpen) {
      throw StateError('No document open — open a finalized PDF first');
    }
    final src = File(source);
    if (!src.existsSync()) {
      throw StateError('Source artifact missing at $source — finalization failed, retry');
    }
    final dst = File(dest);
    dst.parent.createSync(recursive: true);
    src.copySync(dst.path);
  }
}
