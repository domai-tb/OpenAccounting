// ignore_for_file: dangling_library_doc_comments
/// DropService — desktop_drop adapter, type validation, drop-zone UI.
class DropService {
  static const Set<String> allowed = <String>{'.pdf', '.csv', '.jpg', '.png', '.tiff', '.jpeg'};

  bool isAllowed(String path) {
    final String lower = path.toLowerCase();
    return allowed.any(lower.endsWith);
  }

  String? validate(String path) {
    if (isAllowed(path)) return null;
    return 'unsupported: $path';
  }

  String storePath(String path) => 'APP_DATA_DIR/${path.split('/').last}';
}
