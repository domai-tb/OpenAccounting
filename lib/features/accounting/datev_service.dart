import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:openaccounting/features/accounting/datev_entity.dart';

/// DATEV EXTF Buchungsstapel export per spec §DATEV EXTF Export.
/// ponytail: executor-injected, pure string money, semicolon CSV,
/// German DD.MM.YYYY + comma.
/// ponytail: ALTER stub for missing columns — unternehmen
/// datev_beraternummer/datev_mandantennummer/datev_konto_bank,
/// konten datev_kontonummer.
/// ponytail: global executor lock ceiling — per-call if throughput matters.
class DatevService {
  DatevService(this.executor);

  final QueryExecutor executor;

  /// Export DATEV EXTF CSV as String.
  /// [jahr] filters journal by year, [von]/[bis] by inclusive date range.
  /// [kontoBankFallback] overrides global unternehmen.datev_konto_bank.
  /// Throws [DatevException] if datev_beraternummer or mandantennummer missing.
  Future<String> exportCsv({int? jahr, DateTime? von, DateTime? bis, String? kontoBankFallback}) async {
    await _ensureDatevColumns();

    // --- Unternehmen metadata ---
    final List<Map<String, Object?>> uRows = await executor.runSelect(
      'SELECT * FROM unternehmen LIMIT 1',
      const <Object?>[],
    );
    if (uRows.isEmpty) {
      throw const DatevException(
        'Missing DATEV config: unternehmen not found — '
        'datev_beraternummer/datev_mandantennummer required',
      );
    }
    final Map<String, Object?> u = uRows.first;
    final String berater = _unternehmenField(u, <String>['datev_beraternummer']);
    final String mandant = _unternehmenField(u, <String>['datev_mandantennummer']);
    if (berater.trim().isEmpty || mandant.trim().isEmpty) {
      debugPrint('DATEV warn: missing berater/mandant berater=$berater mandant=$mandant');
      throw DatevException(
        'Missing DATEV config: datev_beraternummer=${berater.isEmpty ? 'NULL' : berater} '
        'datev_mandantennummer=${mandant.isEmpty ? 'NULL' : mandant} — both required',
      );
    }
    final String globalBankRaw = kontoBankFallback?.trim().isNotEmpty == true
        ? kontoBankFallback!.trim()
        : _unternehmenField(u, <String>['datev_konto_bank', 'konto_bank', 'datev_konto', 'datev_kontonummer']);
    final String globalBank = globalBankRaw.trim();

    // --- Kategorieliste ---
    final Map<int, _KatInfo> katMap = <int, _KatInfo>{};
    try {
      final List<Map<String, Object?>> kRows = await executor.runSelect(
        'SELECT id, konto_skr03, konto_skr04 FROM kategorien',
        const <Object?>[],
      );
      for (final Map<String, Object?> r in kRows) {
        final int? id = (r['id'] as num?)?.toInt();
        if (id == null) continue;
        katMap[id] = _KatInfo(
          skr03: (r['konto_skr03'] as String?)?.trim() ?? '',
          skr04: (r['konto_skr04'] as String?)?.trim() ?? '',
        );
      }
    } catch (_) {
      // keep empty — fallback handled per row
    }

    // --- Konten datev_kontonummer ---
    final Map<int, String> kontenMap = <int, String>{};
    try {
      final List<Map<String, Object?>> koRows = await executor.runSelect(
        'SELECT id, datev_kontonummer FROM konten',
        const <Object?>[],
      );
      for (final Map<String, Object?> r in koRows) {
        final int? id = (r['id'] as num?)?.toInt();
        final String? nr = r['datev_kontonummer'] as String?;
        if (id != null && nr != null && nr.trim().isNotEmpty) {
          kontenMap[id] = nr.trim();
        }
      }
    } catch (_) {
      // ponytail stub: table may lack column before ensure — retry via PRAGMA handled in ensure
    }

    // --- Journal rows ---
    final List<Map<String, Object?>> allRows = await _fetchJournalRows();
    final List<Map<String, Object?>> filtered = allRows.where((Map<String, Object?> row) {
      final String? datumRaw = row['datum'] as String?;
      return _inPeriod(datumRaw, jahr: jahr, von: von, bis: bis);
    }).toList();

    // --- Header ---
    final DateTime now = DateTime.now();
    final String headerVon;
    if (von != null) {
      headerVon = _formatDdMmYyyy(_formatDateIso(von));
    } else if (jahr != null) {
      headerVon = '01.01.$jahr';
    } else {
      headerVon = _formatDdMmYyyy(_formatDateIso(DateTime(now.year)));
    }
    final String headerBis;
    if (bis != null) {
      headerBis = _formatDdMmYyyy(_formatDateIso(bis));
    } else if (jahr != null) {
      headerBis = '31.12.$jahr';
    } else {
      headerBis = _formatDdMmYyyy(_formatDateIso(DateTime(now.year, 12, 31)));
    }
    const String wjBegin = '0101';
    final String rawFirma = (u['name'] as String?)?.trim() ?? '';
    final String firmaName = rawFirma.isNotEmpty ? rawFirma : 'Firma';
    final List<String> headerFields = <String>[
      'EXTF',
      '700',
      '21',
      'Buchungsstapel',
      '7',
      wjBegin,
      '4',
      headerVon,
      headerBis,
      berater,
      mandant,
      jahr?.toString() ?? now.year.toString(),
      '1',
      '0',
      'EUR',
      firmaName,
      '',
    ];
    final String headerLine = headerFields.map(_escapeCsv).join(';');

    // Column header line (DATEV second header — minimal for stable encoding)
    final List<String> colHeader = <String>[
      'Umsatz (ohne Soll/Haben-Kz)',
      'Soll/Haben-Kennzeichen',
      'WKZ Umsatz',
      'Konto',
      'Gegenkonto (ohne BU-Schlüssel)',
      'BU-Schlüssel',
      'Belegdatum',
      'Belegfeld 1',
      'Buchungstext',
    ];
    final String colHeaderLine = colHeader.map(_escapeCsv).join(';');

    // --- Data lines ---
    final List<String> lines = <String>[headerLine, colHeaderLine];
    for (final Map<String, Object?> row in filtered) {
      final String betragRaw = row['betrag']?.toString() ?? '0.00';
      final String betragDe = _toGermanAmount(betragRaw);
      final String datumRaw = row['datum'] as String? ?? '';
      final String datumDe = _formatDdMmYyyy(datumRaw);
      final String bezeichnung =
          (row['beschreibung'] as String?)?.trim() ?? (row['bezeichnung'] as String?)?.trim() ?? '';
      final String belegNr = (row['beleg_nr'] as String?)?.trim() ?? '';
      final String art = (row['beleg_typ'] as String?)?.trim() ?? (row['art'] as String?)?.trim() ?? '';

      final int? kontoId = (row['konto_id'] as num?)?.toInt();
      final int? kategorieId = (row['kategorie_id'] as num?)?.toInt();
      final _KatInfo? kat = kategorieId != null ? katMap[kategorieId] : null;

      // Solver: konto = entry.konto_id?.datev_kontonummer ?? globalBankKonto ?? kategorien.konto_skr03
      String resolvedBank = '';
      if (kontoId != null && kontenMap[kontoId]?.isNotEmpty == true) {
        resolvedBank = kontenMap[kontoId]!;
      } else if (globalBank.isNotEmpty) {
        resolvedBank = globalBank;
      } else if (kat != null && kat.skr03.isNotEmpty) {
        resolvedBank = kat.skr03;
      } else {
        resolvedBank = '1200';
      }

      final String gegenkonto = (kat != null && kat.skr03.isNotEmpty) ? kat.skr03 : '8400';
      // guard: avoid Konto == Gegenkonto when global empty (both fell back to kat.skr03)
      if (globalBank.isEmpty && resolvedBank == gegenkonto) {
        resolvedBank = '1200';
        if (resolvedBank == gegenkonto) {
          // kat was 1200 — pick alternate bank to keep distinct
          resolvedBank = '1800';
        }
      }

      // Soll/Haben: Ausgabe=S, Einnahme=H (ponytail: deterministic per art)
      final String artLower = art.toLowerCase();
      String sh = 'H';
      if (artLower == 'ausgabe') {
        sh = 'S';
      } else if (artLower == 'einnahme') {
        sh = 'H';
      } else {
        // fallback from betrag sign
        final String t = betragRaw.trim();
        if (t.startsWith('-')) sh = 'S';
      }

      // Konto/Gegenkonto ordering: DATEV Konto vs Gegenkonto — bank vs sachkonto
      String kontoField;
      String gegenkontoField;
      if (artLower == 'ausgabe') {
        kontoField = gegenkonto;
        gegenkontoField = resolvedBank;
      } else {
        kontoField = resolvedBank;
        gegenkontoField = gegenkonto;
      }

      final List<String> fields = <String>[
        betragDe,
        sh,
        '',
        kontoField,
        gegenkontoField,
        '',
        datumDe,
        belegNr,
        bezeichnung,
      ];
      lines.add(fields.map(_escapeCsv).join(';'));
    }

    final String csv = lines.join('\r\n');

    // --- Export log ---
    try {
      final String vonStr;
      if (von != null) {
        vonStr = _formatDateIso(von);
      } else if (jahr != null) {
        vonStr = '$jahr-01-01';
      } else {
        vonStr = '';
      }
      final String bisStr;
      if (bis != null) {
        bisStr = _formatDateIso(bis);
      } else if (jahr != null) {
        bisStr = '$jahr-12-31';
      } else {
        bisStr = '';
      }
      final int? unternehmenId = (u['id'] as num?)?.toInt();
      final Object? vonVal = vonStr.isEmpty ? null : vonStr;
      final Object? bisVal = bisStr.isEmpty ? null : bisStr;
      const String insertLog =
          'INSERT INTO datev_export_log '
          '(datum, zeitraum_von, zeitraum_bis, anzahl_buchungen, '
          'datei_pfad, unternehmen_id, status) '
          'VALUES (?, ?, ?, ?, ?, ?, ?)';
      await executor.runInsert(insertLog, <Object?>[
        _formatDateIso(now),
        vonVal,
        bisVal,
        filtered.length,
        'memory_export.csv',
        unternehmenId,
        'erfolg',
      ]);
    } catch (_) {
      // ponytail: log failure must not break export
      debugPrint('DATEV warn: export_log insert failed');
    }

    return csv;
  }

