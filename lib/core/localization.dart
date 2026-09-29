import 'package:flutter/material.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Resolves the generated catalog for a widget, including isolated widgets
/// mounted without an AppLocalizations delegate in tests or embedders.
AppLocalizations appLocalizationsOf(BuildContext context) {
  final AppLocalizations? provided = AppLocalizations.of(context);
  if (provided != null) return provided;

  // MaterialApp installs a generic Localizations ancestor even when the app
  // catalog delegate is absent. Treat that isolated embedding as the app's
  // German default; production roots always provide the generated delegate
  // and therefore take the active locale branch above.
  return lookupAppLocalizations(const Locale('de'));
}
