// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'OpenAccounting';

  @override
  String get hello => 'Hallo! Deine Buchhaltung ist bereit.';

  @override
  String get welcome => 'Willkommen! Du kannst jetzt loslegen.';

  @override
  String get settingsTheme => 'Darstellung';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get sidebarOverview => 'Übersicht';

  @override
  String get sidebarInvoices => 'Rechnungen';

  @override
  String get sidebarReceipts => 'Belege';

  @override
  String get sidebarBanking => 'Bank & Zahlungen';

  @override
  String get sidebarContacts => 'Kontakte';

  @override
  String get sidebarTaxes => 'Steuern';

  @override
  String get sidebarReports => 'Auswertungen';

  @override
  String get sidebarSettings => 'Einstellungen';

  @override
  String get backendUnreachable => 'Backend nicht erreichbar';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get notFound => 'Nicht gefunden';

  @override
  String get invoiceNotFound => 'Rechnung nicht gefunden';

  @override
  String get setupTitle => 'Deine Buchhaltung. Lokal auf deinem Gerät.';

  @override
  String get setupStart => 'Loslegen';

  @override
  String get confirmDelete => 'Möchtest du diese Rechnung wirklich löschen?';

  @override
  String get emptyInvoices => 'Noch keine Rechnungen. Erstelle deine erste Rechnung.';
}
