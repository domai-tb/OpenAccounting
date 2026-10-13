import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/accounting/rechnung_typ.dart';
import 'package:openaccounting/features/mahnwesen/dunning_balance_source.dart';
import 'package:openaccounting/features/mahnwesen/dunning_exclusions_repository.dart';
import 'package:openaccounting/features/mahnwesen/dunning_interest.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_entity.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_exception.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_entity.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_repository.dart';
import 'package:openaccounting/features/mahnwesen/sperrung_service.dart';

/// Why an invoice produced no reminder in a run.
enum DunningSkipReason { bezahlt, nichtFaellig, ausgeschlossen, mahnsperre, keinBedarf, bereitsVersendet, keinBeleg }

/// One reviewable eligible invoice with its calculated inputs.
class EligibleInvoice {
  const EligibleInvoice({
    required this.rechnungId,
    required this.kundeId,
    required this.rechnungsnummer,
    required this.faelligkeit,
    required this.stufeId,
    required this.stufe,
    required this.outstandingCents,
    required this.effektiveGebuehr,
    required this.zinssatz,
    required this.zinssummeCents,
    required this.segmente,
  });

  final int rechnungId;
  final int? kundeId;
  final String rechnungsnummer;
  final String faelligkeit;
  final int stufeId;
  final int stufe;
  final int outstandingCents;
  final String effektiveGebuehr;
  final String zinssatz;
  final int zinssummeCents;
  final List<DunningInterestSegment> segmente;

  String get outstanding => money.fromCents(outstandingCents);
  String get zinssumme => money.fromCents(zinssummeCents);
}

class DunningSkipped {
  const DunningSkipped({required this.rechnungId, required this.reason, this.detail = ''});

  final int rechnungId;
  final DunningSkipReason reason;
  final String detail;
}

class DunningOpUnavailable {
  const DunningOpUnavailable({required this.rechnungId, required this.unavailable});

  final int rechnungId;
  final DunningUnavailable unavailable;
}

class DunningPreview {
  const DunningPreview({required this.eligible, required this.skipped, required this.unavailable, required this.asOf});

  final List<EligibleInvoice> eligible;
  final List<DunningSkipped> skipped;
  final List<DunningOpUnavailable> unavailable;
  final String asOf;
}

class DunningRunResult {
  const DunningRunResult({
    required this.created,
    required this.reused,
    required this.alreadyAccepted,
    required this.skipped,
    required this.unavailable,
  });

  final List<Mahnung> created;
  final List<Mahnung> reused;
  final List<Mahnung> alreadyAccepted;
  final List<DunningSkipped> skipped;
  final List<DunningOpUnavailable> unavailable;
}

/// Manual and assisted dunning runs over the settled-receivable source.
///
/// Assisted mode = [previewRun] then [confirmRun]; manual mode = direct
/// [createForInvoice] or [confirmRun]. Both share date, balance, exclusion,
/// and Mahnsperre rules. No automatic evaluation exists: dashboard loads and
/// background tasks never trigger a run. `initial_grace_days` is deprecated
/// and never consulted; stage eligibility uses only `due_date + days_after_due`.
class DunningService {
  DunningService({
    required this.executor,
    required this.mahnungen,
    required this.stufen,
    required this.balances,
    required this.exclusions,
    required this.sperrung,
  });

  final QueryExecutor executor;
  final MahnungenRepository mahnungen;
  final MahnstufenRepository stufen;
  final SettledBalanceSource balances;
  final DunningExclusionsRepository exclusions;
  final SperrungService sperrung;

  /// Reviewable preview without any write, artifact, or transport call.
  Future<DunningPreview> previewRun({required String asOf}) async {
    final String day = _requireDay(asOf);
    final List<Mahnstufe> stages = await _orderedStages();
    final List<Map<String, Object?>> invoices = await _candidateInvoices();
    final List<EligibleInvoice> eligible = <EligibleInvoice>[];
    final List<DunningSkipped> skipped = <DunningSkipped>[];
    final List<DunningOpUnavailable> unavailable = <DunningOpUnavailable>[];
    for (final Map<String, Object?> invoice in invoices) {
      final int id = _asInt(invoice['id']) ?? 0;
      final _Evaluated evaluated = await _evaluate(id, invoice: invoice, stages: stages, asOf: day);
      switch (evaluated) {
        case _EligibleReady(value: final EligibleInvoice value):
          eligible.add(value);
        case _Skipped(value: final DunningSkipped value):
          skipped.add(value);
        case _Blocked(value: final DunningOpUnavailable value):
          unavailable.add(value);
      }
    }
    return DunningPreview(eligible: eligible, skipped: skipped, unavailable: unavailable, asOf: day);
  }

