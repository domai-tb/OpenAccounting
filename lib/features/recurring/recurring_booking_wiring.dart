import 'package:drift/drift.dart';
import 'package:openaccounting/features/accounting/rechnung_typ.dart';
import 'package:openaccounting/features/recurring/buchungsvorlagen_repository.dart';
import 'package:openaccounting/features/recurring/recurring_booking_workspace_usecases.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_item_entity.dart';
import 'package:openaccounting/pages/rechnungen/rechnungen_usecases.dart';

/// Production wiring for the workspace use case: real template storage,
/// fail-closed shared posting boundary, draft handoff through the
/// incoming-invoice draft use case, and live category/article probes.
RecurringBookingWorkspaceUseCases buildRecurringBookingUseCases(QueryExecutor executor, RechnungenUseCases rechnungen) {
  final BuchungsVorlagenRepository vorlagen = BuchungsVorlagenRepository(executor);
  return RecurringBookingWorkspaceUseCases(
    vorlagen,
    sharedPosting: const UnavailableSharedPostingGateway(),
    belegDrafts: _ProductionBelegDraftGateway(executor, rechnungen),
    kategorien: (int? kategorieId) => lookupRecurringCategory(executor, kategorieId),
    artikelpreise: (int artikelId) => lookupRecurringArticlePrice(executor, artikelId),
  );
}

Future<RecurringCategoryProbe?> lookupRecurringCategory(QueryExecutor executor, int? kategorieId) async {
  if (kategorieId == null) return null;
  try {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT aktiv, mapping_status FROM kategorien WHERE id = ? LIMIT 1',
      <Object?>[kategorieId],
    );
    if (rows.isEmpty) return null;
    final Object? aktiv = rows.single['aktiv'];
    final bool isAktiv = aktiv is num ? aktiv != 0 : aktiv.toString() == '1';
    return RecurringCategoryProbe(aktiv: isAktiv, mappingStatus: rows.single['mapping_status']?.toString() ?? '');
  } catch (_) {
    return null;
  }
}

Future<String?> lookupRecurringArticlePrice(QueryExecutor executor, int artikelId) async {
  try {
    final List<Map<String, Object?>> rows = await executor.runSelect(
      'SELECT vk_brutto, vk_netto FROM artikel WHERE id = ? LIMIT 1',
      <Object?>[artikelId],
    );
    if (rows.isEmpty) return null;
    final Object? brutto = rows.single['vk_brutto'];
    if (brutto != null && brutto.toString().trim().isNotEmpty && brutto.toString() != '0') {
      return brutto.toString();
    }
    return rows.single['vk_netto']?.toString();
  } catch (_) {
    return null;
  }
}

/// Production Beleg handoff: creates exactly one incoming-invoice draft per
/// occurrence through the owning use case. Never writes invoice SQL
/// directly; recovery reads only.
class _ProductionBelegDraftGateway implements BelegDraftGateway {
  const _ProductionBelegDraftGateway(this._executor, this._rechnungen);

  final QueryExecutor _executor;
  final RechnungenUseCases _rechnungen;

  @override
  bool get isAvailable => true;

  @override
  String get unavailableReason => 'Entwurfs-Übergabe ist nicht verfügbar';

  @override
  Future<int> createDraft({
    required int vorlageId,
    required String faelligkeit,
    required String datum,
    required List<BelegDraftPosition> positionen,
    required String eingabemodus,
    int? lieferantId,
  }) async {
    final List<RechnungPositionItem> items = <RechnungPositionItem>[
      for (var index = 0; index < positionen.length; index++)
        RechnungPositionItem(
          bezeichnung: positionen[index].bezeichnung,
          menge: num.tryParse(positionen[index].menge) ?? 1,
          einzelpreis: num.tryParse(positionen[index].einzelpreis) ?? 0,
          gesamt: (num.tryParse(positionen[index].menge) ?? 1) * (num.tryParse(positionen[index].einzelpreis) ?? 0),
          ustSatz: num.tryParse(positionen[index].ustSatz) ?? 19,
          artikelId: positionen[index].artikelId,
          position: index,
        ),
    ];
    final RechnungItem draft = await _rechnungen.createDraftRechnung(
      datum: datum,
      positionen: items,
      typ: RechnungTyp.eingang,
      eingabemodus: eingabemodus,
    );
    return draft.id;
  }

  @override
  Future<int?> findByIdentity(int vorlageId, String faelligkeit) async {
    try {
      final List<Map<String, Object?>> rows = await _executor.runSelect(
        'SELECT id FROM rechnungen WHERE vorlage_id = ? AND datum = ? ORDER BY id LIMIT 1',
        <Object?>[vorlageId, faelligkeit],
      );
      if (rows.isEmpty) return null;
      return (rows.single['id'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }
}

/// Test helper: in-memory workspace with injectable gateways.
RecurringBookingWorkspaceUseCases buildTestRecurringBookingUseCases(
  QueryExecutor executor, {
  SharedPostingGateway? sharedPosting,
  BelegDraftGateway? belegDrafts,
  RecurringCategoryLookup? kategorien,
  RecurringArticlePriceLookup? artikelpreise,
}) {
  return RecurringBookingWorkspaceUseCases(
    BuchungsVorlagenRepository(executor),
    sharedPosting: sharedPosting,
    belegDrafts: belegDrafts,
    kategorien: kategorien,
    artikelpreise: artikelpreise,
  );
}