  /// Alias per task description: export({jahr, von, bis}) → CSV String
  Future<String> export({int? jahr, DateTime? von, DateTime? bis, String? kontoBankFallback}) {
    return exportCsv(jahr: jahr, von: von, bis: bis, kontoBankFallback: kontoBankFallback);
  }

  Future<List<Map<String, Object?>>> _fetchJournalRows() async {
    try {
      return await executor.runSelect('SELECT * FROM journal', const <Object?>[]);
    } catch (_) {
      return <Map<String, Object?>>[];
    }
  }

  Future<void> _ensureDatevColumns() async {
    // unternehmen columns
    try {
      final List<Map<String, Object?>> uCols = await executor.runSelect(
        'PRAGMA table_info(unternehmen)',
        const <Object?>[],
      );
      final Set<String> uNames = <String>{for (final Map<String, Object?> r in uCols) r['name'].toString()};
      if (!uNames.contains('datev_beraternummer')) {
        await executor.runCustom('ALTER TABLE unternehmen ADD COLUMN datev_beraternummer TEXT');
      }
      if (!uNames.contains('datev_mandantennummer')) {
        await executor.runCustom('ALTER TABLE unternehmen ADD COLUMN datev_mandantennummer TEXT');
      }
      if (!uNames.contains('datev_konto_bank')) {
        await executor.runCustom('ALTER TABLE unternehmen ADD COLUMN datev_konto_bank TEXT');
      }
      if (!uNames.contains('datev_konto_bar')) {
        await executor.runCustom('ALTER TABLE unternehmen ADD COLUMN datev_konto_bar TEXT');
      }
    } catch (_) {}

    // konten datev_kontonummer
    try {
      final List<Map<String, Object?>> kCols = await executor.runSelect('PRAGMA table_info(konten)', const <Object?>[]);
      final Set<String> kNames = <String>{for (final Map<String, Object?> r in kCols) r['name'].toString()};
      if (!kNames.contains('datev_kontonummer')) {
        await executor.runCustom('ALTER TABLE konten ADD COLUMN datev_kontonummer TEXT');
      }
    } catch (_) {}

    // journal missing columns defensiv (ust etc already via migrations, but ensure datum/betrag exist)
    // no-op

    // datev_export_log ensure
    try {
      await executor.runSelect('SELECT 1 FROM datev_export_log LIMIT 1', const <Object?>[]);
    } catch (_) {
      try {
        await executor.runCustom(
          'CREATE TABLE IF NOT EXISTS datev_export_log '
          '(id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'datum TEXT DEFAULT CURRENT_TIMESTAMP, '
          'zeitraum_von TEXT, zeitraum_bis TEXT, '
          'anzahl_buchungen INTEGER DEFAULT 0, '
          'datei_pfad TEXT, '
          'unternehmen_id INTEGER REFERENCES unternehmen(id), '
          'status TEXT)',
        );
      } catch (_) {}
    }
  }
}

