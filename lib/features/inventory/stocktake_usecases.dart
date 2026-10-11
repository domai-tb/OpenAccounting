import 'package:openaccounting/features/feature_modules/feature_module_catalog.dart';
import 'package:openaccounting/features/feature_modules/feature_module_service.dart';
import 'package:openaccounting/features/inventory/stocktake_entity.dart';
import 'package:openaccounting/features/inventory/stocktake_repository.dart';

/// Stocktake orchestration above the repository. Creating, editing, or
/// recording never changes article stock, movements, documents, or postings.
/// Valuation stays fail-closed: no policy, no value, no side effects.
class StocktakeUseCases {
  StocktakeUseCases(this._repository, this._modules);

  final StocktakeRepository _repository;
  final FeatureModuleService _modules;

  /// Global inventory toggle (backfilled from `lagerfuehrung_aktiv`).
  Future<bool> isInventoryEnabled() => _modules.isEffectivelyEnabled(FeatureModuleCatalog.inventory);

  /// Starts a draft for [stichtag]. Refused while inventory is disabled;
  /// performs no write then. Throws [StocktakeNoCountableArticlesException]
  /// without creating a row when nothing can be snapshotted.
  Future<Stocktake> startDraft({required String stichtag}) async {
    if (!await isInventoryEnabled()) throw const StocktakeUnavailableException();
    return _repository.createDraft(stichtag: stichtag);
  }

  Future<Stocktake> setCount({required int inventurId, required int artikelId, required num? menge}) async {
    if (!await isInventoryEnabled()) throw const StocktakeUnavailableException();
    return _repository.setCount(inventurId: inventurId, artikelId: artikelId, menge: menge);
  }

  Future<Stocktake> saveCounts({required int inventurId, required Map<int, num?> counts, bool record = false}) async {
    if (!await isInventoryEnabled()) throw const StocktakeUnavailableException();
    return _repository.saveCounts(inventurId: inventurId, counts: counts, record: record);
  }

  Future<Stocktake> record(int inventurId) async {
    if (!await isInventoryEnabled()) throw const StocktakeUnavailableException();
    return _repository.record(inventurId);
  }

  /// Recorded history stays readable while inventory is disabled; it is the
  /// sole global-toggle exception. Never throws for disabled inventory.
  Future<List<Stocktake>> history() => _repository.recordedHistory();

  Future<List<Stocktake>> drafts() async {
    if (!await isInventoryEnabled()) return const <Stocktake>[];
    return _repository.openDrafts();
  }

  /// Valuation request without a reviewed policy: fails closed. Pure throw —
  /// no value is calculated, stored, exported, or posted, and existing
  /// counts and live stock stay untouched.
  Future<Never> requestValuation(int inventurId) async {
    throw const StocktakeValuationUnavailableException();
  }
}
