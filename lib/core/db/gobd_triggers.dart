import 'package:drift/drift.dart';

/// GoBD trigger SQL per spec §GoBD Triggers.
/// Immutable journal rows (immutable = 1) rejected on UPDATE/DELETE.
class GobdTriggers {
  static const String dropUpdate = 'DROP TRIGGER IF EXISTS protect_journal_update';
  static const String dropDelete = 'DROP TRIGGER IF EXISTS protect_journal_delete';
  static const String dropInsert = 'DROP TRIGGER IF EXISTS protect_journal_insert';

  static const String createUpdate = '''
CREATE TRIGGER protect_journal_update
BEFORE UPDATE ON journal
FOR EACH ROW
WHEN OLD.immutable = 1
BEGIN
  SELECT RAISE(ABORT, 'GoBD: Dieser Journaleintrag ist unveränderlich');
END
''';

  static const String createDelete = '''
CREATE TRIGGER protect_journal_delete
BEFORE DELETE ON journal
FOR EACH ROW
WHEN OLD.immutable = 1
BEGIN
  SELECT RAISE(ABORT, 'GoBD: Dieser Journaleintrag ist unveränderlich');
END
''';

  // ponytail: insert trigger is no-op placeholder — insert of immutable row allowed,
  // but name must exist per tasks 5.4 deliverable.
  static const String createInsert = '''
CREATE TRIGGER protect_journal_insert
BEFORE INSERT ON journal
FOR EACH ROW
WHEN NEW.immutable = 1 AND 0
BEGIN
  SELECT RAISE(ABORT, 'GoBD: Dieser Journaleintrag ist unveränderlich');
END
''';

  static Future<void> install(QueryExecutor executor) async {
    await executor.runCustom(dropUpdate);
    await executor.runCustom(dropDelete);
    await executor.runCustom(dropInsert);
    await executor.runCustom(createUpdate);
    await executor.runCustom(createDelete);
    await executor.runCustom(createInsert);
  }

  static Future<void> uninstall(QueryExecutor executor) async {
    await executor.runCustom(dropUpdate);
    await executor.runCustom(dropDelete);
    await executor.runCustom(dropInsert);
  }
}
