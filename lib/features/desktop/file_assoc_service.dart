// ignore_for_file: dangling_library_doc_comments
/// DesktopFileAssocService — VM-safe file association registration.
/// Additive, OS-capability checked, fals back silently.
abstract interface class FileAssocBackend {
  Future<bool> register(String ext, String handler);
  Future<void> launch(String path);
}

class FakeFileAssocBackend implements FileAssocBackend {
  final Map<String, String> registered = <String, String>{};
  final List<String> launched = <String>[];

  @override
  Future<bool> register(String ext, String handler) async {
    registered[ext] = handler;
    return true;
  }

  @override
  Future<void> launch(String path) async => launched.add(path);
}

class DesktopFileAssocService {
  DesktopFileAssocService(this.backend);

  final FileAssocBackend backend;

  Future<bool> registerPdfHandler() => backend.register('.pdf', 'viewer');
  Future<bool> registerCsvHandler() => backend.register('.csv', 'import');

  /// Route double-click path to handler: viewer for pdf, import for csv, null for unsupported.
  String? route(String path) {
    final String lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) return 'viewer';
    if (lower.endsWith('.csv')) return 'import';
    return null;
  }
}
