// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OpenAccounting';

  @override
  String get hello => 'Hello! Your accounting is ready.';

  @override
  String get welcome => 'Welcome! You can get started.';

  @override
  String get settingsTheme => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get sidebarOverview => 'Overview';

  @override
  String get sidebarInvoices => 'Invoices';

  @override
  String get sidebarReceipts => 'Receipts';

  @override
  String get sidebarBanking => 'Banking';

  @override
  String get sidebarContacts => 'Contacts';

  @override
  String get sidebarTaxes => 'Taxes';

  @override
  String get sidebarReports => 'Reports';

  @override
  String get sidebarSettings => 'Settings';

  @override
  String get backendUnreachable => 'Backend not reachable';

  @override
  String get retry => 'Retry';

  @override
  String get notFound => 'Not found';

  @override
  String get invoiceNotFound => 'Invoice not found';

  @override
  String get setupTitle => 'Your accounting. Local on your device.';

  @override
  String get setupStart => 'Get started';

  @override
  String get confirmDelete => 'Do you really want to delete this invoice?';

  @override
  String get emptyInvoices => 'No invoices yet. Create your first invoice.';
}
