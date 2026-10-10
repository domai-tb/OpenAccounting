import 'package:flutter/material.dart';

import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/features/feature_modules/feature_module_service.dart';

/// Route/entry guard for disabled modules. Shows a localized unavailable
/// state and performs no database write. Disabling never deletes records.
class FeatureModuleGuard extends StatelessWidget {
  const FeatureModuleGuard({required this.service, required this.moduleId, required this.child, super.key});

  final FeatureModuleService service;
  final String moduleId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: service.isEffectivelyEnabled(moduleId),
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data == true) return child;
        final l10n = appLocalizationsOf(context);
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.block_outlined, size: 48),
                const SizedBox(height: 12),
                Text(l10n.featureModuleUnavailableTitle, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(l10n.featureModuleUnavailableDescription, textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }
}
