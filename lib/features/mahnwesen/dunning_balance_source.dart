import 'package:drift/drift.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;

/// One dated settlement event from the accepted settlement source.
class SettlementEvent {
  const SettlementEvent({required this.effectiveDate, required this.appliedCents, required this.typ});

  final String effectiveDate;
  final int appliedCents;
  final String typ;
}

/// Validated settled-receivable projection for one invoice.
class SettledBalance {
  const SettledBalance({
    required this.rechnungId,
    required this.outstandingCents,
    required this.initialCents,
    required this.events,
  });

  final int rechnungId;
  final int outstandingCents;
  final int initialCents;
  final List<SettlementEvent> events;

  String get outstanding => money.fromCents(outstandingCents);
}

/// Typed actionable unavailable result: retryable, no write performed.
class DunningUnavailable {
  const DunningUnavailable({required this.code, required this.message});

  final String code;
  final String message;
}

sealed class DunningBalanceResult {
  const DunningBalanceResult();
}

class DunningBalanceOk extends DunningBalanceResult {
  const DunningBalanceOk(this.balance);

  final SettledBalance balance;
}

class DunningBalanceUnavailable extends DunningBalanceResult {
  const DunningBalanceUnavailable(this.unavailable);

  final DunningUnavailable unavailable;
}

/// Settled-receivable source for the dunning monetary path.
///
/// Uses the `forderungen` projection with dated `forderung_zahlungen` events
/// and the accepted invoice-money amount/sign rules. Missing, invalid, or
/// conflicting sources fail closed with a typed unavailable result: callers
/// SHALL perform no write, artifact generation, stage-state update, or
/// transport call. Never falls back to invoice gross/net totals, bank-import
/// rows, or fabricated zero balances.
class SettledBalanceSource {
  SettledBalanceSource(this.executor);

  final QueryExecutor executor;

  Future<DunningBalanceResult> forRechnung(int rechnungId) async {
    List<Map<String, Object?>> rows;
    try {
      rows = await executor.runSelect(
        'SELECT id, anfangsbetrag, betrag, status FROM forderungen WHERE rechnung_id = ? LIMIT 1',
        <Object?>[rechnungId],
      );
    } catch (_) {
      return const DunningBalanceUnavailable(
        DunningUnavailable(
          code: 'saldo_nicht_verfuegbar',
          message: 'Offener Saldo ist nicht verfügbar. Erneut versuchen.',
        ),
      );
    }
    if (rows.isEmpty) {
      return const DunningBalanceUnavailable(
        DunningUnavailable(
          code: 'saldo_nicht_verfuegbar',
          message: 'Offener Saldo ist nicht verfügbar. Erneut versuchen.',
        ),
      );
    }
    final Map<String, Object?> row = rows.single;
    final int? initial = _centsOrNull(row['anfangsbetrag']);
    final int? current = _centsOrNull(row['betrag']);
    if (initial == null || current == null || initial < 0 || current < 0) {
      return const DunningBalanceUnavailable(
        DunningUnavailable(code: 'saldo_ungueltig', message: 'Offener Saldo ist ungültig. Beleg prüfen.'),
      );
    }
    List<Map<String, Object?>> eventRows;
    try {
      eventRows = await executor.runSelect(
        'SELECT betrag, typ, datum FROM forderung_zahlungen WHERE forderung_id = ? ORDER BY datum ASC, id ASC',
        <Object?>[_asInt(row['id']) ?? 0],
      );
    } catch (_) {
      return const DunningBalanceUnavailable(
        DunningUnavailable(
          code: 'saldo_nicht_verfuegbar',
          message: 'Offener Saldo ist nicht verfügbar. Erneut versuchen.',
        ),
      );
    }
    final List<SettlementEvent> events = <SettlementEvent>[];
    var appliedTotal = 0;
    for (final Map<String, Object?> event in eventRows) {
      final String typ = '${event['typ'] ?? ''}';
      final int? cents = _centsOrNull(event['betrag']);
      final String datum = _dateOnly('${event['datum'] ?? ''}');
      if (cents == null || cents < 0 || !_isValidDay(datum) || !_isKnownTyp(typ)) {
        return const DunningBalanceUnavailable(
          DunningUnavailable(code: 'ereignis_ungueltig', message: 'Ausgleichsereignis ist ungültig. Beleg prüfen.'),
        );
      }
      events.add(SettlementEvent(effectiveDate: datum, appliedCents: cents, typ: typ));
      // ponytail: ueberzahlung is recorded excess beyond the balance and must
      // not reduce the projection a second time.
      if (typ == 'zahlung' || typ == 'ausbuchen') {
        appliedTotal += cents;
      }
    }
    if (initial - appliedTotal != current) {
      return const DunningBalanceUnavailable(
        DunningUnavailable(
          code: 'saldo_konflikt',
          message: 'Saldo und Ausgleichsverlauf widersprechen sich. Beleg prüfen.',
        ),
      );
    }
    final String status = '${row['status'] ?? ''}';
    if ((status == 'bezahlt' || status == 'ausgebucht') && current != 0) {
      return const DunningBalanceUnavailable(
        DunningUnavailable(
          code: 'saldo_konflikt',
          message: 'Saldo und Ausgleichsverlauf widersprechen sich. Beleg prüfen.',
        ),
      );
    }
    if ((status == 'offen' || status == 'teilbezahlt') && current == 0 && events.isNotEmpty) {
      return const DunningBalanceUnavailable(
        DunningUnavailable(
          code: 'saldo_konflikt',
          message: 'Saldo und Ausgleichsverlauf widersprechen sich. Beleg prüfen.',
        ),
      );
    }
    return DunningBalanceOk(
      SettledBalance(rechnungId: rechnungId, outstandingCents: current, initialCents: initial, events: events),
    );
  }

  static bool _isKnownTyp(String typ) => typ == 'zahlung' || typ == 'ueberzahlung' || typ == 'ausbuchen';

  static int? _centsOrNull(Object? value) {
    if (value == null) return null;
    try {
      return money.parseScaled(value.toString(), scale: 2, field: 'Betrag', roundExcess: true);
    } on money.MoneyParseException {
      return null;
    }
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  static String _dateOnly(String raw) => raw.length >= 10 ? raw.substring(0, 10) : raw;

  static bool _isValidDay(String day) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) return false;
    final List<String> parts = day.split('-');
    final DateTime parsed = DateTime.utc(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' ==
        day;
  }
}
