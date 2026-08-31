import 'package:drift/drift.dart';

class Lieferant {
  const Lieferant({
    required this.id,
    required this.kreditorNr,
    required this.anrede,
    required this.name,
    this.firma,
    required this.strasse,
    this.hausnummer,
    required this.plz,
    required this.ort,
    required this.land,
    this.ustIdNr,
    this.foreignTaxNumber,
    this.telefon,
    this.email,
    this.iban,
    required this.zahlungsziel,
    required this.skontoProzent,
    required this.skontoTage,
    this.note,
  });

  final int id;
  final String kreditorNr;
  final String anrede;
  final String name;
  final String? firma;
  final String strasse;
  final String? hausnummer;
  final String plz;
  final String ort;
  final String land;
  final String? ustIdNr;
  final String? foreignTaxNumber;
  final String? telefon;
  final String? email;
  final String? iban;
  final int zahlungsziel;
  final num skontoProzent;
  final int skontoTage;
  final String? note;
}

class LieferantenException implements Exception {
  const LieferantenException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LieferantenRepository {
  LieferantenRepository(this.executor);

  final QueryExecutor executor;
  Future<void>? _schemaReady;

  Future<void> ensureSchema() => _schemaReady ??= _ensureSchema(executor);

  static const List<_ColumnDefinition> _lieferantenColumns = <_ColumnDefinition>[
    _ColumnDefinition('anrede', "TEXT NOT NULL DEFAULT 'Herr'"),
    _ColumnDefinition('firma', 'TEXT'),
    _ColumnDefinition('hausnummer', 'TEXT'),
    _ColumnDefinition('steuernummer_ausland', 'VARCHAR(50)'),
    _ColumnDefinition('zahlungsziel', 'INTEGER DEFAULT 14'),
    _ColumnDefinition('skonto_prozent', 'NUMERIC(12,2) DEFAULT 0'),
    _ColumnDefinition('skonto_tage', 'INTEGER NOT NULL DEFAULT 0'),
    _ColumnDefinition('note', 'TEXT'),
  ];

  static Future<void> _ensureSchema(QueryExecutor executor) async {
    final transaction = executor.beginTransaction();
    try {
      await transaction.ensureOpen(_NoopTransactionUser());
      await _addMissingColumns(transaction, 'lieferanten', _lieferantenColumns);
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

  static Future<void> _addMissingColumns(
    QueryExecutor executor,
    String table,
    List<_ColumnDefinition> definitions,
  ) async {
    final rows = await executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
    final existing = <String>{
      for (final row in rows)
        if (row['name'] is String) row['name']! as String,
    };
    for (final definition in definitions) {
      if (!existing.contains(definition.name)) {
        await executor.runCustom('ALTER TABLE $table ADD COLUMN ${definition.name} ${definition.definition}');
      }
    }
  }
}

class _ColumnDefinition {
  const _ColumnDefinition(this.name, this.definition);

  final String name;
  final String definition;
}

class _NoopTransactionUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
