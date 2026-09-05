import 'dart:convert';

import 'package:drift/drift.dart';

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

  static const Set<String> allowedInterval = <String>{'monatlich', 'quartalsweise', 'jährlich'};

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
    // Positionen JSON mit Pflichtfeldern validieren.
    final String jsonStr = jsonEncode(positionen);
    // Sicherstellen, dass Positionen Felder haben.
    for (final Map<String, dynamic> p in positionen) {
      if (p['bezeichnung'] == null || (p['bezeichnung'] as String).trim().isEmpty) {
        throw const RechnungsVorlagenException('Position bezeichnung ist Pflicht');
      }
    }
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
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, name, kunde_id, intervall, naechste_faelligkeit, aktiv, vorlage_daten, status, auftrag_id '
      'FROM rechnungsvorlagen WHERE id = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.single);
  }

  Future<List<RechnungsVorlage>> list() async {
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
    // ponytail: einfache Transaktion via SQL BEGIN/COMMIT — vermeidet Drift-Transaction Typ-Komplexität.
    await executor.runCustom('BEGIN');
    try {
      final String datumStr = _formatDate(datum);
      num netto = 0;
      num brutto = 0;
      for (final Map<String, dynamic> p in vorlage.positionen) {
        final num menge = (p['menge'] as num?) ?? 1;
        final num preis = (p['einzelpreis'] as num?) ?? 0;
        netto += menge * preis;
      }
      brutto = netto * 1.19;
      final int rechnungId = await executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, '
        'netto_betrag, brutto_betrag, vorlage_id, storno_von) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          null,
          'rechnung',
          'entwurf',
          1,
          'netto',
          vorlage.kundeId,
          datumStr,
          netto.toStringAsFixed(2),
          brutto.toStringAsFixed(2),
          vorlage.id,
          vorlage.auftragId,
        ],
      );
      int posIndex = 0;
      for (final Map<String, dynamic> p in vorlage.positionen) {
        final String bezeichnung = (p['bezeichnung'] as String?) ?? 'Position';
        final num menge = (p['menge'] as num?) ?? 1;
        final num einzelpreis = (p['einzelpreis'] as num?) ?? 0;
        final int? artikelId = (p['artikel_id'] as num?)?.toInt();
        final num gesamt = menge * einzelpreis;
        await executor.runInsert(
          'INSERT INTO rechnungspositionen (rechnung_id, artikel_id, bezeichnung, menge, einzelpreis, gesamt, '
          'ust_satz, position) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[rechnungId, artikelId, bezeichnung, menge, einzelpreis, gesamt, 19, posIndex],
        );
        posIndex++;
      }
      await executor.runCustom('COMMIT');
      return rechnungId;
    } catch (e) {
      try {
        await executor.runCustom('ROLLBACK');
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> listGeneratedInvoices(int vorlageId) async {
    return executor.runSelect(
      'SELECT id, rechnungsnummer, datum, status, vorlage_id FROM rechnungen WHERE vorlage_id = ? ORDER BY id',
      <Object?>[vorlageId],
    );
  }

  RechnungsVorlage _fromRow(Map<String, Object?> row) {
    final int id = (row['id'] as num).toInt();
    final String name = row['name'] as String;
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
        pos = decoded.whereType<Map>().map((Map<dynamic, dynamic> e) => Map<String, dynamic>.from(e)).toList();
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
}
