import 'package:flutter/material.dart';

import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/features/feature_modules/feature_module_catalog.dart';
import 'package:openaccounting/features/feature_modules/feature_module_service.dart';
import 'package:openaccounting/features/feature_modules/feature_module_state.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Module controls for `Einstellungen → Funktionen`. Reads and writes only
/// through [FeatureModuleService]; never issues database queries from UI.
/// Disabling hides entry points; records are preserved and the re-enable
/// action stays on this section.
class FeatureModuleSettingsSection extends StatefulWidget {
  const FeatureModuleSettingsSection({required this.service, super.key});

  final FeatureModuleService service;

  @override
  State<FeatureModuleSettingsSection> createState() => _FeatureModuleSettingsSectionState();
}

class _FeatureModuleSettingsSectionState extends State<FeatureModuleSettingsSection> {
  FeatureModuleState? _state;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final FeatureModuleState state = await widget.service.currentState();
      if (!mounted) return;
      setState(() {
        _state = state;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _toggle(String id, bool value) async {
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    final FeatureModuleSetResult result = await widget.service.setEnabled(id, value: value);
    if (!mounted) return;
    final AppLocalizations l10n = appLocalizationsOf(context);
    setState(() {
      _saving = false;
      _state = result.state;
      if (!result.success) {
        _error = result.reason == FeatureModuleSetResult.threshold
            ? l10n.featureModuleThresholdActive
            : l10n.featureModuleSaveError;
      } else {
        _notice = result.state.isEnabled(id) ? l10n.featureModuleEnabled : l10n.featureModuleDisabled;
      }
    });
  }

  String _name(AppLocalizations l10n, String id) {
    switch (id) {
      case FeatureModuleCatalog.profileManager:
        return l10n.featureModuleProfileManagerName;
      case FeatureModuleCatalog.inventory:
        return l10n.featureModuleInventoryName;
      case FeatureModuleCatalog.guv:
        return l10n.featureModuleGuvName;
      default:
        return id;
    }
  }

  String _description(AppLocalizations l10n, String id) {
    switch (id) {
      case FeatureModuleCatalog.profileManager:
        return l10n.featureModuleProfileManagerDescription;
      case FeatureModuleCatalog.inventory:
        return l10n.featureModuleInventoryDescription;
      case FeatureModuleCatalog.guv:
        return l10n.featureModuleGuvDescription;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    if (_loading) {
      return const LinearProgressIndicator();
    }
    final FeatureModuleState state = _state ?? FeatureModuleState.defaults();
    return Semantics(
      liveRegion: true,
      label: _notice ?? _error ?? l10n.featureModulesTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.featureModulesTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(l10n.featureModulesDescription, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(l10n.featureModuleDataRetained, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          for (final String id in FeatureModuleCatalog.ids) ...<Widget>[
            Builder(
              builder: (BuildContext context) {
                final bool available = widget.service.isAvailable(id);
                final bool enabled = state.isEnabled(id) && available;
                final String status = enabled
                    ? l10n.featureModuleEnabled
                    : (available ? l10n.featureModuleDisabled : l10n.featureModuleUnavailable);
                return SwitchListTile.adaptive(
                  key: ValueKey<String>('feature_module_toggle_$id'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(_name(l10n, id)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(_description(l10n, id)),
                      Text(status, key: ValueKey<String>('feature_module_status_$id')),
                      if (id == FeatureModuleCatalog.guv && widget.service.guvThresholdApplies)
                        Text(l10n.featureModuleThresholdActive),
                    ],
                  ),
                  value: enabled,
                  onChanged: (!available || _saving) ? null : (bool value) => _toggle(id, value),
                );
              },
            ),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              semanticsLabel: _error,
            ),
          ],
          if (_notice != null) ...<Widget>[const SizedBox(height: 8), Text(_notice!, semanticsLabel: _notice)],
        ],
      ),
    );
  }
}
