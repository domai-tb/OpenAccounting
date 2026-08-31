import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/journal_entity.dart';

/// Journal repository — raw SQL via drift executor, GoBD via DB triggers.
/// ponytail: global executor lock ceiling — per-journal if throughput matters.
class JournalRepository {
  JournalRepository(this.executor);

  final QueryExecutor executor;

  static const Set<String> _allowedArt = <String>{'Einnahme', 'Ausgabe'};

  static final RegExp _betragRegex = RegExp(r'^-?\d+(\.\d{1,2})?$');

  Future<JournalEntry> create({
    required DateTime datum,
    required String bezeichnung,
    required int kategorieId,
    required String betrag,
    required String art,
    String? kontoSkr03,
    String? kontoSkr04,
    int? ustSatzId,
    String? belegNr,
    int? kontoId,
    int? stornoVon,
  }) async {
    final cleanBezeichnung = bezeichnung.trim();
    if (cleanBezeichnung.isEmpty) {
      throw const JournalException('Bezeichnung ist Pflicht');
    }
    if (kategorieId <= 0) {
      throw const JournalException('Kategorie ist Pflicht');
    }
    final cleanBetrag = betrag.trim();
    if (cleanBetrag.isEmpty) {
      throw const JournalException('Betrag ist Pflicht');
    }
    if (!_betragRegex.hasMatch(cleanBetrag)) {
      throw const JournalException('Betrag ungültig: max 2 Dezimalstellen');
    }
    // ponytail: O(1) numeric range — 12,2 means |betrag| < 10^10
    final parsed = double.tryParse(cleanBetrag);
    if (parsed == null || parsed.abs() >= 10000000000) {
      throw const JournalException('Betrag außerhalb NUMERIC(12,2)');
    }
    if (!_allowedArt.contains(art)) {
      throw const JournalException('Art muss Einnahme oder Ausgabe sein');
    }

    final datumStr = _formatDate(datum);
    final id = await executor.runInsert(
      'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, '
      'konto_skr03_snapshot, konto_skr04_snapshot, ust_satz_id, immutable, beleg_nr, storno_von, konto_id) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)',
      <Object?>[
        datumStr,
        cleanBezeichnung,
        kategorieId,
        cleanBetrag,
        art,
        kontoSkr03,
        kontoSkr04,
        ustSatzId,
        belegNr,
        stornoVon,
        kontoId,
      ],
    );

    final entry = await findById(id);
    if (entry == null) {
      throw const JournalException('Journaleintrag konnte nicht gespeichert werden');
    }
    return entry;
  }

  Future<JournalEntry> storno({required int originalId}) async {
    final original = await findById(originalId);
    if (original == null) {
      throw const JournalException('Original-Eintrag nicht gefunden');
    }

    // Prevent duplicate storno per spec §Storno correction.
    final existing = await executor.runSelect('SELECT id FROM journal WHERE storno_von = ? LIMIT 1', <Object?>[
      originalId,
    ]);
    if (existing.isNotEmpty) {
      throw const JournalException('Eintrag bereits storniert');
    }

    final negBetrag = _negateBetrag(original.betrag);
    final now = DateTime.now();
    final datumStr = _formatDate(now);
    final stornoBezeichnung = 'Storno: ${original.bezeichnung}';

    final id = await executor.runInsert(
      'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, '
      'konto_skr03_snapshot, konto_skr04_snapshot, ust_satz_id, immutable, storno_von, konto_id) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)',
      <Object?>[
        datumStr,
        stornoBezeichnung,
        original.kategorieId,
        negBetrag,
        original.art,
        original.kontoSkr03,
        original.kontoSkr04,
        original.ustSatzId,
        originalId,
        original.kontoId,
      ],
    );

    final entry = await findById(id);
    if (entry == null) {
      throw const JournalException('Storno konnte nicht gespeichert werden');
    }
    return entry;
  }

  Future<JournalEntry?> findById(int id) async {
    final rows = await executor.runSelect(
      'SELECT id, datum, beschreibung, kategorie_id, betrag, beleg_typ, '
      'konto_skr03_snapshot, konto_skr04_snapshot, ust_satz_id, immutable, beleg_nr, storno_von, konto_id '
      'FROM journal WHERE id = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.single);
  }

  Future<List<JournalEntry>> list() async {
    final rows = await executor.runSelect(
      'SELECT id, datum, beschreibung, kategorie_id, betrag, beleg_typ, '
      'konto_skr03_snapshot, konto_skr04_snapshot, ust_satz_id, immutable, beleg_nr, storno_von, konto_id '
      'FROM journal ORDER BY id',
      const <Object?>[],
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  JournalEntry _fromRow(Map<String, Object?> row) {
    final id = (row['id'] as num).toInt();
    final datumRaw = row['datum'] as String? ?? '';
    final datum = DateTime.tryParse(datumRaw) ?? DateTime(1970, 1, 1);
    final beschreibung = row['beschreibung'] as String? ?? '';
    final kategorieId = (row['kategorie_id'] as num?)?.toInt() ?? 0;
    final betragNum = row['betrag'] as num? ?? 0;
    final betrag = betragNum.toStringAsFixed(2);
    final art = row['beleg_typ'] as String? ?? 'Einnahme';
    final immutable = (row['immutable'] as num? ?? 0).toInt() == 1;
    final kontoSkr03 = row['konto_skr03_snapshot'] as String?;
    final kontoSkr04 = row['konto_skr04_snapshot'] as String?;
    final ustSatzId = (row['ust_satz_id'] as num?)?.toInt();
    final belegNr = row['beleg_nr'] as String?;
    final stornoVon = (row['storno_von'] as num?)?.toInt();
    final kontoId = (row['konto_id'] as num?)?.toInt();
    return JournalEntry(
      id: id,
      datum: datum,
      bezeichnung: beschreibung,
      kategorieId: kategorieId,
      betrag: betrag,
      art: art,
      immutable: immutable,
      kontoSkr03: kontoSkr03,
      kontoSkr04: kontoSkr04,
      ustSatzId: ustSatzId,
      belegNr: belegNr,
      stornoVon: stornoVon,
      kontoId: kontoId,
      beschreibung: beschreibung,
    );
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _negateBetrag(String betrag) {
    final v = double.parse(betrag);
    final neg = -v;
    return neg.toStringAsFixed(2);
  }
}