class _KatInfo {
  const _KatInfo({required this.skr03, required this.skr04});
  final String skr03;
  final String skr04;
}

String _unternehmenField(Map<String, Object?> row, List<String> keys) {
  for (final String k in keys) {
    if (row.containsKey(k)) {
      final Object? v = row[k];
      if (v != null) {
        final String s = v.toString();
        if (s.trim().isNotEmpty) return s.trim();
      }
    }
  }
  // case-insensitive fallback
  for (final String k in keys) {
    for (final MapEntry<String, Object?> e in row.entries) {
      if (e.key.toLowerCase() == k.toLowerCase()) {
        final Object? v = e.value;
        if (v != null) {
          final String s = v.toString();
          if (s.trim().isNotEmpty) return s.trim();
        }
      }
    }
  }
  return '';
}

bool _inPeriod(String? raw, {int? jahr, DateTime? von, DateTime? bis}) {
  if (raw == null || raw.isEmpty) return false;
  DateTime? dt;
  try {
    dt = DateTime.tryParse(raw);
  } catch (_) {}
  if (dt == null && raw.length >= 10) {
    try {
      dt = DateTime.tryParse(raw.substring(0, 10));
    } catch (_) {}
  }
  if (dt == null) return false;
  if (von != null && bis != null) {
    final DateTime v = DateTime(von.year, von.month, von.day);
    final DateTime b = DateTime(bis.year, bis.month, bis.day, 23, 59, 59);
    return !dt.isBefore(v) && !dt.isAfter(b);
  }
  if (von != null) {
    final DateTime v = DateTime(von.year, von.month, von.day);
    return !dt.isBefore(v);
  }
  if (bis != null) {
    final DateTime b = DateTime(bis.year, bis.month, bis.day, 23, 59, 59);
    return !dt.isAfter(b);
  }
  if (jahr != null) {
    return dt.year == jahr;
  }
  return true;
}

