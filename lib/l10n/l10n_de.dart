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
}
