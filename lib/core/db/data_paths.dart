import 'dart:io';

import 'package:path/path.dart' as p;

String resolveDefaultBaseDir() {
  if (Platform.isLinux) {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return p.join(home, '.local', 'share', 'OpenInvoices');
  }
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return p.join(home, 'Library', 'Application Support', 'OpenInvoices');
  }
  if (Platform.isWindows) {
    final local =
        Platform.environment['LOCALAPPDATA'] ?? Platform.environment['APPDATA'] ?? r'C:\Users\Default\AppData\Local';
    return p.join(local, 'OpenInvoices');
  }
  final home = Platform.environment['HOME'] ?? '/tmp';
  return p.join(home, '.local', 'share', 'OpenInvoices');
}
