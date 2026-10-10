import 'package:openaccounting/features/feature_modules/feature_module_catalog.dart';
import 'package:openaccounting/features/feature_modules/feature_module_repository.dart';
import 'package:openaccounting/features/feature_modules/feature_module_state.dart';

/// Outcome of a module preference write.
class FeatureModuleSetResult {
  const FeatureModuleSetResult({required this.success, required this.state, this.reason});

  final bool success;
  final FeatureModuleState state;

  /// Null on success; otherwise `unknown`, `unavailable`, `threshold`, or `save`.
  final String? reason;

  static const String unknown = 'unknown';
  static const String unavailable = 'unavailable';
  static const String threshold = 'threshold';
  static const String save = 'save';
}

/// Outcome of a GuV threshold evaluation.
class GuvThresholdOutcome {
  const GuvThresholdOutcome({required this.applies, required this.state, this.reason});

  final bool applies;
  final FeatureModuleState state;
  final String? reason;
}

/// Central resolver for effective module state. A module is effectively
/// enabled only when its providers/dependencies are available and its
/// saved preference is enabled. Unknown, unavailable, and
/// dependency-blocked modules resolve to disabled even when the saved
/// preference claims true.
class FeatureModuleService {
  FeatureModuleService({required this._repository, Set<String>? availableProviders})
    : availableProviders = availableProviders ?? FeatureModuleProviders.all;

  final FeatureModuleRepository _repository;

  /// Registered providers/dependencies. Tests inject subsets to simulate
  /// unavailable modules; production registers all five.
  final Set<String> availableProviders;

  bool _guvThresholdLatched = false;

  /// Whether the maintained GuV threshold currently forces GuV on.
  bool get guvThresholdApplies => _guvThresholdLatched;

  bool isAvailable(String id) {
    if (!FeatureModuleCatalog.isKnown(id)) return false;
    return FeatureModuleCatalog.requiredProviders[id]!.every(availableProviders.contains);
  }

  /// Saved preference resolved to declared defaults on invalid data,
  /// without rewriting the stored value.
  Future<FeatureModuleState> currentState() async {
    try {
      return await _repository.loadOrDefaults();
    } catch (_) {
      return FeatureModuleState.defaults();
    }
  }

  Future<bool> isEffectivelyEnabled(String id) async {
    if (!isAvailable(id)) return false;
    return (await currentState()).isEnabled(id);
  }

  /// Whether a module action may mutate that module's records.
  Future<bool> canMutate(String id) => isEffectivelyEnabled(id);

  /// Applies one preference change. Unknown/unavailable modules and a
  /// threshold-locked GuV disable are refused; a failed write leaves the
  /// prior canonical value and effective state in force.
  Future<FeatureModuleSetResult> setEnabled(String id, {required bool value}) async {
    final FeatureModuleState before = await currentState();
    if (!FeatureModuleCatalog.isKnown(id)) {
      return FeatureModuleSetResult(success: false, state: before, reason: FeatureModuleSetResult.unknown);
    }
    if (!isAvailable(id)) {
      return FeatureModuleSetResult(success: false, state: before, reason: FeatureModuleSetResult.unavailable);
    }
    if (id == FeatureModuleCatalog.guv && !value && _guvThresholdLatched) {
      try {
        final FeatureModuleState locked = await _repository.save(before.withEnabled(id, value: true));
        return FeatureModuleSetResult(success: false, state: locked, reason: FeatureModuleSetResult.threshold);
      } catch (_) {
        return FeatureModuleSetResult(success: false, state: before, reason: FeatureModuleSetResult.threshold);
      }
    }
    try {
      final FeatureModuleState saved = await _repository.save(before.withEnabled(id, value: value));
      return FeatureModuleSetResult(success: true, state: saved);
    } catch (_) {
      return FeatureModuleSetResult(success: false, state: before, reason: FeatureModuleSetResult.save);
    }
  }

  /// Maintained GuV threshold auto-activation: persists `guv=true` through
  /// the catalog state writer and reports the threshold reason. No separate
  /// `guv_aktiv` runtime flag is read or written.
  Future<GuvThresholdOutcome> evaluateGuvThreshold({required double turnover, required double profit}) async {
    if (!GuvThresholds.applies(turnover: turnover, profit: profit)) {
      return GuvThresholdOutcome(applies: false, state: await currentState());
    }
    _guvThresholdLatched = true;
    try {
      final FeatureModuleState withGuv = (await currentState()).withEnabled(FeatureModuleCatalog.guv, value: true);
      final FeatureModuleState saved = await _repository.save(withGuv);
      return GuvThresholdOutcome(applies: true, state: saved, reason: GuvThresholds.reason);
    } catch (_) {
      return GuvThresholdOutcome(applies: true, state: await currentState(), reason: GuvThresholds.reason);
    }
  }

  /// Profile Manager stays visible with more than one profile regardless
  /// of the saved preference; with a single profile it follows the catalog.
  Future<bool> isProfileManagerVisible({required int profileCount}) async {
    if (profileCount > 1) return true;
    return isEffectivelyEnabled(FeatureModuleCatalog.profileManager);
  }

  /// Shared entry-point visibility: navigation, dashboard widgets and
  /// quick links, and module-specific create actions.
  Future<bool> isEntryVisible(String id, {int profileCount = 1}) async {
    if (id == FeatureModuleCatalog.profileManager) {
      return isProfileManagerVisible(profileCount: profileCount);
    }
    return isEffectivelyEnabled(id);
  }

  /// Dashboard widget visibility. Inventory widgets hide with the module;
  /// every other widget is unaffected by module state.
  Future<bool> isDashboardWidgetVisible(String widgetId) async {
    if (widgetId == 'lagerwarnung' || widgetId == 'lagerbestand') {
      return isEffectivelyEnabled(FeatureModuleCatalog.inventory);
    }
    return true;
  }
}
