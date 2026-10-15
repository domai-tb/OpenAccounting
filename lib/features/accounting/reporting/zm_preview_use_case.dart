import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/accounting/reporting/report_workspace_result.dart';

/// One recipient grouping of the ZM preview.
class ZmRecipientTotal {
  const ZmRecipientTotal({
    required this.ustIdNr,
    required this.memberState,
    required this.taxableBaseCents,
    required this.sourceRechnungIds,
  });

  final String ustIdNr;
  final String memberState;

  /// Summed taxable base in integer cents.
  final int taxableBaseCents;

  /// Source invoice ids linked to this total.
  final List<int> sourceRechnungIds;
}

/// Immutable ZM preview for one calendar month: recipient totals plus the
/// recorded §18a contract version and exact period.
class ZmPreview {
  const ZmPreview({
    required this.month,
    required this.periodStart,
    required this.periodEnd,
    required this.sourceContractVersion,
    required this.recipients,
    required this.noEligibleEvents,
  });

  /// Selected invoice-issue month 'YYYY-MM'.
  final String month;

  /// Exact period, start-inclusive end-exclusive ISO dates.
  final String periodStart;
  final String periodEnd;

  /// Accepted §18a UStG contract version recorded on the result.
  final String sourceContractVersion;

  final List<ZmRecipientTotal> recipients;

  /// True when the complete month contains no supported reportable supplies.
  final bool noEligibleEvents;

  /// A ZM preview is never an official filing artifact or submission.
  bool get isFilingArtifact => false;
}

/// Typed owner for `/taxes?report=zm&month=YYYY-MM` (design.md route table).
/// Supports only outgoing §6a(1) goods supplies; any potentially reportable
/// unsupported direction blocks the whole month instead of an empty report.
class ZmPreviewUseCase {
  ZmPreviewUseCase(this.executor);

  final QueryExecutor executor;

  static const String sourceContractVersion = 'ustg-18a-2026';

  /// EU-27 member-state codes ('EL' alternate for Greece accepted).
  static const Set<String> euMemberStates = <String>{
    'AT',
    'BE',
    'BG',
    'CY',
    'CZ',
    'DE',
    'DK',
    'EE',
    'ES',
    'FI',
    'FR',
    'GR',
    'EL',
    'HR',
    'HU',
    'IE',
    'IT',
    'LT',
    'LU',
    'LV',
    'MT',
    'NL',
    'PL',
    'PT',
    'RO',
    'SE',
    'SI',
    'SK',
  };

  Future<ReportWorkspaceResult<ZmPreview>> preview({required String month}) async {
    final RegExpMatch? m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(month.trim());
    if (m == null) {
      return const ReportWorkspaceResult<ZmPreview>.invalidSelection('invalidPeriod');
    }
    final int year = int.parse(m.group(1)!);
    final int mon = int.parse(m.group(2)!);
    if (mon < 1 || mon > 12) {
      return const ReportWorkspaceResult<ZmPreview>.invalidSelection('invalidPeriod');
    }
    final String periodStart = '$year-${mon.toString().padLeft(2, '0')}-01';
    final String periodEnd = mon == 12 ? '${year + 1}-01-01' : '$year-${(mon + 1).toString().padLeft(2, '0')}-01';

    // Potentially reportable unsupported direction (e.g. §3a(2) service):
    // finalized outgoing invoice to an EU taxable recipient without a §6a(1)
    // goods posting blocks the whole month.
    final List<Map<String, Object?>> blocked = await executor.runSelect(
      'SELECT r.id FROM rechnungen r JOIN kunden k ON k.id = r.kunde_id '
      "WHERE r.ist_entwurf = 0 AND r.datum LIKE '$month-%' AND k.land IN (${euMemberStates.map((String s) => "'$s'").join(', ')}) "
      "AND k.ust_idnr IS NOT NULL AND k.ust_idnr <> '' "
      'AND NOT EXISTS (SELECT 1 FROM journal j WHERE j.rechnung_id = r.id AND j.ist_eu_lieferung = 1)',
      const <Object?>[],
    );
    if (blocked.isNotEmpty) {
      final int id = (blocked.first['id']! as num).toInt();
      return ReportWorkspaceResult<ZmPreview>.unavailable('unsupportedReportableDirection: rechnung $id');
    }

    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT j.datum, j.betrag, j.rechnung_id, r.datum AS issue_datum, k.land, k.ust_idnr '
      'FROM journal j JOIN rechnungen r ON r.id = j.rechnung_id LEFT JOIN kunden k ON k.id = r.kunde_id '
      "WHERE j.ist_eu_lieferung = 1 AND j.beleg_typ = 'Einnahme' AND r.ist_entwurf = 0 AND r.datum LIKE '$month-%'",
      const <Object?>[],
    );

