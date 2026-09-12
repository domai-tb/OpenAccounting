import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:openaccounting/features/accounting/eks_entity.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;

/// Anlage EKS 9-page for Jobcenter Transferleistungen.
/// Customer-scoped reports resolve the customer before reading any journal row;
/// an omitted filter remains explicit in the result.
class EksException implements Exception {
  const EksException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'EksException: $message';
}

class EksService {
  EksService(this.executor);

  final QueryExecutor executor;

  Future<EksResult> generate({required int jahr, int? kundeId}) async {
    await _ensureEksColumns();

    if (kundeId != null) {
      if (kundeId <= 0) {
        throw const EksException('Kunde für EKS muss eine positive ID haben');
      }
      final List<Map<String, Object?>> customerRows = await executor.runSelect(
        'SELECT id FROM kunden WHERE id = ? LIMIT 1',
        <Object?>[kundeId],
      );
      if (customerRows.isEmpty) {
        throw EksException('Kunde $kundeId für EKS nicht gefunden');
      }
    }

    final String jahrStr = jahr.toString().padLeft(4, '0');
    final List<String> warnings = <String>[];

    // Section D — unternehmen 1 row
    String berufsbezeichnung = '';
    String kammer = '';
    String geburtsdatum = '';
    String bgNummer = '';
    String jobcenter = '';

    try {
      final List<Map<String, Object?>> uRows = await executor.runSelect(
        'SELECT * FROM unternehmen LIMIT 1',
        const <Object?>[],
      );
      if (uRows.isNotEmpty) {
        final Map<String, Object?> r = uRows.first;
        berufsbezeichnung = _stringOrEmpty(r, 'berufsbezeichnung');
        kammer = _stringOrEmpty(r, 'kammer_mitgliedschaft');
        // fallback kammer column naming
        if (kammer.isEmpty) {
          kammer = _stringOrEmpty(r, 'kammer');
        }
        geburtsdatum = _stringOrEmpty(r, 'geburtsdatum');
        bgNummer = _stringOrEmpty(r, 'bg_nummer');
        // fallback bg fields
        if (bgNummer.isEmpty) {
          bgNummer = _stringOrEmpty(r, 'bgNummer');
        }
        jobcenter = _stringOrEmpty(r, 'jobcenter_name');
        if (jobcenter.isEmpty) {
          jobcenter = _stringOrEmpty(r, 'jobcenter');
        }
      } else {
        warnings.add('EKS warn: unternehmen empty');
        debugPrint('EKS warn: unternehmen empty');
      }
    } catch (error, stackTrace) {
      // fail-closed: missing unternehmen table is not an empty report
      Error.throwWithStackTrace(EksException('EKS: unternehmen konnte nicht gelesen werden', error), stackTrace);
    }

    if (bgNummer.trim().isEmpty) {
      const String msg = 'EKS warn: missing bg_nummer';
      warnings.add(msg);
      debugPrint(msg);
    }
    if (jobcenter.trim().isEmpty) {
      const String msg = 'EKS warn: missing jobcenter_name';
      warnings.add(msg);
      debugPrint(msg);
    }

    // Kategorien eks_kategorie map — fail-closed if table missing
    final Map<int, String> katMap = <int, String>{};
    try {
      final List<Map<String, Object?>> kRows = await executor.runSelect(
        'SELECT id, eks_kategorie FROM kategorien',
        const <Object?>[],
      );
      for (final Map<String, Object?> r in kRows) {
        final int? id = (r['id'] as num?)?.toInt();
        final String? eks = r['eks_kategorie'] as String?;
        if (id != null && eks != null && eks.trim().isNotEmpty) {
          katMap[id] = eks.trim();
        }
      }
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(EksException('EKS: kategorien konnte nicht gelesen werden', error), stackTrace);
    }

    // Journal rows — scoped to ownership
    final List<Map<String, Object?>> journalRows = await _fetchJournalRows(kundeId: kundeId);

    // Filter by year and build sectionF + income/costs + b6_5
    final Map<String, String> sectionF = <String, String>{};
    int totalIncomeCents = 0;
    int totalCostsBetragCents = 0;
    int b65Cents = 0;

    for (final Map<String, Object?> row in journalRows) {
      final String? datumRaw = row['datum'] as String?;
      if (datumRaw == null || datumRaw.length < 4) {
        continue;
      }
      if (!datumRaw.startsWith(jahrStr)) {
        continue;
      }
      final int? kId = (row['kategorie_id'] as num?)?.toInt();
      final String? eksKat = kId != null ? katMap[kId] : null;
      final String betragRaw = row['betrag']?.toString() ?? '0.00';
      final String betragStr = money.formatBetrag(betragRaw);
      final int betragCents = money.toCents(betragStr);
      final String art = row['beleg_typ'] as String? ?? row['art'] as String? ?? '';

      // Section F Zeilen 23-41 — only F23-41 per Anlage EKS.
      if (eksKat != null && eksKat.isNotEmpty) {
        if (_isFLine(eksKat)) {
          final String current = sectionF[eksKat] ?? '0.00';
          sectionF[eksKat] = money.add(current, betragStr);
        } else {
          // ponytail: non-F (e.g. B6_5) not in Section F — handled via b6_*.
          debugPrint('EKS skip non-F eks_kategorie: $eksKat');
        }
      }

      // Income / costs via art
      final bool isEinnahme = art.toLowerCase() == 'einnahme';
      final bool isAusgabe = art.toLowerCase() == 'ausgabe';
      if (isEinnahme) {
        if (eksKat != null) {
          totalIncomeCents += betragCents;
        }
      } else if (isAusgabe) {
        if (eksKat != null) {
          totalCostsBetragCents += betragCents;
        }
      }

      // B6_5 km_anzahl *0.10
      final String? kmRaw = _stringOrNull(row, 'km_anzahl');
      if (kmRaw != null && kmRaw.trim().isNotEmpty) {
        // Keep B6_5 comma handling: "1,5" -> "1.5"
        final String kmTrim = kmRaw.trim().replaceAll(',', '.');
        final String kmFormatted = money.formatBetrag(kmTrim);
        final int kmCents = money.toCents(kmFormatted);
        // travel cents = kmCents /10 with rounding (km*0.10)
        final int travel = (kmCents + 5) ~/ 10;
        b65Cents += travel;
      }
    }

    // B6_4_priv via anlageverzeichnis — ownership scoped, fail-closed
    int b64PrivCents = 0;
    try {
      // Ownership scope: if kundeId provided and anlage has owner column, filter; otherwise scoped report excludes private assets to avoid cross-owner leak.
      // ponytail: assets have no kunde_id in baseline schema — scoped report returns 0 for B6_4_priv to stay owner-isolated; add kunde_id column to anlageverzeichnis to enable per-customer KFZ.
      final Set<String> anlageCols = await _tableColumns('anlageverzeichnis');
      final bool hasKundeCol = anlageCols.contains('kunde_id');
      final bool hasOwnerCol = anlageCols.contains('owner_id') || anlageCols.contains('inhaber_id');
      if (kundeId != null && !hasKundeCol && !hasOwnerCol) {
        // Fail-closed ownership: do not leak all-customer assets into scoped report.
        b64PrivCents = 0;
        if (anlageCols.isNotEmpty) {
          debugPrint('EKS: scoped kundeId=$kundeId but anlageverzeichnis has no owner column — B6_4_priv excluded');
        }
      } else {
        final String select =
            'SELECT anschaffungskosten, nutzungsdauer, privatanteil, '
            'status, bezeichnung, anschaffungsdatum '
            'FROM anlageverzeichnis'
            '${kundeId != null && hasKundeCol ? ' WHERE kunde_id = ?' : ''}';
        final List<Object?> args = kundeId != null && hasKundeCol ? <Object?>[kundeId] : const <Object?>[];
        final List<Map<String, Object?>> avRows = await executor.runSelect(select, args);
        for (final Map<String, Object?> r in avRows) {
          final String? statusRaw = r['status'] as String?;
          final String status = (statusRaw ?? 'aktiv').toLowerCase();
          if (status == 'inaktiv' || status == 'verkauft') {
            continue;
          }
          // Optional date filter: skip assets acquired after jahr
          final String? datumRaw = r['anschaffungsdatum'] as String?;
          if (datumRaw != null && datumRaw.length >= 4) {
            final int? anschaffJahr = int.tryParse(datumRaw.substring(0, 4));
            if (anschaffJahr != null && anschaffJahr > jahr) {
              continue;
            }
          }
          final String kostenRaw = r['anschaffungskosten']?.toString() ?? '0.00';
          final int kostenCents = money.toCents(money.formatBetrag(kostenRaw));
          if (kostenCents == 0) {
            continue;
          }
          final String privatRaw = r['privatanteil']?.toString() ?? r['privat_anteil_prozent']?.toString() ?? '0';
          final String privatFormatted = money.formatBetrag(privatRaw);
          final int privatCents = money.toCents(privatFormatted); // percent*100
          if (privatCents <= 0) {
            continue;
          }
          final int nutz = (r['nutzungsdauer'] as num?)?.toInt() ?? 0;
          final int baseCents;
          if (nutz > 0) {
            baseCents = kostenCents ~/ nutz;
          } else {
            baseCents = kostenCents;
          }
          // deduction = base * privat% = base * privatCents /10000
          final int deduction = (baseCents * privatCents) ~/ 10000;
          b64PrivCents += deduction;
        }
      }
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(EksException('EKS: anlageverzeichnis konnte nicht gelesen werden', error), stackTrace);
    }

    // Also try eks_einstellungen / schnellbuchungen fetch — fail-closed if table expected but missing column is tolerated only for optional tables
    // These are optional config tables; missing table now fails closed to surface DDL drift.
    try {
      await executor.runSelect('SELECT * FROM eks_einstellungen LIMIT 1', const <Object?>[]);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(EksException('EKS: eks_einstellungen konnte nicht gelesen werden', error), stackTrace);
    }
    try {
      await executor.runSelect('SELECT * FROM schnellbuchungen LIMIT 5', const <Object?>[]);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(EksException('EKS: schnellbuchungen konnte nicht gelesen werden', error), stackTrace);
    }

    // Page9 summary: income/costs/net
    // totalCosts includes betrag costs + B6_5 + B6_4_priv per spec B6 lines
    final int totalCostsCents = totalCostsBetragCents + b65Cents + b64PrivCents;
    final int netCents = totalIncomeCents - totalCostsCents;

    final String b65Str = money.fromCents(b65Cents);
    final String b64Str = money.fromCents(b64PrivCents);

    final EksSectionD sectionD = EksSectionD(
      berufsbezeichnung: berufsbezeichnung,
      kammerMitgliedschaft: kammer,
      geburtsdatum: geburtsdatum,
      bgNummer: bgNummer,
      jobcenterName: jobcenter,
    );

    final EksPage9 page9 = EksPage9(
      totalIncome: money.fromCents(totalIncomeCents),
      totalCosts: money.fromCents(totalCostsCents),
      netResult: money.fromCents(netCents),
    );

    return EksResult(
      jahr: jahr,
      kundeId: kundeId,
      isUnscoped: kundeId == null,
      sectionD: sectionD,
      sectionF: sectionF,
      b6_5: b65Str,
      b6_4_priv: b64Str,
      page9: page9,
      warnings: warnings,
    );
  }

