import 'package:drift/drift.dart';

import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/quick_booking/quick_booking_repository.dart';

/// Execution gate for quick-booking presets per quick-booking-workspace.
///
/// Activation submits exact typed inputs with an explicit business date to an
/// accepted accounting posting port and reports success only with a committed
/// posting identity. No accepted direct cash/bank posting contract exists, so
/// production execution stays unavailable and persists no accounting effect.
/// Quick-booking code never inserts into `journal`.
class QuickBookingExecutionException implements Exception {
  const QuickBookingExecutionException(this.message, {this.missingInputs = const <String>[]});
  final String message;
  final List<String> missingInputs;
  @override
  String toString() => message;
}

/// Accepted accounting posting port. The production profile has no accepted
/// direct cash/bank posting contract; tests inject fakes.
abstract class QuickBookingPostingPort {
  bool get isAvailable;
  Future<String> submit({required QuickBookingPreset preset, required String businessDate, required String betrag});
}

/// Production port: unavailable until the posting contract accepts direct
/// cash/bank transaction inputs.
class UnavailableQuickBookingPosting implements QuickBookingPostingPort {
  const UnavailableQuickBookingPosting();

  @override
  bool get isAvailable => false;

  @override
  Future<String> submit({required QuickBookingPreset preset, required String businessDate, required String betrag}) {
    throw const QuickBookingExecutionException('Buchungsposten-Vertrag nicht verfügbar');
  }
}

/// Result of a preset activation attempt.
class QuickBookingExecution {
  const QuickBookingExecution({required this.executed, this.postingIdentity, this.unavailableReason});

  final bool executed;
  final String? postingIdentity;
  final String? unavailableReason;
}

/// Validates preset completeness against live configuration and, when every
/// required input resolves, submits through [port]. Returns an unavailable
/// result (never a fake success) when the contract or an input is missing.
Future<QuickBookingExecution> executePreset({
  required QueryExecutor executor,
  required QuickBookingRepository repository,
  required QuickBookingPostingPort port,
  required int presetId,
  required String businessDate,
  String? betrag,
}) async {
  final QuickBookingPreset? preset = await repository.findById(presetId);
  if (preset == null) throw const QuickBookingExecutionException('Preset nicht gefunden');
  final List<String> missing = await _missingInputs(executor, preset, betrag);
  if (missing.isNotEmpty) {
    return QuickBookingExecution(executed: false, unavailableReason: 'Unvollständig: ${missing.join(', ')}');
  }
  if (!port.isAvailable) {
    return const QuickBookingExecution(executed: false, unavailableReason: 'Buchungsposten-Vertrag nicht verfügbar');
  }
  final String identity = await port.submit(
    preset: preset,
    businessDate: businessDate,
    betrag: betrag ?? preset.betrag!,
  );
  if (identity.trim().isEmpty) {
    return const QuickBookingExecution(
      executed: false,
      unavailableReason: 'Buchungsposten-Vertrag lieferte keine Buchungsidentität',
    );
  }
  return QuickBookingExecution(executed: true, postingIdentity: identity);
}

Future<List<String>> _missingInputs(QueryExecutor executor, QuickBookingPreset preset, String? betragOverride) async {
  final List<String> missing = <String>[];
  if (preset.direction == null) missing.add('Richtung');
  if (preset.kontoId == null) {
    missing.add('Konto');
  } else {
    final konten = await executor.runSelect('SELECT id FROM konten WHERE id = ?', <Object?>[preset.kontoId]);
    if (konten.isEmpty) missing.add('Konto');
  }
  if (preset.kategorieId == null) {
    missing.add('Kategorie');
  } else {
    final kats = await executor.runSelect('SELECT aktiv FROM kategorien WHERE id = ?', <Object?>[preset.kategorieId]);
    if (kats.isEmpty || ((kats.single['aktiv'] as num?) ?? 0).toInt() == 0) missing.add('Kategorie');
  }
  if (preset.ustSatzId == null) {
    missing.add('Steuersatz');
  } else {
    final saetze = await executor.runSelect('SELECT id FROM ust_saetze WHERE id = ?', <Object?>[preset.ustSatzId]);
    if (saetze.isEmpty) missing.add('Steuersatz');
  }
  if (preset.modus == null) missing.add('Eingabemodus');
  final String? amount = betragOverride ?? preset.betrag;
  if (amount == null) {
    missing.add('Betrag');
  } else {
    try {
      money.parseScaled(amount, scale: 2, field: 'Betrag', allowNegative: false);
    } on money.MoneyParseException {
      missing.add('Betrag');
    }
  }
  return missing;
}