  /// Creates confirmed letters, one per invoice and stage. Reuses an existing
  /// unsent draft; reports an already transport-accepted reminder instead of
  /// duplicating it. Never creates a consolidated customer letter.
  Future<DunningRunResult> confirmRun({required List<int> rechnungIds, required String asOf}) async {
    final String day = _requireDay(asOf);
    final List<Mahnstufe> stages = await _orderedStages();
    final List<Mahnung> created = <Mahnung>[];
    final List<Mahnung> reused = <Mahnung>[];
    final List<Mahnung> alreadyAccepted = <Mahnung>[];
    final List<DunningSkipped> skipped = <DunningSkipped>[];
    final List<DunningOpUnavailable> unavailable = <DunningOpUnavailable>[];
    for (final int id in rechnungIds) {
      final Map<String, Object?>? invoice = await _invoiceById(id);
      if (invoice == null) {
        skipped.add(DunningSkipped(rechnungId: id, reason: DunningSkipReason.keinBeleg));
        continue;
      }
      final _Evaluated evaluated = await _evaluate(id, invoice: invoice, stages: stages, asOf: day);
      switch (evaluated) {
        case _EligibleReady(value: final EligibleInvoice value):
          final Mahnung? existing = await mahnungen.findByRechnungAndStufe(id, value.stufeId);
          if (existing != null && existing.status != 'versendet') {
            reused.add(existing);
          } else if (existing != null) {
            alreadyAccepted.add(existing);
          } else {
            created.add(await _createFromEligible(value));
          }
        case _Skipped(value: final DunningSkipped value):
          if (value.reason == DunningSkipReason.bezahlt) {
            await mahnungen.clearInvoiceLevel(id);
          }
          skipped.add(value);
        case _Blocked(value: final DunningOpUnavailable value):
          unavailable.add(value);
      }
    }
    return DunningRunResult(
      created: created,
      reused: reused,
      alreadyAccepted: alreadyAccepted,
      skipped: skipped,
      unavailable: unavailable,
    );
  }

  /// Manual single-invoice creation with the same rules as assisted runs.
  Future<Mahnung> createForInvoice({required int rechnungId, required String asOf, int? stufeId}) async {
    final String day = _requireDay(asOf);
    final List<Mahnstufe> stages = await _orderedStages();
    final Map<String, Object?>? invoice = await _invoiceById(rechnungId);
    if (invoice == null) {
      throw const MahnungException('Rechnung nicht gefunden');
    }
    final _Evaluated evaluated = await _evaluate(
      rechnungId,
      invoice: invoice,
      stages: stages,
      asOf: day,
      stufeId: stufeId,
    );
    switch (evaluated) {
      case _EligibleReady(value: final EligibleInvoice value):
        final Mahnung? existing = await mahnungen.findByRechnungAndStufe(rechnungId, value.stufeId);
        if (existing != null && existing.status != 'versendet') return existing;
        if (existing != null) {
          throw const MahnungException('Für diese Stufe existiert bereits eine transport-akzeptierte Mahnung');
        }
        return _createFromEligible(value);
      case _Skipped(value: final DunningSkipped value):
        if (value.reason == DunningSkipReason.bezahlt) {
          await mahnungen.clearInvoiceLevel(rechnungId);
        }
        throw MahnungException('Keine Mahnung möglich: ${value.reason.name}');
      case _Blocked(value: final DunningOpUnavailable value):
        throw MahnungException('Saldo nicht verfügbar: ${value.unavailable.message}');
    }
  }

  /// Clears the level when the settled balance reached zero.
  Future<void> syncLevelAfterSettlement(int rechnungId) async {
    final DunningBalanceResult result = await balances.forRechnung(rechnungId);
    if (result is DunningBalanceOk && result.balance.outstandingCents <= 0) {
      await mahnungen.clearInvoiceLevel(rechnungId);
    }
  }

  Future<int> currentLevel(int rechnungId) => mahnungen.getInvoiceDunningLevel(rechnungId);

  Future<Mahnung> markTransportAccepted(int mahnungId) async {
    final Mahnung? existing = await mahnungen.getById(mahnungId);
    if (existing == null) throw const MahnungException('Mahnung nicht gefunden');
    final int stufeNummer = _stufeNummer(existing);
    return mahnungen.markTransportAccepted(mahnungId, stufeNummer: stufeNummer);
  }

