import 'dart:convert';

import 'package:openaccounting/features/feature_modules/feature_module_catalog.dart';

/// Versioned company module state.
/// Shape (version 1): `{"version":1,"enabled":{"profile_manager":false,
/// "inventory":false,"guv":false}}`. Unknown keys are ignored; malformed
/// values resolve to declared defaults without rewriting stored data.
class FeatureModuleState {
  const FeatureModuleState({Map<String, bool>? enabled}) : enabled = enabled ?? FeatureModuleCatalog.defaults;

  final Map<String, bool> enabled;

  factory FeatureModuleState.defaults() => const FeatureModuleState();

  static String defaultsEncoded() => FeatureModuleState.defaults().encode();

  bool isEnabled(String id) => enabled[id] ?? false;

  FeatureModuleState withEnabled(String id, {required bool value}) {
    if (!FeatureModuleCatalog.isKnown(id)) return this;
    return FeatureModuleState(enabled: <String, bool>{...enabled, id: value});
  }

  String encode() {
    return jsonEncode(<String, Object?>{
      'version': FeatureModuleCatalog.version,
      'enabled': <String, Object?>{for (final String id in FeatureModuleCatalog.ids) id: isEnabled(id)},
    });
  }

  /// Valid versioned JSON, or null when absent/malformed. Per-key type
  /// errors fall back to the declared default but keep the shape valid.
  static FeatureModuleState? tryParse(Object? raw) {
    if (raw == null || raw is! String || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['version'] != FeatureModuleCatalog.version) return null;
      if (decoded['enabled'] is! Map) return null;
      final Map<String, dynamic> map = decoded['enabled'] as Map<String, dynamic>;
      return FeatureModuleState(
        enabled: <String, bool>{for (final String id in FeatureModuleCatalog.ids) id: map[id] == true},
      );
    } catch (_) {
      return null;
    }
  }

  /// Legacy backfill: only integer booleans 0/1 are valid; absent or
  /// invalid values default to false. Pure helper shared by the schema
  /// migration and profile initialization.
  static String backfillJson({Object? profilmanagerAktiv, Object? lagerfuehrungAktiv, Object? guvAktiv}) {
    return FeatureModuleState(
      enabled: <String, bool>{
        FeatureModuleCatalog.profileManager: _legacyBool(profilmanagerAktiv),
        FeatureModuleCatalog.inventory: _legacyBool(lagerfuehrungAktiv),
        FeatureModuleCatalog.guv: _legacyBool(guvAktiv),
      },
    ).encode();
  }

  static bool _legacyBool(Object? value) => value is int && value == 1;
}