String _formatDateIso(DateTime d) {
  final String y = d.year.toString().padLeft(4, '0');
  final String m = d.month.toString().padLeft(2, '0');
  final String day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String _formatDdMmYyyy(String raw) {
  final String t = raw.trim();
  if (t.isEmpty) return '';
  // raw is ISO YYYY-MM-DD...
  if (t.length >= 10 && t[4] == '-' && t[7] == '-') {
    final String y = t.substring(0, 4);
    final String m = t.substring(5, 7);
    final String d = t.substring(8, 10);
    return '$d.$m.$y';
  }
  // already DD.MM.YYYY
  if (t.contains('.')) return t;
  // fallback try parse
  try {
    final DateTime? dt = DateTime.tryParse(t);
    if (dt != null) {
      final String y = dt.year.toString().padLeft(4, '0');
      final String m = dt.month.toString().padLeft(2, '0');
      final String d = dt.day.toString().padLeft(2, '0');
      return '$d.$m.$y';
    }
  } catch (_) {}
  return t;
}

String _toGermanAmount(String raw) {
  final String t = raw.trim();
  if (t.isEmpty) return '0,00';
  final bool isNeg = t.startsWith('-');
  final String unsigned = isNeg ? t.substring(1) : t;
  final List<String> parts = unsigned.split('.');
  final String intPartRaw = parts[0].isEmpty ? '0' : parts[0].replaceFirst(RegExp('^0+'), '');
  final String effInt = intPartRaw.isEmpty ? '0' : intPartRaw;
  final String decRaw = parts.length > 1 ? parts[1] : '';
  final String dec = '${decRaw}00'.substring(0, 2);
  final String german = '$effInt,$dec';
  return isNeg ? '-$german' : german;
}

String _escapeCsv(String field) {
  if (field.contains(';') || field.contains('"') || field.contains('\n') || field.contains('\r')) {
    final String esc = field.replaceAll('"', '""');
    return '"$esc"';
  }
  return field;
}