  // --- evaluation ---

  Future<_Evaluated> _evaluate(
    int rechnungId, {
    required Map<String, Object?> invoice,
    required List<Mahnstufe> stages,
    required String asOf,
    int? stufeId,
  }) async {
    final Object? entwurfRaw = invoice['ist_entwurf'];
    final bool entwurf = entwurfRaw is num ? entwurfRaw != 0 : '${entwurfRaw ?? '1'}' == '1';
    final String typ = '${invoice['typ'] ?? ''}';
    final int? lieferantId = _asInt(invoice['lieferant_id']);
    if (entwurf || !RechnungTyp.isInvoice(typ) || RechnungTyp.isIncomingInvoice(typ, lieferantId: lieferantId)) {
      return _Skipped(DunningSkipped(rechnungId: rechnungId, reason: DunningSkipReason.keinBeleg));
    }
    final String faelligkeit = _dateOnly('${invoice['faelligkeit'] ?? ''}');
    if (!_isValidDay(faelligkeit)) {
      return _Skipped(
        DunningSkipped(rechnungId: rechnungId, reason: DunningSkipReason.keinBedarf, detail: 'Fälligkeit fehlt'),
      );
    }
    final int? kundeId = _asInt(invoice['kunde_id']);
    if (await exclusions.isExcluded(kundeId: kundeId, rechnungId: rechnungId)) {
      return _Skipped(DunningSkipped(rechnungId: rechnungId, reason: DunningSkipReason.ausgeschlossen));
    }
    if (kundeId != null && await sperrung.isMahngesperrt(kundeId, asOf: DateTime.parse(asOf))) {
      return _Skipped(DunningSkipped(rechnungId: rechnungId, reason: DunningSkipReason.mahnsperre));
    }
    final DunningBalanceResult balanceResult = await balances.forRechnung(rechnungId);
    if (balanceResult is DunningBalanceUnavailable) {
      return _Blocked(DunningOpUnavailable(rechnungId: rechnungId, unavailable: balanceResult.unavailable));
    }
    final SettledBalance balance = (balanceResult as DunningBalanceOk).balance;
    if (balance.outstandingCents <= 0) {
      return _Skipped(DunningSkipped(rechnungId: rechnungId, reason: DunningSkipReason.bezahlt));
    }
    Mahnstufe? target;
    if (stufeId != null) {
      target = await stufen.getById(stufeId);
      if (target == null) {
        return _Skipped(DunningSkipped(rechnungId: rechnungId, reason: DunningSkipReason.keinBedarf));
      }
      final int accepted = await mahnungen.currentAcceptedLevel(rechnungId);
      if (target.stufe != accepted + 1) {
        return _Skipped(DunningSkipped(rechnungId: rechnungId, reason: DunningSkipReason.keinBedarf));
      }
    } else {
      final int accepted = await mahnungen.currentAcceptedLevel(rechnungId);
      for (final Mahnstufe stage in stages) {
        if (stage.stufe == accepted + 1) {
          target = stage;
          break;
        }
      }
      if (target == null) {
        return _Skipped(DunningSkipped(rechnungId: rechnungId, reason: DunningSkipReason.bereitsVersendet));
      }
    }
    final String threshold = _addDays(faelligkeit, target.tageNachFaelligkeit);
    if (asOf.compareTo(threshold) < 0) {
      return _Skipped(DunningSkipped(rechnungId: rechnungId, reason: DunningSkipReason.nichtFaellig));
    }
    final String fee = await stufen.effektiveGebuehr(target.id);
    final DunningInterestResult interest = DunningInterest.calculate(
      dueDate: faelligkeit,
      stages: <DunningStageRate>[
        for (final Mahnstufe stage in stages)
          DunningStageRate(stufe: stage.stufe, daysAfterDue: stage.tageNachFaelligkeit, annualRate: stage.zinssatz),
      ],
      initialPrincipalCents: balance.initialCents,
      settlements: <DunningSettlement>[
        for (final SettlementEvent event in balance.events)
          if (event.typ == 'zahlung' || event.typ == 'ausbuchen')
            DunningSettlement(effectiveDate: event.effectiveDate, appliedCents: event.appliedCents),
      ],
      asOf: asOf,
    );
    return _EligibleReady(
      EligibleInvoice(
        rechnungId: rechnungId,
        kundeId: kundeId,
        rechnungsnummer: '${invoice['rechnungsnummer'] ?? ''}',
        faelligkeit: faelligkeit,
        stufeId: target.id,
        stufe: target.stufe,
        outstandingCents: balance.outstandingCents,
        effektiveGebuehr: fee,
        zinssatz: target.zinssatz,
        zinssummeCents: interest.totalCents,
        segmente: interest.segments,
      ),
    );
  }

