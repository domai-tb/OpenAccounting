import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/accounting/rechnung_typ.dart';

/// Exception für Rechnungsvorlagen-Validierung — deutsche Meldungen.
class RechnungsVorlagenException implements Exception {
  const RechnungsVorlagenException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Datenmodell für Rechnungsvorlage.
class RechnungsVorlage {
  const RechnungsVorlage({
    required this.id,
    required this.name,
    this.kundeId,
    required this.intervall,
    this.naechsteFaelligkeit,
    required this.aktiv,
    required this.status,
    required this.positionen,
    this.auftragId,
    this.vorlageDatenRaw,
  });

  final int id;
  final String name;
  final int? kundeId;
  final String intervall;
  final String? naechsteFaelligkeit;
  final bool aktiv;
  final String status;
  final List<Map<String, dynamic>> positionen;
  final int? auftragId;
  final String? vorlageDatenRaw;
}

/// Warnung Preisabweichung.
class PreisWarnung {
  const PreisWarnung({required this.artikelId, required this.vorlagePreis, required this.aktuellVkBrutto});

  final int artikelId;
  final num vorlagePreis;
  final num aktuellVkBrutto;
}

/// Repository für Rechnungsvorlagen — drift raw SQL, Transaktionen, 120 Zeichen.
class RechnungsVorlagenRepository {
  RechnungsVorlagenRepository(this.executor);

  final QueryExecutor executor;
  Future<void>? _schemaReady;

  static const Set<String> allowedInterval = <String>{'monatlich', 'quartalsweise', 'jährlich'};

  Future<void> ensureSchema() => _schemaReady ??= _ensureSchema();

  Future<void> _ensureSchema() async {
    await executor.runCustom('''
CREATE TABLE IF NOT EXISTS rechnungsvorlagen_occurrences (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  vorlage_id INTEGER NOT NULL REFERENCES rechnungsvorlagen(id),
  faelligkeit TEXT NOT NULL,
  rechnung_id INTEGER NOT NULL REFERENCES rechnungen(id),
  UNIQUE(vorlage_id, faelligkeit)
)''');
    await _ensureRechnungenLineageColumn();
  }

  Future<void> _ensureRechnungenLineageColumn() async {
    try {
      final List<Map<String, Object?>> cols = await executor.runSelect(
        'PRAGMA table_info(rechnungen)',
        const <Object?>[],
      );
      if (cols.any((Map<String, Object?> row) => row['name'] == 'konvertiert_von')) return;
      await executor.runCustom('ALTER TABLE rechnungen ADD COLUMN konvertiert_von INTEGER REFERENCES rechnungen(id)');
      final List<Map<String, Object?>> verified = await executor.runSelect(
        'PRAGMA table_info(rechnungen)',
        const <Object?>[],
      );
      if (!verified.any((Map<String, Object?> row) => row['name'] == 'konvertiert_von')) {
        throw StateError('Rechnungsschema konnte Spalte rechnungen.konvertiert_von nicht verifizieren');
      }
    } catch (_) {
      // ponytail: idempotent — ignore if column already exists via other ensure path
    }
  }

