import 'package:drift/drift.dart';

class BuchungsVorlagenException implements Exception {
  const BuchungsVorlagenException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BuchungsVorlage {
  const BuchungsVorlage({
    required this.id,
    required this.name,
    this.kategorieId,
    this.kontoId,
    this.betrag,
    this.beschreibung,
    required this.modus,
    required this.art,
    required this.intervall,
    this.naechsteFaelligkeit,
    required this.aktiv,
    required this.status,
    this.lieferantId,
  });

  final int id;
  final String name;
  final int? kategorieId;
  final int? kontoId;
  final String? betrag;
  final String? beschreibung;
  final String modus;
  final String art;
  final String intervall;
  final String? naechsteFaelligkeit;
  final bool aktiv;
  final String status;
  final int? lieferantId;
}

class BuchungsVorlagenRepository {
  BuchungsVorlagenRepository(this.executor);

  final QueryExecutor executor;

  static const Set<String> allowedInterval = <String>{'monatlich', 'quartalsweise', 'jährlich'};
  static const Set<String> allowedModus = <String>{'direkt', 'beleg'};
  static const Set<String> allowedArt = <String>{'Einnahme', 'Ausgabe'};

  Future<BuchungsVorlage> create({
    required String name,
    int? kategorieId,
    int? kontoId,
    String betrag = '0.00',
    String? beschreibung,
    String modus = 'direkt',
    required String art,
    required String intervall,
    String? naechsteFaelligkeit,
    int? lieferantId,
    DateTime? bezugsDatum,
  }) async {
    final String cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const BuchungsVorlagenException('Name ist Pflicht');
    }
    if (!allowedModus.contains(modus)) {
      throw BuchungsVorlagenException('Ungültiger modus: $modus');
    }
    if (!allowedArt.contains(art)) {
      throw BuchungsVorlagenException('Ungültige art: $art');
    }
    final String cleanIntervall = intervall.trim();
    if (cleanIntervall.isEmpty) {
      throw const BuchungsVorlagenException('Intervall ist Pflicht');
    }
    if (!allowedInterval.contains(cleanIntervall)) {
      throw BuchungsVorlagenException('Ungültiges Intervall: $cleanIntervall');
    }
    final String nextDue =
        naechsteFaelligkeit ?? _formatDate(_nextDueFrom(bezugsDatum ?? DateTime.now(), cleanIntervall));
    final int id = await executor.runInsert(
      'INSERT INTO buchungsvorlagen (name, kategorie_id, konto_id, betrag, beschreibung, modus, aktiv, intervall, '
      'naechste_faelligkeit, art, lieferant_id, status) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?)',
      <Object?>[
        cleanName,
        kategorieId,
        kontoId,
        betrag,
        beschreibung,
        modus,
        cleanIntervall,
        nextDue,
        art,
        lieferantId,
        'aktiv',
      ],
    );
    final BuchungsVorlage? created = await findById(id);
    if (created == null) throw const BuchungsVorlagenException('Vorlage konnte nicht gespeichert werden');
    return created;
  }

