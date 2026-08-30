import 'package:path/path.dart' as p;

import 'package:openaccounting/core/db/database.dart';

Future<void> initializeProfileDatabase(String databasePath) async {
  final database = AppDatabase.forProfile(p.dirname(databasePath));
  try {
    await database.ensureOpen();
  } finally {
    await database.close();
  }
}