  Future<Mahnung> _createFromEligible(EligibleInvoice value) async {
    final Map<String, String> carry = await mahnungen.getCarryOverBreakdown(value.rechnungId);
    final String segmentsJson = jsonEncode(<Map<String, Object?>>[
      for (final DunningInterestSegment segment in value.segmente)
        <String, Object?>{
          'von': segment.von,
          'bis': segment.bis,
          'tage': segment.tage,
          'stufe': segment.stufe,
          'zinssatz': segment.zinssatz,
          'principal': money.fromCents(segment.principalCents),
        },
    ]);
    final Mahnstufe? stage = await stufen.getById(value.stufeId);
    return mahnungen.createSettled(
      rechnungId: value.rechnungId,
      stufeId: value.stufeId,
      rechnungsnummer: value.rechnungsnummer,
      faelligkeit: value.faelligkeit,
      kundeId: value.kundeId,
      stufeNummer: value.stufe,
      stufenBezeichnung: stage?.bezeichnung ?? 'Stufe ${value.stufe}',
      outstandingPrincipal: value.outstanding,
      effektiveGebuehr: value.effektiveGebuehr,
      zinssumme: value.zinssumme,
      zinssegmenteJson: segmentsJson,
      uebernommeneGebuehr: carry['gebuehr'] ?? '0.00',
      uebernommeneZinsen: carry['zinsen'] ?? '0.00',
    );
  }

  Future<List<Mahnstufe>> _orderedStages() async {
    final List<Mahnstufe> stages = await stufen.list();
    stages.sort((Mahnstufe a, Mahnstufe b) => a.stufe.compareTo(b.stufe));
    return stages;
  }

  Future<List<Map<String, Object?>>> _candidateInvoices() async {
    try {
      return await executor.runSelect(
        'SELECT id, rechnungsnummer, kunde_id, lieferant_id, typ, ist_entwurf, faelligkeit FROM rechnungen ORDER BY id ASC',
        const <Object?>[],
      );
    } catch (_) {
      throw const MahnungException('Rechnungen sind nicht verfügbar');
    }
  }

  Future<Map<String, Object?>?> _invoiceById(int id) async {
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT id, rechnungsnummer, kunde_id, lieferant_id, typ, ist_entwurf, faelligkeit FROM rechnungen WHERE id = ? LIMIT 1',
        <Object?>[id],
      );
      return rows.isEmpty ? null : rows.single;
    } catch (_) {
      throw const MahnungException('Rechnung ist nicht verfügbar');
    }
  }

  int _stufeNummer(Mahnung mahnung) {
    final Map<String, dynamic>? snapshot = mahnung.snapshotData;
    final Object? stufe = snapshot?['stufe'];
    if (stufe is num) return stufe.toInt();
    return int.tryParse('$stufe') ?? 0;
  }

  static String _requireDay(String raw) {
    final String day = _dateOnly(raw);
    if (!_isValidDay(day)) {
      throw MahnungException('Datum ungültig: $raw (JJJJ-MM-TT erwartet)');
    }
    return day;
  }

  static String _dateOnly(String raw) => raw.length >= 10 ? raw.substring(0, 10) : raw;

  static bool _isValidDay(String day) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) return false;
    final List<String> parts = day.split('-');
    final DateTime parsed = DateTime.utc(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' ==
        day;
  }

  static String _addDays(String day, int days) {
    final List<String> parts = day.split('-');
    final DateTime parsed = DateTime.utc(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final DateTime shifted = parsed.add(Duration(days: days));
    return '${shifted.year.toString().padLeft(4, '0')}-${shifted.month.toString().padLeft(2, '0')}-${shifted.day.toString().padLeft(2, '0')}';
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }
}

sealed class _Evaluated {
  const _Evaluated();
}

class _EligibleReady extends _Evaluated {
  const _EligibleReady(this.value);

  final EligibleInvoice value;
}

class _Skipped extends _Evaluated {
  const _Skipped(this.value);

  final DunningSkipped value;
}

class _Blocked extends _Evaluated {
  const _Blocked(this.value);

  final DunningOpUnavailable value;
}
