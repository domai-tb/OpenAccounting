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
  String get localDescription =>
      'All data is stored locally — no cloud access.';

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
  String get settingsPrivacyDescription =>
      'Your accounting data stays on this device.';

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
  String get reportCatalogEuer => 'EÜR income surplus';

  @override
  String get reportCatalogEks => 'Anlage EKS';

  @override
  String get reportCatalogGuv => 'Profit and loss';

  @override
  String get reportCatalogDatev => 'DATEV export';

  @override
  String get reportCatalogHistory => 'Export history';

  @override
  String get reportCatalogUstva => 'VAT pre-return';

  @override
  String get reportCatalogZm => 'EU Sales List';

  @override
  String get reportStatusAvailable => 'Available';

  @override
  String get reportStatusUnavailable => 'Unavailable';

  @override
  String get reportSelectionInvalid => 'Invalid report selection';

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
  String get globalSearchShortcutUnavailable =>
      'Global search (keyboard shortcut unavailable)';

  @override
  String get globalSearchTitle => 'Search or run a command';

  @override
  String get globalSearchPlaceholder =>
      'Search invoices, contacts, receipts, transactions, settings, or commands';

  @override
  String get globalSearchEmptyPrompt => 'Start typing to search';

  @override
  String get globalSearchNoResults => 'No matches for this search';

  @override
  String get globalSearchLoading => 'Searching…';

  @override
  String get globalSearchPartialFailure =>
      'Some local records could not be searched.';

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
  String get bankTransactionInvalidSelection =>
      'The transaction link is invalid.';

  @override
  String get bankTransactionNotFound =>
      'This bank transaction is not available in the active profile.';

  @override
  String get bankTransactionLoadFailed =>
      'The bank transaction could not be loaded.';

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
  String get filterInvalidDateRange =>
      'The start date must be on or before the end date.';

  @override
  String get filterInvalidAmount =>
      'Enter a valid amount with up to two decimal places.';

  @override
  String get filterInvalidAmountRange =>
      'The minimum amount must be on or below the maximum amount.';

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
  String get dashboardInventoryUnavailable =>
      'Inventory is currently unavailable.';

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
  String get setupInvalidIban =>
      'Enter a valid IBAN or leave this field empty.';

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
  String get inventoryUnavailable =>
      'Inventory management is not available yet.';

  @override
  String get inventoryUnavailableDescription =>
      'Inventory tracking is not available in this profile.';

  @override
  String get inventoryReadOnly => 'Read-only';

  @override
  String get inventoryRetry => 'Retry';

  @override
  String get inventoryBack => 'Back to overview';

  @override
  String get stocktakeNewAction => 'New stocktake';

  @override
  String get stocktakeStichtagLabel => 'Reporting date';

  @override
  String get stocktakeRecordAction => 'Record';

  @override
  String get stocktakeDraftStatus => 'Draft';

  @override
  String get stocktakeRecordedStatus => 'Recorded';

  @override
  String get stocktakeCountLabel => 'Counted quantity';

  @override
  String get stocktakePhysicalCount => 'Physical count';

  @override
  String get stocktakeMissingCount =>
      'Enter a counted quantity for every article.';

  @override
  String get stocktakeInvalidCount => 'Enter a valid counted quantity.';

  @override
  String get stocktakeInvalidDate => 'Enter the reporting date as YYYY-MM-DD';

  @override
  String get stocktakeNegativeForbidden =>
      'Counted quantities must not be negative.';

  @override
  String get stocktakePrecisionInvalid =>
      'Counted quantities may have at most three decimal places.';

  @override
  String get stocktakeNoCountable => 'No countable articles available.';

  @override
  String get stocktakeNoCountableDescription =>
      'Enable inventory tracking for at least one article.';

  @override
  String get stocktakeHistoryTitle => 'Recorded stocktakes';

  @override
  String get stocktakeBookUnavailable => 'Book quantity unavailable';

  @override
  String get stocktakeVarianceUnavailable => 'Variance unavailable';

  @override
  String get stocktakeValuationUnavailable => 'Valuation unavailable';

  @override
  String get stocktakeValuationDescription =>
      'No reviewed valuation policy is available. Counted quantities remain available.';

  @override
  String get stocktakeCorrectionHint =>
      'Record corrections in a new stocktake.';

  @override
  String get stocktakeDisabledNew => 'New stocktakes are disabled.';

  @override
  String get stocktakeEmpty => 'No stocktakes yet.';

  @override
  String get stocktakeCapturedAt => 'Captured at';

  @override
  String get stocktakeArticleColumn => 'Article';

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
  String get invoiceDraftNoCustomerMessage =>
      'An invoice needs a customer so it can be assigned correctly.';

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
  String get profileSavedRestartHint =>
      'Profile saved. Please restart OpenAccounting.';

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
  String get bankUnsupportedFile =>
      'This file format is not supported. CSV and CAMT.053 XML are supported.';

  @override
  String bankFileReadFailed(String error) {
    return 'The file could not be read: $error';
  }

  @override
  String get bankFileTooLarge =>
      'The file is larger than 20 MB. Export a shorter period and try again.';

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
  String get bankRetryNotice =>
      'Only unsaved rows are checked again. Already imported rows stay deduplicated.';

  @override
  String bankImportAborted(String diagnostic) {
    return 'Import aborted: $diagnostic No transaction was saved.';
  }

  @override
  String get bankImportAbortedHint =>
      'Fix the file or choose a matching template and try again.';

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
  String get bankPathHint =>
      'Choose a file or paste a path; drag & drop supported';

  @override
  String get bankStepAccountTemplate => '2. Account and template';

  @override
  String get bankNoAccountYet =>
      'No bank account yet. Create an account in the master data first; import without an account is blocked.';

  @override
  String get bankCamtHint =>
      'CAMT.053 is detected from the XML structure; a CSV template is not required for it.';

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
  String get bankDuplicateOverride =>
      'Re-import already imported duplicates (only enable deliberately)';

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
  String get bankResultAllSaved =>
      'All confirmed new rows were saved. The import is documented in the history.';

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
  String get bankHistoryCardSubtitle =>
      'Source, template, counts and result status stay traceable here.';

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
  String get bankHeaderSubtitleImport =>
      'File import with review before saving';

  @override
  String get bankHeaderSubtitleTransactions =>
      'Search and filter saved bank transactions';

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
  String get bankInvalidImportNoDiagnostic =>
      'Invalid import: no error diagnosis was provided.';

  @override
  String get bankRecoveryCheckFileTemplate =>
      'Check the file and template and try again.';

  @override
  String get bankInvalidImportNoAccount =>
      'Invalid import: no valid bank account selected.';

  @override
  String get bankRecoverySelectAccount =>
      'Choose a valid bank account and try again.';

  @override
  String get bankNoTransactionsToImport => 'No transactions to import.';

  @override
  String get bankRecoverySelectSupportedFile =>
      'Choose a supported file with at least one transaction.';

  @override
  String get bankHistoryNotFinalSaved =>
      'Import history could not be saved in the end.';

  @override
  String bankHistoryCreateFailed(String error) {
    return 'Import history could not be created: $error';
  }

  @override
  String get bankRecoveryFixDatabase =>
      'Fix the database problem and try again.';

  @override
  String get bankRecoveryCheckDuplicates =>
      'Check the existing duplicates and try again.';

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
  String get bankRecoveryFixCsvRow =>
      'Fix the CSV row and run the import again.';

  @override
  String get bankNoTransactionsFound => 'No transactions found';

  @override
  String get bankNoTemplateFound =>
      'No matching template found. Please choose a template.';

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
  String get bankInvalidXmlNoClosingTag =>
      'Invalid XML: no closing tag found (invalid)';

  @override
  String get bankInvalidXmlDocumentUnclosed =>
      'Invalid XML: Document not closed (invalid)';

  @override
  String get bankInvalidXmlNtryUnclosed =>
      'Invalid XML: Ntry not closed (invalid)';

  @override
  String get bankInvalidXmlMismatched =>
      'Invalid XML: nested tags do not match (invalid)';

  @override
  String get bankInvalidXmlTagUnclosed =>
      'Invalid XML: tag not closed (invalid)';

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
  String get setupErrorDatabaseStatus =>
      'The database could not be read for the setup status';

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
  String get bankDuplicateOverrideLimit =>
      'Duplicate override limit reached (100) — manual cleanup required';

  @override
  String get bankConfidenceHigh => 'High match';

  @override
  String get bankConfidenceMedium => 'Medium match';

  @override
  String get bankConfidenceLow => 'Low match';

  @override
  String get bankConfidenceNone => 'No match';

  @override
  String get bankCandidatesUnavailable =>
      'Candidates could not be loaded. Automatic linking is disabled.';

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
  String get bankRuleEmpty =>
      'No rules yet. Create a rule to categorize imports automatically.';

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
  String get featureModulesDescription =>
      'Enable optional modules individually.';

  @override
  String get featureModuleProfileManagerName => 'Profile Manager';

  @override
  String get featureModuleProfileManagerDescription =>
      'Profile overview with create, select, and rename.';

  @override
  String get featureModuleInventoryName => 'Inventory';

  @override
  String get featureModuleInventoryDescription =>
      'Stock warnings, balances, and manual corrections.';

  @override
  String get featureModuleGuvName => 'Profit and loss';

  @override
  String get featureModuleGuvDescription =>
      'Profit and loss statement from journal postings.';

  @override
  String get featureModuleEnabled => 'Enabled';

  @override
  String get featureModuleDisabled => 'Disabled';

  @override
  String get featureModuleUnavailable => 'Unavailable';

  @override
  String get featureModuleDataRetained =>
      'Disabling hides entries. Existing data is retained.';

  @override
  String get featureModuleThresholdActive =>
      'GuV threshold reached. GuV stays enabled.';

  @override
  String get featureModuleSaveError => 'Save failed. Please retry.';

  @override
  String get featureModuleUnavailableTitle => 'Module unavailable';

  @override
  String get featureModuleUnavailableDescription =>
      'This module is disabled. No data was changed.';

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
  String get guidanceNoAdviceNote =>
      'Note: This explanation describes app behavior and is not tax advice.';

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
  String get guidanceTitleMahnungFeeInterest =>
      'Dunning fees and late interest';

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
  String get workspaceUnavailableMessage =>
      'The data could not be loaded. Please retry.';

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

  @override
  String get smtpTestSuccess =>
      'SMTP check succeeded: greeting, TLS negotiation, and sign-in completed. No message was sent.';

  @override
  String get smtpTestHostUnreachable =>
      'Host unreachable. No message was sent.';

  @override
  String get smtpTestTlsFailed =>
      'TLS verification failed. No plaintext attempt was made.';

  @override
  String get smtpTestAuthFailed => 'Sign-in failed. Check the credentials.';

  @override
  String get smtpModeImplicitTls => 'Implicit TLS';

  @override
  String get smtpModeStarttls => 'STARTTLS (required)';

  @override
  String get smtpVaultUnavailable =>
      'The system keychain is unavailable. SMTP stays disabled.';

  @override
  String get smtpMigrationRetry =>
      'Please retry access or re-enter the password.';

  @override
  String get smtpPasswordMissing =>
      'No SMTP password stored yet. Please enter the password.';

  @override
  String get smtpDisabled => 'SMTP disabled';

  @override
  String get docEmailSend => 'Send by email';

  @override
  String get docEmailPreviewTitle => 'Review message';

  @override
  String get docEmailConfirmSend => 'Send reviewed message';

  @override
  String get docEmailRecipient => 'Recipient';

  @override
  String get docEmailSender => 'Sender';

  @override
  String get docEmailSubject => 'Subject';

  @override
  String get docEmailBody => 'Message';

  @override
  String get docEmailAttachments => 'Attachments';

  @override
  String get docEmailAccepted =>
      'Accepted by the SMTP server (no delivery proof).';

  @override
  String get docEmailRejected => 'Rejected by the server. Not marked as sent.';

  @override
  String get docEmailUnknown =>
      'Outcome unclear. Resend only after confirmation.';

  @override
  String get docEmailUnknownRetryConfirm =>
      'May already be delivered. Send again anyway?';

  @override
  String get docEmailBlockedDraft => 'Drafts cannot be sent.';

  @override
  String get docEmailBlockedRecipient => 'No valid recipient.';

  @override
  String get docEmailBlockedArtifact =>
      'No generated PDF exists for this document.';

  @override
  String get docEmailTemplateUnresolved =>
      'A placeholder could not be resolved. Sending is blocked.';

  @override
  String get docEmailHeaderLineBreak =>
      'Subject and addresses must not contain line breaks.';

  @override
  String get docEmailNoSendControl =>
      'Sending is not yet available for this document type.';

  @override
  String get docEmailDuplicateInProgress =>
      'A send attempt is already running.';

  @override
  String get docEmailHistory => 'Send attempts';

  @override
  String get csvImportTitle => 'CSV import';

  @override
  String get csvImportStepSource => '1. Source';

  @override
  String get csvImportStepMapping => '2. Mapping';

  @override
  String get csvImportStepReview => '3. Review';

  @override
  String get csvImportStepResult => '4. Result';

  @override
  String get csvImportSourceHint =>
      'Paste CSV text or enter a local file path. Preview writes nothing.';

  @override
  String get csvImportCsvLabel => 'CSV text';

  @override
  String get csvImportPathLabel => 'Local file path (optional)';

  @override
  String get csvImportDelimiter => 'Delimiter';

  @override
  String get csvImportHeaderOption => 'First row is header';

  @override
  String get csvImportDecimalConvention => 'Numeric format';

  @override
  String get csvImportDecimalPoint => 'Decimal point (123.50)';

  @override
  String get csvImportDecimalComma => 'Decimal comma (123,50)';

  @override
  String get csvImportDuplicatePolicy => 'Duplicate policy';

  @override
  String get csvImportPolicySkip => 'Skip';

  @override
  String get csvImportPolicyUpdate => 'Update';

  @override
  String get csvImportPolicyCreateNew => 'Create new';

  @override
  String get csvImportMatchField => 'Match field';

  @override
  String get csvImportPriceBasis => 'Price basis';

  @override
  String get csvImportPriceNet => 'Net';

  @override
  String get csvImportPriceGross => 'Gross';

  @override
  String get csvImportParseAndMap => 'Parse and map';

  @override
  String get csvImportValidatePreview => 'Validate preview';

  @override
  String get csvImportConfirm => 'Confirm import';

  @override
  String get csvImportTemplate => 'Mapping template';

  @override
  String get csvImportTemplateNone => 'No template';

  @override
  String get csvImportSaveMapping => 'Save mapping';

  @override
  String get csvImportTemplateName => 'Template name';

  @override
  String get csvImportStatusValid => 'Valid';

  @override
  String get csvImportStatusInvalid => 'Invalid';

  @override
  String get csvImportStatusSkip => 'Skipped';

  @override
  String get csvImportStatusUpdate => 'Update';

  @override
  String get csvImportStatusCreate => 'Create';

  @override
  String get csvImportStatusAmbiguous => 'Ambiguous';

  @override
  String get csvImportStatusDuplicate => 'Duplicate';

  @override
  String get csvImportSelectUpdate => 'Select update';

  @override
  String get csvImportCounts => 'Counts';

  @override
  String get csvImportFileTooLarge =>
      'File exceeds 20 MiB; no record was written.';

  @override
  String get csvImportRowLimit =>
      'File exceeds 50,000 rows; no record was written.';

  @override
  String get csvImportMalformed => 'Malformed quoting; no record was written.';

  @override
  String get csvImportUnsupportedEncoding =>
      'Unsupported encoding; only UTF-8 is supported.';

  @override
  String get csvImportColumnMismatch =>
      'Inconsistent column count; no record was written.';

  @override
  String get csvImportEmptyFile => 'File is empty; no record was written.';

  @override
  String get csvImportMappingConflict =>
      'Column mapping is ambiguous; preview was not opened.';

  @override
  String get csvImportEntityMismatch => 'Template does not match this entity.';

  @override
  String get csvImportMatchFieldRequired =>
      'Skip/Update requires a match field.';

  @override
  String get csvImportPriceBasisRequired =>
      'Articles require a price basis (net/gross).';

  @override
  String csvImportUnsupportedFieldForUpdate(String field) {
    return '$field is not supported for article update.';
  }

  @override
  String get csvImportBatchFailure => 'Import failed; no row was committed.';

  @override
  String get csvImportUnavailable =>
      'Import data is currently unavailable. Mapping is preserved.';

  @override
  String get customerDisclosureExportAction => 'Export customer data';

  @override
  String get customerDisclosureExportScopeTitle => 'Disclosure export: scope';

  @override
  String get customerDisclosureExportScopeDescription =>
      'This export contains only this customer and records with verified links (invoices, items, reminders, receivables, payments, templates, receipts). Free-text matches are neither searched nor exported. Unsupported or excluded content is listed in the manifest; the archive may be incomplete. This is not a profile archive and not a backup. Customer data is neither deleted nor anonymized.';

  @override
  String get customerDisclosureExportConfirm => 'Export';

  @override
  String get customerDisclosureExportProgress => 'Export in progress…';

  @override
  String get customerDisclosureExportComplete =>
      'Export completed and verified.';

  @override
  String get customerDisclosureExportIncomplete =>
      'Export saved as incomplete. Please review the notes.';

  @override
  String get customerDisclosureExportFailed =>
      'Export failed. Check the destination and try again.';

  @override
  String get customerDisclosureExportCancelled =>
      'Export cancelled. No archive was created.';

  @override
  String get customerDisclosureExportUnavailable =>
      'Disclosure export is unavailable.';

  @override
  String get customerDisclosureExportNotFound =>
      'Customer not found. No archive was created.';

  @override
  String get customerDisclosureExportDestinationExists =>
      'Destination file already exists. Choose another name.';

  @override
  String get routeAssets => 'Fixed assets';

  @override
  String get assetRegisterTitle => 'Fixed asset register';

  @override
  String get assetRegisterSubtitle =>
      'Manage assets and review linear depreciation';

  @override
  String get assetAdd => 'Add asset';

  @override
  String get assetEdit => 'Edit asset';

  @override
  String get assetDescription => 'Description';

  @override
  String get assetType => 'Asset type';

  @override
  String get assetAcquisitionDate => 'Acquisition date';

  @override
  String get assetNetPrice => 'Net purchase price';

  @override
  String get assetUsefulLife => 'Useful life (years)';

  @override
  String get assetMethod => 'Depreciation method';

  @override
  String get assetPrivateShare => 'Private-use share (%)';

  @override
  String get assetCategory => 'Category';

  @override
  String get assetDisposalDate => 'Disposed on';

  @override
  String assetInvalidField(String field) {
    return 'Invalid input: $field';
  }

  @override
  String get assetEmpty => 'No assets yet. Add the first asset.';

  @override
  String get assetDeleteRefused =>
      'Asset cannot be deleted: schedule history exists. Please archive it.';

  @override
  String get assetArchived => 'Asset archived';

  @override
  String get assetScheduleTitle => 'Annual depreciation';

  @override
  String get assetScheduleUnavailable => 'Unavailable';

  @override
  String get assetFinancialBlocked =>
      'Financial effect unavailable: no posting contract.';

  @override
  String get assetLoadFailed => 'Assets could not be loaded.';

  @override
  String get assetUnresolved => 'Unresolved: review required';

  @override
  String get receiptInboxTitle => 'Receipt inbox';

  @override
  String get receiptInboxSubtitle =>
      'Import, review and link — without leaving the record.';

  @override
  String get receiptReviewAction => 'Review';

  @override
  String get receiptLinkAction => 'Link';

  @override
  String get receiptPreviewAction => 'View source';

  @override
  String get receiptSourceUnavailable => 'Source unavailable';

  @override
  String get paketWorkspaceTitle => 'Document packages';

  @override
  String get paketWorkspaceSubtitle =>
      'Group documents and receipts and export a snapshot.';

  @override
  String get paketCreateAction => 'Create package';

  @override
  String get paketExportAction => 'Export package';

  @override
  String get gobdExportTitle => 'GoBD export';

  @override
  String get gobdExportSubtitle => 'Select a period, export and verify.';

  @override
  String get gobdVerifyAction => 'Verify';

  @override
  String get gobdIncomplete => 'Incomplete: check missing evidence';

  @override
  String get belegDropHint =>
      'Drop PDF, PNG, JPEG or e-invoice XML here (max 50 MiB)';

  @override
  String get belegUnsupportedType => 'File type not supported';

  @override
  String get invoiceWorkspaceTitle => 'Invoice workspace';

  @override
  String get invoiceWorkspaceEditorTab => 'Edit';

  @override
  String get invoiceWorkspacePreviewTab => 'Preview';

  @override
  String get invoiceWorkspaceAddPosition => 'Add line item';

  @override
  String get invoiceWorkspaceRemovePosition => 'Remove line item';

  @override
  String get invoiceWorkspaceMoveUp => 'Move up';

  @override
  String get invoiceWorkspaceMoveDown => 'Move down';

  @override
  String get invoiceWorkspacePreviewStale => 'Preview unavailable or outdated';

  @override
  String get invoiceWorkspaceInvalid => 'Check the highlighted inputs';

  @override
  String get invoiceWorkspaceEditDraft => 'Edit draft';

  @override
  String get invoiceWorkspaceSaved => 'Draft saved';

  @override
  String get invoiceActionFinalize => 'Finalize';

  @override
  String get invoiceFinalizeConfirmTitle => 'Finalize invoice?';

  @override
  String get invoiceFinalizeConfirmMessage =>
      'Review the summary and confirm finalization.';

  @override
  String get invoiceFinalizeConfirm => 'Finalize';

  @override
  String get invoiceActionStorno => 'Cancel';

  @override
  String get invoiceStornoReasonLabel => 'Reason';

  @override
  String get invoiceStornoReasonRequired => 'A reason is required';

  @override
  String get invoiceActionCreditNote => 'Create credit note';

  @override
  String get invoiceCreditNoteConfirmMessage =>
      'A linked credit note will be created from this invoice.';

  @override
  String get invoiceActionReplacement => 'Create replacement invoice';

  @override
  String get invoiceReplacementConfirmMessage =>
      'A linked replacement draft will be created from this cancelled invoice.';

  @override
  String get invoiceActionConvert => 'Convert';

  @override
  String get invoiceConvertConfirmTitle => 'Confirm conversion';

  @override
  String get invoiceLifecycleTitle => 'Document actions';

  @override
  String get invoiceLifecycleUnavailable => 'No further actions available';

  @override
  String get invoiceLifecycleDone => 'Action completed';

  @override
  String get invoiceActionFailed =>
      'The action could not be completed. Check the document and try again.';

  @override
  String get invoiceRelationshipsTitle => 'Relationships';

  @override
  String get invoiceRelationshipsEmpty => 'No linked documents';

  @override
  String get invoiceRelationshipMissing => 'Linked document unavailable';

  @override
  String get eInvoiceOutputTitle => 'Output format';

  @override
  String get eInvoiceFormatPdf => 'PDF';

  @override
  String get eInvoiceFormatPdfDescription =>
      'Visual PDF without structured data';

  @override
  String get eInvoiceFormatZugferd => 'ZUGFeRD';

  @override
  String get eInvoiceFormatZugferdDescription =>
      'PDF with embedded ZUGFeRD XML (2.5.2 EN 16931)';

  @override
  String get eInvoiceFormatXrechnung => 'XRechnung';

  @override
  String get eInvoiceFormatXrechnungDescription =>
      'XRechnung 3.0 XML export after finalization';

  @override
  String get customerZugferdDefaultTitle =>
      'Preselect ZUGFeRD for new invoices';

  @override
  String get customerZugferdDefaultDescription =>
      'This sets the starting format; you can choose another format for each invoice.';

  @override
  String get eInvoiceReadinessValid => 'E-invoice validated';

  @override
  String get eInvoiceReadinessInvalid => 'E-invoice invalid – check details';

  @override
  String get eInvoiceReadinessNotValidated => 'Not yet validated';

  @override
  String get eInvoiceReadinessUnavailable => 'Validation unavailable';

  @override
  String get eInvoiceExportXrechnung => 'Export XRechnung';

  @override
  String get eInvoiceExportSaved => 'XRechnung saved';

  @override
  String get eInvoiceExportCancelled => 'Export cancelled';

  @override
  String get eInvoiceValidationTitle => 'Validation result';

  @override
  String get eInvoiceDraftNoExport => 'Export available after finalization';

  @override
  String get eInvoiceBuyerReferenceLabel => 'Buyer reference (e.g. Leitweg ID)';

  @override
  String get eInvoiceBuyerReferenceHint => 'Required for XRechnung';

  @override
  String get routeRecurring => 'Recurring';

  @override
  String get sidebarRecurring => 'Recurring';

  @override
  String get recurringTitle => 'Recurring bookings';

  @override
  String get recurringSubtitle => 'Review templates and due bookings';

  @override
  String get recurringNewTemplate => 'New template';

  @override
  String get recurringEmpty => 'No templates yet. Create your first template.';

  @override
  String get recurringLoadFailed => 'Recurring bookings could not be loaded';

  @override
  String get recurringDueTitle => 'Due bookings';

  @override
  String get recurringDueEmpty => 'No due bookings.';

  @override
  String recurringBlockedReason(String reason) {
    return 'Blocked: $reason';
  }

  @override
  String recurringHandoffError(String error) {
    return 'Handoff failed: $error';
  }

  @override
  String recurringInvalidField(String field) {
    return 'Invalid field: $field';
  }

  @override
  String get recurringConfirmExecute => 'Execute';

  @override
  String get recurringCreateDraft => 'Create draft';

  @override
  String get settingsSectionBackup => 'Backup';

  @override
  String get settingsBackupNow => 'Back up now';

  @override
  String get settingsBackupSchedule => 'Automatic backup';

  @override
  String get settingsBackupManual => 'Manual';

  @override
  String get settingsBackupDaily => 'Daily';

  @override
  String get settingsBackupWeekly => 'Weekly';

  @override
  String get settingsBackupNever => 'Never backed up';

  @override
  String get settingsBackupCurrent => 'Current';

  @override
  String get settingsBackupStale => 'Stale';

  @override
  String get settingsBackupFailed => 'Failed';

  @override
  String get settingsRestoreRestartRequired =>
      'Restore staged. Please exit and restart the app.';

  @override
  String get settingsProfileUnregister => 'Remove profile (files are retained)';

  @override
  String get settingsProfileRename => 'Rename';

  @override
  String get settingsProfileRestartRequired => 'Restart required';

  @override
  String get settingsProfileInUse => 'Profile is already in use';

  @override
  String get settingsRegion => 'Region';

  @override
  String get settingsHolder => 'Account holder';

  @override
  String get setupDeferredCategories =>
      'Categories are deferred (no verified catalog).';

  @override
  String get setupLegalForm => 'Legal form';

  @override
  String get smtpConnectivityOnly =>
      'Connectivity checked (no sign-in, no delivery).';

  @override
  String get settingsNoErasure => 'No permanent deletion available.';

  @override
  String get settingsExportScope => 'Exports come from their owning section.';

  @override
  String get routeDunning => 'Dunning';

  @override
  String get sidebarDunning => 'Dunning';

  @override
  String get dunningTitle => 'Dunning';

  @override
  String get dunningSubtitle => 'Review open receivables, prepare reminders';

  @override
  String get dunningPreviewAction => 'Preview run';

  @override
  String get dunningConfirmAction => 'Confirm & create';

  @override
  String get dunningHistoryTitle => 'Dunning history';

  @override
  String get dunningExclusionsTitle => 'Exclusions';

  @override
  String get dunningEmpty => 'No due receivables.';

  @override
  String get dunningLoadFailed => 'Dunning could not be loaded';

  @override
  String get dunningUnavailable => 'Dunning is unavailable';

  @override
  String get dunningExcludedState => 'Excluded';

  @override
  String get dunningDraftState => 'Draft';

  @override
  String get dunningTransportAccepted => 'Transport accepted';

  @override
  String get dunningOutstandingLabel => 'Open';

  @override
  String get dunningFeeLabel => 'Fee';

  @override
  String get dunningRateLabel => 'Rate';

  @override
  String get dunningInterestLabel => 'Interest';

  @override
  String get dunningStageLabel => 'Stage';

  @override
  String get dunningExclusionReasonHint => 'Reason';

  @override
  String get dunningAddExclusion => 'Add exclusion';

  @override
  String get dunningRemoveExclusion => 'Remove exclusion';

  @override
  String get dunningGraceDeprecated => 'Grace (deprecated, no effect)';

  @override
  String get dunningSendAction => 'Send reminder';

  @override
  String get dunningCollectionAction => 'Collection package';

  @override
  String get dunningNoBalance => 'Balance unavailable';

  @override
  String dunningDetailTitle(String number) {
    return 'Receivable $number';
  }

  @override
  String get incomingInvoiceCaptureTitle => 'Capture supplier invoice';

  @override
  String get incomingInvoiceCaptureAction => 'Create incoming invoice';

  @override
  String get incomingInvoiceSupplierLabel => 'Supplier';

  @override
  String get incomingInvoiceSourceNumberLabel => 'Supplier invoice number';

  @override
  String get incomingInvoiceDueDateLabel => 'Due date';

  @override
  String get incomingInvoiceVatRateLabel => 'VAT %';

  @override
  String get incomingInvoiceSupplierRequired =>
      'Select a supplier before saving.';

  @override
  String get incomingInvoiceSaveFailed =>
      'The incoming invoice draft could not be saved.';

  @override
  String get incomingInvoiceCaptureSaved => 'Incoming invoice draft saved.';

  @override
  String get incomingInvoiceUnsupportedProfile =>
      'This structured invoice profile is not supported. Enter the values manually.';

  @override
  String get incomingInvoiceUnreadable =>
      'Structured invoice data could not be read. Enter the values manually.';

  @override
  String incomingInvoiceUnsupportedValue(String value) {
    return 'Unsupported source value: $value';
  }

  @override
  String incomingInvoiceSuggestedValue(String value) {
    return 'Source value: $value';
  }

  @override
  String get incomingInvoiceSourcePreviewUnavailable =>
      'The original source preview is unavailable.';

  @override
  String get incomingInvoiceTotalsDisplayOnly =>
      'Source totals are shown for comparison only.';

  @override
  String get incomingInvoiceConfirmUnsupportedValues =>
      'I reviewed the unsupported source values and entered the invoice manually.';

  @override
  String get dashboardPeriodYear => 'Reporting year';

  @override
  String dashboardPeriodRange(int year, String start, String end) {
    return '$year · $start – $end';
  }

  @override
  String get dashboardReportingPending =>
      'No period metrics – reporting pending.';

  @override
  String get dashboardReportingPrerequisite =>
      'Period metrics unavailable – reporting workspace pending.';

  @override
  String get dashboardUnsupportedPeriod =>
      'Month/quarter is unavailable – annual view only.';

  @override
  String get dashboardInvalidPeriod => 'Invalid period.';

  @override
  String get dashboardNotComparable => 'Not comparable';

  @override
  String get dashboardProfit => 'Profit';

  @override
  String get dashboardMargin => 'Margin';

  @override
  String get dashboardMarginUnavailable => 'Margin n/a';

  @override
  String get dashboardVatReserveEstimate => 'VAT reserve (estimate)';

  @override
  String get dashboardQuickLinkAdd => 'Add link';

  @override
  String get dashboardQuickLinkEdit => 'Edit link';

  @override
  String get dashboardQuickLinkInvalid => 'Route is not supported.';

  @override
  String get dashboardQuickLinkInvalidState => 'Invalid link – remove';

  @override
  String get dashboardAttentionTitle => 'Attention';

  @override
  String get dashboardAttentionOverdue => 'Overdue invoice';

  @override
  String get dashboardAttentionUnmatched => 'Unmatched transaction';

  @override
  String get dashboardAttentionTaxDeadline => 'Tax deadline';

  @override
  String get dashboardTaxCalendarMissing => 'No tax calendar configured.';

  @override
  String get dashboardTrendTitle => 'Trend';

  @override
  String get dashboardTrendEmpty => 'No trend data for this period.';

  @override
  String get dashboardTrendError => 'Trend data could not be loaded.';

  @override
  String get dashboardOpenBalance => 'Open balance at year end';

  @override
  String get dashboardIncompleteHistory =>
      'Incomplete history – effective date missing.';

  @override
  String get dashboardUnavailable => 'Unavailable';

  @override
  String get dashboardQuickLinkInvalidLabel => 'invalid';

  @override
  String get dashboardQuickLinkLabel => 'Label';

  @override
  String get dashboardQuickLinkRoute => 'Route';
}
