import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/accounting/reporting/report_workspace_result.dart';

/// Configured DATEV header values that have no profile storage yet.
///
/// shortcut: Sachkontenlänge, chart code and BU-Schlüssel mapping are passed
/// by the caller because no accepted profile fields exist; move them to
/// profile storage once the DATEV master-data contract is accepted.
class DatevExportConfig {
  const DatevExportConfig({required this.sachkontenlaenge, required this.chartCode, required this.buSchluessel});

  /// Configured Sachkontenlänge ('3'..'10').
  final String sachkontenlaenge;

  /// Supported chart code ('03' or '04').
  final String chartCode;

  /// Explicit tax key per source tax treatment (ust_satz → BU-Schlüssel).
  final Map<String, String> buSchluessel;
}

/// Immutable validated DATEV EXTF artifact: the CSV plus the pinned versions.
class DatevExportArtifact {
  const DatevExportArtifact({
    required this.month,
    required this.csv,
    required this.headerVersion,
    required this.formatVersion,
    required this.bookingRowCount,
  });

  /// One calendar month per EXTF file, 'YYYY-MM'.
  final String month;

  final String csv;

  /// Pinned header version 700 (category 21, Buchungsstapel).
  static const int pinnedHeaderVersion = 700;
  static const int pinnedFormatVersion = 13;

  final int headerVersion;
  final int formatVersion;
  final int bookingRowCount;
}

/// Typed owner for `/reports?report=datev&month=YYYY-MM` (design.md).
///
/// Produces only the pinned v13 Buchungsstapel CSV: 31 header positions,
/// 125 booking-row positions, fail-closed on any missing required config or
/// source mapping. No fallback account, guessed tax key or fabricated
/// partner/document value is ever emitted.
class DatevExportUseCase {
  DatevExportUseCase(this.executor);

  final QueryExecutor executor;

  static const Set<String> _sachkontenlaengen = <String>{'3', '4', '5', '6', '7', '8', '9', '10'};
  static const Set<String> _chartCodes = <String>{'03', '04'};

  Future<ReportWorkspaceResult<DatevExportArtifact>> create({
    required String month,
    required DatevExportConfig config,
    DateTime? generatedAt,
  }) async {
    final RegExpMatch? m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(month.trim());
    if (m == null || int.parse(m.group(2)!) < 1 || int.parse(m.group(2)!) > 12) {
      return const ReportWorkspaceResult<DatevExportArtifact>.invalidSelection('invalidPeriod');
    }
    final int year = int.parse(m.group(1)!);
    final int mon = int.parse(m.group(2)!);

    if (!_sachkontenlaengen.contains(config.sachkontenlaenge)) {
      return const ReportWorkspaceResult<DatevExportArtifact>.unavailable('missingCompanyConfig: sachkontenlaenge');
    }
    if (!_chartCodes.contains(config.chartCode)) {
      return const ReportWorkspaceResult<DatevExportArtifact>.unavailable('missingCompanyConfig: chartCode');
    }

    final List<Map<String, Object?>> uRows = await executor.runSelect(
      'SELECT datev_beraternummer, datev_mandantennummer FROM unternehmen LIMIT 1',
      const <Object?>[],
    );
    final String berater = uRows.isEmpty ? '' : (uRows.first['datev_beraternummer']?.toString() ?? '').trim();
    final String mandant = uRows.isEmpty ? '' : (uRows.first['datev_mandantennummer']?.toString() ?? '').trim();
    if (berater.isEmpty) {
      return const ReportWorkspaceResult<DatevExportArtifact>.unavailable('missingCompanyConfig: datev_beraternummer');
    }
    if (mandant.isEmpty) {
      return const ReportWorkspaceResult<DatevExportArtifact>.unavailable(
        'missingCompanyConfig: datev_mandantennummer',
      );
    }

    // Accepted balanced-posting records for the month only; legacy rows
    // outside the posting contract are not export candidates.
    final List<Map<String, Object?>> candidates = await executor.runSelect(
      'SELECT id, datum, betrag, beleg_nr, beschreibung, soll_konto_id, haben_konto_id, ust_satz, rechnung_id '
      "FROM journal WHERE source_kind IS NOT NULL AND datum LIKE '$month-%' ORDER BY id",
      const <Object?>[],
    );

    final List<List<String>> rows = <List<String>>[];
    for (final Map<String, Object?> j in candidates) {
      final int id = (j['id']! as num).toInt();
      final String? belegNr = j['beleg_nr']?.toString();
      if (belegNr == null || belegNr.trim().isEmpty) {
        return ReportWorkspaceResult<DatevExportArtifact>.unavailable('missingSourceIdentity: journal $id, belegfeld1');
      }
      final Object? soll = j['soll_konto_id'];
      final Object? haben = j['haben_konto_id'];
      if (soll == null || haben == null) {
        return ReportWorkspaceResult<DatevExportArtifact>.unavailable('missingSourceMapping: journal $id, Konto');
      }
      final int sollId = int.parse(soll.toString());
      final int habenId = int.parse(haben.toString());
      final Map<String, String> konto = await _datevKonten(<int>[sollId, habenId]);
      final String kontoNr = konto[sollId.toString()] ?? '';
      final String gegenNr = konto[habenId.toString()] ?? '';
      if (kontoNr.isEmpty || gegenNr.isEmpty) {
        return ReportWorkspaceResult<DatevExportArtifact>.unavailable('missingSourceMapping: journal $id, Konto');
      }
      final String ustSatz = j['ust_satz']?.toString() ?? '';
      final String? buKey = config.buSchluessel[ustSatz];
      if (buKey == null || buKey.isEmpty) {
        return ReportWorkspaceResult<DatevExportArtifact>.unavailable('missingTaxKey: journal $id, buSchluessel');
      }
      if (j['rechnung_id'] != null) {
        // No DATEV-supported persisted document-link representation is
        // accepted yet; a local file path is not a DATEV link.
        return ReportWorkspaceResult<DatevExportArtifact>.unavailable('missingDocumentLink: journal $id, beleglink');
      }
      final int cents = money.parseScaled(j['betrag']?.toString() ?? '', scale: 2, allowNegative: false);
      if (cents <= 0) {
        return ReportWorkspaceResult<DatevExportArtifact>.unavailable('missingSourceField: journal $id, umsatz');
      }
      final String datum = j['datum']?.toString() ?? '';
      final String belegdatum = datum.length >= 10 ? '${datum.substring(8, 10)}${datum.substring(5, 7)}' : '';
      if (belegdatum.isEmpty) {
        return ReportWorkspaceResult<DatevExportArtifact>.unavailable('missingSourceField: journal $id, belegdatum');
      }
      rows.add(
        _bookingRow(
          umsatz: cents,
          konto: kontoNr,
          gegenkonto: gegenNr,
          buSchluessel: buKey,
          belegdatum: belegdatum,
          belegfeld1: belegNr,
          buchungstext: j['beschreibung']?.toString() ?? '',
        ),
      );
    }

    final DateTime bis = DateTime(year, mon + 1, 0);
    final String mm = mon.toString().padLeft(2, '0');
    final String lastDd = bis.day.toString().padLeft(2, '0');
    final List<String> header = _header(
      berater: berater,
      mandant: mandant,
      jahr: year,
      von: '$year${mm}01',
      bis: '$year$mm$lastDd',
      sachkontenlaenge: config.sachkontenlaenge,
      chartCode: config.chartCode,
      generatedAt: generatedAt ?? DateTime.now(),
      label: 'Buchungsstapel $month',
    );

    final String csv = <String>[header.join(';'), for (final List<String> r in rows) r.join(';')].join('\r\n');

    return ReportWorkspaceResult<DatevExportArtifact>.available(
      DatevExportArtifact(
        month: month,
        csv: csv,
        headerVersion: DatevExportArtifact.pinnedHeaderVersion,
        formatVersion: DatevExportArtifact.pinnedFormatVersion,
        bookingRowCount: rows.length,
      ),
    );
  }

