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
  String get sidebarHelp => 'Hilfe';

  @override
  String get sidebarMenu => 'Menü';

  @override
  String get sidebarSectionOverview => 'ÜBERSICHT';

  @override
  String get sidebarSectionBusiness => 'GESCHÄFT';

  @override
  String get sidebarSectionTaxes => 'STEUERN';

  @override
  String get workspaceLocalProfile => 'Lokales Profil';

  @override
  String get workspaceManage => 'Profil verwalten';

  @override
  String get localTitle => 'Lokal';

  @override
  String get localDescription => 'Alle Daten werden lokal gespeichert — kein Cloud-Zugriff.';

  @override
  String get close => 'Schließen';

  @override
  String get backendUnreachable => 'Backend nicht erreichbar';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get profileLoadError => 'Profile konnten nicht geladen werden';

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

  @override
  String get language => 'Sprache';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsPrivacy => 'Datenschutz';

  @override
  String get settingsPrivacyDescription => 'Deine Buchhaltungsdaten bleiben auf diesem Gerät.';

  @override
  String get settingsProfiles => 'Profile';

  @override
  String get settingsAppearance => 'Darstellung';

  @override
  String get settingsProfileLoadError => 'Profile konnten nicht geladen werden';

  @override
  String get settingsProfileRetry => 'Erneut versuchen';

  @override
  String get routeOverview => 'Übersicht';

  @override
  String get routeInvoices => 'Rechnungen';

  @override
  String get routeReceipts => 'Belege';

  @override
  String get routeBanking => 'Banking';

  @override
  String get routeContacts => 'Kontakte';

  @override
  String get routeTaxes => 'Steuern';

  @override
  String get routeReports => 'Auswertungen';

  @override
  String get reportCatalogEuer => 'EÜR';

  @override
  String get reportCatalogEks => 'Anlage EKS';

  @override
  String get reportCatalogGuv => 'GuV';

  @override
  String get reportCatalogDatev => 'DATEV-Export';

  @override
  String get reportCatalogHistory => 'Exportverlauf';

  @override
  String get reportCatalogUstva => 'Umsatzsteuer-Voranmeldung';

  @override
  String get reportCatalogZm => 'Zusammenfassende Meldung';

  @override
  String get reportStatusAvailable => 'Verfügbar';

  @override
  String get reportStatusUnavailable => 'Nicht verfügbar';

  @override
  String get reportSelectionInvalid => 'Ungültige Berichtsabfrage';

  @override
  String get routeSettings => 'Einstellungen';

  @override
  String get routeHelp => 'Hilfe';

  @override
  String get routeInventory => 'Lager';

  @override
  String get routeSetup => 'Einrichtung';

  @override
  String get actionBackOverview => 'Zur Übersicht';

  @override
  String get actionNewInvoice => 'Neue Rechnung';

  @override
  String get actionSearch => 'Suchen';

  @override
  String get actionReset => 'Zurücksetzen';

  @override
  String get actionRefresh => 'Aktualisieren';

  @override
  String get actionSave => 'Speichern';

  @override
  String get actionCancel => 'Abbrechen';

  @override
  String get actionRetry => 'Erneut versuchen';

  @override
  String get actionClose => 'Schließen';

  @override
  String get actionContinue => 'Weiter';

  @override
  String get actionBack => 'Zurück';

  @override
  String get actionSkip => 'Überspringen';

  @override
  String get searchHint => 'Suchen…';

  @override
  String get globalSearchButton => 'Globale Suche';

  @override
  String get globalSearchShortcutUnavailable => 'Globale Suche (Tastenkürzel nicht verfügbar)';

  @override
  String get globalSearchTitle => 'Suchen oder Befehl ausführen';

  @override
  String get globalSearchPlaceholder =>
      'Rechnungen, Kontakte, Belege, Transaktionen, Einstellungen oder Befehle suchen';

  @override
  String get globalSearchEmptyPrompt => 'Suchbegriff eingeben';

  @override
  String get globalSearchNoResults => 'Keine Treffer für diese Suche';

  @override
  String get globalSearchLoading => 'Suche läuft…';

  @override
  String get globalSearchPartialFailure => 'Einige lokale Datensätze konnten nicht durchsucht werden.';

  @override
  String globalSearchSourceUnavailable(String source) {
    return '$source konnten nicht durchsucht werden.';
  }

  @override
  String get globalSearchInvoiceType => 'Rechnung';

  @override
  String get globalSearchContactType => 'Kontakt';

  @override
  String get globalSearchReceiptType => 'Beleg';

  @override
  String get globalSearchBankTransactionType => 'Banktransaktion';

  @override
  String get globalSearchDestinationType => 'Ziel';

  @override
  String get globalSearchCommandType => 'Befehl';

  @override
  String get globalSearchSettingsDestination => 'Einstellungen';

  @override
  String get globalSearchNewInvoiceCommand => 'Neue Rechnung';

  @override
  String globalSearchInvoiceFallback(String id) {
    return 'Rechnung Nr. $id';
  }

  @override
  String globalSearchReceiptFallback(String id) {
    return 'Beleg Nr. $id';
  }

  @override
  String globalSearchTransactionFallback(String id) {
    return 'Transaktion Nr. $id';
  }

  @override
  String get bankSelectedTransactionTitle => 'Ausgewählte Banktransaktion';

  @override
  String get bankTransactionInvalidSelection => 'Der Transaktionslink ist ungültig.';

  @override
  String get bankTransactionNotFound => 'Diese Banktransaktion ist im aktiven Profil nicht verfügbar.';

  @override
  String get bankTransactionLoadFailed => 'Die Banktransaktion konnte nicht geladen werden.';

  @override
  String get bankTransactionCounterparty => 'Gegenkonto';

  @override
  String get bankTransactionPurpose => 'Verwendungszweck';

  @override
  String get bankTransactionAmount => 'Betrag';

  @override
  String get bankTransactionStatus => 'Status';

  @override
  String get filterDateFrom => 'Datum ab';

  @override
  String get filterDateTo => 'Datum bis';

  @override
  String get filterStatusExact => 'Exakter Status';

  @override
  String get filterAmountFrom => 'Betrag ab';

  @override
  String get filterAmountTo => 'Betrag bis';

  @override
  String get filterApply => 'Filter anwenden';

  @override
  String get filterClearAll => 'Alle Filter löschen';

  @override
  String get filterInvalidDateRange => 'Das Startdatum muss vor oder am Enddatum liegen.';

  @override
  String get filterInvalidAmount => 'Gib einen gültigen Betrag mit höchstens zwei Nachkommastellen ein.';

  @override
  String get filterInvalidAmountRange => 'Der Mindestbetrag muss kleiner oder gleich dem Höchstbetrag sein.';

  @override
  String get filterPreviousPage => 'Vorherige Seite';

  @override
  String get filterNextPage => 'Nächste Seite';

  @override
  String filterPageCount(int page, int pages) {
    return 'Seite $page von $pages';
  }

  @override
  String get loading => 'Wird geladen…';

  @override
  String get loadError => 'Daten konnten nicht geladen werden';

  @override
  String get emptyResults => 'Keine Treffer';

  @override
  String get emptyEntries => 'Noch keine Einträge';

  @override
  String get countResults => 'Ergebnisse';

  @override
  String get countInvoices => 'Rechnungen';

  @override
  String get countReceipts => 'Belege';

  @override
  String get countContacts => 'Kontakte';

  @override
  String get countTransactions => 'Transaktionen';

  @override
  String get countRecords => 'Einträge';

  @override
  String get statusOpen => 'Offen';

  @override
  String get statusPaid => 'Bezahlt';

  @override
  String get statusDraft => 'Entwurf';

  @override
  String get statusOverdue => 'Überfällig';

  @override
  String get statusUnknown => 'Unbekannt';

  @override
  String get documentInvoice => 'Rechnung';

  @override
  String get documentCreditNote => 'Gutschrift';

  @override
  String get documentReceipt => 'Beleg';

  @override
  String get documentOther => 'Dokument';

  @override
  String get dateLabel => 'Datum';

  @override
  String get invoiceWorkspaceDeliveryDate => 'Leistungsdatum (optional)';

  @override
  String get invoiceWorkspaceClearDeliveryDate => 'Leistungsdatum löschen';

  @override
  String get amountHidden => 'Betrag verborgen';

  @override
  String get dashboardTitle => 'Übersicht';

  @override
  String get dashboardWelcome => 'Willkommen in deiner lokalen Buchhaltung.';

  @override
  String get dashboardInventory => 'Lager';

  @override
  String get dashboardInventoryUnavailable => 'Die Lagerverwaltung ist derzeit nicht verfügbar.';

  @override
  String get invoicesSubtitle => 'Rechnungen';

  @override
  String get receiptsSubtitle => 'Belege';

  @override
  String get bankingSubtitle => 'Banktransaktionen';

  @override
  String get contactsSubtitle => 'Kontakte';

  @override
  String get taxesSubtitle => 'Steuern';

  @override
  String get reportsSubtitle => 'Auswertungen';

  @override
  String get helpSubtitle => 'Hilfe und Support';

  @override
  String get notFoundDescription => 'Die angeforderte Seite wurde nicht gefunden.';

  @override
  String get databaseUnavailable => 'Die lokale Datenbank ist nicht verfügbar.';

  @override
  String get dataLoadError => 'Diese Daten konnten nicht geladen werden.';

  @override
  String get setupSubtitle => 'Richte dein lokales Buchhaltungsprofil ein.';

  @override
  String get setupStep => 'Schritt';

  @override
  String get setupCompanyName => 'Firmenname';

  @override
  String get setupCompanyNameHint => 'Gib den rechtlichen Namen deines Unternehmens ein.';

  @override
  String get setupIban => 'IBAN';

  @override
  String get setupIbanHint => 'Optionales Bankkonto für den Eröffnungssaldo.';

  @override
  String get setupCashBalance => 'Kassenbestand';

  @override
  String get setupCashBalanceHint => 'Gib den aktuellen Kassenbestand ein.';

  @override
  String get setupCategories => 'Kategorien';

  @override
  String get setupCategoriesHint => 'Wähle die Kategorien, die du am häufigsten nutzt.';

  @override
  String get setupRequired => 'Bitte fülle die Pflichtfelder aus.';

  @override
  String get setupInvalidIban => 'Gib eine gültige IBAN ein oder lasse das Feld leer.';

  @override
  String get setupDatabaseError => 'Das Profil konnte nicht gespeichert werden.';

  @override
  String get setupRetry => 'Einrichtung wiederholen';

  @override
  String get setupComplete => 'Einrichtung abgeschlossen';

  @override
  String get setupSaving => 'Profil wird gespeichert…';

  @override
  String get setupSaved => 'Profil gespeichert.';

  @override
  String get setupSkipConfirm => 'Einrichtung jetzt überspringen?';

  @override
  String get inventoryTitle => 'Lager';

  @override
  String get inventoryUnavailable => 'Die Lagerverwaltung ist noch nicht verfügbar.';

  @override
  String get inventoryUnavailableDescription => 'Die Lagerverwaltung ist für dieses Profil nicht verfügbar.';

  @override
  String get inventoryReadOnly => 'Nur lesen';

  @override
  String get inventoryRetry => 'Erneut versuchen';

  @override
  String get inventoryBack => 'Zur Übersicht';

  @override
  String get stocktakeNewAction => 'Neue Inventur';

  @override
  String get stocktakeStichtagLabel => 'Stichtag';

  @override
  String get stocktakeRecordAction => 'Erfassen';

  @override
  String get stocktakeDraftStatus => 'Entwurf';

  @override
  String get stocktakeRecordedStatus => 'Erfasst';

  @override
  String get stocktakeCountLabel => 'Gezählte Menge';

  @override
  String get stocktakePhysicalCount => 'Gezählte Istmenge';

  @override
  String get stocktakeMissingCount => 'Für jeden Artikel eine gezählte Menge eingeben.';

  @override
  String get stocktakeInvalidCount => 'Bitte eine gültige gezählte Menge eingeben.';

  @override
  String get stocktakeInvalidDate => 'Stichtag im Format JJJJ-MM-TT eingeben';

  @override
  String get stocktakeNegativeForbidden => 'Gezählte Mengen dürfen nicht negativ sein.';

  @override
  String get stocktakePrecisionInvalid => 'Gezählte Mengen dürfen höchstens drei Nachkommastellen haben.';

  @override
  String get stocktakeNoCountable => 'Keine zählbaren Artikel vorhanden.';

  @override
  String get stocktakeNoCountableDescription => 'Aktiviere die Lagerführung für mindestens einen Artikel.';

  @override
  String get stocktakeHistoryTitle => 'Erfasste Inventuren';

  @override
  String get stocktakeBookUnavailable => 'Buchbestand nicht verfügbar';

  @override
  String get stocktakeVarianceUnavailable => 'Differenz nicht verfügbar';

  @override
  String get stocktakeValuationUnavailable => 'Bewertung nicht verfügbar';

  @override
  String get stocktakeValuationDescription =>
      'Keine geprüfte Bewertungsrichtlinie hinterlegt. Gezählte Mengen bleiben verfügbar.';

  @override
  String get stocktakeCorrectionHint => 'Korrekturen über eine neue Inventur erfassen.';

  @override
  String get stocktakeDisabledNew => 'Neue Inventuren sind deaktiviert.';

  @override
  String get stocktakeEmpty => 'Noch keine Inventuren.';

  @override
  String get stocktakeCapturedAt => 'Erfasst am';

  @override
  String get stocktakeArticleColumn => 'Artikel';

  @override
  String get pdfInvoice => 'Rechnung';

  @override
  String get pdfCreditNote => 'Gutschrift';

  @override
  String get pdfStorno => 'Stornorechnung';

  @override
  String get pdfQuote => 'Angebot';

  @override
  String get pdfOrder => 'Auftrag';

  @override
  String get pdfProforma => 'Proforma-Rechnung';

  @override
  String get pdfDelivery => 'Lieferschein';

  @override
  String get pdfOriginalInvoice => 'Ursprüngliche Rechnung';

  @override
  String get pdfDate => 'Datum';

  @override
  String get pdfInvoiceDate => 'Rechnungsdatum';

  @override
  String get pdfDueSince => 'Fällig seit';

  @override
  String get pdfValidUntil => 'Gültig bis';

  @override
  String get pdfCustomerNumber => 'Kundennummer';

  @override
  String get pdfNet => 'Netto';

  @override
  String get pdfTax => 'USt';

  @override
  String get pdfTotal => 'Gesamt';

  @override
  String get pdfPayment => 'Zahlung';

  @override
  String get pdfReminder => 'Mahnung';

  @override
  String get pdfUnknown => '—';

  @override
  String get pdfPage => 'Seite';

  @override
  String get a11yNavigation => 'Navigation';

  @override
  String get a11yOpenMenu => 'Menü öffnen';

  @override
  String get a11yCloseMenu => 'Menü schließen';

  @override
  String get a11yAmountHidden => 'Betrag verborgen';

  @override
  String get pdfPhone => 'Telefon';

  @override
  String get pdfEmail => 'E-Mail';

  @override
  String get pdfTaxNumber => 'Steuernummer';

  @override
  String get pdfVatId => 'USt-IdNr.';

  @override
  String get pdfTo => 'Rechnung an';

  @override
  String get pdfInvoiceNumber => 'Rechnungsnummer';

  @override
  String get pdfOrderStatus => 'Auftragsstatus';

  @override
  String get pdfNoVat => 'Gemäß §19 UStG wird keine Umsatzsteuer berechnet';

  @override
  String get pdfPosition => 'Pos.';

  @override
  String get pdfDescription => 'Beschreibung';

  @override
  String get pdfQuantity => 'Menge';

  @override
  String get pdfUnitPrice => 'Einzelpreis';

  @override
  String get pdfDiscount => 'Rabatt';

  @override
  String get pdfGross => 'Brutto';

  @override
  String get pdfVatRate => 'USt-Satz';

  @override
  String get pdfSubtotal => 'Zwischensumme';

  @override
  String get pdfDiscountAmount => 'Rabatt';

  @override
  String get pdfGrossTotal => 'Gesamtbetrag';

  @override
  String get pdfPaymentDetails => 'Zahlungsdaten';

  @override
  String get pdfIban => 'IBAN';

  @override
  String get pdfBic => 'BIC';

  @override
  String get pdfBank => 'Bank';

  @override
  String get setupWizardTitle => 'Setup Wizard';

  @override
  String get setupStepCompany => 'Stammdaten';

  @override
  String get setupStepAccounts => 'Konten';

  @override
  String get setupStepCategories => 'Kategorien';

  @override
  String get setupStepCompletion => 'Abschluss';

  @override
  String get profileSelectionTitle => 'Profil wählen';

  @override
  String get profileLastUsed => 'Zuletzt verwendet';

  @override
  String get dashboardLoadError => 'Fehler beim Laden';

  @override
  String get dashboardInventoryWarning => 'Lagerwarnung';

  @override
  String get dashboardInventoryStock => 'Lagerbestand';

  @override
  String get actionChooseFile => 'Datei auswählen';

  @override
  String get actionPreview => 'Vorschau';

  @override
  String get actionHistory => 'Verlauf';

  @override
  String get actionImport => 'Importieren';

  @override
  String receiptDetailTitle(String id) {
    return 'Beleg $id';
  }

  @override
  String get actionFilter => 'Filter';

  @override
  String get actionRemoveFilter => 'Filter entfernen';

  @override
  String get actionResetFilters => 'Filter zurücksetzen';

  @override
  String get headerViews => 'Ansichten';

  @override
  String get countResultSingular => 'Ergebnis';

  @override
  String journalDetailTitle(String id) {
    return 'Buchung $id';
  }

  @override
  String filterTypeLabel(String value) {
    return 'Typ: $value';
  }

  @override
  String filterStatusLabel(String value) {
    return 'Status: $value';
  }

  @override
  String get draftDiscardTitle => 'Entwurf verwerfen?';

  @override
  String get draftDiscardMessage => 'Die eingegebenen Rechnungsdaten gehen verloren.';

  @override
  String get actionKeepEditing => 'Weiter bearbeiten';

  @override
  String get actionDiscard => 'Verwerfen';

  @override
  String draftSaveFailed(String error) {
    return 'Entwurf konnte nicht gespeichert werden: $error';
  }

  @override
  String get errorDateFormat => 'Datum im Format JJJJ-MM-TT eingeben';

  @override
  String errorPositiveAmount(String label) {
    return '$label muss größer als 0 sein';
  }

  @override
  String get customersLoading => 'Kunden werden geladen …';

  @override
  String get customersLoadFailed => 'Kunden konnten nicht geladen werden';

  @override
  String get actionReload => 'Erneut laden';

  @override
  String get invoiceDraftNoCustomerTitle => 'Noch kein Kunde angelegt';

  @override
  String get invoiceDraftNoCustomerMessage =>
      'Eine Rechnung braucht einen Kunden, damit sie korrekt zugeordnet werden kann.';

  @override
  String get actionCreateCustomer => 'Kunde anlegen';

  @override
  String get invoiceDraftCustomerLabel => 'Kunde';

  @override
  String get invoiceDraftCustomerHint => 'Kunde auswählen';

  @override
  String get errorCustomerRequired => 'Kunde ist erforderlich';

  @override
  String get invoiceDraftTitle => 'Rechnungsentwurf';

  @override
  String get invoiceDraftDescription => 'Speichere eine Rechnungsposition als Entwurf.';

  @override
  String get invoiceDraftPositionLabel => 'Position';

  @override
  String get errorPositionRequired => 'Position ist erforderlich';

  @override
  String get invoiceDraftUnitPriceLabel => 'Einzelpreis netto';

  @override
  String get actionSaveDraft => 'Entwurf speichern';

  @override
  String get errorInvoiceIdInvalid => 'Die Rechnungs-ID ist ungültig.';

  @override
  String contactDetailTitle(String id) {
    return 'Kontakt $id';
  }

  @override
  String get profileSavedRestartHint => 'Profil gespeichert. Bitte OpenAccounting neu starten.';

  @override
  String get profileAlreadyActive => 'Profil ist bereits aktiv.';

  @override
  String profileSelectFailed(String error) {
    return 'Profil konnte nicht gewählt werden: $error';
  }

  @override
  String get profileCreateTitle => 'Neues Profil';

  @override
  String get profileNameLabel => 'Profilname';

  @override
  String get actionCreate => 'Anlegen';

  @override
  String get profileCreated => 'Profil angelegt.';

  @override
  String profileCreateFailed(String error) {
    return 'Profil konnte nicht angelegt werden: $error';
  }

  @override
  String get errorRecordIdInvalid => 'Die Datensatz-ID ist ungültig.';

  @override
  String errorRecordNotFound(String id) {
    return 'Der Datensatz mit der ID $id wurde nicht gefunden.';
  }

  @override
  String recordIdLabel(String id) {
    return 'Datensatz-ID $id';
  }

  @override
  String recordFallbackTitle(String id) {
    return 'Datensatz #$id';
  }

  @override
  String routeErrorSource(String source) {
    return 'Vorgang: $source';
  }

  @override
  String get bankCategoriesLoadFailed =>
      'Kategorien konnten nicht geladen werden. Manuelle Kategorisierung ist derzeit nicht verfügbar.';

  @override
  String get bankHistoryLoadFailed => 'Importverlauf konnte nicht geladen werden.';

  @override
  String get bankUnsupportedFile =>
      'Dieses Dateiformat wird nicht unterstützt. Unterstützt werden CSV und CAMT.053 XML.';

  @override
  String bankFileReadFailed(String error) {
    return 'Die Datei konnte nicht gelesen werden: $error';
  }

  @override
  String get bankFileTooLarge =>
      'Die Datei ist größer als 20 MB. Exportiere einen kleineren Zeitraum und versuche es erneut.';

  @override
  String get bankPasteTitle => 'CSV-Daten einfügen';

  @override
  String get bankPasteContentLabel => 'CSV-Inhalt';

  @override
  String get bankPasteHint => 'Datum;Betrag;Verwendungszweck;Partner';

  @override
  String get actionApply => 'Übernehmen';

  @override
  String get bankPasteFileName => 'eingefügter-import.csv';

  @override
  String bankFileProcessFailed(String error) {
    return 'Die Datei konnte nicht verarbeitet werden: $error';
  }

  @override
  String get bankConfirmTitle => 'Import bestätigen';

  @override
  String bankConfirmMessage(int count, String account) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ausgewählte Zeilen',
      one: '$count ausgewählte Zeile',
    );
    return '$_temp0 werden in $account importiert. Duplikate werden standardmäßig übersprungen.';
  }

  @override
  String get bankBackToReview => 'Zurück zur Prüfung';

  @override
  String bankImportIncomplete(String error) {
    return 'Der Import wurde nicht vollständig abgeschlossen: $error';
  }

  @override
  String get bankRetryNotice =>
      'Nur die nicht gespeicherten Zeilen werden erneut geprüft. Bereits importierte Zeilen bleiben dedupliziert.';

  @override
  String bankImportAborted(String diagnostic) {
    return 'Import abgebrochen: $diagnostic Keine Transaktion wurde gespeichert.';
  }

  @override
  String get bankImportAbortedHint => 'Korrigiere die Datei oder wähle ein passendes Template und versuche es erneut.';

  @override
  String get bankStatusRejected => 'Abgelehnt';

  @override
  String get bankStepChooseFile => '1. Datei auswählen';

  @override
  String get bankUploadHint =>
      'Unterstützt werden CSV-Dateien und CAMT.053 XML-Exporte. Die Vorschau schreibt noch nichts in die Datenbank.';

  @override
  String get bankPathLabel => 'Dateipfad';

  @override
  String get bankPathHint => 'Datei wählen oder Pfad einfügen; Drag & Drop unterstützt';

  @override
  String get bankStepAccountTemplate => '2. Konto und Template';

  @override
  String get bankNoAccountYet =>
      'Noch kein Bankkonto vorhanden. Lege zuerst ein Konto in den Stammdaten an; ein Import ohne Konto ist gesperrt.';

  @override
  String get bankCamtHint =>
      'CAMT.053 wird anhand der XML-Struktur erkannt; ein CSV-Template ist dafür nicht erforderlich.';

  @override
  String get bankStepReview => '3. Vorschau prüfen und bearbeiten';

  @override
  String bankRowsDetected(int count) {
    return '$count Zeilen erkannt';
  }

  @override
  String bankRowsSelected(int count) {
    return '$count ausgewählt';
  }

  @override
  String bankRowsManual(int count) {
    return '$count manuell kategorisiert';
  }

  @override
  String get bankReviewNotice =>
      'Änderungen und manuelle Kategorien werden erst nach deiner ausdrücklichen Importbestätigung gespeichert.';

  @override
  String get bankDuplicateOverride => 'Bereits importierte Duplikate erneut übernehmen (nur bewusst aktivieren)';

  @override
  String bankConfirmActionCount(int count) {
    return 'Import bestätigen ($count)';
  }

  @override
  String get bankColPartnerPurpose => 'Partner / Zweck';

  @override
  String bankRowLabel(int line) {
    return 'Zeile $line';
  }

  @override
  String get bankColPartner => 'Partner';

  @override
  String get bankColPurpose => 'Verwendungszweck';

  @override
  String get bankStepResult => '4. Importergebnis';

  @override
  String get bankStatImported => 'Importiert';

  @override
  String get bankStatDuplicatesSkipped => 'Duplikate übersprungen';

  @override
  String get bankStatCategorized => 'Kategorisiert';

  @override
  String get bankStatManualReview => 'Manuelle Prüfung';

  @override
  String get bankStatFailed => 'Fehlgeschlagen';

  @override
  String get bankResultAllSaved =>
      'Alle bestätigten neuen Zeilen wurden gespeichert. Der Import ist im Verlauf dokumentiert.';

  @override
  String get bankRetryFailedRows => 'Fehlgeschlagene Zeilen erneut prüfen';

  @override
  String get bankFailureRowsGeneric =>
      'Die Datenbank meldete nicht gespeicherte Zeilen, konnte aber keinen einzelnen Zeilenfehler zurückgeben. Prüfe Konto, Datum und Betrag; ein erneuter Versuch bleibt dedupliziert.';

  @override
  String get bankNotSavedFix => 'Nicht gespeichert — bitte korrigieren und erneut prüfen:';

  @override
  String bankFailureRowPrefix(int line, String error) {
    return 'Zeile $line: $error';
  }

  @override
  String get bankWithoutPartner => 'ohne Partner';

  @override
  String get bankWithoutPurpose => 'ohne Verwendungszweck';

  @override
  String get bankHistoryTitle => 'Importverlauf';

  @override
  String get bankHistoryCardSubtitle => 'Quelle, Template, Mengen und Ergebnisstatus bleiben hier nachvollziehbar.';

  @override
  String get bankHistoryRefresh => 'Importverlauf aktualisieren';

  @override
  String get bankColTime => 'Zeitpunkt';

  @override
  String get bankColSource => 'Quelle';

  @override
  String get bankColTemplate => 'Template';

  @override
  String get bankColAccount => 'Konto';

  @override
  String get bankColImported => 'Importiert';

  @override
  String get bankColDuplicates => 'Duplikate';

  @override
  String get bankColError => 'Fehler';

  @override
  String get bankColStatus => 'Status';

  @override
  String get bankStageFile => 'Datei';

  @override
  String get bankStageReview => 'Prüfen';

  @override
  String get bankStageResult => 'Ergebnis';

  @override
  String get bankStageCurrent => 'aktuell';

  @override
  String get bankStageComplete => 'abgeschlossen';

  @override
  String get bankStageOpen => 'offen';

  @override
  String bankReady(String name, String size) {
    return 'Bereit: $name · $size';
  }

  @override
  String get bankDelimiterSemicolon => 'Semikolon';

  @override
  String get bankDelimiterComma => 'Komma';

  @override
  String get bankHeaderSubtitleHistory => 'Nachvollziehbarer Importverlauf';

  @override
  String get bankHeaderSubtitleImport => 'Dateiimport mit Prüfung vor dem Speichern';

  @override
  String get bankHeaderSubtitleTransactions => 'Gespeicherte Banktransaktionen suchen und filtern';

  @override
  String get bankViewTransactions => 'Transaktionen';

  @override
  String get bankNoAccountSelected => 'kein Konto';

  @override
  String bankAccountFallback(String id) {
    return 'Konto $id';
  }

  @override
  String bankCategoryFallback(String id) {
    return 'Kategorie $id';
  }

  @override
  String get bankUnknownFile => 'Unbekannte Datei';

  @override
  String get bankStatusPartial => 'Teilweise importiert';

  @override
  String get bankStatusFailed => 'Import fehlgeschlagen';

  @override
  String get bankStatusImported => 'Importiert';

  @override
  String get bankInvalidImportNoDiagnostic => 'Ungültiger Import: Es wurde keine Fehlerdiagnose angegeben.';

  @override
  String get bankRecoveryCheckFileTemplate => 'Prüfe Datei und Template und versuche es erneut.';

  @override
  String get bankInvalidImportNoAccount => 'Ungültiger Import: Kein gültiges Bankkonto ausgewählt.';

  @override
  String get bankRecoverySelectAccount => 'Wähle ein gültiges Bankkonto und versuche es erneut.';

  @override
  String get bankNoTransactionsToImport => 'Keine Transaktionen zum Importieren.';

  @override
  String get bankRecoverySelectSupportedFile => 'Wähle eine unterstützte Datei mit mindestens einer Transaktion.';

  @override
  String get bankHistoryNotFinalSaved => 'Importhistorie konnte nicht abschließend gespeichert werden.';

  @override
  String bankHistoryCreateFailed(String error) {
    return 'Importhistorie konnte nicht angelegt werden: $error';
  }

  @override
  String get bankRecoveryFixDatabase => 'Behebe das Datenbankproblem und versuche es erneut.';

  @override
  String get bankRecoveryCheckDuplicates => 'Prüfe die vorhandenen Duplikate und versuche es erneut.';

  @override
  String get bankUnknownError => 'Unbekannter Fehler';

  @override
  String get bankInvalidDate => 'Datum ungültig';

  @override
  String get bankInvalidAmount => 'Betrag ungültig';

  @override
  String get bankCsvUnclosedQuotes => 'Ungültige CSV: Anführungszeichen nicht geschlossen';

  @override
  String bankCsvRowSuffix(int row) {
    return ' in Zeile $row';
  }

  @override
  String get bankRecoveryFixCsvRow => 'Korrigiere die CSV-Zeile und versuche den Import erneut.';

  @override
  String get bankNoTransactionsFound => 'Keine Transaktionen gefunden';

  @override
  String get bankNoTemplateFound => 'Kein passendes Template gefunden. Bitte wähle ein Template.';

  @override
  String get bankNoTemplateFoundNoTransactions =>
      'Keine Transaktionen gefunden. Kein passendes Template gefunden. Bitte wähle ein Template.';

  @override
  String get bankEmptyFile => 'Datei ist leer';

  @override
  String get bankNoHeader => 'Datei enthält keine Kopfzeile';

  @override
  String get bankInvalidXmlNoTag => 'Ungültiges XML: kein XML-Tag gefunden (invalid)';

  @override
  String get bankInvalidXmlNoClosingTag => 'Ungültiges XML: kein schliessendes Tag (invalid)';

  @override
  String get bankInvalidXmlDocumentUnclosed => 'Ungültiges XML: Document nicht geschlossen (invalid)';

  @override
  String get bankInvalidXmlNtryUnclosed => 'Ungültiges XML: Ntry nicht geschlossen (invalid)';

  @override
  String get bankInvalidXmlMismatched => 'Ungültiges XML: verschachtelte Tags stimmen nicht überein (invalid)';

  @override
  String get bankInvalidXmlTagUnclosed => 'Ungültiges XML: Tag nicht geschlossen (invalid)';

  @override
  String get bankAmountMissingNtry => 'Betrag fehlt in Ntry';

  @override
  String get bankDateMissingNtry => 'Datum fehlt in Ntry';

  @override
  String get bankAmountMissing => 'Betrag fehlt';

  @override
  String bankDateInvalidRaw(String raw) {
    return 'Datum ungültig: $raw';
  }

  @override
  String bankAmountInvalidRaw(String raw) {
    return 'Betrag ungültig: $raw';
  }

  @override
  String bankAmountOutOfRange(String raw) {
    return 'Betrag außerhalb NUMERIC(12,2): $raw';
  }

  @override
  String get setupErrorNameRequired => 'Name ist Pflicht';

  @override
  String get setupErrorAccountRequired => 'Mindestens ein Konto erforderlich';

  @override
  String setupErrorIbanInvalid(String iban) {
    return 'IBAN ungültig: $iban';
  }

  @override
  String get setupErrorCashNegative => 'Kassenbestand darf nicht negativ sein';

  @override
  String get setupErrorCashInvalid => 'Kassenbestand ungültig';

  @override
  String get setupErrorCategoryRequired => 'Mindestens eine Kategorie erforderlich';

  @override
  String get setupErrorDatabaseStatus => 'Datenbank konnte für den Setup-Status nicht gelesen werden';

  @override
  String get dashboardCustomize => 'Dashboard anpassen';

  @override
  String get dashboardIncome => 'Einnahmen';

  @override
  String get dashboardExpenses => 'Ausgaben';

  @override
  String get dashboardEmptyNoWarnings => 'Keine Warnungen';

  @override
  String get dashboardEmptyNoStock => 'Kein Lagerbestand';

  @override
  String get dashboardEmptyNoReminders => 'Keine Mahnungen';

  @override
  String get dashboardEmptyNoDeadlines => 'Keine Fristen';

  @override
  String get dashboardEmptyNoActivities => 'Keine Aktivitäten';

  @override
  String get dashboardEmptyNoPayments => 'Keine Zahlungen';

  @override
  String quickLinkUnavailable(String label) {
    return '$label (nicht verfügbar)';
  }

  @override
  String dashboardUstvaDue(String date) {
    return 'UStVA fällig am $date';
  }

  @override
  String get quickLinkJournal => 'Journal';

  @override
  String get quickLinkItems => 'Artikel';

  @override
  String get dashboardWidgetOpenInvoices => 'Offene Rechnungen';

  @override
  String get dashboardWidgetIncomingPayments => 'Zahlungseingänge';

  @override
  String get dashboardWidgetReminderWarning => 'Mahnung-Warnung';

  @override
  String get dashboardWidgetDeadlines => 'Fristen';

  @override
  String get dashboardWidgetUstvaDeadline => 'UStVA-Frist';

  @override
  String get dashboardWidgetQuickLinks => 'Schnellzugriff';

  @override
  String get dashboardWidgetIncomeExpenses => 'Einnahmen/Ausgaben';

  @override
  String get dashboardWidgetOverdueInvoices => 'Überfällige Rechnungen';

  @override
  String get dashboardWidgetOpenLiabilities => 'Offene Verbindlichkeiten';

  @override
  String get dashboardWidgetBalance => 'Kontostand';

  @override
  String get dashboardWidgetActivityLog => 'Aktivitäts-Log';

  @override
  String get bankColImport => 'Import';

  @override
  String get bankColAmount => 'Betrag';

  @override
  String get bankColCategory => 'Kategorie';

  @override
  String get bankPathHintExample => '/Pfad/zum/Kontoauszug.csv';

  @override
  String invoiceDraftNumber(int number) {
    return 'Entwurf #$number';
  }

  @override
  String get bankDuplicateOverrideLimit => 'Duplicate override limit reached (100) — manual cleanup required';

  @override
  String get bankConfidenceHigh => 'Hohe Übereinstimmung';

  @override
  String get bankConfidenceMedium => 'Mittlere Übereinstimmung';

  @override
  String get bankConfidenceLow => 'Geringe Übereinstimmung';

  @override
  String get bankConfidenceNone => 'Keine Übereinstimmung';

  @override
  String get bankCandidatesUnavailable =>
      'Treffer konnten nicht geladen werden. Automatische Verknüpfung ist deaktiviert.';

  @override
  String get bankRulesTitle => 'Regeln';

  @override
  String get bankRulePattern => 'Muster (Verwendungszweck)';

  @override
  String get bankRuleCategory => 'Kategorie';

  @override
  String get bankRulePriority => 'Priorität';

  @override
  String get bankRuleActive => 'Aktiv';

  @override
  String get bankRuleNew => 'Neue Regel';

  @override
  String get bankRuleEdit => 'Regel bearbeiten';

  @override
  String get bankRuleDelete => 'Regel löschen';

  @override
  String get bankRuleSave => 'Speichern';

  @override
  String get bankRuleCancel => 'Abbrechen';

  @override
  String get bankRuleEmpty => 'Keine Regeln vorhanden. Lege eine Regel an, um Importe automatisch zu kategorisieren.';

  @override
  String get bankRuleDisabled => 'Deaktiviert';

  @override
  String get bankTemplatesTitle => 'Vorlagen';

  @override
  String get bankTemplateNew => 'Eigene Vorlage';

  @override
  String get bankTemplateEdit => 'Vorlage bearbeiten';

  @override
  String get bankTemplateName => 'Name';

  @override
  String get bankTemplateProtected => 'Vordefiniert – geschützt';

  @override
  String get bankTemplateDelete => 'Vorlage löschen';

  @override
  String get bankModeLabel => 'Importmodus';

  @override
  String get bankModeManual => 'Manuell';

  @override
  String get bankModeAutomatic => 'Automatisch';

  @override
  String get bankModeOverride => 'Einmalig für diesen Import überschreiben';

  @override
  String get bankScoreLabel => 'Treffer';

  @override
  String get bankViewImport => 'Import';

  @override
  String get bankViewHistory => 'Verlauf';

  @override
  String get bankViewRules => 'Regeln';

  @override
  String get bankViewTemplates => 'Vorlagen';

  @override
  String get bankHistoryDetail => 'Details';

  @override
  String get bankHistoryRetry => 'Wiederholen';

  @override
  String get bankHistoryReview => 'Prüfen';

  @override
  String get bankHistorySearch => 'Suchen';

  @override
  String get bankHistorySearchHint => 'Dateiname, Vorlage oder Status suchen';

  @override
  String get bankHistoryEmpty => 'Noch keine Importe vorhanden.';

  @override
  String get bankHistoryImportAction => 'Datei wählen';

  @override
  String get bankHistoryNextPage => 'Weiter';

  @override
  String get bankHistoryPrevPage => 'Zurück';

  @override
  String get bankDetailImported => 'Importiert';

  @override
  String get bankDetailDuplicates => 'Duplikate';

  @override
  String get bankDetailFailed => 'Fehler';

  @override
  String get bankDetailUnresolved => 'Offen';

  @override
  String get bankDetailFileRejection => 'Dateiabweisung';

  @override
  String get bankDetailErrorRows => 'fehlerhafte Zeilen';

  @override
  String get bankDetailSeeHistory => 'Details in der Historie';

  @override
  String get bankDiagnosticFile => 'Datei';

  @override
  String get bankDiagnosticRow => 'Zeile';

  @override
  String get bankDetailsUnavailable => 'Details nicht verfügbar';

  @override
  String get incomeTaxTitle => 'Einkommensteuer-Anlagen';

  @override
  String get incomeTaxScheduleS => 'Anlage S';

  @override
  String get incomeTaxScheduleG => 'Anlage G';

  @override
  String get incomeTaxSelectPrompt => 'Anlage für die Verfügbarkeitsprüfung wählen';

  @override
  String get incomeTaxUnavailable => 'Noch nicht verfügbar';

  @override
  String get incomeTaxBlockerForm => 'Kein akzeptierter Formular- und Quellvertrag';

  @override
  String get incomeTaxBlockerPeriod => 'Kein akzeptierter Zeitraumvertrag';

  @override
  String get incomeTaxBlockerClassification => 'Keine akzeptierte Klassifizierung';

  @override
  String get incomeTaxBlockerSource => 'Keine vollständige Buchhaltungsquelle';

  @override
  String get fiscalYearTitle => 'Geschäftsjahr';

  @override
  String get fiscalYearStartMonth => 'Startmonat des Geschäftsjahres';

  @override
  String get fiscalYearHint =>
      'Legt die Grenzen historischer und künftiger Geschäftsjahresberichte fest. Buchungen und Exporte bleiben unverändert.';

  @override
  String get fiscalYearSave => 'Speichern';

  @override
  String get fiscalYearSaved => 'Geschäftsjahr gespeichert';

  @override
  String get fiscalYearError => 'Speichern fehlgeschlagen. Erneut versuchen.';

  @override
  String get fiscalYearInvalid => 'Monat muss zwischen 1 und 12 liegen';

  @override
  String get quickBookingsTitle => 'Schnellbuchungen';

  @override
  String get quickBookingNew => 'Neue Schnellbuchung';

  @override
  String get quickBookingEdit => 'Schnellbuchung bearbeiten';

  @override
  String get quickBookingDelete => 'Schnellbuchung löschen';

  @override
  String get quickBookingSave => 'Speichern';

  @override
  String get quickBookingCancel => 'Abbrechen';

  @override
  String get quickBookingName => 'Name';

  @override
  String get quickBookingDirection => 'Richtung';

  @override
  String get quickBookingDirectionIn => 'Einnahme';

  @override
  String get quickBookingDirectionOut => 'Ausgabe';

  @override
  String get quickBookingAccount => 'Konto';

  @override
  String get quickBookingCategory => 'Kategorie';

  @override
  String get quickBookingTaxRate => 'Steuersatz';

  @override
  String get quickBookingModus => 'Eingabemodus';

  @override
  String get quickBookingModusNetto => 'Netto';

  @override
  String get quickBookingModusBrutto => 'Brutto';

  @override
  String get quickBookingAmount => 'Betrag';

  @override
  String get quickBookingDescription => 'Beschreibung';

  @override
  String get quickBookingExecute => 'Ausführen';

  @override
  String get quickBookingReviewRequired => 'Prüfung erforderlich';

  @override
  String get quickBookingUnavailable => 'Ausführung nicht verfügbar';

  @override
  String get quickBookingEnterAmount => 'Betrag eingeben';

  @override
  String get quickBookingEmpty => 'Keine Schnellbuchungen vorhanden.';

  @override
  String get featureModulesTitle => 'Funktionen';

  @override
  String get featureModulesDescription => 'Optionale Module einzeln aktivieren.';

  @override
  String get featureModuleProfileManagerName => 'Profilverwaltung';

  @override
  String get featureModuleProfileManagerDescription => 'Profilübersicht mit Anlegen, Wählen und Umbenennen.';

  @override
  String get featureModuleInventoryName => 'Lagerverwaltung';

  @override
  String get featureModuleInventoryDescription => 'Lagerwarnungen, Bestände und manuelle Korrekturen.';

  @override
  String get featureModuleGuvName => 'GuV';

  @override
  String get featureModuleGuvDescription => 'Gewinn- und Verlustrechnung aus Journalbuchungen.';

  @override
  String get featureModuleEnabled => 'Aktiviert';

  @override
  String get featureModuleDisabled => 'Deaktiviert';

  @override
  String get featureModuleUnavailable => 'Nicht verfügbar';

  @override
  String get featureModuleDataRetained => 'Deaktivieren blendet Einträge aus. Bestehende Daten bleiben erhalten.';

  @override
  String get featureModuleThresholdActive => 'GuV-Schwelle erreicht. GuV bleibt aktiviert.';

  @override
  String get featureModuleSaveError => 'Speichern fehlgeschlagen. Erneut versuchen.';

  @override
  String get featureModuleUnavailableTitle => 'Modul nicht verfügbar';

  @override
  String get featureModuleUnavailableDescription => 'Dieses Modul ist deaktiviert. Keine Daten wurden geändert.';

  @override
  String get guidanceExplainAction => 'Erklärung';

  @override
  String get guidanceSearchHint => 'Hilfe-Themen suchen …';

  @override
  String get guidanceEmptyResults => 'Keine geprüfte Hilfe zu dieser Suche.';

  @override
  String guidanceLocationLabel(String route, String control) {
    return 'Ort: $route · $control';
  }

  @override
  String guidanceContractLabel(String contract, String revision) {
    return 'Vertrag: $contract · $revision';
  }

  @override
  String get guidanceNoAdviceNote =>
      'Hinweis: Diese Erklärung beschreibt das Verhalten der App und ist keine Steuerberatung.';

  @override
  String get guidanceTitleSkrMapping => 'SKR-Zuordnung der Kategorie';

  @override
  String get guidanceBodySkrMapping =>
      'Legt fest, welchem Standardkonto des Kontenrahmens (SKR 03/04) diese Kategorie in Auswertungen zugeordnet wird. Die Zuordnung steuert, in welcher Zeile der Auswertung Beträge dieser Kategorie erscheinen. Sie ändert keine Buchungen und ersetzt keine steuerliche Kontenwahl.';

  @override
  String get guidanceTitleJournalImmutability => 'Unveränderbarkeit des Journals';

  @override
  String get guidanceBodyJournalImmutability =>
      'Abgeschlossene Journalbuchungen können nicht nachträglich geändert oder gelöscht werden. Fehler werden ausschließlich über eine Stornobuchung mit Gegenbuchung korrigiert. So bleibt die Buchungshistorie lückenlos nachvollziehbar.';

  @override
  String get guidanceTitleJournalStorno => 'Stornobuchung';

  @override
  String get guidanceBodyJournalStorno =>
      'Erstellt eine Gegenbuchung, die die ursprüngliche Buchung rechnerisch aufhebt. Die Originalbuchung bleibt erhalten und sichtbar. Erst nach der Stornobuchung kann bei Bedarf neu gebucht werden.';

  @override
  String get guidanceTitleJournalGroup => 'Journalgruppe';

  @override
  String get guidanceBodyJournalGroup =>
      'Fasst zusammengehörende Buchungen eines Vorgangs zu einer Gruppe zusammen. Die Gruppe dient der Übersicht und Filterung in Auswertungen. Sie ändert weder Beträge noch Steuersätze.';

  @override
  String get guidanceTitleEuerInputTaxClaim => 'Vorsteuerabzug in der EÜR';

  @override
  String get guidanceBodyEuerInputTaxClaim =>
      'Gibt an, in welcher Richtung geltend gemachte Vorsteuer in die EÜR-Finalisierung einfließt. Die Einstellung wirkt sich auf die ausgewiesenen Betriebsausgaben der Periode aus. Ob und in welcher Höhe Vorsteuer geltend gemacht werden kann, prüft die App nicht; maßgeblich ist § 15 UStG.';

  @override
  String get guidanceTitleForderungStatus => 'Forderungsstatus';

  @override
  String get guidanceBodyForderungStatus =>
      'Zeigt den Bearbeitungsstand einer offenen Forderung: offen, teilbezahlt, bezahlt oder überfällig. Der Status steuert, ob die Forderung in Mahnläufen und Übersichten offener Posten erscheint. Er ändert keine Rechnungsbeträge.';

  @override
  String get guidanceTitleForderungOverpayment => 'Überzahlungs-Hinweis';

  @override
  String get guidanceBodyForderungOverpayment =>
      'Markiert eine Zahlung, die den offenen Forderungsbetrag übersteigt. Der überzahlte Betrag wird im Überzahlungs-Protokoll festgehalten und steht für Zuordnung oder Erstattung bereit. Es erfolgt keine automatische Verrechnung ohne deine Buchung.';

  @override
  String get guidanceTitleVerbindlichkeitPayment => 'Verbindlichkeitszahlung';

  @override
  String get guidanceBodyVerbindlichkeitPayment =>
      'Erfasst eine geleistete Zahlung auf eine offene Verbindlichkeit. Die Zahlung mindert den offenen Saldo des Lieferanten und erscheint im Zahlungsjournal. Fälligkeits- und Skontoprüfung übernimmt die App nicht.';

  @override
  String get guidanceTitleMahnungFeeInterest => 'Mahngebühr und Verzugszinsen';

  @override
  String get guidanceBodyMahnungFeeInterest =>
      'Erfasst pauschale Mahngebühren und berechnete Verzugszinsen eines Mahnlaufs. Die Beträge erhöhen die offene Forderung und werden im Mahnverlauf dokumentiert. Die App prüft nicht, ob und in welcher Höhe Gebühren oder Zinsen nach §§ 286, 288 BGB zulässig sind.';

  @override
  String get guidanceTitleBankMatchStatus => 'Trefferstatus der Zuordnung';

  @override
  String get guidanceBodyBankMatchStatus =>
      'Zeigt, wie sicher die App eine Banktransaktion einer Rechnung oder Kategorie zuordnet: Vorschlag oder bestätigt. Nur bestätigte Zuordnungen wirken sich auf offene Posten aus. Vorschläge mit geringer Trefferquote werden nie automatisch bestätigt.';

  @override
  String get guidanceTitleBankClassification => 'Manuelle Klassifizierung';

  @override
  String get guidanceBodyBankClassification =>
      'Überschreibt den automatisch vorgeschlagenen Geschäftsvorfall einer Transaktion (betrieblich, privat oder gemischt). Die Überschreibung gilt für diese Transaktion und steuert ihre steuerliche Auswertung. Regeln für wiederkehrende Fälle legst du separat an.';

  @override
  String get guidanceTitleAngebotStatus => 'Angebotsstatus';

  @override
  String get guidanceBodyAngebotStatus =>
      'Verfolgt den Stand eines Angebots von Entwurf über versendet und angenommen bis abgelehnt oder abgelaufen. Nur ein angenommenes Angebot kann in einen Auftrag überführt werden. Der Status hat keine steuerliche Wirkung.';

  @override
  String get guidanceTitleAuftragStatus => 'Auftragsstatus';

  @override
  String get guidanceBodyAuftragStatus =>
      'Verfolgt den Stand eines Auftrags von bestätigt über in Bearbeitung bis abgeschlossen oder storniert. Der Abschluss gibt die zugehörige Rechnung zur Erstellung frei. Stornierte Aufträge bleiben zu Nachweiszwecken erhalten.';

  @override
  String get guidanceTitleCorrectionCreditSign => 'Vorzeichen der Korrekturbeträge';

  @override
  String get guidanceBodyCorrectionCreditSign =>
      'Korrekturbeträge behalten ihr Vorzeichen, damit die Umsatzsteuer-Mathematik der Ursprungsrechnung erhalten bleibt. Eine Gutschrift mindert, eine Nachbelastung erhöht die Bemessungsgrundlage. Die App erstellt keine umsatzsteuerliche Würdigung des Korrekturgrunds; das Verhalten ist auf unterstützte Korrekturfälle beschränkt.';

  @override
  String get guidanceTitleTaxSpecial25a => 'Differenzbesteuerung nach § 25a UStG';

  @override
  String get guidanceBodyTaxSpecial25a =>
      'Kennzeichnet Umsätze, deren Bemessungsgrundlage die Marge statt des Gesamtpreises ist. Die App weist solche Umsätze in der Steuerübersicht gesondert aus. Ob die Voraussetzungen des § 25a UStG erfüllt sind, prüft die App nicht; nicht unterstützte Konstellationen werden als nicht verfügbar ausgewiesen.';

  @override
  String get contactsTabCustomers => 'Kunden';

  @override
  String get contactsTabSuppliers => 'Lieferanten';

  @override
  String get filterArchived => 'Archiviert';

  @override
  String get filterActive => 'Aktiv';

  @override
  String get actionArchive => 'Archivieren';

  @override
  String get actionRestore => 'Wiederherstellen';

  @override
  String get actionBulkArchive => 'Auswahl archivieren';

  @override
  String get actionEdit => 'Bearbeiten';

  @override
  String get actionInspect => 'Ansehen';

  @override
  String get actionOpen => 'Öffnen';

  @override
  String get actionDelete => 'Löschen';

  @override
  String get actionSaving => 'Wird gespeichert…';

  @override
  String get actionConfirm => 'Bestätigen';

  @override
  String get actionSelectCustomer => 'Kunde';

  @override
  String get actionSelectSupplier => 'Lieferant';

  @override
  String get actionCreateSupplier => 'Lieferant anlegen';

  @override
  String get actionCreateArticle => 'Artikel anlegen';

  @override
  String get actionCreateGroup => 'Gruppe anlegen';

  @override
  String get actionCreateCategory => 'Kategorie anlegen';

  @override
  String get actionCreateAccount => 'Konto anlegen';

  @override
  String get actionCreateTaxRate => 'Steuersatz anlegen';

  @override
  String get actionCreateNumberRange => 'Nummernkreis anlegen';

  @override
  String get contactTypeSelectionTitle => 'Kontaktart wählen';

  @override
  String get contactTypeSelectionMessage =>
      'Wähle, ob ein Kunden- oder Lieferantendatensatz geöffnet werden soll. Ohne Auswahl wird kein Datensatz geladen.';

  @override
  String get articleTypeSelectionTitle => 'Artikelart wählen';

  @override
  String get articleTypeSelectionMessage =>
      'Wähle, ob ein Artikel oder eine Warengruppe geöffnet werden soll. Ohne Auswahl wird kein Datensatz geladen.';

  @override
  String get archiveConfirmTitle => 'Archivieren bestätigen';

  @override
  String get archiveConfirmMessage =>
      'Der Datensatz erhält einen Archivzeitpunkt und bleibt für vorhandene Belege und Auswertungen erhalten.';

  @override
  String get restoreConfirmTitle => 'Wiederherstellen bestätigen';

  @override
  String get restoreConfirmMessage =>
      'Der Archivzeitpunkt wird entfernt und der Datensatz erscheint wieder in der Standardauswahl.';

  @override
  String get workspaceUnavailable => 'Daten nicht verfügbar';

  @override
  String get workspaceUnavailableMessage => 'Die Daten konnten nicht geladen werden. Versuche es erneut.';

  @override
  String get saveFailed => 'Speichern fehlgeschlagen';

  @override
  String get formRequiredField => 'Pflichtfeld';

  @override
  String get formName => 'Name';

  @override
  String get formCompany => 'Firma';

  @override
  String get formStreet => 'Straße und Hausnummer';

  @override
  String get formPostalCode => 'PLZ';

  @override
  String get formCity => 'Ort';

  @override
  String get formEmail => 'E-Mail';

  @override
  String get formPhone => 'Telefon';

  @override
  String get formVatId => 'USt-IdNr.';

  @override
  String get formIban => 'IBAN';

  @override
  String get formDescription => 'Beschreibung';

  @override
  String get formSectionBasic => 'Grunddaten';

  @override
  String get formSectionContact => 'Kontakt';

  @override
  String get formSectionTax => 'Steuer und Zahlung';

  @override
  String get customerEditTitle => 'Kunde bearbeiten';

  @override
  String get supplierEditTitle => 'Lieferant bearbeiten';

  @override
  String get contactArchived => 'Archiviert';

  @override
  String get routeArticles => 'Artikel';

  @override
  String get articlesViewItems => 'Artikel';

  @override
  String get articlesViewGroups => 'Warengruppen';

  @override
  String get settingsMasterData => 'Stammdaten';

  @override
  String get settingsCompany => 'Firmendaten';

  @override
  String get settingsCategories => 'Kategorien';

  @override
  String get settingsAccounts => 'Bankkonten';

  @override
  String get settingsTaxRates => 'Steuersätze';

  @override
  String get settingsNumberRanges => 'Nummernkreise';

  @override
  String get countCustomers => 'Kunden';

  @override
  String get countSuppliers => 'Lieferanten';

  @override
  String get countArticles => 'Artikel';

  @override
  String get countGroups => 'Gruppen';

  @override
  String get companySetupNeeded => 'Noch keine Firmendaten. Lege sie jetzt an.';

  @override
  String get numberRangeNextLabel => 'Nächste Nummer';

  @override
  String get smtpTestSuccess =>
      'SMTP-Prüfung erfolgreich: Begrüßung, TLS-Aufbau und Anmeldung abgeschlossen. Es wurde keine Nachricht gesendet.';

  @override
  String get smtpTestHostUnreachable => 'Host nicht erreichbar. Es wurde keine Nachricht gesendet.';

  @override
  String get smtpTestTlsFailed => 'TLS-Prüfung fehlgeschlagen. Es wurde kein Klartext-Versuch unternommen.';

  @override
  String get smtpTestAuthFailed => 'Anmeldung fehlgeschlagen. Zugangsdaten prüfen.';

  @override
  String get smtpModeImplicitTls => 'Implizites TLS';

  @override
  String get smtpModeStarttls => 'STARTTLS (erforderlich)';

  @override
  String get smtpVaultUnavailable => 'Der System-Schlüsselspeicher ist nicht verfügbar. SMTP bleibt deaktiviert.';

  @override
  String get smtpMigrationRetry => 'Bitte Zugriff erneut versuchen oder das Passwort neu eingeben.';

  @override
  String get smtpPasswordMissing => 'Noch kein SMTP-Passwort gespeichert. Bitte Passwort eingeben.';

  @override
  String get smtpDisabled => 'SMTP deaktiviert';

  @override
  String get docEmailSend => 'Per E-Mail senden';

  @override
  String get docEmailPreviewTitle => 'Nachricht prüfen';

  @override
  String get docEmailConfirmSend => 'Geprüfte Nachricht senden';

  @override
  String get docEmailRecipient => 'Empfänger';

  @override
  String get docEmailSender => 'Absender';

  @override
  String get docEmailSubject => 'Betreff';

  @override
  String get docEmailBody => 'Nachricht';

  @override
  String get docEmailAttachments => 'Anhänge';

  @override
  String get docEmailAccepted => 'Vom SMTP-Server angenommen (kein Zustellnachweis).';

  @override
  String get docEmailRejected => 'Vom Server abgelehnt. Nicht als versendet markiert.';

  @override
  String get docEmailUnknown => 'Ergebnis unklar. Erneutes Senden erst nach Bestätigung.';

  @override
  String get docEmailUnknownRetryConfirm => 'Möglicherweise bereits zugestellt. Trotzdem erneut senden?';

  @override
  String get docEmailBlockedDraft => 'Entwürfe können nicht versendet werden.';

  @override
  String get docEmailBlockedRecipient => 'Kein gültiger Empfänger.';

  @override
  String get docEmailBlockedArtifact => 'Kein erzeugtes PDF für dieses Dokument vorhanden.';

  @override
  String get docEmailTemplateUnresolved => 'Platzhalter konnte nicht aufgelöst werden. Senden blockiert.';

  @override
  String get docEmailHeaderLineBreak => 'Betreff und Adressen dürfen keine Zeilenumbrüche enthalten.';

  @override
  String get docEmailNoSendControl => 'Versand für diesen Dokumenttyp noch nicht verfügbar.';

  @override
  String get docEmailDuplicateInProgress => 'Sendeversuch läuft bereits.';

  @override
  String get docEmailHistory => 'Sendeversuche';

  @override
  String get csvImportTitle => 'CSV-Import';

  @override
  String get csvImportStepSource => '1. Datei';

  @override
  String get csvImportStepMapping => '2. Zuordnung';

  @override
  String get csvImportStepReview => '3. Prüfung';

  @override
  String get csvImportStepResult => '4. Ergebnis';

  @override
  String get csvImportSourceHint => 'CSV-Text einfügen oder lokalen Dateipfad angeben. Die Vorschau schreibt nichts.';

  @override
  String get csvImportCsvLabel => 'CSV-Text';

  @override
  String get csvImportPathLabel => 'Lokaler Dateipfad (optional)';

  @override
  String get csvImportDelimiter => 'Trennzeichen';

  @override
  String get csvImportHeaderOption => 'Erste Zeile ist Kopfzeile';

  @override
  String get csvImportDecimalConvention => 'Zahlenformat';

  @override
  String get csvImportDecimalPoint => 'Dezimalpunkt (123.50)';

  @override
  String get csvImportDecimalComma => 'Dezimalkomma (123,50)';

  @override
  String get csvImportDuplicatePolicy => 'Duplikatregel';

  @override
  String get csvImportPolicySkip => 'Überspringen';

  @override
  String get csvImportPolicyUpdate => 'Aktualisieren';

  @override
  String get csvImportPolicyCreateNew => 'Neu anlegen';

  @override
  String get csvImportMatchField => 'Vergleichsfeld';

  @override
  String get csvImportPriceBasis => 'Preisbasis';

  @override
  String get csvImportPriceNet => 'Netto';

  @override
  String get csvImportPriceGross => 'Brutto';

  @override
  String get csvImportParseAndMap => 'Parsen und zuordnen';

  @override
  String get csvImportValidatePreview => 'Vorschau prüfen';

  @override
  String get csvImportConfirm => 'Import bestätigen';

  @override
  String get csvImportTemplate => 'Zuordnungsvorlage';

  @override
  String get csvImportTemplateNone => 'Keine Vorlage';

  @override
  String get csvImportSaveMapping => 'Zuordnung speichern';

  @override
  String get csvImportTemplateName => 'Vorlagenname';

  @override
  String get csvImportStatusValid => 'Gültig';

  @override
  String get csvImportStatusInvalid => 'Ungültig';

  @override
  String get csvImportStatusSkip => 'Übersprungen';

  @override
  String get csvImportStatusUpdate => 'Aktualisierung';

  @override
  String get csvImportStatusCreate => 'Neu';

  @override
  String get csvImportStatusAmbiguous => 'Mehrdeutig';

  @override
  String get csvImportStatusDuplicate => 'Duplikat';

  @override
  String get csvImportSelectUpdate => 'Aktualisierung wählen';

  @override
  String get csvImportCounts => 'Anzahlen';

  @override
  String get csvImportFileTooLarge => 'Datei überschreitet 20 MiB; kein Datensatz wurde geschrieben.';

  @override
  String get csvImportRowLimit => 'Datei überschreitet 50.000 Zeilen; kein Datensatz wurde geschrieben.';

  @override
  String get csvImportMalformed => 'Fehlerhafte Anführungszeichen; kein Datensatz wurde geschrieben.';

  @override
  String get csvImportUnsupportedEncoding => 'Nicht unterstützte Kodierung; nur UTF-8 wird unterstützt.';

  @override
  String get csvImportColumnMismatch => 'Uneinheitliche Spaltenzahl; kein Datensatz wurde geschrieben.';

  @override
  String get csvImportEmptyFile => 'Datei ist leer; kein Datensatz wurde geschrieben.';

  @override
  String get csvImportMappingConflict => 'Spaltenzuordnung ist mehrdeutig; die Vorschau wurde nicht geöffnet.';

  @override
  String get csvImportEntityMismatch => 'Vorlage passt nicht zu dieser Datenart.';

  @override
  String get csvImportMatchFieldRequired => 'Für Überspringen/Aktualisieren ist ein Vergleichsfeld erforderlich.';

  @override
  String get csvImportPriceBasisRequired => 'Für Artikel ist eine Preisbasis (netto/brutto) erforderlich.';

  @override
  String csvImportUnsupportedFieldForUpdate(String field) {
    return '$field wird für Artikel-Aktualisierung nicht unterstützt.';
  }

  @override
  String get csvImportBatchFailure => 'Import fehlgeschlagen; keine Zeile wurde übernommen.';

  @override
  String get csvImportUnavailable => 'Importdaten sind derzeit nicht verfügbar. Zuordnung bleibt erhalten.';

  @override
  String get customerDisclosureExportAction => 'Kundendaten exportieren';

  @override
  String get customerDisclosureExportScopeTitle => 'Auskunfts-Export: Umfang';

  @override
  String get customerDisclosureExportScopeDescription =>
      'Dieser Export enthält ausschließlich diesen Kunden und Datensätze mit verifizierten Verknüpfungen (Rechnungen, Positionen, Mahnungen, Forderungen, Zahlungen, Vorlagen, Belege). Freitext-Treffer werden nicht gesucht oder exportiert. Nicht unterstützte oder ausgeschlossene Inhalte werden im Manifest genannt; das Archiv kann unvollständig sein. Dies ist kein Profil-Archiv und kein Backup. Kundendaten werden weder gelöscht noch anonymisiert.';

  @override
  String get customerDisclosureExportConfirm => 'Exportieren';

  @override
  String get customerDisclosureExportProgress => 'Export läuft…';

  @override
  String get customerDisclosureExportComplete => 'Export abgeschlossen und geprüft.';

  @override
  String get customerDisclosureExportIncomplete => 'Export unvollständig gespeichert. Bitte Hinweise prüfen.';

  @override
  String get customerDisclosureExportFailed => 'Export fehlgeschlagen. Bitte Ziel prüfen und erneut versuchen.';

  @override
  String get customerDisclosureExportCancelled => 'Export abgebrochen. Es wurde kein Archiv erstellt.';

  @override
  String get customerDisclosureExportUnavailable => 'Auskunfts-Export ist nicht verfügbar.';

  @override
  String get customerDisclosureExportNotFound => 'Kunde nicht gefunden. Es wurde kein Archiv erstellt.';

  @override
  String get customerDisclosureExportDestinationExists => 'Zieldatei existiert bereits. Bitte anderen Namen wählen.';

  @override
  String get routeAssets => 'Anlagen';

  @override
  String get assetRegisterTitle => 'Anlagenverzeichnis';

  @override
  String get assetRegisterSubtitle => 'Anlagen verwalten und lineare AfA prüfen';

  @override
  String get assetAdd => 'Anlage hinzufügen';

  @override
  String get assetEdit => 'Anlage bearbeiten';

  @override
  String get assetDescription => 'Bezeichnung';

  @override
  String get assetType => 'Anlagetyp';

  @override
  String get assetAcquisitionDate => 'Anschaffungsdatum';

  @override
  String get assetNetPrice => 'Nettokaufpreis';

  @override
  String get assetUsefulLife => 'Nutzungsdauer (Jahre)';

  @override
  String get assetMethod => 'AfA-Methode';

  @override
  String get assetPrivateShare => 'Privatanteil (%)';

  @override
  String get assetCategory => 'Kategorie';

  @override
  String get assetDisposalDate => 'Verkauft am';

  @override
  String assetInvalidField(String field) {
    return 'Ungültige Eingabe: $field';
  }

  @override
  String get assetEmpty => 'Noch keine Anlagen. Lege die erste Anlage an.';

  @override
  String get assetDeleteRefused => 'Anlage kann nicht gelöscht werden: AfA-Jahreswerte vorhanden. Bitte archivieren.';

  @override
  String get assetArchived => 'Anlage archiviert';

  @override
  String get assetScheduleTitle => 'AfA-Jahreswerte';

  @override
  String get assetScheduleUnavailable => 'Nicht verfügbar';

  @override
  String get assetFinancialBlocked => 'Finanzielle Wirkung nicht verfügbar: kein Buchungsvertrag.';

  @override
  String get assetLoadFailed => 'Anlagen konnten nicht geladen werden.';

  @override
  String get assetUnresolved => 'Unaufgelöst: Prüfung erforderlich';

  @override
  String get receiptInboxTitle => 'Beleg-Eingang';

  @override
  String get receiptInboxSubtitle => 'Importieren, prüfen und zuordnen — ohne den Datensatz zu verlassen.';

  @override
  String get receiptReviewAction => 'Prüfen';

  @override
  String get receiptLinkAction => 'Zuordnen';

  @override
  String get receiptPreviewAction => 'Quelle ansehen';

  @override
  String get receiptSourceUnavailable => 'Quelle ist nicht verfügbar';

  @override
  String get paketWorkspaceTitle => 'Dokumentenpakete';

  @override
  String get paketWorkspaceSubtitle => 'Dokumente und Belege gruppieren und als Snapshot exportieren.';

  @override
  String get paketCreateAction => 'Paket erstellen';

  @override
  String get paketExportAction => 'Paket exportieren';

  @override
  String get gobdExportTitle => 'GoBD-Export';

  @override
  String get gobdExportSubtitle => 'Zeitraum wählen, exportieren und prüfen.';

  @override
  String get gobdVerifyAction => 'Prüfen';

  @override
  String get gobdIncomplete => 'Unvollständig: fehlende Nachweise prüfen';

  @override
  String get belegDropHint => 'PDF, PNG, JPEG oder E-Rechnungs-XML hier ablegen (max. 50 MiB)';

  @override
  String get belegUnsupportedType => 'Dateityp nicht unterstützt';

  @override
  String get invoiceWorkspaceTitle => 'Rechnungsarbeitsbereich';

  @override
  String get invoiceWorkspaceEditorTab => 'Bearbeiten';

  @override
  String get invoiceWorkspacePreviewTab => 'Vorschau';

  @override
  String get invoiceWorkspaceAddPosition => 'Position hinzufügen';

  @override
  String get invoiceWorkspaceRemovePosition => 'Position entfernen';

  @override
  String get invoiceWorkspaceMoveUp => 'Nach oben verschieben';

  @override
  String get invoiceWorkspaceMoveDown => 'Nach unten verschieben';

  @override
  String get invoiceWorkspacePreviewStale => 'Vorschau ist veraltet oder ungültig';

  @override
  String get invoiceWorkspaceInvalid => 'Eingaben prüfen';

  @override
  String get invoiceWorkspaceEditDraft => 'Entwurf bearbeiten';

  @override
  String get invoiceWorkspaceSaved => 'Entwurf gespeichert';

  @override
  String get invoiceActionFinalize => 'Finalisieren';

  @override
  String get invoiceFinalizeConfirmTitle => 'Rechnung finalisieren?';

  @override
  String get invoiceFinalizeConfirmMessage => 'Zusammenfassung prüfen und Finalisierung bestätigen.';

  @override
  String get invoiceFinalizeConfirm => 'Finalisieren';

  @override
  String get invoiceActionStorno => 'Stornieren';

  @override
  String get invoiceStornoReasonLabel => 'Stornogrund';

  @override
  String get invoiceStornoReasonRequired => 'Stornogrund ist erforderlich';

  @override
  String get invoiceActionCreditNote => 'Gutschrift erstellen';

  @override
  String get invoiceCreditNoteConfirmMessage => 'Aus dieser Rechnung wird eine verknüpfte Gutschrift erstellt.';

  @override
  String get invoiceActionReplacement => 'Ersatzrechnung erstellen';

  @override
  String get invoiceReplacementConfirmMessage =>
      'Aus dieser stornierten Rechnung wird ein verknüpfter Ersatzentwurf erstellt.';

  @override
  String get invoiceActionConvert => 'Konvertieren';

  @override
  String get invoiceConvertConfirmTitle => 'Konvertierung bestätigen';

  @override
  String get invoiceLifecycleTitle => 'Belegaktionen';

  @override
  String get invoiceLifecycleUnavailable => 'Keine weiteren Aktionen verfügbar';

  @override
  String get invoiceLifecycleDone => 'Aktion abgeschlossen';

  @override
  String get invoiceActionFailed => 'Aktion fehlgeschlagen. Prüfen Sie das Dokument und versuchen Sie es erneut.';

  @override
  String get invoiceRelationshipsTitle => 'Verknüpfungen';

  @override
  String get invoiceRelationshipsEmpty => 'Keine Verknüpfungen';

  @override
  String get invoiceRelationshipMissing => 'Verknüpfung nicht verfügbar';

  @override
  String get eInvoiceOutputTitle => 'Ausgabeformat';

  @override
  String get eInvoiceFormatPdf => 'PDF';

  @override
  String get eInvoiceFormatPdfDescription => 'Visuelles PDF ohne strukturierte Daten';

  @override
  String get eInvoiceFormatZugferd => 'ZUGFeRD';

  @override
  String get eInvoiceFormatZugferdDescription => 'PDF mit eingebetteter ZUGFeRD-XML (2.5.2 EN 16931)';

  @override
  String get eInvoiceFormatXrechnung => 'XRechnung';

  @override
  String get eInvoiceFormatXrechnungDescription => 'XRechnung 3.0 XML-Export nach Finalisierung';

  @override
  String get customerZugferdDefaultTitle => 'ZUGFeRD für neue Rechnungen vorauswählen';

  @override
  String get customerZugferdDefaultDescription =>
      'Legt das Startformat fest; das Format kann für jede Rechnung geändert werden.';

  @override
  String get eInvoiceReadinessValid => 'E-Rechnung geprüft und gültig';

  @override
  String get eInvoiceReadinessInvalid => 'E-Rechnung fehlerhaft – Details prüfen';

  @override
  String get eInvoiceReadinessNotValidated => 'Noch nicht geprüft';

  @override
  String get eInvoiceReadinessUnavailable => 'Prüfung nicht verfügbar';

  @override
  String get eInvoiceExportXrechnung => 'XRechnung exportieren';

  @override
  String get eInvoiceExportSaved => 'XRechnung gespeichert';

  @override
  String get eInvoiceExportCancelled => 'Export abgebrochen';

  @override
  String get eInvoiceValidationTitle => 'Prüfergebnis';

  @override
  String get eInvoiceDraftNoExport => 'Export erst nach Finalisierung verfügbar';

  @override
  String get eInvoiceBuyerReferenceLabel => 'Käuferreferenz (z. B. Leitweg-ID)';

  @override
  String get eInvoiceBuyerReferenceHint => 'Für XRechnung erforderlich';

  @override
  String get routeRecurring => 'Wiederkehrend';

  @override
  String get sidebarRecurring => 'Wiederkehrend';

  @override
  String get recurringTitle => 'Wiederkehrende Buchungen';

  @override
  String get recurringSubtitle => 'Vorlagen und fällige Buchungen prüfen';

  @override
  String get recurringNewTemplate => 'Neue Vorlage';

  @override
  String get recurringEmpty => 'Noch keine Vorlagen. Lege deine erste Vorlage an.';

  @override
  String get recurringLoadFailed => 'Wiederkehrende Buchungen konnten nicht geladen werden';

  @override
  String get recurringDueTitle => 'Fällige Buchungen';

  @override
  String get recurringDueEmpty => 'Keine fälligen Buchungen.';

  @override
  String recurringBlockedReason(String reason) {
    return 'Blockiert: $reason';
  }

  @override
  String recurringHandoffError(String error) {
    return 'Übergabe fehlgeschlagen: $error';
  }

  @override
  String recurringInvalidField(String field) {
    return 'Ungültiges Feld: $field';
  }

  @override
  String get recurringConfirmExecute => 'Ausführen';

  @override
  String get recurringCreateDraft => 'Entwurf erstellen';

  @override
  String get settingsSectionBackup => 'Sicherung';

  @override
  String get settingsBackupNow => 'Jetzt sichern';

  @override
  String get settingsBackupSchedule => 'Automatische Sicherung';

  @override
  String get settingsBackupManual => 'Manuell';

  @override
  String get settingsBackupDaily => 'Täglich';

  @override
  String get settingsBackupWeekly => 'Wöchentlich';

  @override
  String get settingsBackupNever => 'Noch nie gesichert';

  @override
  String get settingsBackupCurrent => 'Aktuell';

  @override
  String get settingsBackupStale => 'Veraltet';

  @override
  String get settingsBackupFailed => 'Fehlgeschlagen';

  @override
  String get settingsRestoreRestartRequired => 'Wiederherstellung vorbereitet. Bitte App beenden und neu starten.';

  @override
  String get settingsProfileUnregister => 'Profil entfernen (Dateien bleiben erhalten)';

  @override
  String get settingsProfileRename => 'Umbenennen';

  @override
  String get settingsProfileRestartRequired => 'Neustart erforderlich';

  @override
  String get settingsProfileInUse => 'Profil wird bereits verwendet';

  @override
  String get settingsRegion => 'Region';

  @override
  String get settingsHolder => 'Kontoinhaber';

  @override
  String get setupDeferredCategories => 'Kategorien sind zurückgestellt (kein geprüfter Katalog).';

  @override
  String get setupLegalForm => 'Rechtsform';

  @override
  String get smtpConnectivityOnly => 'Verbindung geprüft (keine Anmeldung, kein Versand).';

  @override
  String get settingsNoErasure => 'Kein dauerhaftes Löschen verfügbar.';

  @override
  String get settingsExportScope => 'Exporte stammen aus dem zuständigen Bereich.';

  @override
  String get routeDunning => 'Mahnwesen';

  @override
  String get sidebarDunning => 'Mahnwesen';

  @override
  String get dunningTitle => 'Mahnwesen';

  @override
  String get dunningSubtitle => 'Offene Forderungen prüfen, Mahnungen vorbereiten';

  @override
  String get dunningPreviewAction => 'Lauf prüfen';

  @override
  String get dunningConfirmAction => 'Bestätigen & erstellen';

  @override
  String get dunningHistoryTitle => 'Mahnhistorie';

  @override
  String get dunningExclusionsTitle => 'Ausschlüsse';

  @override
  String get dunningEmpty => 'Keine fälligen Forderungen.';

  @override
  String get dunningLoadFailed => 'Mahnwesen konnte nicht geladen werden';

  @override
  String get dunningUnavailable => 'Mahnwesen ist nicht verfügbar';

  @override
  String get dunningExcludedState => 'Ausgeschlossen';

  @override
  String get dunningDraftState => 'Entwurf';

  @override
  String get dunningTransportAccepted => 'Transport akzeptiert';

  @override
  String get dunningOutstandingLabel => 'Offen';

  @override
  String get dunningFeeLabel => 'Gebühr';

  @override
  String get dunningRateLabel => 'Zinssatz';

  @override
  String get dunningInterestLabel => 'Zinsen';

  @override
  String get dunningStageLabel => 'Stufe';

  @override
  String get dunningExclusionReasonHint => 'Grund';

  @override
  String get dunningAddExclusion => 'Ausschluss hinzufügen';

  @override
  String get dunningRemoveExclusion => 'Ausschluss entfernen';

  @override
  String get dunningGraceDeprecated => 'Karenz (veraltet, ohne Wirkung)';

  @override
  String get dunningSendAction => 'Mahnung senden';

  @override
  String get dunningCollectionAction => 'Inkassopaket';

  @override
  String get dunningNoBalance => 'Saldo nicht verfügbar';

  @override
  String dunningDetailTitle(String number) {
    return 'Forderung $number';
  }

  @override
  String get incomingInvoiceCaptureTitle => 'Lieferantenrechnung erfassen';

  @override
  String get incomingInvoiceCaptureAction => 'Eingangsrechnung erstellen';

  @override
  String get incomingInvoiceSupplierLabel => 'Lieferant';

  @override
  String get incomingInvoiceSourceNumberLabel => 'Rechnungsnummer des Lieferanten';

  @override
  String get incomingInvoiceDueDateLabel => 'Fällig am';

  @override
  String get incomingInvoiceVatRateLabel => 'USt %';

  @override
  String get incomingInvoiceSupplierRequired => 'Wählen Sie vor dem Speichern einen Lieferanten aus.';

  @override
  String get incomingInvoiceSaveFailed => 'Der Entwurf der Eingangsrechnung konnte nicht gespeichert werden.';

  @override
  String get incomingInvoiceCaptureSaved => 'Entwurf der Eingangsrechnung gespeichert.';

  @override
  String get incomingInvoiceUnsupportedProfile =>
      'Dieses strukturierte Rechnungsprofil wird nicht unterstützt. Erfassen Sie die Werte manuell.';

  @override
  String get incomingInvoiceUnreadable =>
      'Strukturierte Rechnungsdaten konnten nicht gelesen werden. Erfassen Sie die Werte manuell.';

  @override
  String incomingInvoiceUnsupportedValue(String value) {
    return 'Nicht unterstützter Quellenwert: $value';
  }

  @override
  String incomingInvoiceSuggestedValue(String value) {
    return 'Quellenwert: $value';
  }

  @override
  String get incomingInvoiceSourcePreviewUnavailable => 'Die Vorschau der Originalquelle ist nicht verfügbar.';

  @override
  String get incomingInvoiceTotalsDisplayOnly => 'Quellensummen dienen nur zum Vergleich.';

  @override
  String get incomingInvoiceConfirmUnsupportedValues =>
      'Ich habe die nicht unterstützten Quellenwerte geprüft und die Rechnung manuell erfasst.';

  @override
  String get dashboardPeriodYear => 'Geschäftsjahr';

  @override
  String dashboardPeriodRange(int year, String start, String end) {
    return '$year · $start – $end';
  }

  @override
  String get dashboardReportingPending => 'Keine Periodenwerte – Auswertung ausstehend.';

  @override
  String get dashboardReportingPrerequisite => 'Periodenwerte nicht verfügbar – Auswertungs-Arbeitsbereich fehlt.';

  @override
  String get dashboardUnsupportedPeriod => 'Monat/Quartal ist nicht verfügbar – Jahresansicht.';

  @override
  String get dashboardInvalidPeriod => 'Ungültiger Zeitraum.';

  @override
  String get dashboardNotComparable => 'Nicht vergleichbar';

  @override
  String get dashboardProfit => 'Gewinn';

  @override
  String get dashboardMargin => 'Marge';

  @override
  String get dashboardMarginUnavailable => 'Marge n. v.';

  @override
  String get dashboardVatReserveEstimate => 'USt-Rücklage (Schätzung)';

  @override
  String get dashboardQuickLinkAdd => 'Link hinzufügen';

  @override
  String get dashboardQuickLinkEdit => 'Link bearbeiten';

  @override
  String get dashboardQuickLinkInvalid => 'Route wird nicht unterstützt.';

  @override
  String get dashboardQuickLinkInvalidState => 'Ungültiger Link – entfernen';

  @override
  String get dashboardAttentionTitle => 'Aufgaben';

  @override
  String get dashboardAttentionOverdue => 'Überfällige Rechnung';

  @override
  String get dashboardAttentionUnmatched => 'Abzustimmende Transaktion';

  @override
  String get dashboardAttentionTaxDeadline => 'Steuerfrist';

  @override
  String get dashboardTaxCalendarMissing => 'Kein Steuerkalender konfiguriert.';

  @override
  String get dashboardTrendTitle => 'Verlauf';

  @override
  String get dashboardTrendEmpty => 'Keine Verlaufsdaten für diesen Zeitraum.';

  @override
  String get dashboardTrendError => 'Verlaufsdaten konnten nicht geladen werden.';

  @override
  String get dashboardOpenBalance => 'Offener Saldo zum Jahresende';

  @override
  String get dashboardIncompleteHistory => 'Unvollständige Historie – effektives Datum fehlt.';

  @override
  String get dashboardUnavailable => 'Nicht verfügbar';

  @override
  String get dashboardQuickLinkInvalidLabel => 'ungültig';

  @override
  String get dashboardQuickLinkLabel => 'Bezeichnung';

  @override
  String get dashboardQuickLinkRoute => 'Route';
}
