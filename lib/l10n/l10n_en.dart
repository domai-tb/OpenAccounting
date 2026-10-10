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
  String get globalSearchButton => 'Global search';

  @override
  String get globalSearchShortcutUnavailable => 'Global search (keyboard shortcut unavailable)';

  @override
  String get globalSearchTitle => 'Search or run a command';

  @override
  String get globalSearchPlaceholder => 'Search invoices, contacts, receipts, transactions, settings, or commands';

  @override
  String get globalSearchEmptyPrompt => 'Start typing to search';

  @override
  String get globalSearchNoResults => 'No matches for this search';

  @override
  String get globalSearchLoading => 'Searching…';

  @override
  String get globalSearchPartialFailure => 'Some local records could not be searched.';

  @override
  String globalSearchSourceUnavailable(String source) {
    return '$source could not be searched.';
  }

  @override
  String get globalSearchInvoiceType => 'Invoice';

  @override
  String get globalSearchContactType => 'Contact';

  @override
  String get globalSearchReceiptType => 'Receipt';

  @override
  String get globalSearchBankTransactionType => 'Bank transaction';

  @override
  String get globalSearchDestinationType => 'Destination';

  @override
  String get globalSearchCommandType => 'Command';

  @override
  String get globalSearchSettingsDestination => 'Settings';

  @override
  String get globalSearchNewInvoiceCommand => 'New invoice';

  @override
  String globalSearchInvoiceFallback(String id) {
    return 'Invoice #$id';
  }

  @override
  String globalSearchReceiptFallback(String id) {
    return 'Receipt #$id';
  }

  @override
  String globalSearchTransactionFallback(String id) {
    return 'Transaction #$id';
  }

  @override
  String get bankSelectedTransactionTitle => 'Selected bank transaction';

  @override
  String get bankTransactionInvalidSelection => 'The transaction link is invalid.';

  @override
  String get bankTransactionNotFound => 'This bank transaction is not available in the active profile.';

  @override
  String get bankTransactionLoadFailed => 'The bank transaction could not be loaded.';

  @override
  String get bankTransactionCounterparty => 'Counterparty';

  @override
  String get bankTransactionPurpose => 'Remittance';

  @override
  String get bankTransactionAmount => 'Amount';

  @override
  String get bankTransactionStatus => 'Status';

  @override
  String get filterDateFrom => 'Date from';

  @override
  String get filterDateTo => 'Date to';

  @override
  String get filterStatusExact => 'Exact status';

  @override
  String get filterAmountFrom => 'Amount from';

  @override
  String get filterAmountTo => 'Amount to';

  @override
  String get filterApply => 'Apply filters';

  @override
  String get filterClearAll => 'Clear all filters';

  @override
  String get filterInvalidDateRange => 'The start date must be on or before the end date.';

  @override
  String get filterInvalidAmount => 'Enter a valid amount with up to two decimal places.';

  @override
  String get filterInvalidAmountRange => 'The minimum amount must be on or below the maximum amount.';

  @override
  String get filterPreviousPage => 'Previous page';

  @override
  String get filterNextPage => 'Next page';

  @override
  String filterPageCount(int page, int pages) {
    return 'Page $page of $pages';
  }

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

  @override
  String get setupWizardTitle => 'Setup wizard';

  @override
  String get setupStepCompany => 'Company details';

  @override
  String get setupStepAccounts => 'Accounts';

  @override
  String get setupStepCategories => 'Categories';

  @override
  String get setupStepCompletion => 'Completion';

  @override
  String get profileSelectionTitle => 'Choose profile';

  @override
  String get profileLastUsed => 'Last used';

  @override
  String get dashboardLoadError => 'Loading failed';

  @override
  String get dashboardInventoryWarning => 'Inventory warning';

  @override
  String get dashboardInventoryStock => 'Inventory stock';

  @override
  String get actionChooseFile => 'Choose file';

  @override
  String get actionPreview => 'Preview';

  @override
  String get actionHistory => 'History';

  @override
  String get actionImport => 'Import';

  @override
  String receiptDetailTitle(String id) {
    return 'Receipt $id';
  }

  @override
  String get actionFilter => 'Filter';

  @override
  String get actionRemoveFilter => 'Remove filter';

  @override
  String get actionResetFilters => 'Reset filters';

  @override
  String get headerViews => 'Views';

  @override
  String get countResultSingular => 'Result';

  @override
  String journalDetailTitle(String id) {
    return 'Entry $id';
  }

  @override
  String filterTypeLabel(String value) {
    return 'Type: $value';
  }

  @override
  String filterStatusLabel(String value) {
    return 'Status: $value';
  }

  @override
  String get draftDiscardTitle => 'Discard draft?';

  @override
  String get draftDiscardMessage => 'The entered invoice data will be lost.';

  @override
  String get actionKeepEditing => 'Keep editing';

  @override
  String get actionDiscard => 'Discard';

  @override
  String draftSaveFailed(String error) {
    return 'Draft could not be saved: $error';
  }

  @override
  String get errorDateFormat => 'Enter the date in YYYY-MM-DD format';

  @override
  String errorPositiveAmount(String label) {
    return '$label must be greater than 0';
  }

  @override
  String get customersLoading => 'Loading customers…';

  @override
  String get customersLoadFailed => 'Customers could not be loaded';

  @override
  String get actionReload => 'Reload';

  @override
  String get invoiceDraftNoCustomerTitle => 'No customer created yet';

  @override
  String get invoiceDraftNoCustomerMessage => 'An invoice needs a customer so it can be assigned correctly.';

  @override
  String get actionCreateCustomer => 'Create customer';

  @override
  String get invoiceDraftCustomerLabel => 'Customer';

  @override
  String get invoiceDraftCustomerHint => 'Select customer';

  @override
  String get errorCustomerRequired => 'Customer is required';

  @override
  String get invoiceDraftTitle => 'Invoice draft';

  @override
  String get invoiceDraftDescription => 'Save an invoice line as a draft.';

  @override
  String get invoiceDraftPositionLabel => 'Line item';

  @override
  String get errorPositionRequired => 'Line item is required';

  @override
  String get invoiceDraftUnitPriceLabel => 'Unit price net';

  @override
  String get actionSaveDraft => 'Save draft';

  @override
  String get errorInvoiceIdInvalid => 'The invoice ID is invalid.';

  @override
  String contactDetailTitle(String id) {
    return 'Contact $id';
  }

  @override
  String get profileSavedRestartHint => 'Profile saved. Please restart OpenAccounting.';

  @override
  String get profileAlreadyActive => 'The profile is already active.';

  @override
  String profileSelectFailed(String error) {
    return 'The profile could not be selected: $error';
  }

  @override
  String get profileCreateTitle => 'New profile';

  @override
  String get profileNameLabel => 'Profile name';

  @override
  String get actionCreate => 'Create';

  @override
  String get profileCreated => 'Profile created.';

  @override
  String profileCreateFailed(String error) {
    return 'The profile could not be created: $error';
  }

  @override
  String get errorRecordIdInvalid => 'The record ID is invalid.';

  @override
  String errorRecordNotFound(String id) {
    return 'The record with ID $id was not found.';
  }

  @override
  String recordIdLabel(String id) {
    return 'Record ID $id';
  }

  @override
  String recordFallbackTitle(String id) {
    return 'Record #$id';
  }

  @override
  String routeErrorSource(String source) {
    return 'Operation: $source';
  }

  @override
  String get bankCategoriesLoadFailed =>
      'Categories could not be loaded. Manual categorization is not available right now.';

  @override
  String get bankHistoryLoadFailed => 'Import history could not be loaded.';

  @override
  String get bankUnsupportedFile => 'This file format is not supported. CSV and CAMT.053 XML are supported.';

  @override
  String bankFileReadFailed(String error) {
    return 'The file could not be read: $error';
  }

  @override
  String get bankFileTooLarge => 'The file is larger than 20 MB. Export a shorter period and try again.';

  @override
  String get bankPasteTitle => 'Paste CSV data';

  @override
  String get bankPasteContentLabel => 'CSV content';

  @override
  String get bankPasteHint => 'Date;Amount;Purpose;Partner';

  @override
  String get actionApply => 'Apply';

  @override
  String get bankPasteFileName => 'pasted-import.csv';

  @override
  String bankFileProcessFailed(String error) {
    return 'The file could not be processed: $error';
  }

  @override
  String get bankConfirmTitle => 'Confirm import';

  @override
  String bankConfirmMessage(int count, String account) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected rows',
      one: '$count selected row',
    );
    return '$_temp0 will be imported into $account. Duplicates are skipped by default.';
  }

  @override
  String get bankBackToReview => 'Back to review';

  @override
  String bankImportIncomplete(String error) {
    return 'The import did not complete fully: $error';
  }

  @override
  String get bankRetryNotice => 'Only unsaved rows are checked again. Already imported rows stay deduplicated.';

  @override
  String bankImportAborted(String diagnostic) {
    return 'Import aborted: $diagnostic No transaction was saved.';
  }

  @override
  String get bankImportAbortedHint => 'Fix the file or choose a matching template and try again.';

  @override
  String get bankStatusRejected => 'Rejected';

  @override
  String get bankStepChooseFile => '1. Choose file';

  @override
  String get bankUploadHint =>
      'CSV files and CAMT.053 XML exports are supported. The preview writes nothing to the database yet.';

  @override
  String get bankPathLabel => 'File path';

  @override
  String get bankPathHint => 'Choose a file or paste a path; drag & drop supported';

  @override
  String get bankStepAccountTemplate => '2. Account and template';

  @override
  String get bankNoAccountYet =>
      'No bank account yet. Create an account in the master data first; import without an account is blocked.';

  @override
  String get bankCamtHint => 'CAMT.053 is detected from the XML structure; a CSV template is not required for it.';

  @override
  String get bankStepReview => '3. Review and edit the preview';

  @override
  String bankRowsDetected(int count) {
    return '$count rows detected';
  }

  @override
  String bankRowsSelected(int count) {
    return '$count selected';
  }

  @override
  String bankRowsManual(int count) {
    return '$count categorized manually';
  }

  @override
  String get bankReviewNotice =>
      'Changes and manual categories are only saved after you explicitly confirm the import.';

  @override
  String get bankDuplicateOverride => 'Re-import already imported duplicates (only enable deliberately)';

  @override
  String bankConfirmActionCount(int count) {
    return 'Confirm import ($count)';
  }

  @override
  String get bankColPartnerPurpose => 'Partner / purpose';

  @override
  String bankRowLabel(int line) {
    return 'Row $line';
  }

  @override
  String get bankColPartner => 'Partner';

  @override
  String get bankColPurpose => 'Purpose';

  @override
  String get bankStepResult => '4. Import result';

  @override
  String get bankStatImported => 'Imported';

  @override
  String get bankStatDuplicatesSkipped => 'Duplicates skipped';

  @override
  String get bankStatCategorized => 'Categorized';

  @override
  String get bankStatManualReview => 'Manual review';

  @override
  String get bankStatFailed => 'Failed';

  @override
  String get bankResultAllSaved => 'All confirmed new rows were saved. The import is documented in the history.';

  @override
  String get bankRetryFailedRows => 'Re-check failed rows';

  @override
  String get bankFailureRowsGeneric =>
      'The database reported unsaved rows but could not return a single row error. Check account, date and amount; another attempt stays deduplicated.';

  @override
  String get bankNotSavedFix => 'Not saved — fix and check again:';

  @override
  String bankFailureRowPrefix(int line, String error) {
    return 'Row $line: $error';
  }

  @override
  String get bankWithoutPartner => 'without partner';

  @override
  String get bankWithoutPurpose => 'without purpose';

  @override
  String get bankHistoryTitle => 'Import history';

  @override
  String get bankHistoryCardSubtitle => 'Source, template, counts and result status stay traceable here.';

  @override
  String get bankHistoryRefresh => 'Refresh import history';

  @override
  String get bankColTime => 'Timestamp';

  @override
  String get bankColSource => 'Source';

  @override
  String get bankColTemplate => 'Template';

  @override
  String get bankColAccount => 'Account';

  @override
  String get bankColImported => 'Imported';

  @override
  String get bankColDuplicates => 'Duplicates';

  @override
  String get bankColError => 'Errors';

  @override
  String get bankColStatus => 'Status';

  @override
  String get bankStageFile => 'File';

  @override
  String get bankStageReview => 'Review';

  @override
  String get bankStageResult => 'Result';

  @override
  String get bankStageCurrent => 'current';

  @override
  String get bankStageComplete => 'complete';

  @override
  String get bankStageOpen => 'open';

  @override
  String bankReady(String name, String size) {
    return 'Ready: $name · $size';
  }

  @override
  String get bankDelimiterSemicolon => 'Semicolon';

  @override
  String get bankDelimiterComma => 'Comma';

  @override
  String get bankHeaderSubtitleHistory => 'Traceable import history';

  @override
  String get bankHeaderSubtitleImport => 'File import with review before saving';

  @override
  String get bankHeaderSubtitleTransactions => 'Search and filter saved bank transactions';

  @override
  String get bankViewTransactions => 'Transactions';

  @override
  String get bankNoAccountSelected => 'no account';

  @override
  String bankAccountFallback(String id) {
    return 'Account $id';
  }

  @override
  String bankCategoryFallback(String id) {
    return 'Category $id';
  }

  @override
  String get bankUnknownFile => 'Unknown file';

  @override
  String get bankStatusPartial => 'Partially imported';

  @override
  String get bankStatusFailed => 'Import failed';

  @override
  String get bankStatusImported => 'Imported';

  @override
  String get bankInvalidImportNoDiagnostic => 'Invalid import: no error diagnosis was provided.';

  @override
  String get bankRecoveryCheckFileTemplate => 'Check the file and template and try again.';

  @override
  String get bankInvalidImportNoAccount => 'Invalid import: no valid bank account selected.';

  @override
  String get bankRecoverySelectAccount => 'Choose a valid bank account and try again.';

  @override
  String get bankNoTransactionsToImport => 'No transactions to import.';

  @override
  String get bankRecoverySelectSupportedFile => 'Choose a supported file with at least one transaction.';

  @override
  String get bankHistoryNotFinalSaved => 'Import history could not be saved in the end.';

  @override
  String bankHistoryCreateFailed(String error) {
    return 'Import history could not be created: $error';
  }

  @override
  String get bankRecoveryFixDatabase => 'Fix the database problem and try again.';

  @override
  String get bankRecoveryCheckDuplicates => 'Check the existing duplicates and try again.';

  @override
  String get bankUnknownError => 'Unknown error';

  @override
  String get bankInvalidDate => 'Invalid date';

  @override
  String get bankInvalidAmount => 'Invalid amount';

  @override
  String get bankCsvUnclosedQuotes => 'Invalid CSV: quotes not closed';

  @override
  String bankCsvRowSuffix(int row) {
    return ' in row $row';
  }

  @override
  String get bankRecoveryFixCsvRow => 'Fix the CSV row and run the import again.';

  @override
  String get bankNoTransactionsFound => 'No transactions found';

  @override
  String get bankNoTemplateFound => 'No matching template found. Please choose a template.';

  @override
  String get bankNoTemplateFoundNoTransactions =>
      'No transactions found. No matching template found. Please choose a template.';

  @override
  String get bankEmptyFile => 'File is empty';

  @override
  String get bankNoHeader => 'File contains no header row';

  @override
  String get bankInvalidXmlNoTag => 'Invalid XML: no XML tag found (invalid)';

  @override
  String get bankInvalidXmlNoClosingTag => 'Invalid XML: no closing tag found (invalid)';

  @override
  String get bankInvalidXmlDocumentUnclosed => 'Invalid XML: Document not closed (invalid)';

  @override
  String get bankInvalidXmlNtryUnclosed => 'Invalid XML: Ntry not closed (invalid)';

  @override
  String get bankInvalidXmlMismatched => 'Invalid XML: nested tags do not match (invalid)';

  @override
  String get bankInvalidXmlTagUnclosed => 'Invalid XML: tag not closed (invalid)';

  @override
  String get bankAmountMissingNtry => 'Amount missing in Ntry';

  @override
  String get bankDateMissingNtry => 'Date missing in Ntry';

  @override
  String get bankAmountMissing => 'Amount missing';

  @override
  String bankDateInvalidRaw(String raw) {
    return 'Invalid date: $raw';
  }

  @override
  String bankAmountInvalidRaw(String raw) {
    return 'Invalid amount: $raw';
  }

  @override
  String bankAmountOutOfRange(String raw) {
    return 'Amount outside NUMERIC(12,2): $raw';
  }

  @override
  String get setupErrorNameRequired => 'Name is required';

  @override
  String get setupErrorAccountRequired => 'At least one account is required';

  @override
  String setupErrorIbanInvalid(String iban) {
    return 'Invalid IBAN: $iban';
  }

  @override
  String get setupErrorCashNegative => 'Cash balance must not be negative';

  @override
  String get setupErrorCashInvalid => 'Invalid cash balance';

  @override
  String get setupErrorCategoryRequired => 'At least one category is required';

  @override
  String get setupErrorDatabaseStatus => 'The database could not be read for the setup status';

  @override
  String get dashboardCustomize => 'Customize dashboard';

  @override
  String get dashboardIncome => 'Income';

  @override
  String get dashboardExpenses => 'Expenses';

  @override
  String get dashboardEmptyNoWarnings => 'No warnings';

  @override
  String get dashboardEmptyNoStock => 'No stock';

  @override
  String get dashboardEmptyNoReminders => 'No reminders';

  @override
  String get dashboardEmptyNoDeadlines => 'No deadlines';

  @override
  String get dashboardEmptyNoActivities => 'No activities';

  @override
  String get dashboardEmptyNoPayments => 'No payments';

  @override
  String quickLinkUnavailable(String label) {
    return '$label (not available)';
  }

  @override
  String dashboardUstvaDue(String date) {
    return 'VAT return due on $date';
  }

  @override
  String get quickLinkJournal => 'Journal';

  @override
  String get quickLinkItems => 'Items';

  @override
  String get dashboardWidgetOpenInvoices => 'Open invoices';

  @override
  String get dashboardWidgetIncomingPayments => 'Incoming payments';

  @override
  String get dashboardWidgetReminderWarning => 'Reminder warning';

  @override
  String get dashboardWidgetDeadlines => 'Deadlines';

  @override
  String get dashboardWidgetUstvaDeadline => 'VAT return deadline';

  @override
  String get dashboardWidgetQuickLinks => 'Quick links';

  @override
  String get dashboardWidgetIncomeExpenses => 'Income/Expenses';

  @override
  String get dashboardWidgetOverdueInvoices => 'Overdue invoices';

  @override
  String get dashboardWidgetOpenLiabilities => 'Open liabilities';

  @override
  String get dashboardWidgetBalance => 'Account balance';

  @override
  String get dashboardWidgetActivityLog => 'Activity log';

  @override
  String get bankColImport => 'Import';

  @override
  String get bankColAmount => 'Amount';

  @override
  String get bankColCategory => 'Category';

  @override
  String get bankPathHintExample => '/path/to/bank-statement.csv';

  @override
  String invoiceDraftNumber(int number) {
    return 'Draft #$number';
  }

  @override
  String get bankDuplicateOverrideLimit => 'Duplicate override limit reached (100) — manual cleanup required';

  @override
  String get bankConfidenceHigh => 'High match';

  @override
  String get bankConfidenceMedium => 'Medium match';

  @override
  String get bankConfidenceLow => 'Low match';

  @override
  String get bankConfidenceNone => 'No match';

  @override
  String get bankCandidatesUnavailable => 'Candidates could not be loaded. Automatic linking is disabled.';

  @override
  String get bankRulesTitle => 'Rules';

  @override
  String get bankRulePattern => 'Pattern (purpose)';

  @override
  String get bankRuleCategory => 'Category';

  @override
  String get bankRulePriority => 'Priority';

  @override
  String get bankRuleActive => 'Active';

  @override
  String get bankRuleNew => 'New rule';

  @override
  String get bankRuleEdit => 'Edit rule';

  @override
  String get bankRuleDelete => 'Delete rule';

  @override
  String get bankRuleSave => 'Save';

  @override
  String get bankRuleCancel => 'Cancel';

  @override
  String get bankRuleEmpty => 'No rules yet. Create a rule to categorize imports automatically.';

  @override
  String get bankRuleDisabled => 'Disabled';

  @override
  String get bankTemplatesTitle => 'Templates';

  @override
  String get bankTemplateNew => 'Custom template';

  @override
  String get bankTemplateEdit => 'Edit template';

  @override
  String get bankTemplateName => 'Name';

  @override
  String get bankTemplateProtected => 'Predefined – protected';

  @override
  String get bankTemplateDelete => 'Delete template';

  @override
  String get bankModeLabel => 'Import mode';

  @override
  String get bankModeManual => 'Manual';

  @override
  String get bankModeAutomatic => 'Automatic';

  @override
  String get bankModeOverride => 'Override once for this import';

  @override
  String get bankScoreLabel => 'Match';

  @override
  String get bankViewImport => 'Import';

  @override
  String get bankViewHistory => 'History';

  @override
  String get bankViewRules => 'Rules';

  @override
  String get bankViewTemplates => 'Templates';

  @override
  String get bankHistoryDetail => 'Details';

  @override
  String get bankHistoryRetry => 'Retry';

  @override
  String get bankHistoryReview => 'Review';

  @override
  String get bankHistorySearch => 'Search';

  @override
  String get bankHistorySearchHint => 'Search filename, template, or status';

  @override
  String get bankHistoryEmpty => 'No imports yet.';

  @override
  String get bankHistoryImportAction => 'Choose file';

  @override
  String get bankHistoryNextPage => 'Next';

  @override
  String get bankHistoryPrevPage => 'Back';

  @override
  String get bankDetailImported => 'Imported';

  @override
  String get bankDetailDuplicates => 'Duplicates';

  @override
  String get bankDetailFailed => 'Failed';

  @override
  String get bankDetailUnresolved => 'Open';

  @override
  String get bankDetailFileRejection => 'File rejection';

  @override
  String get bankDetailErrorRows => 'failed rows';

  @override
  String get bankDetailSeeHistory => 'see history for details';

  @override
  String get bankDiagnosticFile => 'File';

  @override
  String get bankDiagnosticRow => 'Row';

  @override
  String get bankDetailsUnavailable => 'Details unavailable';

  @override
  String get incomeTaxTitle => 'Income tax schedules';

  @override
  String get incomeTaxScheduleS => 'Schedule S';

  @override
  String get incomeTaxScheduleG => 'Schedule G';

  @override
  String get incomeTaxSelectPrompt => 'Choose a schedule to check availability';

  @override
  String get incomeTaxUnavailable => 'Not yet available';

  @override
  String get incomeTaxBlockerForm => 'No accepted form and source contract';

  @override
  String get incomeTaxBlockerPeriod => 'No accepted period contract';

  @override
  String get incomeTaxBlockerClassification => 'No accepted classification';

  @override
  String get incomeTaxBlockerSource => 'No complete accounting source';

  @override
  String get fiscalYearTitle => 'Fiscal year';

  @override
  String get fiscalYearStartMonth => 'Fiscal year start month';

  @override
  String get fiscalYearHint =>
      'Sets historical and future business-year report boundaries. Postings and exports stay unchanged.';

  @override
  String get fiscalYearSave => 'Save';

  @override
  String get fiscalYearSaved => 'Fiscal year saved';

  @override
  String get fiscalYearError => 'Save failed. Please retry.';

  @override
  String get fiscalYearInvalid => 'Month must be between 1 and 12';

  @override
  String get quickBookingsTitle => 'Quick bookings';

  @override
  String get quickBookingNew => 'New quick booking';

  @override
  String get quickBookingEdit => 'Edit quick booking';

  @override
  String get quickBookingDelete => 'Delete quick booking';

  @override
  String get quickBookingSave => 'Save';

  @override
  String get quickBookingCancel => 'Cancel';

  @override
  String get quickBookingName => 'Name';

  @override
  String get quickBookingDirection => 'Direction';

  @override
  String get quickBookingDirectionIn => 'Income';

  @override
  String get quickBookingDirectionOut => 'Expense';

  @override
  String get quickBookingAccount => 'Account';

  @override
  String get quickBookingCategory => 'Category';

  @override
  String get quickBookingTaxRate => 'Tax rate';

  @override
  String get quickBookingModus => 'Input mode';

  @override
  String get quickBookingModusNetto => 'Net';

  @override
  String get quickBookingModusBrutto => 'Gross';

  @override
  String get quickBookingAmount => 'Amount';

  @override
  String get quickBookingDescription => 'Description';

  @override
  String get quickBookingExecute => 'Execute';

  @override
  String get quickBookingReviewRequired => 'Review required';

  @override
  String get quickBookingUnavailable => 'Execution unavailable';

  @override
  String get quickBookingEnterAmount => 'Enter amount';

  @override
  String get quickBookingEmpty => 'No quick bookings yet.';

  @override
  String get featureModulesTitle => 'Features';

  @override
  String get featureModulesDescription => 'Enable optional modules individually.';

  @override
  String get featureModuleProfileManagerName => 'Profile Manager';

  @override
  String get featureModuleProfileManagerDescription => 'Profile overview with create, select, and rename.';

  @override
  String get featureModuleInventoryName => 'Inventory';

  @override
  String get featureModuleInventoryDescription => 'Stock warnings, balances, and manual corrections.';

  @override
  String get featureModuleGuvName => 'Profit and loss';

  @override
  String get featureModuleGuvDescription => 'Profit and loss statement from journal postings.';

  @override
  String get featureModuleEnabled => 'Enabled';

  @override
  String get featureModuleDisabled => 'Disabled';

  @override
  String get featureModuleUnavailable => 'Unavailable';

  @override
  String get featureModuleDataRetained => 'Disabling hides entries. Existing data is retained.';

  @override
  String get featureModuleThresholdActive => 'GuV threshold reached. GuV stays enabled.';

  @override
  String get featureModuleSaveError => 'Save failed. Please retry.';

  @override
  String get featureModuleUnavailableTitle => 'Module unavailable';

  @override
  String get featureModuleUnavailableDescription => 'This module is disabled. No data was changed.';

  @override
  String get guidanceExplainAction => 'Explanation';

  @override
  String get guidanceSearchHint => 'Search help topics…';

  @override
  String get guidanceEmptyResults => 'No reviewed help for this search.';

  @override
  String guidanceLocationLabel(String route, String control) {
    return 'Location: $route · $control';
  }

  @override
  String guidanceContractLabel(String contract, String revision) {
    return 'Contract: $contract · $revision';
  }

  @override
  String get guidanceNoAdviceNote => 'Note: This explanation describes app behavior and is not tax advice.';

  @override
  String get guidanceTitleSkrMapping => 'SKR mapping of the category';

  @override
  String get guidanceBodySkrMapping =>
      'Defines which standard chart-of-accounts (SKR 03/04) account this category is assigned to in reports. The mapping controls the report line where amounts of this category appear. It changes no postings and does not replace a tax account choice.';

  @override
  String get guidanceTitleJournalImmutability => 'Immutability of the journal';

  @override
  String get guidanceBodyJournalImmutability =>
      'Completed journal postings cannot be edited or deleted afterwards. Errors are corrected only through a reversal posting with a counter-entry. This keeps the posting history fully traceable.';

  @override
  String get guidanceTitleJournalStorno => 'Reversal posting';

  @override
  String get guidanceBodyJournalStorno =>
      'Creates a counter-entry that arithmetically cancels the original posting. The original posting stays preserved and visible. Only after the reversal can a corrected posting be made if needed.';

  @override
  String get guidanceTitleJournalGroup => 'Journal group';

  @override
  String get guidanceBodyJournalGroup =>
      'Groups related postings of one transaction for overview and filtering in reports. It changes neither amounts nor tax rates.';

  @override
  String get guidanceTitleEuerInputTaxClaim => 'Input-tax claim in the EÜR';

  @override
  String get guidanceBodyEuerInputTaxClaim =>
      'States the direction in which claimed input tax flows into EÜR finalization. The setting affects the reported business expenses of the period. The app does not check whether or to what extent input tax can be claimed; § 15 UStG (German VAT Act) applies.';

  @override
  String get guidanceTitleForderungStatus => 'Receivable status';

  @override
  String get guidanceBodyForderungStatus =>
      'Shows the processing state of an open receivable: open, partially paid, paid, or overdue. The status controls whether the item appears in dunning runs and open-item overviews. It changes no invoice amounts.';

  @override
  String get guidanceTitleForderungOverpayment => 'Overpayment notice';

  @override
  String get guidanceBodyForderungOverpayment =>
      'Marks a payment that exceeds the open receivable amount. The excess is recorded in the overpayment log and kept available for allocation or refund. No automatic offsetting happens without your posting.';

  @override
  String get guidanceTitleVerbindlichkeitPayment => 'Payable payment';

  @override
  String get guidanceBodyVerbindlichkeitPayment =>
      'Records a payment made against an open payable. The payment reduces the supplier open balance and appears in the payment journal. The app does not check due dates or cash-discount eligibility.';

  @override
  String get guidanceTitleMahnungFeeInterest => 'Dunning fees and late interest';

  @override
  String get guidanceBodyMahnungFeeInterest =>
      'Records flat dunning fees and calculated late-payment interest of a dunning run. The amounts increase the open receivable and are documented in the dunning history. The app does not check whether or what amount of fees or interest is permitted under §§ 286, 288 BGB (German Civil Code).';

  @override
  String get guidanceTitleBankMatchStatus => 'Match status of the assignment';

  @override
  String get guidanceBodyBankMatchStatus =>
      'Shows how confidently the app assigns a bank transaction to an invoice or category: suggested or confirmed. Only confirmed assignments affect open items. Low-score suggestions are never confirmed automatically.';

  @override
  String get guidanceTitleBankClassification => 'Manual classification';

  @override
  String get guidanceBodyBankClassification =>
      'Overrides the automatically suggested business nature of a transaction (business, private, or mixed). The override applies to this transaction and controls its tax reporting. Rules for recurring cases are created separately.';

  @override
  String get guidanceTitleAngebotStatus => 'Quote status';

  @override
  String get guidanceBodyAngebotStatus =>
      'Tracks a quote from draft through sent and accepted to rejected or expired. Only an accepted quote can be converted into an order. The status has no tax effect.';

  @override
  String get guidanceTitleAuftragStatus => 'Order status';

  @override
  String get guidanceBodyAuftragStatus =>
      'Tracks an order from confirmed through in progress to completed or cancelled. Completion releases the related invoice for creation. Cancelled orders are kept for record purposes.';

  @override
  String get guidanceTitleCorrectionCreditSign => 'Sign of correction amounts';

  @override
  String get guidanceBodyCorrectionCreditSign =>
      'Correction amounts keep their sign so the VAT mathematics of the original invoice is preserved. A credit reduces, an additional charge increases the taxable base. The app performs no VAT assessment of the correction reason; the behavior is limited to supported correction cases.';

  @override
  String get guidanceTitleTaxSpecial25a => 'Margin taxation under § 25a UStG';

  @override
  String get guidanceBodyTaxSpecial25a =>
      'Marks supplies whose taxable base is the margin rather than the total price. The app reports such supplies separately in the tax overview. The app does not check whether the conditions of § 25a UStG are met; unsupported constellations are shown as unavailable.';

  @override
  String get contactsTabCustomers => 'Customers';

  @override
  String get contactsTabSuppliers => 'Suppliers';

  @override
  String get filterArchived => 'Archived';

  @override
  String get filterActive => 'Active';

  @override
  String get actionArchive => 'Archive';

  @override
  String get actionRestore => 'Restore';

  @override
  String get actionBulkArchive => 'Archive selection';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionInspect => 'Inspect';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionSaving => 'Saving…';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionSelectCustomer => 'Customer';

  @override
  String get actionSelectSupplier => 'Supplier';

  @override
  String get actionCreateSupplier => 'Create supplier';

  @override
  String get actionCreateArticle => 'Create article';

  @override
  String get actionCreateGroup => 'Create group';

  @override
  String get actionCreateCategory => 'Create category';

  @override
  String get actionCreateAccount => 'Create account';

  @override
  String get actionCreateTaxRate => 'Create tax rate';

  @override
  String get actionCreateNumberRange => 'Create number range';

  @override
  String get contactTypeSelectionTitle => 'Choose contact type';

  @override
  String get contactTypeSelectionMessage =>
      'Choose whether to open a customer or supplier record. No record is loaded without a selection.';

  @override
  String get articleTypeSelectionTitle => 'Choose article type';

  @override
  String get articleTypeSelectionMessage =>
      'Choose whether to open an article or an article group. No record is loaded without a selection.';

  @override
  String get archiveConfirmTitle => 'Confirm archive';

  @override
  String get archiveConfirmMessage =>
      'The record receives an archive timestamp and stays available to existing documents and reports.';

  @override
  String get restoreConfirmTitle => 'Confirm restore';

  @override
  String get restoreConfirmMessage =>
      'The archive timestamp is removed and the record returns to the default selection.';

  @override
  String get workspaceUnavailable => 'Data unavailable';

  @override
  String get workspaceUnavailableMessage => 'The data could not be loaded. Please retry.';

  @override
  String get saveFailed => 'Save failed';

  @override
  String get formRequiredField => 'Required field';

  @override
  String get formName => 'Name';

  @override
  String get formCompany => 'Company';

  @override
  String get formStreet => 'Street and number';

  @override
  String get formPostalCode => 'Postal code';

  @override
  String get formCity => 'City';

  @override
  String get formEmail => 'Email';

  @override
  String get formPhone => 'Phone';

  @override
  String get formVatId => 'VAT ID';

  @override
  String get formIban => 'IBAN';

  @override
  String get formDescription => 'Description';

  @override
  String get formSectionBasic => 'Basic data';

  @override
  String get formSectionContact => 'Contact';

  @override
  String get formSectionTax => 'Tax and payment';

  @override
  String get customerEditTitle => 'Edit customer';

  @override
  String get supplierEditTitle => 'Edit supplier';

  @override
  String get contactArchived => 'Archived';

  @override
  String get routeArticles => 'Articles';

  @override
  String get articlesViewItems => 'Articles';

  @override
  String get articlesViewGroups => 'Article groups';

  @override
  String get settingsMasterData => 'Master data';

  @override
  String get settingsCompany => 'Company data';

  @override
  String get settingsCategories => 'Categories';

  @override
  String get settingsAccounts => 'Bank accounts';

  @override
  String get settingsTaxRates => 'Tax rates';

  @override
  String get settingsNumberRanges => 'Number ranges';

  @override
  String get countCustomers => 'customers';

  @override
  String get countSuppliers => 'suppliers';

  @override
  String get countArticles => 'articles';

  @override
  String get countGroups => 'groups';

  @override
  String get companySetupNeeded => 'No company data yet. Create it now.';

  @override
  String get numberRangeNextLabel => 'Next number';
}