  Future<Map<String, String>> _datevKonten(List<int> ids) async {
    final String inList = ids.join(', ');
    final List<Map<String, Object?>> rs = await executor.runSelect(
      'SELECT id, datev_kontonummer FROM konten WHERE id IN ($inList)',
      const <Object?>[],
    );
    return <String, String>{
      for (final Map<String, Object?> r in rs)
        (r['id']! as num).toInt().toString(): r['datev_kontonummer']?.toString() ?? '',
    };
  }

  /// Official 31-position v13 EXTF header.
  static List<String> _header({
    required String berater,
    required String mandant,
    required int jahr,
    required String von,
    required String bis,
    required String sachkontenlaenge,
    required String chartCode,
    required DateTime generatedAt,
    required String label,
  }) {
    final String ts =
        '${generatedAt.year.toString().padLeft(4, '0')}'
        '${generatedAt.month.toString().padLeft(2, '0')}'
        '${generatedAt.day.toString().padLeft(2, '0')}'
        '${generatedAt.hour.toString().padLeft(2, '0')}'
        '${generatedAt.minute.toString().padLeft(2, '0')}'
        '${generatedAt.second.toString().padLeft(2, '0')}'
        '${generatedAt.millisecond.toString().padLeft(3, '0')}';
    return <String>[
      'EXTF',
      '700',
      '21',
      'Buchungsstapel',
      '13',
      ts,
      '',
      'RE',
      '',
      '',
      berater,
      mandant,
      '${jahr}0101',
      sachkontenlaenge,
      von,
      bis,
      label,
      '',
      '1',
      '0',
      '0',
      'EUR',
      '',
      '',
      '',
      '',
      chartCode,
      '',
      '',
      '',
      '',
    ];
  }

  /// One v13 booking row: exactly 125 positions, unused fields blank.
  static List<String> _bookingRow({
    required int umsatz,
    required String konto,
    required String gegenkonto,
    required String buSchluessel,
    required String belegdatum,
    required String belegfeld1,
    required String buchungstext,
  }) {
    final List<String> row = List<String>.filled(125, '');
    final int euro = umsatz ~/ 100;
    final int cents = umsatz % 100;
    row[0] = '$euro,${cents.toString().padLeft(2, '0')}'; // 001 Umsatz.
    row[1] = 'S'; // 002 Soll/Haben for field 007.
    row[6] = konto; // 007 Konto.
    row[7] = gegenkonto; // 008 Gegenkonto.
    row[8] = buSchluessel; // 009 BU-Schlüssel.
    row[9] = belegdatum; // 010 Belegdatum TTMM.
    row[10] = belegfeld1; // 011 Belegfeld 1.
    row[13] = buchungstext; // 014 Buchungstext.
    return row;
  }
}
