import 'package:drift/drift.dart';

class RechnungTriggers {
  static const String _dropInvoiceUpdate = 'DROP TRIGGER IF EXISTS protect_rechnung_update';
  static const String _dropInvoiceDelete = 'DROP TRIGGER IF EXISTS protect_rechnung_delete';
  static const String _dropSnapshotUpdate = 'DROP TRIGGER IF EXISTS protect_rechnung_snapshot_update';
  static const String _dropPositionInsert = 'DROP TRIGGER IF EXISTS protect_rechnungsposition_insert';
  static const String _dropPositionUpdate = 'DROP TRIGGER IF EXISTS protect_rechnungsposition_update';
  static const String _dropPositionDelete = 'DROP TRIGGER IF EXISTS protect_rechnungsposition_delete';

  static const String _createInvoiceUpdate = '''
CREATE TRIGGER protect_rechnung_update
BEFORE UPDATE ON rechnungen
FOR EACH ROW
WHEN OLD.ist_entwurf = 0 AND (
  NEW.id IS NOT OLD.id OR
  NEW.rechnungsnummer IS NOT OLD.rechnungsnummer OR
  NEW.typ IS NOT OLD.typ OR
  NEW.ist_entwurf IS NOT OLD.ist_entwurf OR
  NEW.eingabemodus IS NOT OLD.eingabemodus OR
  NEW.kunde_id IS NOT OLD.kunde_id OR
  NEW.lieferant_id IS NOT OLD.lieferant_id OR
  NEW.datum IS NOT OLD.datum OR
  NEW.faelligkeit IS NOT OLD.faelligkeit OR
  NEW.netto_betrag IS NOT OLD.netto_betrag OR
  NEW.brutto_betrag IS NOT OLD.brutto_betrag OR
  NEW.ust_betrag IS NOT OLD.ust_betrag OR
  NEW.skonto_prozent IS NOT OLD.skonto_prozent OR
  NEW.skonto_faelligkeit IS NOT OLD.skonto_faelligkeit OR
  NEW.notiz IS NOT OLD.notiz OR
  NEW.unternehmen_id IS NOT OLD.unternehmen_id OR
  NEW.nummernkreis_id IS NOT OLD.nummernkreis_id OR
  NEW.storno_von IS NOT OLD.storno_von OR
  NEW.ausgegeben_am IS NOT OLD.ausgegeben_am OR
  NEW.status IS NULL OR
  NEW.status NOT IN ('offen', 'teilbezahlt', 'bezahlt', 'storniert')
)
BEGIN
  SELECT RAISE(ABORT, 'Dokument ist bereits finalisiert');
END
''';

  static const String _createInvoiceDelete = '''
CREATE TRIGGER protect_rechnung_delete
BEFORE DELETE ON rechnungen
FOR EACH ROW
WHEN OLD.ist_entwurf = 0
BEGIN
  SELECT RAISE(ABORT, 'Dokument ist bereits finalisiert');
END
''';

  static const String _createSnapshotUpdate = '''
CREATE TRIGGER protect_rechnung_snapshot_update
BEFORE UPDATE ON rechnungen
FOR EACH ROW
WHEN OLD.ist_entwurf = 0 AND NEW.absender_snapshot IS NOT OLD.absender_snapshot
BEGIN
  SELECT RAISE(ABORT, 'Absender-Snapshot ist nach Finalisierung unveränderlich');
END
''';

  static const String _createPositionInsert = '''
CREATE TRIGGER protect_rechnungsposition_insert
BEFORE INSERT ON rechnungspositionen
FOR EACH ROW
WHEN EXISTS (
  SELECT 1 FROM rechnungen WHERE id = NEW.rechnung_id AND ist_entwurf = 0
)
BEGIN
  SELECT RAISE(ABORT, 'Dokument ist bereits finalisiert');
END
''';

  static const String _createPositionUpdate = '''
CREATE TRIGGER protect_rechnungsposition_update
BEFORE UPDATE ON rechnungspositionen
FOR EACH ROW
WHEN EXISTS (
  SELECT 1 FROM rechnungen WHERE id = OLD.rechnung_id AND ist_entwurf = 0
)
OR EXISTS (
  SELECT 1 FROM rechnungen WHERE id = NEW.rechnung_id AND ist_entwurf = 0
)
BEGIN
  SELECT RAISE(ABORT, 'Dokument ist bereits finalisiert');
END
''';

  static const String _createPositionDelete = '''
CREATE TRIGGER protect_rechnungsposition_delete
BEFORE DELETE ON rechnungspositionen
FOR EACH ROW
WHEN EXISTS (
  SELECT 1 FROM rechnungen WHERE id = OLD.rechnung_id AND ist_entwurf = 0
)
BEGIN
  SELECT RAISE(ABORT, 'Dokument ist bereits finalisiert');
END
''';

  static Future<void> install(QueryExecutor executor) async {
    final transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      await transaction.runCustom(_dropInvoiceUpdate);
      await transaction.runCustom(_dropInvoiceDelete);
      await transaction.runCustom(_dropSnapshotUpdate);
      await transaction.runCustom(_dropPositionInsert);
      await transaction.runCustom(_dropPositionUpdate);
      await transaction.runCustom(_dropPositionDelete);
      await transaction.runCustom(_createInvoiceUpdate);
      await transaction.runCustom(_createInvoiceDelete);
      await transaction.runCustom(_createSnapshotUpdate);
      await transaction.runCustom(_createPositionInsert);
      await transaction.runCustom(_createPositionUpdate);
      await transaction.runCustom(_createPositionDelete);
      await transaction.send();
    } catch (error, stackTrace) {
      try {
        await transaction.rollback();
      } catch (rollbackError, rollbackStackTrace) {
        Error.throwWithStackTrace(rollbackError, rollbackStackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

class _NoopTransactionUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
