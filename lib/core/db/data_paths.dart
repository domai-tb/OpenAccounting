import 'dart:io';

import 'package:path/path.dart' as p;

String resolveDefaultBaseDir() {
  if (Platform.isLinux) {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return p.join(home, '.local', 'share', 'OpenAccounting');
  }
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return p.join(home, 'Library', 'Application Support', 'OpenAccounting');
  }
  if (Platform.isWindows) {
    final local =
        Platform.environment['LOCALAPPDATA'] ?? Platform.environment['APPDATA'] ?? r'C:\Users\Default\AppData\Local';
    return p.join(local, 'OpenAccounting');
  }
  final home = Platform.environment['HOME'] ?? '/tmp';
  return p.join(home, '.local', 'share', 'OpenAccounting');
}
