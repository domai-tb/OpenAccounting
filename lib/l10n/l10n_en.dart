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
  String get sidebarHelp => 'Help';

  @override
  String get sidebarMenu => 'Menu';

  @override
  String get sidebarSectionOverview => 'OVERVIEW';

  @override
  String get sidebarSectionBusiness => 'BUSINESS';

  @override
  String get sidebarSectionTaxes => 'TAXES';

  @override
  String get workspaceLocalProfile => 'Local profile';

  @override
  String get workspaceManage => 'Manage profiles';

  @override
  String get localTitle => 'Local';

  @override
  String get localDescription => 'All data is stored locally — no cloud access.';

  @override
  String get close => 'Close';

  @override
  String get backendUnreachable => 'Backend not reachable';

  @override
  String get retry => 'Retry';

  @override
  String get profileLoadError => 'Profiles could not be loaded';

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

  @override
  String get language => 'Language';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsPrivacyDescription => 'Your accounting data stays on this device.';

  @override
  String get settingsProfiles => 'Profiles';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsProfileLoadError => 'Profiles could not be loaded';

  @override
  String get settingsProfileRetry => 'Retry';

  @override
  String get routeOverview => 'Overview';

  @override
  String get routeInvoices => 'Invoices';

  @override
  String get routeReceipts => 'Receipts';

  @override
  String get routeBanking => 'Banking';

  @override
  String get routeContacts => 'Contacts';

  @override
  String get routeTaxes => 'Taxes';

  @override
  String get routeReports => 'Reports';

  @override
  String get routeSettings => 'Settings';

  @override
  String get routeHelp => 'Help';

  @override
  String get routeInventory => 'Inventory';

  @override
  String get routeSetup => 'Setup';

  @override
  String get actionBackOverview => 'Back to overview';

  @override
  String get actionNewInvoice => 'New invoice';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionReset => 'Reset';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionClose => 'Close';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionBack => 'Back';

  @override
  String get actionSkip => 'Skip';

  @override
  String get searchHint => 'Search…';

  @override
  String get loading => 'Loading…';

  @override
  String get loadError => 'Data could not be loaded';

  @override
  String get emptyResults => 'No matches';

  @override
  String get emptyEntries => 'No entries yet';

  @override
  String get countResults => 'results';

  @override
  String get countInvoices => 'invoices';

  @override
  String get countReceipts => 'receipts';

  @override
  String get countContacts => 'contacts';

  @override
  String get countTransactions => 'transactions';

  @override
  String get countRecords => 'records';

  @override
  String get statusOpen => 'Open';

  @override
  String get statusPaid => 'Paid';

  @override
  String get statusDraft => 'Draft';

  @override
  String get statusOverdue => 'Overdue';

  @override
  String get statusUnknown => 'Unknown';

  @override
  String get documentInvoice => 'Invoice';

  @override
  String get documentCreditNote => 'Credit note';

  @override
  String get documentReceipt => 'Receipt';

  @override
  String get documentOther => 'Document';

  @override
  String get dateLabel => 'Date';

  @override
  String get amountHidden => 'Amount hidden';

  @override
  String get dashboardTitle => 'Overview';

  @override
  String get dashboardWelcome => 'Welcome to your local accounting workspace.';

  @override
  String get dashboardInventory => 'Inventory';

  @override
  String get dashboardInventoryUnavailable => 'Inventory is currently unavailable.';

  @override
  String get invoicesSubtitle => 'Invoices';

  @override
  String get receiptsSubtitle => 'Receipts';

  @override
  String get bankingSubtitle => 'Bank transactions';

  @override
  String get contactsSubtitle => 'Contacts';

  @override
  String get taxesSubtitle => 'Taxes';

  @override
  String get reportsSubtitle => 'Reports';

  @override
  String get helpSubtitle => 'Help and support';

  @override
  String get notFoundDescription => 'The requested page could not be found.';

  @override
  String get databaseUnavailable => 'The local database is unavailable.';

  @override
  String get dataLoadError => 'We could not load this data.';

  @override
  String get setupSubtitle => 'Set up your local accounting profile.';

  @override
  String get setupStep => 'Step';

  @override
  String get setupCompanyName => 'Company name';

  @override
  String get setupCompanyNameHint => 'Enter the legal name of your company.';

  @override
  String get setupIban => 'IBAN';

  @override
  String get setupIbanHint => 'Optional bank account for the opening balance.';

  @override
  String get setupCashBalance => 'Opening cash balance';

  @override
  String get setupCashBalanceHint => 'Enter the current cash balance.';

  @override
  String get setupCategories => 'Categories';

  @override
  String get setupCategoriesHint => 'Choose the categories you use most often.';

  @override
  String get setupRequired => 'Please complete the required fields.';

  @override
  String get setupInvalidIban => 'Enter a valid IBAN or leave this field empty.';

  @override
  String get setupDatabaseError => 'The profile could not be saved.';

  @override
  String get setupRetry => 'Try setup again';

  @override
  String get setupComplete => 'Setup complete';

  @override
  String get setupSaving => 'Saving profile…';

  @override
  String get setupSaved => 'Profile saved.';

  @override
  String get setupSkipConfirm => 'Skip setup for now?';

  @override
  String get inventoryTitle => 'Inventory';

  @override
  String get inventoryUnavailable => 'Inventory management is not available yet.';

  @override
  String get inventoryUnavailableDescription => 'Inventory tracking is not available in this profile.';

  @override
  String get inventoryReadOnly => 'Read-only';

  @override
  String get inventoryRetry => 'Retry';

  @override
  String get inventoryBack => 'Back to overview';

  @override
  String get pdfInvoice => 'Invoice';

  @override
  String get pdfCreditNote => 'Credit note';

  @override
  String get pdfStorno => 'Cancellation';

  @override
  String get pdfQuote => 'Quote';

  @override
  String get pdfOrder => 'Order';

  @override
  String get pdfProforma => 'Proforma invoice';

  @override
  String get pdfDelivery => 'Delivery note';

  @override
  String get pdfOriginalInvoice => 'Original invoice';

  @override
  String get pdfDate => 'Date';

  @override
  String get pdfInvoiceDate => 'Invoice date';

  @override
  String get pdfDueSince => 'Due since';

  @override
  String get pdfValidUntil => 'Valid until';

  @override
  String get pdfCustomerNumber => 'Customer number';

  @override
  String get pdfNet => 'Net';

  @override
  String get pdfTax => 'Tax';

  @override
  String get pdfTotal => 'Total';

  @override
  String get pdfPayment => 'Payment';

  @override
  String get pdfReminder => 'Reminder';

  @override
  String get pdfUnknown => '—';

  @override
  String get pdfPage => 'Page';

  @override
  String get a11yNavigation => 'Navigation';

  @override
  String get a11yOpenMenu => 'Open menu';

  @override
  String get a11yCloseMenu => 'Close menu';

  @override
  String get a11yAmountHidden => 'Amount hidden';

  @override
  String get pdfPhone => 'Phone';

  @override
  String get pdfEmail => 'Email';

  @override
  String get pdfTaxNumber => 'Tax number';

  @override
  String get pdfVatId => 'VAT ID';

  @override
  String get pdfTo => 'Bill to';

  @override
  String get pdfInvoiceNumber => 'Invoice number';

  @override
  String get pdfOrderStatus => 'Order status';

  @override
  String get pdfNoVat => 'No VAT is charged under §19 UStG';

  @override
  String get pdfPosition => 'No.';

  @override
  String get pdfDescription => 'Description';

  @override
  String get pdfQuantity => 'Quantity';

  @override
  String get pdfUnitPrice => 'Unit price';

  @override
  String get pdfDiscount => 'Discount';

  @override
  String get pdfGross => 'Gross';

  @override
  String get pdfVatRate => 'VAT rate';

  @override
  String get pdfSubtotal => 'Subtotal';

  @override
  String get pdfDiscountAmount => 'Discount';

  @override
  String get pdfGrossTotal => 'Total amount';

  @override
  String get pdfPaymentDetails => 'Payment details';

  @override
  String get pdfIban => 'IBAN';

  @override
  String get pdfBic => 'BIC';

  @override
  String get pdfBank => 'Bank';
}