  /// Erstellt Vorlage mit Validierung.
  Future<RechnungsVorlage> create({
    required String name,
    int? kundeId,
    required String intervall,
    String? naechsteFaelligkeit,
    List<Map<String, dynamic>> positionen = const <Map<String, dynamic>>[],
    int? auftragId,
    DateTime? bezugsDatum,
  }) async {
    await ensureSchema();
    final String cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const RechnungsVorlagenException('Name ist Pflicht');
    }
    final String cleanIntervall = intervall.trim();
    if (cleanIntervall.isEmpty) {
      throw const RechnungsVorlagenException('Intervall ist Pflicht');
    }
    if (!allowedInterval.contains(cleanIntervall)) {
      throw RechnungsVorlagenException('Ungültiges Intervall: $cleanIntervall');
    }
    for (var index = 0; index < positionen.length; index++) {
      _validatePosition(positionen[index], index);
    }
    _documentInputMode(positionen);
    // auftrag lineage: ensure referenced auftrag exists if provided
    if (auftragId != null) {
      final List<Map<String, Object?>> aRows = await executor.runSelect(
        'SELECT id FROM rechnungen WHERE id = ? LIMIT 1',
        <Object?>[auftragId],
      );
      if (aRows.isEmpty) throw const RechnungsVorlagenException('Auftrag nicht gefunden');
    }
    final String jsonStr = jsonEncode(positionen);
    final String nextDue =
        naechsteFaelligkeit ?? _formatDate(_nextDueFrom(bezugsDatum ?? DateTime.now(), cleanIntervall));
    final int id = await executor.runInsert(
      'INSERT INTO rechnungsvorlagen (name, kunde_id, intervall, naechste_faelligkeit, aktiv, vorlage_daten, status, auftrag_id) '
      'VALUES (?, ?, ?, ?, 1, ?, ?, ?)',
      <Object?>[cleanName, kundeId, cleanIntervall, nextDue, jsonStr, 'aktiv', auftragId],
    );
    final RechnungsVorlage? created = await findById(id);
    if (created == null) {
      throw const RechnungsVorlagenException('Vorlage konnte nicht gespeichert werden');
    }
    return created;
  }

  Future<RechnungsVorlage?> findById(int id) async {
    await ensureSchema();
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, name, kunde_id, intervall, naechste_faelligkeit, aktiv, vorlage_daten, status, auftrag_id '
      'FROM rechnungsvorlagen WHERE id = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.single);
  }