    final Map<String, ZmRecipientTotal> byRecipient = <String, ZmRecipientTotal>{};
    for (final Map<String, Object?> r in rows) {
      final int rechnungId = (r['rechnung_id']! as num).toInt();
      final String? land = r['land']?.toString();
      final String? ustId = r['ust_idnr']?.toString();
      final String supplyDatum = r['datum']?.toString() ?? '';
      final String issueDatum = r['issue_datum']?.toString() ?? '';
      if (land == null || land.isEmpty || land == 'DE' || !euMemberStates.contains(land)) {
        return ReportWorkspaceResult<ZmPreview>.unavailable('missingZmSourceField: memberState, rechnung $rechnungId');
      }
      if (ustId == null || ustId.trim().isEmpty) {
        return ReportWorkspaceResult<ZmPreview>.unavailable('missingZmSourceField: ustIdNr, rechnung $rechnungId');
      }
      int cents;
      try {
        cents = money.parseScaled(r['betrag']?.toString() ?? '', scale: 2, allowNegative: false);
      } on money.MoneyParseException {
        cents = 0;
      }
      if (cents <= 0 || supplyDatum.isEmpty || issueDatum.isEmpty) {
        return ReportWorkspaceResult<ZmPreview>.unavailable('missingZmSourceField: taxableBase, rechnung $rechnungId');
      }
      // Statutory latest period: the calendar month following the supply.
      if (!_withinLatestPeriod(supplyDatum, issueDatum)) {
        return ReportWorkspaceResult<ZmPreview>.unavailable('latestPeriodExceeded: rechnung $rechnungId');
      }
      final ZmRecipientTotal? prev = byRecipient[ustId];
      if (prev == null) {
        byRecipient[ustId] = ZmRecipientTotal(
          ustIdNr: ustId,
          memberState: land,
          taxableBaseCents: cents,
          sourceRechnungIds: <int>[rechnungId],
        );
      } else {
        byRecipient[ustId] = ZmRecipientTotal(
          ustIdNr: ustId,
          memberState: land,
          taxableBaseCents: prev.taxableBaseCents + cents,
          sourceRechnungIds: <int>{...prev.sourceRechnungIds, rechnungId}.toList()..sort(),
        );
      }
    }

    return ReportWorkspaceResult<ZmPreview>.available(
      ZmPreview(
        month: month,
        periodStart: periodStart,
        periodEnd: periodEnd,
        sourceContractVersion: sourceContractVersion,
        recipients: byRecipient.values.toList()
          ..sort((ZmRecipientTotal a, ZmRecipientTotal b) => a.ustIdNr.compareTo(b.ustIdNr)),
        noEligibleEvents: byRecipient.isEmpty,
      ),
    );
  }

  static bool _withinLatestPeriod(String supplyDatum, String issueDatum) {
    final int? supplyIndex = _monthIndex(supplyDatum);
    final int? issueIndex = _monthIndex(issueDatum);
    if (supplyIndex == null || issueIndex == null) {
      return false;
    }
    return issueIndex <= supplyIndex + 1;
  }

  static int? _monthIndex(String isoDate) {
    final RegExpMatch? m = RegExp(r'^(\d{4})-(\d{2})').firstMatch(isoDate);
    if (m == null) {
      return null;
    }
    return int.parse(m.group(1)!) * 12 + int.parse(m.group(2)!);
  }
}
