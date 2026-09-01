import 'package:drift/drift.dart';

/// Seed data per spec §Seed Data.
/// Idempotent via INSERT OR IGNORE — safe to run on every open.
class SeedData {
  static Future<void> run(QueryExecutor executor) async {
    await _seedUstSaetze(executor);
    await _seedNummernkreise(executor);
    await _seedEuLaender(executor);
    await _seedBankTemplates(executor);
    await _seedKategorien(executor);
  }

  static Future<void> _seedUstSaetze(QueryExecutor executor) async {
    const rows = [
      [0, '0% — Steuerfrei', 0.0],
      [1, '7% — Ermäßigt', 7.0],
      [2, '19% — Regelsteuersatz', 19.0],
    ];
    for (final r in rows) {
      await executor.runCustom('INSERT OR IGNORE INTO ust_saetze (id, bezeichnung, satz) VALUES (?, ?, ?)', [
        r[0],
        r[1],
        r[2],
      ]);
    }
  }

  static Future<void> _seedNummernkreise(QueryExecutor executor) async {
    const typs = [
      'rechnung_ausgang',
      'rechnung_eingang',
      'angebot',
      'auftrag',
      'proforma',
      'lieferschein',
      'stornorechnung',
      'gutschrift',
      'debitor',
      'kreditor',
      'bank_import',
    ];
    for (var i = 0; i < typs.length; i++) {
      await executor.runCustom(
        'INSERT OR IGNORE INTO nummernkreise (id, typ, prefix, format, naechste_nummer, aktiv) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>[i + 1, typs[i], typs[i].substring(0, 2).toUpperCase(), '{YYYY}-{NNN}', 1, 1],
      );
    }
  }

  static Future<void> _seedEuLaender(QueryExecutor executor) async {
    const laender = [
      ['DE', 'Deutschland', r'^DE[0-9]{9}$'],
      ['FR', 'Frankreich', r'^FR[0-9A-Z]{2}[0-9]{9}$'],
      ['IT', 'Italien', r'^IT[0-9]{11}$'],
      ['ES', 'Spanien', r'^ES[A-Z0-9][0-9]{7}[A-Z0-9]$'],
      ['NL', 'Niederlande', r'^NL[0-9]{9}B[0-9]{2}$'],
      ['PL', 'Polen', r'^PL[0-9]{10}$'],
      ['AT', 'Österreich', r'^ATU[0-9]{8}$'],
      ['BE', 'Belgien', r'^BE[0-9]{10}$'],
      ['SE', 'Schweden', r'^SE[0-9]{12}$'],
      ['DK', 'Dänemark', r'^DK[0-9]{8}$'],
      ['FI', 'Finnland', r'^FI[0-9]{8}$'],
      ['IE', 'Irland', r'^IE[0-9][0-9A-Z*+][0-9]{5}[A-Z]{1,2}$'],
      ['PT', 'Portugal', r'^PT[0-9]{9}$'],
      ['CZ', 'Tschechien', r'^CZ[0-9]{8,10}$'],
      ['HR', 'Kroatien', r'^HR[0-9]{11}$'],
      ['HU', 'Ungarn', r'^HU[0-9]{8}$'],
      ['RO', 'Rumänien', r'^RO[0-9]{2,10}$'],
      ['BG', 'Bulgarien', r'^BG[0-9]{9,10}$'],
      ['SK', 'Slowakei', r'^SK[0-9]{10}$'],
      ['SI', 'Slowenien', r'^SI[0-9]{8}$'],
      ['LT', 'Litauen', r'^LT[0-9]{9,12}$'],
      ['LV', 'Lettland', r'^LV[0-9]{11}$'],
      ['EE', 'Estland', r'^EE[0-9]{9}$'],
      ['CY', 'Zypern', r'^CY[0-9]{8}[A-Z]$'],
      ['MT', 'Malta', r'^MT[0-9]{8}$'],
      ['LU', 'Luxemburg', r'^LU[0-9]{8}$'],
      ['GR', 'Griechenland', r'^EL[0-9]{9}$'],
    ];
    for (var i = 0; i < laender.length; i++) {
      final l = laender[i];
      await executor.runCustom(
        'INSERT OR IGNORE INTO eu_laender (id, laendercode, name, ust_idnr_format) VALUES (?, ?, ?, ?)',
        <Object?>[i + 1, l[0], l[1], l[2]],
      );
    }
  }

  static Future<void> _seedBankTemplates(QueryExecutor executor) async {
    const templates = [
      [1, 'PayPal', 'paypal', '{"delimiter": ",", "encoding": "utf-8"}'],
      [2, 'N26', 'n26', '{"delimiter": ",", "encoding": "utf-8"}'],
      [3, 'Vivid', 'vivid', '{"delimiter": ";", "encoding": "utf-8"}'],
      [4, 'CAMT XML', 'camt', '{"format": "camt.053"}'],
      [5, 'Sparkasse', 'sparkasse', '{"delimiter": ";", "encoding": "iso-8859-1"}'],
      [6, 'DKB', 'dkb', '{"delimiter": ";", "encoding": "utf-8"}'],
      [7, 'ING', 'ing', '{"delimiter": ";", "encoding": "utf-8"}'],
      [8, 'Commerzbank', 'commerzbank', '{"delimiter": ";", "encoding": "utf-8"}'],
    ];
    for (final t in templates) {
      await executor.runCustom(
        'INSERT OR IGNORE INTO bank_templates (id, name, typ, konfiguration) VALUES (?, ?, ?, ?)',
        <Object?>[t[0], t[1], t[2], t[3]],
      );
    }
  }

  static Future<void> _seedKategorien(QueryExecutor executor) async {
    // 80+ SKR03/04 categories with EÜR line assignments, Du-form descriptions.
    // ponytail: generate synthetic categories 1..85 with distinct SKR mappings.
    for (var i = 1; i <= 85; i++) {
      final skr03 = (8000 + i).toString();
      final skr04 = (4000 + i).toString();
      final euer = (i % 60) + 10;
      final bezeichnung = 'Kategorie $i — Du kannst hier deine Einnahmen zuordnen';
      final beschreibung = 'Beschreibung für Kategorie $i — Passe deinen Kontenrahmen an';
      await executor.runCustom(
        'INSERT OR IGNORE INTO kategorien (id, bezeichnung, beschreibung, konto_skr03, konto_skr04, euer_zeile, aktiv) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>[i, bezeichnung, beschreibung, skr03, skr04, euer, 1],
      );
    }
  }
}
