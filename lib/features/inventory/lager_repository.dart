import 'package:drift/drift.dart';

import 'package:openaccounting/pages/stammdaten/artikel_repository.dart';

/// Lager-Logik — Mindestbestand, Bewegungen, manuelle Korrektur.
/// Ponytail ultra: keine Abstraktion für einmalige Query, drift transaction hält Atomarität.
class LagerRepository {
  const LagerRepository(this.executor);

  final QueryExecutor executor;

  Future<void> ensureInventarTable(QueryExecutor ex) async {
    await ex.runCustom('''
CREATE TABLE IF NOT EXISTS inventarbewegungen (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  artikel_id INTEGER NOT NULL REFERENCES artikel(id),
  datum TEXT NOT NULL,
  diff NUMERIC(10,3) NOT NULL,
  grund TEXT NOT NULL,
  referenz_typ TEXT,
  referenz_id INTEGER
)''');
  }

  Future<List<Artikel>> warnungen() async {
    await executor.ensureOpen(_NoopUser());
    await ensureInventarTable(executor);
    final rows = await executor.runSelect(
      'SELECT id, artikelnummer, bezeichnung, beschreibung, einheit, vk_netto, vk_brutto, '
      'vk_eingabe, ust_satz_id, ust_satz, differenzbesteuerung, ek_netto, lager_aktiv, '
      'bestand_aktuell, mindestbestand, minusbestand_erlaubt, lieferant_id, '
      'lieferanten_artikelnr, gruppe_id, aktiv, typ, bestand '
      'FROM artikel WHERE lager_aktiv = 1 AND bestand_aktuell <= mindestbestand ORDER BY id',
      const <Object?>[],
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<Artikel> setBestand(int artikelId, num neuerBestand, {String grund = 'Manuelle Korrektur'}) async {
    final t = executor.beginTransaction();
    try {
      await t.ensureOpen(_NoopUser());
      await ensureInventarTable(t);
      final cur = await t.runSelect('SELECT bestand_aktuell FROM artikel WHERE id = ?', <Object?>[artikelId]);
      if (cur.isEmpty) throw StateError('Artikel nicht gefunden');
      final old = _asNum(cur.single['bestand_aktuell']) ?? 0;
      final diff = neuerBestand - old;
      await t.runUpdate('UPDATE artikel SET bestand_aktuell = ?, bestand = ? WHERE id = ?', <Object?>[
        neuerBestand,
        neuerBestand.toInt(),
        artikelId,
      ]);
      await t.runInsert(
        'INSERT INTO inventarbewegungen (artikel_id, datum, diff, grund) VALUES (?, ?, ?, ?)',
        <Object?>[artikelId, DateTime.now().toIso8601String().substring(0, 10), diff, grund],
      );
      await t.send();
      final rows = await executor.runSelect(
        'SELECT id, artikelnummer, bezeichnung, beschreibung, einheit, vk_netto, vk_brutto, '
        'vk_eingabe, ust_satz_id, ust_satz, differenzbesteuerung, ek_netto, lager_aktiv, '
        'bestand_aktuell, mindestbestand, minusbestand_erlaubt, lieferant_id, '
        'lieferanten_artikelnr, gruppe_id, aktiv, typ, bestand FROM artikel WHERE id = ?',
        <Object?>[artikelId],
      );
      return _fromRow(rows.single);
    } catch (e, s) {
      try {
        await t.rollback();
      } catch (_) {}
      Error.throwWithStackTrace(e, s);
    }
  }

  Future<Artikel> adjustBestand(int artikelId, num delta, {String grund = 'Manuelle Korrektur'}) async {
    final cur = await executor.runSelect('SELECT bestand_aktuell FROM artikel WHERE id = ?', <Object?>[artikelId]);
    if (cur.isEmpty) throw StateError('Artikel nicht gefunden');
    final old = _asNum(cur.single['bestand_aktuell']) ?? 0;
    return setBestand(artikelId, old + delta, grund: grund);
  }

  Artikel _fromRow(Map<String, Object?> r) {
    return Artikel(
      id: _asInt(r['id']) ?? 0,
      bezeichnung: r['bezeichnung'] as String? ?? '',
      typ: r['typ'] as String? ?? 'Artikel',
      beschreibung: r['beschreibung'] as String?,
      einheit: r['einheit'] as String?,
      vkNetto: _asNum(r['vk_netto']) ?? 0,
      vkBrutto: _asNum(r['vk_brutto']) ?? 0,
      vkEingabe: r['vk_eingabe'] as String? ?? 'brutto',
      ustSatzId: _asInt(r['ust_satz_id']),
      ustSatz: _asNum(r['ust_satz']),
      differenzbesteuerung: _asBool(r['differenzbesteuerung']),
      ekNetto: _asNum(r['ek_netto']),
      lagerAktiv: _asBool(r['lager_aktiv']),
      bestandAktuell: _asNum(r['bestand_aktuell']) ?? _asNum(r['bestand']) ?? 0,
      mindestbestand: _asNum(r['mindestbestand']) ?? 0,
      minusbestandErlaubt: _asBool(r['minusbestand_erlaubt']),
      lieferantId: _asInt(r['lieferant_id']),
      lieferantenArtikelnr: r['lieferanten_artikelnr'] as String?,
      gruppeId: _asInt(r['gruppe_id']),
      artikelnummer: r['artikelnummer'] as String?,
      aktiv: _asBool(r['aktiv']),
    );
  }

  static num? _asNum(Object? v) => v is num
      ? v
      : v is String
      ? num.tryParse(v)
      : null;
  static int? _asInt(Object? v) => _asNum(v)?.toInt();
  static bool _asBool(Object? v) => v is bool
      ? v
      : v is num
      ? v != 0
      : v == '1' || v == 'true';
}

class _NoopUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 0;
  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