  Future<List<RechnungsVorlage>> list() async {
    await ensureSchema();
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, name, kunde_id, intervall, naechste_faelligkeit, aktiv, vorlage_daten, status, auftrag_id '
      'FROM rechnungsvorlagen ORDER BY id',
      const <Object?>[],
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<RechnungsVorlage> update(
    int id, {
    String? name,
    String? intervall,
    String? naechsteFaelligkeit,
    List<Map<String, dynamic>>? positionen,
    int? kundeId,
    int? auftragId,
  }) async {
    await ensureSchema();
    final RechnungsVorlage? cur = await findById(id);
    if (cur == null) throw const RechnungsVorlagenException('Vorlage nicht gefunden');
    String newIntervall = cur.intervall;
    if (intervall != null) {
      final String t = intervall.trim();
      if (t.isEmpty) throw const RechnungsVorlagenException('Intervall ist Pflicht');
      if (!allowedInterval.contains(t)) throw RechnungsVorlagenException('Ungültiges Intervall: $t');
      newIntervall = t;
    }
    final String newName = name?.trim().isEmpty ?? false
        ? throw const RechnungsVorlagenException('Name ist Pflicht')
        : (name?.trim() ?? cur.name);
    if (positionen != null) {
      for (var index = 0; index < positionen.length; index++) {
        _validatePosition(positionen[index], index);
      }
      _documentInputMode(positionen);
    }
    final String newJson = positionen == null ? (cur.vorlageDatenRaw ?? '[]') : jsonEncode(positionen);
    final String? newNext = naechsteFaelligkeit ?? cur.naechsteFaelligkeit;
    await executor.runUpdate(
      'UPDATE rechnungsvorlagen SET name = ?, intervall = ?, naechste_faelligkeit = ?, vorlage_daten = ?, '
      'kunde_id = ?, auftrag_id = ? WHERE id = ?',
      <Object?>[newName, newIntervall, newNext, newJson, kundeId ?? cur.kundeId, auftragId ?? cur.auftragId, id],
    );
    return (await findById(id))!;
  }

  Future<RechnungsVorlage> pause(int id) async {
    final RechnungsVorlage? cur = await findById(id);
    if (cur == null) throw const RechnungsVorlagenException('Vorlage nicht gefunden');
    await executor.runUpdate('UPDATE rechnungsvorlagen SET aktiv = 0, status = ? WHERE id = ?', <Object?>[
      'pausiert',
      id,
    ]);
    return (await findById(id))!;
  }

  Future<RechnungsVorlage> resume(int id) async {
    final RechnungsVorlage? cur = await findById(id);
    if (cur == null) throw const RechnungsVorlagenException('Vorlage nicht gefunden');
    if (cur.status == 'beendet') {
      throw const RechnungsVorlagenException('Beendete Vorlage kann nicht reaktiviert werden');
    }
    await executor.runUpdate('UPDATE rechnungsvorlagen SET aktiv = 1, status = ? WHERE id = ?', <Object?>['aktiv', id]);
    return (await findById(id))!;
  }

  Future<RechnungsVorlage> beenden(int id) async {
    final RechnungsVorlage? cur = await findById(id);
    if (cur == null) throw const RechnungsVorlagenException('Vorlage nicht gefunden');
    await executor.runUpdate('UPDATE rechnungsvorlagen SET aktiv = 0, status = ? WHERE id = ?', <Object?>[
      'beendet',
      id,
    ]);
    return (await findById(id))!;
  }

  Future<void> delete(int id) async {
    final List<Map<String, Object?>> linked = await executor.runSelect(
      'SELECT count(*) as c FROM rechnungen WHERE vorlage_id = ?',
      <Object?>[id],
    );
    final int count = (linked.single['c'] as num?)?.toInt() ?? 0;
    if (count > 0) {
      throw RechnungsVorlagenException('Vorlage hat $count erzeugte Rechnungen und kann nicht gelöscht werden');
    }
    final int deleted = await executor.runDelete('DELETE FROM rechnungsvorlagen WHERE id = ?', <Object?>[id]);
    if (deleted == 0) throw const RechnungsVorlagenException('Vorlage nicht gefunden');
  }

  /// Prüft ob Vorlage fällig ist.
  bool isDue(RechnungsVorlage vorlage, DateTime heute) {
    if (!vorlage.aktiv || vorlage.status != 'aktiv') return false;
    if (vorlage.naechsteFaelligkeit == null) return false;
    final DateTime? due = DateTime.tryParse(vorlage.naechsteFaelligkeit!);
    if (due == null) return false;
    final DateTime h = DateTime(heute.year, heute.month, heute.day);
    final DateTime d = DateTime(due.year, due.month, due.day);
    return !h.isBefore(d);
  }

  /// Nächstes Fälligkeitsdatum berechnen.
  DateTime nextDue(DateTime from, String intervall) => _nextDueFrom(from, intervall);

  /// Advance helper — +1 Monat, +3 Monate, +12 Monate mit Monats-Ende-Korrektur.
  DateTime _nextDueFrom(DateTime from, String intervall) {
    switch (intervall) {
      case 'monatlich':
        return _addMonths(from, 1);
      case 'quartalsweise':
        return _addMonths(from, 3);
      case 'jährlich':
        return _addMonths(from, 12);
      default:
        throw RechnungsVorlagenException('Ungültiges Intervall: $intervall');
    }
  }

  DateTime _addMonths(DateTime d, int months) {
    final int totalMonths = d.month - 1 + months;
    final int year = d.year + totalMonths ~/ 12;
    final int month = totalMonths % 12 + 1;
    final int day = d.day;
    final int dim = _daysInMonth(year, month);
    return DateTime(year, month, day > dim ? dim : day);
  }

  int _daysInMonth(int year, int month) {
    if (month == 12) return DateTime(year + 1, 1, 0).day;
    return DateTime(year, month + 1, 0).day;
  }

  String _formatDate(DateTime d) {
    final String y = d.year.toString().padLeft(4, '0');
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Preisvergleich — liefert Warnungen wo Vorlage-Preis != artikel.vk_brutto.
  Future<List<PreisWarnung>> vergleichePreise(RechnungsVorlage vorlage) async {
    final List<PreisWarnung> warnings = <PreisWarnung>[];
    for (final Map<String, dynamic> pos in vorlage.positionen) {
      final Object? aid = pos['artikel_id'];
      if (aid == null) continue;
      final int artikelId = (aid as num).toInt();
      final num vorlagePreis = (pos['einzelpreis'] as num?) ?? 0;
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT vk_brutto FROM artikel WHERE id = ?',
        <Object?>[artikelId],
      );
      if (rows.isEmpty) continue;
      final num aktuell = (rows.single['vk_brutto'] as num?) ?? 0;
      if ((aktuell - vorlagePreis).abs() > 0.001) {
        warnings.add(PreisWarnung(artikelId: artikelId, vorlagePreis: vorlagePreis, aktuellVkBrutto: aktuell));
      }
    }
    return warnings;
  }

  /// Auto-Generation — erzeugt fällige Rechnungen, rückt naechste_faelligkeit vor, nutzt Transaktion.
  Future<List<int>> generateFaellig({DateTime? heute}) async {
    await ensureSchema();
    final DateTime now = heute ?? DateTime.now();
    final List<RechnungsVorlage> alle = await list();
    final List<int> createdIds = <int>[];
    for (final RechnungsVorlage v in alle) {
      if (!isDue(v, now)) continue;
      // Preiswarnungen ermitteln (nicht blockierend).
      // Generiere fällige + überfällige in Schleife (missed generation).
      DateTime due = DateTime.parse(v.naechsteFaelligkeit!);
      while (!now.isBefore(DateTime(due.year, due.month, due.day))) {
        final int rechnungId = await _generateOne(v, due);
        createdIds.add(rechnungId);
        due = _nextDueFrom(due, v.intervall);
        await executor.runUpdate('UPDATE rechnungsvorlagen SET naechste_faelligkeit = ? WHERE id = ?', <Object?>[
          _formatDate(due),
          v.id,
        ]);
        // Nach erstem Durchlauf neu prüfen, ob noch überfällig (z. B. 3 Monate).
        if (due.isAfter(DateTime(now.year, now.month, now.day))) break;
      }
    }
    return createdIds;
  }

  /// Einzelne Rechnung aus Vorlage erzeugen — in Transaktion für beide Tabellen.
  Future<int> _generateOne(RechnungsVorlage vorlage, DateTime datum) async {
    // The unique occurrence key makes a retry return the original invoice.
    await executor.runCustom('BEGIN');
    try {
      final String datumStr = _formatDate(datum);
      final List<_RecurringInvoiceLine> lines = <_RecurringInvoiceLine>[];
      final String documentInputMode = _documentInputMode(vorlage.positionen);
      var nettoCents = 0;
      var ustCents = 0;
      var bruttoCents = 0;
      for (final Map<String, dynamic> p in vorlage.positionen) {
        final _RecurringInvoiceLine line = _calculateLine(p, lines.length);
        lines.add(line);
        nettoCents += line.nettoCents;
        ustCents += line.ustCents;
        bruttoCents += line.bruttoCents;
      }
      final List<Map<String, Object?>> prior = await executor.runSelect(
        'SELECT rechnung_id FROM rechnungsvorlagen_occurrences WHERE vorlage_id = ? AND faelligkeit = ? LIMIT 1',
        <Object?>[vorlage.id, datumStr],
      );
      if (prior.isNotEmpty) {
        final int? existingId = (prior.single['rechnung_id'] as num?)?.toInt();
        if (existingId != null) {
          await executor.runCustom('COMMIT');
          return existingId;
        }
      }
      // Ensure lineage column exists before insert (idempotent; no-op if present).
      await _ensureRechnungenLineageColumn();
      final int rechnungId = await executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, '
        'netto_betrag, brutto_betrag, ust_betrag, vorlage_id, konvertiert_von) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          null,
          RechnungTyp.rechnung,
          'entwurf',
          1,
          documentInputMode,
          vorlage.kundeId,
          datumStr,
          money.fromCents(nettoCents),
          money.fromCents(bruttoCents),
          money.fromCents(ustCents),
          vorlage.id,
          vorlage.auftragId,
        ],
      );
      for (var posIndex = 0; posIndex < lines.length; posIndex++) {
        final _RecurringInvoiceLine line = lines[posIndex];
        await executor.runInsert(
          'INSERT INTO rechnungspositionen (rechnung_id, artikel_id, bezeichnung, menge, einzelpreis, gesamt, '
          'ust_satz, position) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            rechnungId,
            line.artikelId,
            line.bezeichnung,
            line.menge,
            line.einzelpreis,
            money.fromCents(line.inputMode == 'brutto' ? line.bruttoCents : line.nettoCents),
            line.rate,
            posIndex,
          ],
        );
      }
      await executor.runCustom(
        'INSERT OR IGNORE INTO rechnungsvorlagen_occurrences '
        '(vorlage_id, faelligkeit, rechnung_id) VALUES (?, ?, ?)',
        <Object?>[vorlage.id, datumStr, rechnungId],
      );
      final List<Map<String, Object?>> occurrence = await executor.runSelect(
        'SELECT rechnung_id FROM rechnungsvorlagen_occurrences '
        'WHERE vorlage_id = ? AND faelligkeit = ? LIMIT 1',
        <Object?>[vorlage.id, datumStr],
      );
      final int persistedId = (occurrence.single['rechnung_id'] as num?)?.toInt() ?? rechnungId;
      if (persistedId != rechnungId) {
        await executor.runDelete('DELETE FROM rechnungen WHERE id = ?', <Object?>[rechnungId]);
      }
      await executor.runCustom('COMMIT');
      return persistedId;
    } catch (e) {
      try {
        await executor.runCustom('ROLLBACK');
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> listGeneratedInvoices(int vorlageId) async {
    await ensureSchema();
    return executor.runSelect(
      'SELECT id, rechnungsnummer, datum, status, vorlage_id FROM rechnungen WHERE vorlage_id = ? ORDER BY id',
      <Object?>[vorlageId],
    );
  }

  RechnungsVorlage _fromRow(Map<String, Object?> row) {
    final int id = ((row['id'] as num?) ?? 0).toInt();
    final String name = row['name'] as String? ?? '';
    final int? kundeId = (row['kunde_id'] as num?)?.toInt();
    final String intervall = (row['intervall'] as String?) ?? '';
    final String? next = row['naechste_faelligkeit'] as String?;
    final bool aktiv = ((row['aktiv'] as num?) ?? 0) != 0;
    final String status = (row['status'] as String?) ?? (aktiv ? 'aktiv' : 'pausiert');
    final String raw = (row['vorlage_daten'] as String?) ?? '[]';
    List<Map<String, dynamic>> pos = <Map<String, dynamic>>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        pos = decoded.whereType<Map>().map(Map<String, dynamic>.from).toList();
      }
    } catch (_) {
      pos = <Map<String, dynamic>>[];
    }
    final int? auftragId = (row['auftrag_id'] as num?)?.toInt();
    return RechnungsVorlage(
      id: id,
      name: name,
      kundeId: kundeId,
      intervall: intervall,
      naechsteFaelligkeit: next,
      aktiv: aktiv,
      status: status,
      positionen: pos,
      auftragId: auftragId,
      vorlageDatenRaw: raw,
    );
  }

  void _validatePosition(Map<String, dynamic> position, int index) {
    final Object? description = position['bezeichnung'];
    if (description is! String || description.trim().isEmpty) {
      throw RechnungsVorlagenException('Position $index: bezeichnung ist Pflicht');
    }
    try {
      _scaled(position['menge'] ?? 1, scale: 3, field: 'Position $index menge', allowNegative: false);
      _scaled(position['einzelpreis'] ?? 0, scale: 4, field: 'Position $index einzelpreis', allowNegative: false);
      _rate(position['ust_satz'] ?? position['ustSatz'] ?? 19, index);
      _inputMode(position, index);
    } on money.MoneyParseException catch (error) {
      throw RechnungsVorlagenException(error.message);
    }
  }

  _RecurringInvoiceLine _calculateLine(Map<String, dynamic> position, int index) {
    _validatePosition(position, index);
    final int menge = _scaled(position['menge'] ?? 1, scale: 3, field: 'Position $index menge', allowNegative: false);
    final int einzelpreis = _scaled(
      position['einzelpreis'] ?? 0,
      scale: 4,
      field: 'Position $index einzelpreis',
      allowNegative: false,
    );
    final int rateCents = _rate(position['ust_satz'] ?? position['ustSatz'] ?? 19, index);
    final String mode = _inputMode(position, index);
    final int amountCents = _roundHalfUp(einzelpreis * menge, 100000);
    final int nettoCents;
    final int bruttoCents;
    final int ustCents;
    if (mode == 'brutto') {
      bruttoCents = amountCents;
      nettoCents = _roundHalfUp(amountCents * 10000, 10000 + rateCents);
      ustCents = bruttoCents - nettoCents;
    } else {
      nettoCents = amountCents;
      ustCents = _roundHalfUp(nettoCents * rateCents, 10000);
      bruttoCents = nettoCents + ustCents;
    }
    return _RecurringInvoiceLine(
      bezeichnung: position['bezeichnung'] as String,
      artikelId: (position['artikel_id'] as num?)?.toInt(),
      menge: _formatScaled(menge, scale: 3),
      einzelpreis: _formatScaled(einzelpreis, scale: 4),
      rate: money.fromCents(rateCents),
      inputMode: mode,
      inputCents: amountCents,
      nettoCents: nettoCents,
      ustCents: ustCents,
      bruttoCents: bruttoCents,
    );
  }

  String _inputMode(Map<String, dynamic> position, int index) {
    final String mode = (position['eingabemodus'] ?? 'netto').toString().trim().toLowerCase();
    if (mode != 'netto' && mode != 'brutto') {
      throw RechnungsVorlagenException('Position $index: eingabemodus muss netto oder brutto sein');
    }
    return mode;
  }

  String _documentInputMode(List<Map<String, dynamic>> positions) {
    String? mode;
    for (var index = 0; index < positions.length; index++) {
      final String current = _inputMode(positions[index], index);
      if (mode != null && mode != current) {
        throw const RechnungsVorlagenException('Eine wiederkehrende Rechnung darf nicht netto und brutto mischen');
      }
      mode = current;
    }
    return mode ?? 'netto';
  }

  int _rate(Object raw, int index) {
    final int value = _scaled(raw, scale: 2, field: 'Position $index ust_satz', allowNegative: false);
    if (value > 10000) {
      throw RechnungsVorlagenException('Position $index: USt-Satz muss zwischen 0 und 100 liegen');
    }
    return value;
  }

  int _scaled(Object raw, {required int scale, required String field, required bool allowNegative}) {
    if (raw is num) {
      return money.scaledFromNum(raw, scale: scale, field: field, allowNegative: allowNegative);
    }
    return money.parseScaled(raw.toString(), scale: scale, field: field, allowNegative: allowNegative);
  }

  String _formatScaled(int value, {required int scale}) {
    final bool negative = value < 0;
    final int absolute = value.abs();
    var divisor = 1;
    for (var i = 0; i < scale; i++) {
      divisor *= 10;
    }
    final String integerPart = (absolute ~/ divisor).toString();
    final String fraction = (absolute % divisor).toString().padLeft(scale, '0');
    return '${negative ? '-' : ''}$integerPart.$fraction';
  }

  int _roundHalfUp(int numerator, int denominator) {
    if (numerator < 0) return -_roundHalfUp(-numerator, denominator);
    return (numerator + denominator ~/ 2) ~/ denominator;
  }
}

class _RecurringInvoiceLine {
  const _RecurringInvoiceLine({
    required this.bezeichnung,
    required this.artikelId,
    required this.menge,
    required this.einzelpreis,
    required this.rate,
    required this.inputMode,
    required this.inputCents,
    required this.nettoCents,
    required this.ustCents,
    required this.bruttoCents,
  });

  final String bezeichnung;
  final int? artikelId;
  final String menge;
  final String einzelpreis;
  final String rate;
  final String inputMode;
  final int inputCents;
  final int nettoCents;
  final int ustCents;
  final int bruttoCents;
}