  Future<BuchungsVorlage?> findById(int id) async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, name, kategorie_id, konto_id, betrag, beschreibung, modus, aktiv, intervall, naechste_faelligkeit, '
      'art, lieferant_id, status FROM buchungsvorlagen WHERE id = ?',
      <Object?>[id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.single);
  }

  Future<List<BuchungsVorlage>> list() async {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT id, name, kategorie_id, konto_id, betrag, beschreibung, modus, aktiv, intervall, naechste_faelligkeit, '
      'art, lieferant_id, status FROM buchungsvorlagen ORDER BY id',
      const <Object?>[],
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<BuchungsVorlage> update(
    int id, {
    String? name,
    String? betrag,
    String? modus,
    String? art,
    String? intervall,
    int? kategorieId,
    int? kontoId,
    int? lieferantId,
  }) async {
    final BuchungsVorlage? cur = await findById(id);
    if (cur == null) throw const BuchungsVorlagenException('Vorlage nicht gefunden');
    if (modus != null && !allowedModus.contains(modus)) {
      throw BuchungsVorlagenException('Ungültiger modus: $modus');
    }
    if (art != null && !allowedArt.contains(art)) {
      throw BuchungsVorlagenException('Ungültige art: $art');
    }
    if (intervall != null) {
      final String t = intervall.trim();
      if (t.isEmpty) throw const BuchungsVorlagenException('Intervall ist Pflicht');
      if (!allowedInterval.contains(t)) throw BuchungsVorlagenException('Ungültiges Intervall: $t');
    }
    final String newName = name?.trim().isEmpty ?? true ? cur.name : name!.trim();
    if (newName.isEmpty) throw const BuchungsVorlagenException('Name ist Pflicht');
    await executor.runUpdate(
      'UPDATE buchungsvorlagen SET name = ?, betrag = ?, modus = ?, art = ?, intervall = ?, '
      'kategorie_id = ?, konto_id = ?, lieferant_id = ? WHERE id = ?',
      <Object?>[
        newName,
        betrag ?? cur.betrag,
        modus ?? cur.modus,
        art ?? cur.art,
        intervall ?? cur.intervall,
        kategorieId ?? cur.kategorieId,
        kontoId ?? cur.kontoId,
        lieferantId ?? cur.lieferantId,
        id,
      ],
    );
    return (await findById(id))!;
  }

  Future<BuchungsVorlage> pause(int id) async {
    final BuchungsVorlage? cur = await findById(id);
    if (cur == null) throw const BuchungsVorlagenException('Vorlage nicht gefunden');
    await executor.runUpdate('UPDATE buchungsvorlagen SET aktiv = 0, status = ? WHERE id = ?', <Object?>[
      'pausiert',
      id,
    ]);
    return (await findById(id))!;
  }

  Future<BuchungsVorlage> resume(int id) async {
    final BuchungsVorlage? cur = await findById(id);
    if (cur == null) throw const BuchungsVorlagenException('Vorlage nicht gefunden');
    await executor.runUpdate('UPDATE buchungsvorlagen SET aktiv = 1, status = ? WHERE id = ?', <Object?>['aktiv', id]);
    return (await findById(id))!;
  }

  Future<void> delete(int id) async {
    final List<Map<String, Object?>> linked = await executor.runSelect(
      'SELECT count(*) as c FROM journal WHERE vorlage_id = ?',
      <Object?>[id],
    );
    final int count = (linked.single['c'] as num?)?.toInt() ?? 0;
    if (count > 0) {
      throw BuchungsVorlagenException('Vorlage hat $count erzeugte Buchungen und kann nicht gelöscht werden');
    }
    // Auch Rechnungen prüfen für beleg-Modus.
    final List<Map<String, Object?>> reCnt = await executor.runSelect(
      'SELECT count(*) as c FROM rechnungen WHERE vorlage_id = ?',
      <Object?>[id],
    );
    final int rc = (reCnt.single['c'] as num?)?.toInt() ?? 0;
    if (rc > 0) {
      throw BuchungsVorlagenException('Vorlage hat $rc erzeugte Belege und kann nicht gelöscht werden');
    }
    final int del = await executor.runDelete('DELETE FROM buchungsvorlagen WHERE id = ?', <Object?>[id]);
    if (del == 0) throw const BuchungsVorlagenException('Vorlage nicht gefunden');
  }

  bool isDue(BuchungsVorlage vorlage, DateTime heute) {
    if (!vorlage.aktiv || vorlage.status != 'aktiv') return false;
    if (vorlage.naechsteFaelligkeit == null) return false;
    final DateTime? due = DateTime.tryParse(vorlage.naechsteFaelligkeit!);
    if (due == null) return false;
    final DateTime h = DateTime(heute.year, heute.month, heute.day);
    final DateTime d = DateTime(due.year, due.month, due.day);
    return !h.isBefore(d);
  }

  DateTime nextDue(DateTime from, String intervall) => _nextDueFrom(from, intervall);

  DateTime _nextDueFrom(DateTime from, String intervall) {
    switch (intervall) {
      case 'monatlich':
        return _addMonths(from, 1);
      case 'quartalsweise':
        return _addMonths(from, 3);
      case 'jährlich':
        return _addMonths(from, 12);
      default:
        throw BuchungsVorlagenException('Ungültiges Intervall: $intervall');
    }
  }

  DateTime _addMonths(DateTime d, int months) {
    final int total = d.month - 1 + months;
    final int y = d.year + total ~/ 12;
    final int m = total % 12 + 1;
    final int dim = _daysInMonth(y, m);
    return DateTime(y, m, d.day > dim ? dim : d.day);
  }

  int _daysInMonth(int y, int m) {
    if (m == 12) return DateTime(y + 1, 1, 0).day;
    return DateTime(y, m + 1, 0).day;
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Auto-Generation — erzeugt fällige Journal- oder Beleg-Einträge.
  Future<List<int>> generateFaellig({DateTime? heute}) async {
    final DateTime now = heute ?? DateTime.now();
    final List<BuchungsVorlage> alle = await list();
    final List<int> created = <int>[];
    for (final BuchungsVorlage v in alle) {
      if (!isDue(v, now)) continue;
      DateTime due = DateTime.parse(v.naechsteFaelligkeit!);
      while (!now.isBefore(DateTime(due.year, due.month, due.day))) {
        final int genId = await _generateOne(v, due);
        created.add(genId);
        due = _nextDueFrom(due, v.intervall);
        await executor.runUpdate('UPDATE buchungsvorlagen SET naechste_faelligkeit = ? WHERE id = ?', <Object?>[
          _formatDate(due),
          v.id,
        ]);
        if (due.isAfter(DateTime(now.year, now.month, now.day))) break;
      }
    }
    return created;
  }

  Future<int> _generateOne(BuchungsVorlage vorlage, DateTime datum) async {
    final String datumStr = _formatDate(datum);
    if (vorlage.modus == 'direkt') {
      // USt-Richtung: Ausgabe => Vorsteuer (KZ 66), Einnahme => Umsatzsteuer (KZ 81)
      final bool isAusgabe = vorlage.art == 'Ausgabe';
      final String belegTyp = vorlage.art;
      final String beschreibung = vorlage.beschreibung ?? vorlage.name;
      // Lieferant/Konto werden vererbt — journal.konto_id = vorlage.konto_id, lieferant via rechnung_id null.
      await executor.runCustom('BEGIN');
      try {
        final int jId = await executor.runInsert(
          'INSERT INTO journal (datum, beschreibung, kategorie_id, betrag, beleg_typ, konto_id, '
          'vorlage_id, ist_eu_lieferung, vorsteuer_betrag) VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)',
          <Object?>[
            datumStr,
            beschreibung,
            vorlage.kategorieId,
            vorlage.betrag ?? '0.00',
            belegTyp,
            vorlage.kontoId,
            vorlage.id,
            isAusgabe ? vorlage.betrag : null,
          ],
        );
        await executor.runCustom('COMMIT');
        return jId;
      } catch (e) {
        try {
          await executor.runCustom('ROLLBACK');
        } catch (_) {}
        rethrow;
      }
    } else {
      // beleg Modus: pre-filled Rechnung Draft (Eingangsrechnung).
      await executor.runCustom('BEGIN');
      try {
        final int rId = await executor.runInsert(
          'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, lieferant_id, datum, '
          'netto_betrag, brutto_betrag, vorlage_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            null,
            'eingangsrechnung',
            'entwurf',
            1,
            'netto',
            vorlage.lieferantId,
            datumStr,
            vorlage.betrag ?? '0.00',
            vorlage.betrag ?? '0.00',
            vorlage.id,
          ],
        );
        await executor.runCustom('COMMIT');
        return rId;
      } catch (e) {
        try {
          await executor.runCustom('ROLLBACK');
        } catch (_) {}
        rethrow;
      }
    }
  }

  BuchungsVorlage _fromRow(Map<String, Object?> r) {
    final int id = (r['id'] as num).toInt();
    final String name = r['name'] as String;
    final int? kategorieId = (r['kategorie_id'] as num?)?.toInt();
    final int? kontoId = (r['konto_id'] as num?)?.toInt();
    final String? betrag = r['betrag']?.toString();
    final String? beschreibung = r['beschreibung'] as String?;
    final String modus = (r['modus'] as String?) ?? 'direkt';
    final String art = (r['art'] as String?) ?? 'Ausgabe';
    final String intervall = (r['intervall'] as String?) ?? 'monatlich';
    final String? next = r['naechste_faelligkeit'] as String?;
    final bool aktiv = ((r['aktiv'] as num?) ?? 0) != 0;
    final String status = (r['status'] as String?) ?? (aktiv ? 'aktiv' : 'pausiert');
    final int? lieferantId = (r['lieferant_id'] as num?)?.toInt();
    return BuchungsVorlage(
      id: id,
      name: name,
      kategorieId: kategorieId,
      kontoId: kontoId,
      betrag: betrag,
      beschreibung: beschreibung,
      modus: modus,
      art: art,
      intervall: intervall,
      naechsteFaelligkeit: next,
      aktiv: aktiv,
      status: status,
      lieferantId: lieferantId,
    );
  }
}