  Future<List<Map<String, Object?>>> _fetchJournalRows({int? kundeId}) async {
    try {
      if (kundeId == null) {
        return await executor.runSelect('SELECT * FROM journal', const <Object?>[]);
      }
      final Set<String> journalCols = await _tableColumns('journal');
      final bool hasJournalCustomer = journalCols.contains('kunde_id');
      final String customerPredicate = hasJournalCustomer ? '(j.kunde_id = ? OR r.kunde_id = ?)' : 'r.kunde_id = ?';
      final List<Object?> args = hasJournalCustomer ? <Object?>[kundeId, kundeId] : <Object?>[kundeId];
      return await executor.runSelect(
        'SELECT j.* FROM journal j LEFT JOIN rechnungen r ON r.id = j.rechnung_id WHERE $customerPredicate',
        args,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(EksException('Buchungen konnten für EKS nicht gelesen werden', error), stackTrace);
    }
  }

  Future<Set<String>> _tableColumns(String table) async {
    final List<Map<String, Object?>> rows = await executor.runSelect('PRAGMA table_info($table)', const <Object?>[]);
    // PRAGMA returns empty for missing table — fail-closed instead of empty success
    // Detect missing table via sqlite_master
    if (rows.isEmpty) {
      final List<Map<String, Object?>> exists = await executor.runSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
        <Object?>[table],
      );
      if (exists.isEmpty) {
        throw EksException('EKS: Tabelle $table fehlt');
      }
    }
    return <String>{for (final Map<String, Object?> r in rows) r['name'].toString()};
  }

