import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/assets/asset_entity.dart';
import 'package:openaccounting/features/assets/asset_repository.dart';
import 'package:openaccounting/features/assets/asset_schedule_service.dart';

/// Complete annual AfA values the owning EÜR workflow may consume.
///
/// Only rows with `status == verfuegbar` contribute; this change defines no
/// report output of its own.
class AssetAfaConsumption {
  const AssetAfaConsumption({required this.total, required this.assetRefs, required this.incomplete});

  final String total;
  final List<Map<String, Object?>> assetRefs;
  final List<Map<String, Object?>> incomplete;
}

/// Asset-register use cases: CRUD, schedule, and posting boundaries.
///
/// Creating, editing, archiving, or scheduling only changes asset-register or
/// schedule data. No journal or tax-claim row is ever written here.
class AssetRegisterUseCases {
  AssetRegisterUseCases(this.repository, {AssetScheduleService? scheduleService})
    : scheduleService = scheduleService ?? const AssetScheduleService();

  final AssetRepository repository;
  final AssetScheduleService scheduleService;

  Future<List<FixedAsset>> listAssets() => repository.list();

  Future<FixedAsset?> getAsset(int id) => repository.findById(id);

  Future<FixedAsset> createAsset({
    required String bezeichnung,
    required String assetTyp,
    required String anschaffungsdatum,
    required String kaufpreisNetto,
    required int nutzungsdauerJahre,
    String afaMethode = 'linear',
    String privatAnteilProzent = '0',
    int? kategorieId,
    int? unternehmenId,
    String? verkauftAm,
  }) {
    return repository.create(
      bezeichnung: bezeichnung,
      assetTyp: assetTyp,
      anschaffungsdatum: anschaffungsdatum,
      kaufpreisNetto: kaufpreisNetto,
      nutzungsdauerJahre: nutzungsdauerJahre,
      afaMethode: afaMethode,
      privatAnteilProzent: privatAnteilProzent,
      kategorieId: kategorieId,
      unternehmenId: unternehmenId,
      verkauftAm: verkauftAm,
    );
  }

  Future<FixedAsset> updateAsset(
    int id, {
    String? bezeichnung,
    String? assetTyp,
    String? anschaffungsdatum,
    String? kaufpreisNetto,
    int? nutzungsdauerJahre,
    String? afaMethode,
    String? privatAnteilProzent,
    int? kategorieId,
    String? verkauftAm,
    String? status,
  }) {
    return repository.update(
      id,
      bezeichnung: bezeichnung,
      assetTyp: assetTyp,
      anschaffungsdatum: anschaffungsdatum,
      kaufpreisNetto: kaufpreisNetto,
      nutzungsdauerJahre: nutzungsdauerJahre,
      afaMethode: afaMethode,
      privatAnteilProzent: privatAnteilProzent,
      kategorieId: kategorieId,
      verkauftAm: verkauftAm,
      status: status,
    );
  }

  Future<FixedAsset> archiveAsset(int id) => repository.archive(id);

  Future<void> deleteAsset(int id) => repository.delete(id);

  /// Generates, persists, and returns the schedule row for [jahr].
  ///
  /// Later edits create a new input snapshot without rewriting old rows.
  Future<AssetScheduleRow> generateSchedule({required int anlageId, required int jahr}) async {
    final FixedAsset? asset = await repository.findById(anlageId);
    if (asset == null) throw StateError('Anlage $anlageId nicht gefunden');
    final AssetScheduleRow row = scheduleService.computeRow(asset: asset, jahr: jahr);
    await repository.persistScheduleRow(row);
    return row;
  }

  /// Generates the full useful-life schedule and persists every row.
  Future<List<AssetScheduleRow>> generateFullSchedule(int anlageId) async {
    final FixedAsset? asset = await repository.findById(anlageId);
    if (asset == null) throw StateError('Anlage $anlageId nicht gefunden');
    final List<AssetScheduleRow> rows = scheduleService.fullSchedule(asset);
    for (final AssetScheduleRow row in rows) {
      await repository.persistScheduleRow(row);
    }
    return rows;
  }

  /// Sums only complete annual AfA values for [jahr] across active assets.
  ///
  /// Unresolved assets or unsupported periods are reported as incomplete
  /// instead of contributing an invented zero or amount.
  Future<AssetAfaConsumption> consumeCompleteAfa(int jahr) async {
    final List<FixedAsset> assets = await repository.list();
    int totalCents = 0;
    final List<Map<String, Object?>> refs = <Map<String, Object?>>[];
    final List<Map<String, Object?>> incomplete = <Map<String, Object?>>[];
    for (final FixedAsset asset in assets) {
      final String status = asset.status.trim().toLowerCase();
      if (status == 'inaktiv' || status == 'verkauft' || status == 'disposed' || status == 'archiviert') continue;
      // Legacy rows without canonical inputs stay reviewable but never feed totals.
      if (!asset.hasCanonicalInputs) {
        if (asset.hasUnresolvedLegacy) {
          incomplete.add(<String, Object?>{'anlage_id': asset.id, 'grund': 'unaufgeloeste-quelle'});
        }
        continue;
      }
      final AssetScheduleRow row = scheduleService.computeRow(asset: asset, jahr: jahr);
      if (!row.isAvailable) {
        incomplete.add(<String, Object?>{'anlage_id': asset.id, 'grund': row.blockierungsgrund ?? ''});
        continue;
      }
      totalCents += money.toCents(row.betrag!);
      refs.add(<String, Object?>{'anlage_id': asset.id, 'jahr': jahr, 'formel': row.formel, 'betrag': row.betrag});
    }
    final bool negative = totalCents < 0;
    final int abs = totalCents.abs();
    final String total = '${negative ? '-' : ''}${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
    return AssetAfaConsumption(total: total, assetRefs: refs, incomplete: incomplete);
  }

  /// Every financial effect requires the accepted shared posting contract.
  ///
  /// Until an asset-event mapping exists the action stays unavailable.
  Future<void> requestFinancialEffect(String action) async {
    throw AssetPostingUnavailable(
      'Finanzielle Wirkung ($action) nicht verfügbar: kein akzeptierter Buchungsvertrag und keine Kontenzuordnung.',
    );
  }
}