  Future<void> _ensureEksColumns() async {
    // unternehmen — fail-closed on DDL
    final Set<String> uNames = await _tableColumns('unternehmen');
    if (!uNames.contains('berufsbezeichnung')) {
      await executor.runCustom('ALTER TABLE unternehmen ADD COLUMN berufsbezeichnung TEXT');
    }
    if (!uNames.contains('kammer_mitgliedschaft')) {
      await executor.runCustom('ALTER TABLE unternehmen ADD COLUMN kammer_mitgliedschaft TEXT');
    }
    if (!uNames.contains('geburtsdatum')) {
      await executor.runCustom('ALTER TABLE unternehmen ADD COLUMN geburtsdatum TEXT');
    }
    if (!uNames.contains('bg_nummer')) {
      await executor.runCustom('ALTER TABLE unternehmen ADD COLUMN bg_nummer TEXT');
    }
    if (!uNames.contains('jobcenter_name')) {
      await executor.runCustom('ALTER TABLE unternehmen ADD COLUMN jobcenter_name TEXT');
    }
    if (!uNames.contains('jobcenter')) {
      await executor.runCustom('ALTER TABLE unternehmen ADD COLUMN jobcenter TEXT');
    }
    // kategorien
    final Set<String> kNames = await _tableColumns('kategorien');
    if (!kNames.contains('eks_kategorie')) {
      await executor.runCustom('ALTER TABLE kategorien ADD COLUMN eks_kategorie TEXT');
    }
    // journal
    final Set<String> jNames = await _tableColumns('journal');
    if (!jNames.contains('km_anzahl')) {
      await executor.runCustom('ALTER TABLE journal ADD COLUMN km_anzahl NUMERIC(12,2)');
    }
  }
}

bool _isFLine(String eks) {
  final String t = eks.trim().toUpperCase();
  if (t.startsWith('F')) {
    final String numPart = t.substring(1);
    final int? n = int.tryParse(numPart);
    if (n != null && n >= 23 && n <= 41) {
      return true;
    }
  }
  final int? n = int.tryParse(t);
  if (n != null && n >= 23 && n <= 41) {
    return true;
  }
  return false;
}

String _stringOrEmpty(Map<String, Object?> row, String key) {
  if (!row.containsKey(key)) {
    return '';
  }
  final Object? v = row[key];
  if (v == null) {
    return '';
  }
  return v.toString().trim();
}

String? _stringOrNull(Map<String, Object?> row, String key) {
  if (!row.containsKey(key)) {
    return null;
  }
  final Object? v = row[key];
  if (v == null) {
    return null;
  }
  final String s = v.toString();
  if (s.trim().isEmpty) {
    return null;
  }
  return s;
}
