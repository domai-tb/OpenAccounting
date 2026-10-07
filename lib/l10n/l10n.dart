import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_de.dart';
import 'l10n_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('de'), Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In de, this message translates to:
  /// **'OpenAccounting'**
  String get appTitle;

  /// No description provided for @hello.
  ///
  /// In de, this message translates to:
  /// **'Hallo! Deine Buchhaltung ist bereit.'**
  String get hello;

  /// No description provided for @welcome.
  ///
  /// In de, this message translates to:
  /// **'Willkommen! Du kannst jetzt loslegen.'**
  String get welcome;

  /// No description provided for @settingsTheme.
  ///
  /// In de, this message translates to:
  /// **'Darstellung'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In de, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In de, this message translates to:
  /// **'Hell'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get themeDark;

  /// No description provided for @sidebarOverview.
  ///
  /// In de, this message translates to:
  /// **'Übersicht'**
  String get sidebarOverview;

  /// No description provided for @sidebarInvoices.
  ///
  /// In de, this message translates to:
  /// **'Rechnungen'**
  String get sidebarInvoices;

  /// No description provided for @sidebarReceipts.
  ///
  /// In de, this message translates to:
  /// **'Belege'**
  String get sidebarReceipts;

  /// No description provided for @sidebarBanking.
  ///
  /// In de, this message translates to:
  /// **'Bank & Zahlungen'**
  String get sidebarBanking;

  /// No description provided for @sidebarContacts.
  ///
  /// In de, this message translates to:
  /// **'Kontakte'**
  String get sidebarContacts;

  /// No description provided for @sidebarTaxes.
  ///
  /// In de, this message translates to:
  /// **'Steuern'**
  String get sidebarTaxes;

  /// No description provided for @sidebarReports.
  ///
  /// In de, this message translates to:
  /// **'Auswertungen'**
  String get sidebarReports;

  /// No description provided for @sidebarSettings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get sidebarSettings;

  /// No description provided for @sidebarHelp.
  ///
  /// In de, this message translates to:
  /// **'Hilfe'**
  String get sidebarHelp;

  /// No description provided for @sidebarMenu.
  ///
  /// In de, this message translates to:
  /// **'Menü'**
  String get sidebarMenu;

  /// No description provided for @sidebarSectionOverview.
  ///
  /// In de, this message translates to:
  /// **'ÜBERSICHT'**
  String get sidebarSectionOverview;

  /// No description provided for @sidebarSectionBusiness.
  ///
  /// In de, this message translates to:
  /// **'GESCHÄFT'**
  String get sidebarSectionBusiness;

  /// No description provided for @sidebarSectionTaxes.
  ///
  /// In de, this message translates to:
  /// **'STEUERN'**
  String get sidebarSectionTaxes;

  /// No description provided for @workspaceLocalProfile.
  ///
  /// In de, this message translates to:
  /// **'Lokales Profil'**
  String get workspaceLocalProfile;

  /// No description provided for @workspaceManage.
  ///
  /// In de, this message translates to:
  /// **'Profil verwalten'**
  String get workspaceManage;

  /// No description provided for @localTitle.
  ///
  /// In de, this message translates to:
  /// **'Lokal'**
  String get localTitle;

  /// No description provided for @localDescription.
  ///
  /// In de, this message translates to:
  /// **'Alle Daten werden lokal gespeichert — kein Cloud-Zugriff.'**
  String get localDescription;

  /// No description provided for @close.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get close;

  /// No description provided for @backendUnreachable.
  ///
  /// In de, this message translates to:
  /// **'Backend nicht erreichbar'**
  String get backendUnreachable;

  /// No description provided for @retry.
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get retry;

  /// No description provided for @profileLoadError.
  ///
  /// In de, this message translates to:
  /// **'Profile konnten nicht geladen werden'**
  String get profileLoadError;

  /// No description provided for @notFound.
  ///
  /// In de, this message translates to:
  /// **'Nicht gefunden'**
  String get notFound;

  /// No description provided for @invoiceNotFound.
  ///
  /// In de, this message translates to:
  /// **'Rechnung nicht gefunden'**
  String get invoiceNotFound;

  /// No description provided for @setupTitle.
  ///
  /// In de, this message translates to:
  /// **'Deine Buchhaltung. Lokal auf deinem Gerät.'**
  String get setupTitle;

  /// No description provided for @setupStart.
  ///
  /// In de, this message translates to:
  /// **'Loslegen'**
  String get setupStart;

  /// No description provided for @confirmDelete.
  ///
  /// In de, this message translates to:
  /// **'Möchtest du diese Rechnung wirklich löschen?'**
  String get confirmDelete;

  /// No description provided for @emptyInvoices.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Rechnungen. Erstelle deine erste Rechnung.'**
  String get emptyInvoices;

  /// No description provided for @language.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get language;

  /// No description provided for @languageGerman.
  ///
  /// In de, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @languageEnglish.
  ///
  /// In de, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @settingsTitle.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get settingsLanguage;

  /// No description provided for @settingsPrivacy.
  ///
  /// In de, this message translates to:
  /// **'Datenschutz'**
  String get settingsPrivacy;

  /// No description provided for @settingsPrivacyDescription.
  ///
  /// In de, this message translates to:
  /// **'Deine Buchhaltungsdaten bleiben auf diesem Gerät.'**
  String get settingsPrivacyDescription;

  /// No description provided for @settingsProfiles.
  ///
  /// In de, this message translates to:
  /// **'Profile'**
  String get settingsProfiles;

  /// No description provided for @settingsAppearance.
  ///
  /// In de, this message translates to:
  /// **'Darstellung'**
  String get settingsAppearance;

  /// No description provided for @settingsProfileLoadError.
  ///
  /// In de, this message translates to:
  /// **'Profile konnten nicht geladen werden'**
  String get settingsProfileLoadError;

  /// No description provided for @settingsProfileRetry.
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get settingsProfileRetry;

  /// No description provided for @routeOverview.
  ///
  /// In de, this message translates to:
  /// **'Übersicht'**
  String get routeOverview;

  /// No description provided for @routeInvoices.
  ///
  /// In de, this message translates to:
  /// **'Rechnungen'**
  String get routeInvoices;

  /// No description provided for @routeReceipts.
  ///
  /// In de, this message translates to:
  /// **'Belege'**
  String get routeReceipts;

  /// No description provided for @routeBanking.
  ///
  /// In de, this message translates to:
  /// **'Banking'**
  String get routeBanking;

  /// No description provided for @routeContacts.
  ///
  /// In de, this message translates to:
  /// **'Kontakte'**
  String get routeContacts;

  /// No description provided for @routeTaxes.
  ///
  /// In de, this message translates to:
  /// **'Steuern'**
  String get routeTaxes;

  /// No description provided for @routeReports.
  ///
  /// In de, this message translates to:
  /// **'Auswertungen'**
  String get routeReports;

  /// No description provided for @routeSettings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get routeSettings;

  /// No description provided for @routeHelp.
  ///
  /// In de, this message translates to:
  /// **'Hilfe'**
  String get routeHelp;

  /// No description provided for @routeInventory.
  ///
  /// In de, this message translates to:
  /// **'Lager'**
  String get routeInventory;

  /// No description provided for @routeSetup.
  ///
  /// In de, this message translates to:
  /// **'Einrichtung'**
  String get routeSetup;

  /// No description provided for @actionBackOverview.
  ///
  /// In de, this message translates to:
  /// **'Zur Übersicht'**
  String get actionBackOverview;

  /// No description provided for @actionNewInvoice.
  ///
  /// In de, this message translates to:
  /// **'Neue Rechnung'**
  String get actionNewInvoice;

  /// No description provided for @actionSearch.
  ///
  /// In de, this message translates to:
  /// **'Suchen'**
  String get actionSearch;

  /// No description provided for @actionReset.
  ///
  /// In de, this message translates to:
  /// **'Zurücksetzen'**
  String get actionReset;

  /// No description provided for @actionRefresh.
  ///
  /// In de, this message translates to:
  /// **'Aktualisieren'**
  String get actionRefresh;

  /// No description provided for @actionSave.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get actionCancel;

  /// No description provided for @actionRetry.
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get actionRetry;

  /// No description provided for @actionClose.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get actionClose;

  /// No description provided for @actionContinue.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get actionContinue;

  /// No description provided for @actionBack.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get actionBack;

  /// No description provided for @actionSkip.
  ///
  /// In de, this message translates to:
  /// **'Überspringen'**
  String get actionSkip;

  /// No description provided for @searchHint.
  ///
  /// In de, this message translates to:
  /// **'Suchen…'**
  String get searchHint;

  /// No description provided for @loading.
  ///
  /// In de, this message translates to:
  /// **'Wird geladen…'**
  String get loading;

  /// No description provided for @loadError.
  ///
  /// In de, this message translates to:
  /// **'Daten konnten nicht geladen werden'**
  String get loadError;

  /// No description provided for @emptyResults.
  ///
  /// In de, this message translates to:
  /// **'Keine Treffer'**
  String get emptyResults;

  /// No description provided for @emptyEntries.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Einträge'**
  String get emptyEntries;

  /// No description provided for @countResults.
  ///
  /// In de, this message translates to:
  /// **'Ergebnisse'**
  String get countResults;

  /// No description provided for @countInvoices.
  ///
  /// In de, this message translates to:
  /// **'Rechnungen'**
  String get countInvoices;

  /// No description provided for @countReceipts.
  ///
  /// In de, this message translates to:
  /// **'Belege'**
  String get countReceipts;

  /// No description provided for @countContacts.
  ///
  /// In de, this message translates to:
  /// **'Kontakte'**
  String get countContacts;

  /// No description provided for @countTransactions.
  ///
  /// In de, this message translates to:
  /// **'Transaktionen'**
  String get countTransactions;

  /// No description provided for @countRecords.
  ///
  /// In de, this message translates to:
  /// **'Einträge'**
  String get countRecords;

  /// No description provided for @statusOpen.
  ///
  /// In de, this message translates to:
  /// **'Offen'**
  String get statusOpen;

  /// No description provided for @statusPaid.
  ///
  /// In de, this message translates to:
  /// **'Bezahlt'**
  String get statusPaid;

  /// No description provided for @statusDraft.
  ///
  /// In de, this message translates to:
  /// **'Entwurf'**
  String get statusDraft;

  /// No description provided for @statusOverdue.
  ///
  /// In de, this message translates to:
  /// **'Überfällig'**
  String get statusOverdue;

  /// No description provided for @statusUnknown.
  ///
  /// In de, this message translates to:
  /// **'Unbekannt'**
  String get statusUnknown;

  /// No description provided for @documentInvoice.
  ///
  /// In de, this message translates to:
  /// **'Rechnung'**
  String get documentInvoice;

  /// No description provided for @documentCreditNote.
  ///
  /// In de, this message translates to:
  /// **'Gutschrift'**
  String get documentCreditNote;

  /// No description provided for @documentReceipt.
  ///
  /// In de, this message translates to:
  /// **'Beleg'**
  String get documentReceipt;

  /// No description provided for @documentOther.
  ///
  /// In de, this message translates to:
  /// **'Dokument'**
  String get documentOther;

  /// No description provided for @dateLabel.
  ///
  /// In de, this message translates to:
  /// **'Datum'**
  String get dateLabel;

  /// No description provided for @amountHidden.
  ///
  /// In de, this message translates to:
  /// **'Betrag verborgen'**
  String get amountHidden;

  /// No description provided for @dashboardTitle.
  ///
  /// In de, this message translates to:
  /// **'Übersicht'**
  String get dashboardTitle;

  /// No description provided for @dashboardWelcome.
  ///
  /// In de, this message translates to:
  /// **'Willkommen in deiner lokalen Buchhaltung.'**
  String get dashboardWelcome;

  /// No description provided for @dashboardInventory.
  ///
  /// In de, this message translates to:
  /// **'Lager'**
  String get dashboardInventory;

  /// No description provided for @dashboardInventoryUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Die Lagerverwaltung ist derzeit nicht verfügbar.'**
  String get dashboardInventoryUnavailable;

  /// No description provided for @invoicesSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Rechnungen'**
  String get invoicesSubtitle;

  /// No description provided for @receiptsSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Belege'**
  String get receiptsSubtitle;

  /// No description provided for @bankingSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Banktransaktionen'**
  String get bankingSubtitle;

  /// No description provided for @contactsSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Kontakte'**
  String get contactsSubtitle;

  /// No description provided for @taxesSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Steuern'**
  String get taxesSubtitle;

  /// No description provided for @reportsSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Auswertungen'**
  String get reportsSubtitle;

  /// No description provided for @helpSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Hilfe und Support'**
  String get helpSubtitle;

  /// No description provided for @notFoundDescription.
  ///
  /// In de, this message translates to:
  /// **'Die angeforderte Seite wurde nicht gefunden.'**
  String get notFoundDescription;

  /// No description provided for @databaseUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Die lokale Datenbank ist nicht verfügbar.'**
  String get databaseUnavailable;

  /// No description provided for @dataLoadError.
  ///
  /// In de, this message translates to:
  /// **'Diese Daten konnten nicht geladen werden.'**
  String get dataLoadError;

  /// No description provided for @setupSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Richte dein lokales Buchhaltungsprofil ein.'**
  String get setupSubtitle;

  /// No description provided for @setupStep.
  ///
  /// In de, this message translates to:
  /// **'Schritt'**
  String get setupStep;

  /// No description provided for @setupCompanyName.
  ///
  /// In de, this message translates to:
  /// **'Firmenname'**
  String get setupCompanyName;

  /// No description provided for @setupCompanyNameHint.
  ///
  /// In de, this message translates to:
  /// **'Gib den rechtlichen Namen deines Unternehmens ein.'**
  String get setupCompanyNameHint;

  /// No description provided for @setupIban.
  ///
  /// In de, this message translates to:
  /// **'IBAN'**
  String get setupIban;

  /// No description provided for @setupIbanHint.
  ///
  /// In de, this message translates to:
  /// **'Optionales Bankkonto für den Eröffnungssaldo.'**
  String get setupIbanHint;

  /// No description provided for @setupCashBalance.
  ///
  /// In de, this message translates to:
  /// **'Kassenbestand'**
  String get setupCashBalance;

  /// No description provided for @setupCashBalanceHint.
  ///
  /// In de, this message translates to:
  /// **'Gib den aktuellen Kassenbestand ein.'**
  String get setupCashBalanceHint;

  /// No description provided for @setupCategories.
  ///
  /// In de, this message translates to:
  /// **'Kategorien'**
  String get setupCategories;

  /// No description provided for @setupCategoriesHint.
  ///
  /// In de, this message translates to:
  /// **'Wähle die Kategorien, die du am häufigsten nutzt.'**
  String get setupCategoriesHint;

  /// No description provided for @setupRequired.
  ///
  /// In de, this message translates to:
  /// **'Bitte fülle die Pflichtfelder aus.'**
  String get setupRequired;

  /// No description provided for @setupInvalidIban.
  ///
  /// In de, this message translates to:
  /// **'Gib eine gültige IBAN ein oder lasse das Feld leer.'**
  String get setupInvalidIban;

  /// No description provided for @setupDatabaseError.
  ///
  /// In de, this message translates to:
  /// **'Das Profil konnte nicht gespeichert werden.'**
  String get setupDatabaseError;

  /// No description provided for @setupRetry.
  ///
  /// In de, this message translates to:
  /// **'Einrichtung wiederholen'**
  String get setupRetry;

  /// No description provided for @setupComplete.
  ///
  /// In de, this message translates to:
  /// **'Einrichtung abgeschlossen'**
  String get setupComplete;

  /// No description provided for @setupSaving.
  ///
  /// In de, this message translates to:
  /// **'Profil wird gespeichert…'**
  String get setupSaving;

  /// No description provided for @setupSaved.
  ///
  /// In de, this message translates to:
  /// **'Profil gespeichert.'**
  String get setupSaved;

  /// No description provided for @setupSkipConfirm.
  ///
  /// In de, this message translates to:
  /// **'Einrichtung jetzt überspringen?'**
  String get setupSkipConfirm;

  /// No description provided for @inventoryTitle.
  ///
  /// In de, this message translates to:
  /// **'Lager'**
  String get inventoryTitle;

  /// No description provided for @inventoryUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Die Lagerverwaltung ist noch nicht verfügbar.'**
  String get inventoryUnavailable;

  /// No description provided for @inventoryUnavailableDescription.
  ///
  /// In de, this message translates to:
  /// **'Die Lagerverwaltung ist für dieses Profil nicht verfügbar.'**
  String get inventoryUnavailableDescription;

  /// No description provided for @inventoryReadOnly.
  ///
  /// In de, this message translates to:
  /// **'Nur lesen'**
  String get inventoryReadOnly;

  /// No description provided for @inventoryRetry.
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get inventoryRetry;

  /// No description provided for @inventoryBack.
  ///
  /// In de, this message translates to:
  /// **'Zur Übersicht'**
  String get inventoryBack;

  /// No description provided for @pdfInvoice.
  ///
  /// In de, this message translates to:
  /// **'Rechnung'**
  String get pdfInvoice;

  /// No description provided for @pdfCreditNote.
  ///
  /// In de, this message translates to:
  /// **'Gutschrift'**
  String get pdfCreditNote;

  /// No description provided for @pdfStorno.
  ///
  /// In de, this message translates to:
  /// **'Stornorechnung'**
  String get pdfStorno;

  /// No description provided for @pdfQuote.
  ///
  /// In de, this message translates to:
  /// **'Angebot'**
  String get pdfQuote;

  /// No description provided for @pdfOrder.
  ///
  /// In de, this message translates to:
  /// **'Auftrag'**
  String get pdfOrder;

  /// No description provided for @pdfProforma.
  ///
  /// In de, this message translates to:
  /// **'Proforma-Rechnung'**
  String get pdfProforma;

  /// No description provided for @pdfDelivery.
  ///
  /// In de, this message translates to:
  /// **'Lieferschein'**
  String get pdfDelivery;

  /// No description provided for @pdfOriginalInvoice.
  ///
  /// In de, this message translates to:
  /// **'Ursprüngliche Rechnung'**
  String get pdfOriginalInvoice;

  /// No description provided for @pdfDate.
  ///
  /// In de, this message translates to:
  /// **'Datum'**
  String get pdfDate;

  /// No description provided for @pdfInvoiceDate.
  ///
  /// In de, this message translates to:
  /// **'Rechnungsdatum'**
  String get pdfInvoiceDate;

  /// No description provided for @pdfDueSince.
  ///
  /// In de, this message translates to:
  /// **'Fällig seit'**
  String get pdfDueSince;

  /// No description provided for @pdfValidUntil.
  ///
  /// In de, this message translates to:
  /// **'Gültig bis'**
  String get pdfValidUntil;

  /// No description provided for @pdfCustomerNumber.
  ///
  /// In de, this message translates to:
  /// **'Kundennummer'**
  String get pdfCustomerNumber;

  /// No description provided for @pdfNet.
  ///
  /// In de, this message translates to:
  /// **'Netto'**
  String get pdfNet;

  /// No description provided for @pdfTax.
  ///
  /// In de, this message translates to:
  /// **'USt'**
  String get pdfTax;

  /// No description provided for @pdfTotal.
  ///
  /// In de, this message translates to:
  /// **'Gesamt'**
  String get pdfTotal;

  /// No description provided for @pdfPayment.
  ///
  /// In de, this message translates to:
  /// **'Zahlung'**
  String get pdfPayment;

  /// No description provided for @pdfReminder.
  ///
  /// In de, this message translates to:
  /// **'Mahnung'**
  String get pdfReminder;

  /// No description provided for @pdfUnknown.
  ///
  /// In de, this message translates to:
  /// **'—'**
  String get pdfUnknown;

  /// No description provided for @pdfPage.
  ///
  /// In de, this message translates to:
  /// **'Seite'**
  String get pdfPage;

  /// No description provided for @a11yNavigation.
  ///
  /// In de, this message translates to:
  /// **'Navigation'**
  String get a11yNavigation;

  /// No description provided for @a11yOpenMenu.
  ///
  /// In de, this message translates to:
  /// **'Menü öffnen'**
  String get a11yOpenMenu;

  /// No description provided for @a11yCloseMenu.
  ///
  /// In de, this message translates to:
  /// **'Menü schließen'**
  String get a11yCloseMenu;

  /// No description provided for @a11yAmountHidden.
  ///
  /// In de, this message translates to:
  /// **'Betrag verborgen'**
  String get a11yAmountHidden;

  /// No description provided for @pdfPhone.
  ///
  /// In de, this message translates to:
  /// **'Telefon'**
  String get pdfPhone;

  /// No description provided for @pdfEmail.
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get pdfEmail;

  /// No description provided for @pdfTaxNumber.
  ///
  /// In de, this message translates to:
  /// **'Steuernummer'**
  String get pdfTaxNumber;

  /// No description provided for @pdfVatId.
  ///
  /// In de, this message translates to:
  /// **'USt-IdNr.'**
  String get pdfVatId;

  /// No description provided for @pdfTo.
  ///
  /// In de, this message translates to:
  /// **'Rechnung an'**
  String get pdfTo;

  /// No description provided for @pdfInvoiceNumber.
  ///
  /// In de, this message translates to:
  /// **'Rechnungsnummer'**
  String get pdfInvoiceNumber;

  /// No description provided for @pdfOrderStatus.
  ///
  /// In de, this message translates to:
  /// **'Auftragsstatus'**
  String get pdfOrderStatus;

  /// No description provided for @pdfNoVat.
  ///
  /// In de, this message translates to:
  /// **'Gemäß §19 UStG wird keine Umsatzsteuer berechnet'**
  String get pdfNoVat;

  /// No description provided for @pdfPosition.
  ///
  /// In de, this message translates to:
  /// **'Pos.'**
  String get pdfPosition;

  /// No description provided for @pdfDescription.
  ///
  /// In de, this message translates to:
  /// **'Beschreibung'**
  String get pdfDescription;

  /// No description provided for @pdfQuantity.
  ///
  /// In de, this message translates to:
  /// **'Menge'**
  String get pdfQuantity;

  /// No description provided for @pdfUnitPrice.
  ///
  /// In de, this message translates to:
  /// **'Einzelpreis'**
  String get pdfUnitPrice;

  /// No description provided for @pdfDiscount.
  ///
  /// In de, this message translates to:
  /// **'Rabatt'**
  String get pdfDiscount;

  /// No description provided for @pdfGross.
  ///
  /// In de, this message translates to:
  /// **'Brutto'**
  String get pdfGross;

  /// No description provided for @pdfVatRate.
  ///
  /// In de, this message translates to:
  /// **'USt-Satz'**
  String get pdfVatRate;

  /// No description provided for @pdfSubtotal.
  ///
  /// In de, this message translates to:
  /// **'Zwischensumme'**
  String get pdfSubtotal;

  /// No description provided for @pdfDiscountAmount.
  ///
  /// In de, this message translates to:
  /// **'Rabatt'**
  String get pdfDiscountAmount;

  /// No description provided for @pdfGrossTotal.
  ///
  /// In de, this message translates to:
  /// **'Gesamtbetrag'**
  String get pdfGrossTotal;

  /// No description provided for @pdfPaymentDetails.
  ///
  /// In de, this message translates to:
  /// **'Zahlungsdaten'**
  String get pdfPaymentDetails;

  /// No description provided for @pdfIban.
  ///
  /// In de, this message translates to:
  /// **'IBAN'**
  String get pdfIban;

  /// No description provided for @pdfBic.
  ///
  /// In de, this message translates to:
  /// **'BIC'**
  String get pdfBic;

  /// No description provided for @pdfBank.
  ///
  /// In de, this message translates to:
  /// **'Bank'**
  String get pdfBank;

  /// No description provided for @setupWizardTitle.
  ///
  /// In de, this message translates to:
  /// **'Setup Wizard'**
  String get setupWizardTitle;

  /// No description provided for @setupStepCompany.
  ///
  /// In de, this message translates to:
  /// **'Stammdaten'**
  String get setupStepCompany;

  /// No description provided for @setupStepAccounts.
  ///
  /// In de, this message translates to:
  /// **'Konten'**
  String get setupStepAccounts;

  /// No description provided for @setupStepCategories.
  ///
  /// In de, this message translates to:
  /// **'Kategorien'**
  String get setupStepCategories;

  /// No description provided for @setupStepCompletion.
  ///
  /// In de, this message translates to:
  /// **'Abschluss'**
  String get setupStepCompletion;

  /// No description provided for @profileSelectionTitle.
  ///
  /// In de, this message translates to:
  /// **'Profil wählen'**
  String get profileSelectionTitle;

  /// No description provided for @profileLastUsed.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt verwendet'**
  String get profileLastUsed;

  /// No description provided for @dashboardLoadError.
  ///
  /// In de, this message translates to:
  /// **'Fehler beim Laden'**
  String get dashboardLoadError;

  /// No description provided for @dashboardInventoryWarning.
  ///
  /// In de, this message translates to:
  /// **'Lagerwarnung'**
  String get dashboardInventoryWarning;

  /// No description provided for @dashboardInventoryStock.
  ///
  /// In de, this message translates to:
  /// **'Lagerbestand'**
  String get dashboardInventoryStock;

  /// No description provided for @actionChooseFile.
  ///
  /// In de, this message translates to:
  /// **'Datei auswählen'**
  String get actionChooseFile;

  /// No description provided for @actionPreview.
  ///
  /// In de, this message translates to:
  /// **'Vorschau'**
  String get actionPreview;

  /// No description provided for @actionHistory.
  ///
  /// In de, this message translates to:
  /// **'Verlauf'**
  String get actionHistory;

  /// No description provided for @actionImport.
  ///
  /// In de, this message translates to:
  /// **'Importieren'**
  String get actionImport;

  /// Detail header for a receipt record.
  ///
  /// In de, this message translates to:
  /// **'Beleg {id}'**
  String receiptDetailTitle(String id);

  /// No description provided for @actionFilter.
  ///
  /// In de, this message translates to:
  /// **'Filter'**
  String get actionFilter;

  /// No description provided for @actionRemoveFilter.
  ///
  /// In de, this message translates to:
  /// **'Filter entfernen'**
  String get actionRemoveFilter;

  /// No description provided for @actionResetFilters.
  ///
  /// In de, this message translates to:
  /// **'Filter zurücksetzen'**
  String get actionResetFilters;

  /// No description provided for @headerViews.
  ///
  /// In de, this message translates to:
  /// **'Ansichten'**
  String get headerViews;

  /// No description provided for @countResultSingular.
  ///
  /// In de, this message translates to:
  /// **'Ergebnis'**
  String get countResultSingular;

  /// Localized copy for journalDetailTitle.
  ///
  /// In de, this message translates to:
  /// **'Buchung {id}'**
  String journalDetailTitle(String id);

  /// Localized copy for filterTypeLabel.
  ///
  /// In de, this message translates to:
  /// **'Typ: {value}'**
  String filterTypeLabel(String value);

  /// Localized copy for filterStatusLabel.
  ///
  /// In de, this message translates to:
  /// **'Status: {value}'**
  String filterStatusLabel(String value);

  /// No description provided for @draftDiscardTitle.
  ///
  /// In de, this message translates to:
  /// **'Entwurf verwerfen?'**
  String get draftDiscardTitle;

  /// No description provided for @draftDiscardMessage.
  ///
  /// In de, this message translates to:
  /// **'Die eingegebenen Rechnungsdaten gehen verloren.'**
  String get draftDiscardMessage;

  /// No description provided for @actionKeepEditing.
  ///
  /// In de, this message translates to:
  /// **'Weiter bearbeiten'**
  String get actionKeepEditing;

  /// No description provided for @actionDiscard.
  ///
  /// In de, this message translates to:
  /// **'Verwerfen'**
  String get actionDiscard;

  /// Localized copy for draftSaveFailed.
  ///
  /// In de, this message translates to:
  /// **'Entwurf konnte nicht gespeichert werden: {error}'**
  String draftSaveFailed(String error);

  /// No description provided for @errorDateFormat.
  ///
  /// In de, this message translates to:
  /// **'Datum im Format JJJJ-MM-TT eingeben'**
  String get errorDateFormat;

  /// Localized copy for errorPositiveAmount.
  ///
  /// In de, this message translates to:
  /// **'{label} muss größer als 0 sein'**
  String errorPositiveAmount(String label);

  /// No description provided for @customersLoading.
  ///
  /// In de, this message translates to:
  /// **'Kunden werden geladen …'**
  String get customersLoading;

  /// No description provided for @customersLoadFailed.
  ///
  /// In de, this message translates to:
  /// **'Kunden konnten nicht geladen werden'**
  String get customersLoadFailed;

  /// No description provided for @actionReload.
  ///
  /// In de, this message translates to:
  /// **'Erneut laden'**
  String get actionReload;

  /// No description provided for @invoiceDraftNoCustomerTitle.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Kunde angelegt'**
  String get invoiceDraftNoCustomerTitle;

  /// No description provided for @invoiceDraftNoCustomerMessage.
  ///
  /// In de, this message translates to:
  /// **'Eine Rechnung braucht einen Kunden, damit sie korrekt zugeordnet werden kann.'**
  String get invoiceDraftNoCustomerMessage;

  /// No description provided for @actionCreateCustomer.
  ///
  /// In de, this message translates to:
  /// **'Kunde anlegen'**
  String get actionCreateCustomer;

  /// No description provided for @invoiceDraftCustomerLabel.
  ///
  /// In de, this message translates to:
  /// **'Kunde'**
  String get invoiceDraftCustomerLabel;

  /// No description provided for @invoiceDraftCustomerHint.
  ///
  /// In de, this message translates to:
  /// **'Kunde auswählen'**
  String get invoiceDraftCustomerHint;

  /// No description provided for @errorCustomerRequired.
  ///
  /// In de, this message translates to:
  /// **'Kunde ist erforderlich'**
  String get errorCustomerRequired;

  /// No description provided for @invoiceDraftTitle.
  ///
  /// In de, this message translates to:
  /// **'Rechnungsentwurf'**
  String get invoiceDraftTitle;

  /// No description provided for @invoiceDraftDescription.
  ///
  /// In de, this message translates to:
  /// **'Speichere eine Rechnungsposition als Entwurf.'**
  String get invoiceDraftDescription;

  /// No description provided for @invoiceDraftPositionLabel.
  ///
  /// In de, this message translates to:
  /// **'Position'**
  String get invoiceDraftPositionLabel;

  /// No description provided for @errorPositionRequired.
  ///
  /// In de, this message translates to:
  /// **'Position ist erforderlich'**
  String get errorPositionRequired;

  /// No description provided for @invoiceDraftUnitPriceLabel.
  ///
  /// In de, this message translates to:
  /// **'Einzelpreis netto'**
  String get invoiceDraftUnitPriceLabel;

  /// No description provided for @actionSaveDraft.
  ///
  /// In de, this message translates to:
  /// **'Entwurf speichern'**
  String get actionSaveDraft;

  /// No description provided for @errorInvoiceIdInvalid.
  ///
  /// In de, this message translates to:
  /// **'Die Rechnungs-ID ist ungültig.'**
  String get errorInvoiceIdInvalid;

  /// Localized copy for contactDetailTitle.
  ///
  /// In de, this message translates to:
  /// **'Kontakt {id}'**
  String contactDetailTitle(String id);

  /// No description provided for @profileSavedRestartHint.
  ///
  /// In de, this message translates to:
  /// **'Profil gespeichert. Bitte OpenAccounting neu starten.'**
  String get profileSavedRestartHint;

  /// No description provided for @profileAlreadyActive.
  ///
  /// In de, this message translates to:
  /// **'Profil ist bereits aktiv.'**
  String get profileAlreadyActive;

  /// Localized copy for profileSelectFailed.
  ///
  /// In de, this message translates to:
  /// **'Profil konnte nicht gewählt werden: {error}'**
  String profileSelectFailed(String error);

  /// No description provided for @profileCreateTitle.
  ///
  /// In de, this message translates to:
  /// **'Neues Profil'**
  String get profileCreateTitle;

  /// No description provided for @profileNameLabel.
  ///
  /// In de, this message translates to:
  /// **'Profilname'**
  String get profileNameLabel;

  /// No description provided for @actionCreate.
  ///
  /// In de, this message translates to:
  /// **'Anlegen'**
  String get actionCreate;

  /// No description provided for @profileCreated.
  ///
  /// In de, this message translates to:
  /// **'Profil angelegt.'**
  String get profileCreated;

  /// Localized copy for profileCreateFailed.
  ///
  /// In de, this message translates to:
  /// **'Profil konnte nicht angelegt werden: {error}'**
  String profileCreateFailed(String error);

  /// No description provided for @errorRecordIdInvalid.
  ///
  /// In de, this message translates to:
  /// **'Die Datensatz-ID ist ungültig.'**
  String get errorRecordIdInvalid;

  /// Localized copy for errorRecordNotFound.
  ///
  /// In de, this message translates to:
  /// **'Der Datensatz mit der ID {id} wurde nicht gefunden.'**
  String errorRecordNotFound(String id);

  /// Localized copy for recordIdLabel.
  ///
  /// In de, this message translates to:
  /// **'Datensatz-ID {id}'**
  String recordIdLabel(String id);

  /// Localized copy for recordFallbackTitle.
  ///
  /// In de, this message translates to:
  /// **'Datensatz #{id}'**
  String recordFallbackTitle(String id);

  /// Localized copy for routeErrorSource.
  ///
  /// In de, this message translates to:
  /// **'Vorgang: {source}'**
  String routeErrorSource(String source);

  /// No description provided for @bankCategoriesLoadFailed.
  ///
  /// In de, this message translates to:
  /// **'Kategorien konnten nicht geladen werden. Manuelle Kategorisierung ist derzeit nicht verfügbar.'**
  String get bankCategoriesLoadFailed;

  /// No description provided for @bankHistoryLoadFailed.
  ///
  /// In de, this message translates to:
  /// **'Importverlauf konnte nicht geladen werden.'**
  String get bankHistoryLoadFailed;

  /// No description provided for @bankUnsupportedFile.
  ///
  /// In de, this message translates to:
  /// **'Dieses Dateiformat wird nicht unterstützt. Unterstützt werden CSV und CAMT.053 XML.'**
  String get bankUnsupportedFile;

  /// Localized copy for bankFileReadFailed.
  ///
  /// In de, this message translates to:
  /// **'Die Datei konnte nicht gelesen werden: {error}'**
  String bankFileReadFailed(String error);

  /// No description provided for @bankFileTooLarge.
  ///
  /// In de, this message translates to:
  /// **'Die Datei ist größer als 20 MB. Exportiere einen kleineren Zeitraum und versuche es erneut.'**
  String get bankFileTooLarge;

  /// No description provided for @bankPasteTitle.
  ///
  /// In de, this message translates to:
  /// **'CSV-Daten einfügen'**
  String get bankPasteTitle;

  /// No description provided for @bankPasteContentLabel.
  ///
  /// In de, this message translates to:
  /// **'CSV-Inhalt'**
  String get bankPasteContentLabel;

  /// No description provided for @bankPasteHint.
  ///
  /// In de, this message translates to:
  /// **'Datum;Betrag;Verwendungszweck;Partner'**
  String get bankPasteHint;

  /// No description provided for @actionApply.
  ///
  /// In de, this message translates to:
  /// **'Übernehmen'**
  String get actionApply;

  /// No description provided for @bankPasteFileName.
  ///
  /// In de, this message translates to:
  /// **'eingefügter-import.csv'**
  String get bankPasteFileName;

  /// Localized copy for bankFileProcessFailed.
  ///
  /// In de, this message translates to:
  /// **'Die Datei konnte nicht verarbeitet werden: {error}'**
  String bankFileProcessFailed(String error);

  /// No description provided for @bankConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'Import bestätigen'**
  String get bankConfirmTitle;

  /// Localized copy for bankConfirmMessage.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{{count} ausgewählte Zeile} other{{count} ausgewählte Zeilen}} werden in {account} importiert. Duplikate werden standardmäßig übersprungen.'**
  String bankConfirmMessage(int count, String account);

  /// No description provided for @bankBackToReview.
  ///
  /// In de, this message translates to:
  /// **'Zurück zur Prüfung'**
  String get bankBackToReview;

  /// Localized copy for bankImportIncomplete.
  ///
  /// In de, this message translates to:
  /// **'Der Import wurde nicht vollständig abgeschlossen: {error}'**
  String bankImportIncomplete(String error);

  /// No description provided for @bankRetryNotice.
  ///
  /// In de, this message translates to:
  /// **'Nur die nicht gespeicherten Zeilen werden erneut geprüft. Bereits importierte Zeilen bleiben dedupliziert.'**
  String get bankRetryNotice;

  /// Localized copy for bankImportAborted.
  ///
  /// In de, this message translates to:
  /// **'Import abgebrochen: {diagnostic} Keine Transaktion wurde gespeichert.'**
  String bankImportAborted(String diagnostic);

  /// No description provided for @bankImportAbortedHint.
  ///
  /// In de, this message translates to:
  /// **'Korrigiere die Datei oder wähle ein passendes Template und versuche es erneut.'**
  String get bankImportAbortedHint;

  /// No description provided for @bankStatusRejected.
  ///
  /// In de, this message translates to:
  /// **'Abgelehnt'**
  String get bankStatusRejected;

  /// No description provided for @bankStepChooseFile.
  ///
  /// In de, this message translates to:
  /// **'1. Datei auswählen'**
  String get bankStepChooseFile;

  /// No description provided for @bankUploadHint.
  ///
  /// In de, this message translates to:
  /// **'Unterstützt werden CSV-Dateien und CAMT.053 XML-Exporte. Die Vorschau schreibt noch nichts in die Datenbank.'**
  String get bankUploadHint;

  /// No description provided for @bankPathLabel.
  ///
  /// In de, this message translates to:
  /// **'Dateipfad'**
  String get bankPathLabel;

  /// No description provided for @bankPathHint.
  ///
  /// In de, this message translates to:
  /// **'Datei wählen oder Pfad einfügen; Drag & Drop unterstützt'**
  String get bankPathHint;

  /// No description provided for @bankStepAccountTemplate.
  ///
  /// In de, this message translates to:
  /// **'2. Konto und Template'**
  String get bankStepAccountTemplate;

  /// No description provided for @bankNoAccountYet.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Bankkonto vorhanden. Lege zuerst ein Konto in den Stammdaten an; ein Import ohne Konto ist gesperrt.'**
  String get bankNoAccountYet;

  /// No description provided for @bankCamtHint.
  ///
  /// In de, this message translates to:
  /// **'CAMT.053 wird anhand der XML-Struktur erkannt; ein CSV-Template ist dafür nicht erforderlich.'**
  String get bankCamtHint;

  /// No description provided for @bankStepReview.
  ///
  /// In de, this message translates to:
  /// **'3. Vorschau prüfen und bearbeiten'**
  String get bankStepReview;

  /// Localized copy for bankRowsDetected.
  ///
  /// In de, this message translates to:
  /// **'{count} Zeilen erkannt'**
  String bankRowsDetected(int count);

  /// Localized copy for bankRowsSelected.
  ///
  /// In de, this message translates to:
  /// **'{count} ausgewählt'**
  String bankRowsSelected(int count);

  /// Localized copy for bankRowsManual.
  ///
  /// In de, this message translates to:
  /// **'{count} manuell kategorisiert'**
  String bankRowsManual(int count);

  /// No description provided for @bankReviewNotice.
  ///
  /// In de, this message translates to:
  /// **'Änderungen und manuelle Kategorien werden erst nach deiner ausdrücklichen Importbestätigung gespeichert.'**
  String get bankReviewNotice;

  /// No description provided for @bankDuplicateOverride.
  ///
  /// In de, this message translates to:
  /// **'Bereits importierte Duplikate erneut übernehmen (nur bewusst aktivieren)'**
  String get bankDuplicateOverride;

  /// Localized copy for bankConfirmActionCount.
  ///
  /// In de, this message translates to:
  /// **'Import bestätigen ({count})'**
  String bankConfirmActionCount(int count);

  /// No description provided for @bankColPartnerPurpose.
  ///
  /// In de, this message translates to:
  /// **'Partner / Zweck'**
  String get bankColPartnerPurpose;

  /// Localized copy for bankRowLabel.
  ///
  /// In de, this message translates to:
  /// **'Zeile {line}'**
  String bankRowLabel(int line);

  /// No description provided for @bankColPartner.
  ///
  /// In de, this message translates to:
  /// **'Partner'**
  String get bankColPartner;

  /// No description provided for @bankColPurpose.
  ///
  /// In de, this message translates to:
  /// **'Verwendungszweck'**
  String get bankColPurpose;

  /// No description provided for @bankStepResult.
  ///
  /// In de, this message translates to:
  /// **'4. Importergebnis'**
  String get bankStepResult;

  /// No description provided for @bankStatImported.
  ///
  /// In de, this message translates to:
  /// **'Importiert'**
  String get bankStatImported;

  /// No description provided for @bankStatDuplicatesSkipped.
  ///
  /// In de, this message translates to:
  /// **'Duplikate übersprungen'**
  String get bankStatDuplicatesSkipped;

  /// No description provided for @bankStatCategorized.
  ///
  /// In de, this message translates to:
  /// **'Kategorisiert'**
  String get bankStatCategorized;

  /// No description provided for @bankStatManualReview.
  ///
  /// In de, this message translates to:
  /// **'Manuelle Prüfung'**
  String get bankStatManualReview;

  /// No description provided for @bankStatFailed.
  ///
  /// In de, this message translates to:
  /// **'Fehlgeschlagen'**
  String get bankStatFailed;

  /// No description provided for @bankResultAllSaved.
  ///
  /// In de, this message translates to:
  /// **'Alle bestätigten neuen Zeilen wurden gespeichert. Der Import ist im Verlauf dokumentiert.'**
  String get bankResultAllSaved;

  /// No description provided for @bankRetryFailedRows.
  ///
  /// In de, this message translates to:
  /// **'Fehlgeschlagene Zeilen erneut prüfen'**
  String get bankRetryFailedRows;

  /// No description provided for @bankFailureRowsGeneric.
  ///
  /// In de, this message translates to:
  /// **'Die Datenbank meldete nicht gespeicherte Zeilen, konnte aber keinen einzelnen Zeilenfehler zurückgeben. Prüfe Konto, Datum und Betrag; ein erneuter Versuch bleibt dedupliziert.'**
  String get bankFailureRowsGeneric;

  /// No description provided for @bankNotSavedFix.
  ///
  /// In de, this message translates to:
  /// **'Nicht gespeichert — bitte korrigieren und erneut prüfen:'**
  String get bankNotSavedFix;

  /// Localized copy for bankFailureRowPrefix.
  ///
  /// In de, this message translates to:
  /// **'Zeile {line}: {error}'**
  String bankFailureRowPrefix(int line, String error);

  /// No description provided for @bankWithoutPartner.
  ///
  /// In de, this message translates to:
  /// **'ohne Partner'**
  String get bankWithoutPartner;

  /// No description provided for @bankWithoutPurpose.
  ///
  /// In de, this message translates to:
  /// **'ohne Verwendungszweck'**
  String get bankWithoutPurpose;

  /// No description provided for @bankHistoryTitle.
  ///
  /// In de, this message translates to:
  /// **'Importverlauf'**
  String get bankHistoryTitle;

  /// No description provided for @bankHistoryCardSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Quelle, Template, Mengen und Ergebnisstatus bleiben hier nachvollziehbar.'**
  String get bankHistoryCardSubtitle;

  /// No description provided for @bankHistoryRefresh.
  ///
  /// In de, this message translates to:
  /// **'Importverlauf aktualisieren'**
  String get bankHistoryRefresh;

  /// No description provided for @bankColTime.
  ///
  /// In de, this message translates to:
  /// **'Zeitpunkt'**
  String get bankColTime;

  /// No description provided for @bankColSource.
  ///
  /// In de, this message translates to:
  /// **'Quelle'**
  String get bankColSource;

  /// No description provided for @bankColTemplate.
  ///
  /// In de, this message translates to:
  /// **'Template'**
  String get bankColTemplate;

  /// No description provided for @bankColAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto'**
  String get bankColAccount;

  /// No description provided for @bankColImported.
  ///
  /// In de, this message translates to:
  /// **'Importiert'**
  String get bankColImported;

  /// No description provided for @bankColDuplicates.
  ///
  /// In de, this message translates to:
  /// **'Duplikate'**
  String get bankColDuplicates;

  /// No description provided for @bankColError.
  ///
  /// In de, this message translates to:
  /// **'Fehler'**
  String get bankColError;

  /// No description provided for @bankColStatus.
  ///
  /// In de, this message translates to:
  /// **'Status'**
  String get bankColStatus;

  /// No description provided for @bankStageFile.
  ///
  /// In de, this message translates to:
  /// **'Datei'**
  String get bankStageFile;

  /// No description provided for @bankStageReview.
  ///
  /// In de, this message translates to:
  /// **'Prüfen'**
  String get bankStageReview;

  /// No description provided for @bankStageResult.
  ///
  /// In de, this message translates to:
  /// **'Ergebnis'**
  String get bankStageResult;

  /// No description provided for @bankStageCurrent.
  ///
  /// In de, this message translates to:
  /// **'aktuell'**
  String get bankStageCurrent;

  /// No description provided for @bankStageComplete.
  ///
  /// In de, this message translates to:
  /// **'abgeschlossen'**
  String get bankStageComplete;

  /// No description provided for @bankStageOpen.
  ///
  /// In de, this message translates to:
  /// **'offen'**
  String get bankStageOpen;

  /// Localized copy for bankReady.
  ///
  /// In de, this message translates to:
  /// **'Bereit: {name} · {size}'**
  String bankReady(String name, String size);

  /// No description provided for @bankDelimiterSemicolon.
  ///
  /// In de, this message translates to:
  /// **'Semikolon'**
  String get bankDelimiterSemicolon;

  /// No description provided for @bankDelimiterComma.
  ///
  /// In de, this message translates to:
  /// **'Komma'**
  String get bankDelimiterComma;

  /// No description provided for @bankHeaderSubtitleHistory.
  ///
  /// In de, this message translates to:
  /// **'Nachvollziehbarer Importverlauf'**
  String get bankHeaderSubtitleHistory;

  /// No description provided for @bankHeaderSubtitleImport.
  ///
  /// In de, this message translates to:
  /// **'Dateiimport mit Prüfung vor dem Speichern'**
  String get bankHeaderSubtitleImport;

  /// No description provided for @bankNoAccountSelected.
  ///
  /// In de, this message translates to:
  /// **'kein Konto'**
  String get bankNoAccountSelected;

  /// Localized copy for bankAccountFallback.
  ///
  /// In de, this message translates to:
  /// **'Konto {id}'**
  String bankAccountFallback(String id);

  /// Localized copy for bankCategoryFallback.
  ///
  /// In de, this message translates to:
  /// **'Kategorie {id}'**
  String bankCategoryFallback(String id);

  /// No description provided for @bankUnknownFile.
  ///
  /// In de, this message translates to:
  /// **'Unbekannte Datei'**
  String get bankUnknownFile;

  /// No description provided for @bankStatusPartial.
  ///
  /// In de, this message translates to:
  /// **'Teilweise importiert'**
  String get bankStatusPartial;

  /// No description provided for @bankStatusFailed.
  ///
  /// In de, this message translates to:
  /// **'Import fehlgeschlagen'**
  String get bankStatusFailed;

  /// No description provided for @bankStatusImported.
  ///
  /// In de, this message translates to:
  /// **'Importiert'**
  String get bankStatusImported;

  /// No description provided for @bankInvalidImportNoDiagnostic.
  ///
  /// In de, this message translates to:
  /// **'Ungültiger Import: Es wurde keine Fehlerdiagnose angegeben.'**
  String get bankInvalidImportNoDiagnostic;

  /// No description provided for @bankRecoveryCheckFileTemplate.
  ///
  /// In de, this message translates to:
  /// **'Prüfe Datei und Template und versuche es erneut.'**
  String get bankRecoveryCheckFileTemplate;

  /// No description provided for @bankInvalidImportNoAccount.
  ///
  /// In de, this message translates to:
  /// **'Ungültiger Import: Kein gültiges Bankkonto ausgewählt.'**
  String get bankInvalidImportNoAccount;

  /// No description provided for @bankRecoverySelectAccount.
  ///
  /// In de, this message translates to:
  /// **'Wähle ein gültiges Bankkonto und versuche es erneut.'**
  String get bankRecoverySelectAccount;

  /// No description provided for @bankNoTransactionsToImport.
  ///
  /// In de, this message translates to:
  /// **'Keine Transaktionen zum Importieren.'**
  String get bankNoTransactionsToImport;

  /// No description provided for @bankRecoverySelectSupportedFile.
  ///
  /// In de, this message translates to:
  /// **'Wähle eine unterstützte Datei mit mindestens einer Transaktion.'**
  String get bankRecoverySelectSupportedFile;

  /// No description provided for @bankHistoryNotFinalSaved.
  ///
  /// In de, this message translates to:
  /// **'Importhistorie konnte nicht abschließend gespeichert werden.'**
  String get bankHistoryNotFinalSaved;

  /// Localized copy for bankHistoryCreateFailed.
  ///
  /// In de, this message translates to:
  /// **'Importhistorie konnte nicht angelegt werden: {error}'**
  String bankHistoryCreateFailed(String error);

  /// No description provided for @bankRecoveryFixDatabase.
  ///
  /// In de, this message translates to:
  /// **'Behebe das Datenbankproblem und versuche es erneut.'**
  String get bankRecoveryFixDatabase;

  /// No description provided for @bankRecoveryCheckDuplicates.
  ///
  /// In de, this message translates to:
  /// **'Prüfe die vorhandenen Duplikate und versuche es erneut.'**
  String get bankRecoveryCheckDuplicates;

  /// No description provided for @bankUnknownError.
  ///
  /// In de, this message translates to:
  /// **'Unbekannter Fehler'**
  String get bankUnknownError;

  /// No description provided for @bankInvalidDate.
  ///
  /// In de, this message translates to:
  /// **'Datum ungültig'**
  String get bankInvalidDate;

  /// No description provided for @bankInvalidAmount.
  ///
  /// In de, this message translates to:
  /// **'Betrag ungültig'**
  String get bankInvalidAmount;

  /// No description provided for @bankCsvUnclosedQuotes.
  ///
  /// In de, this message translates to:
  /// **'Ungültige CSV: Anführungszeichen nicht geschlossen'**
  String get bankCsvUnclosedQuotes;

  /// Localized copy for bankCsvRowSuffix.
  ///
  /// In de, this message translates to:
  /// **' in Zeile {row}'**
  String bankCsvRowSuffix(int row);

  /// No description provided for @bankRecoveryFixCsvRow.
  ///
  /// In de, this message translates to:
  /// **'Korrigiere die CSV-Zeile und versuche den Import erneut.'**
  String get bankRecoveryFixCsvRow;

  /// No description provided for @bankNoTransactionsFound.
  ///
  /// In de, this message translates to:
  /// **'Keine Transaktionen gefunden'**
  String get bankNoTransactionsFound;

  /// No description provided for @bankNoTemplateFound.
  ///
  /// In de, this message translates to:
  /// **'Kein passendes Template gefunden. Bitte wähle ein Template.'**
  String get bankNoTemplateFound;

  /// No description provided for @bankNoTemplateFoundNoTransactions.
  ///
  /// In de, this message translates to:
  /// **'Keine Transaktionen gefunden. Kein passendes Template gefunden. Bitte wähle ein Template.'**
  String get bankNoTemplateFoundNoTransactions;

  /// No description provided for @bankEmptyFile.
  ///
  /// In de, this message translates to:
  /// **'Datei ist leer'**
  String get bankEmptyFile;

  /// No description provided for @bankNoHeader.
  ///
  /// In de, this message translates to:
  /// **'Datei enthält keine Kopfzeile'**
  String get bankNoHeader;

  /// No description provided for @bankInvalidXmlNoTag.
  ///
  /// In de, this message translates to:
  /// **'Ungültiges XML: kein XML-Tag gefunden (invalid)'**
  String get bankInvalidXmlNoTag;

  /// No description provided for @bankInvalidXmlNoClosingTag.
  ///
  /// In de, this message translates to:
  /// **'Ungültiges XML: kein schliessendes Tag (invalid)'**
  String get bankInvalidXmlNoClosingTag;

  /// No description provided for @bankInvalidXmlDocumentUnclosed.
  ///
  /// In de, this message translates to:
  /// **'Ungültiges XML: Document nicht geschlossen (invalid)'**
  String get bankInvalidXmlDocumentUnclosed;

  /// No description provided for @bankInvalidXmlNtryUnclosed.
  ///
  /// In de, this message translates to:
  /// **'Ungültiges XML: Ntry nicht geschlossen (invalid)'**
  String get bankInvalidXmlNtryUnclosed;

  /// No description provided for @bankInvalidXmlMismatched.
  ///
  /// In de, this message translates to:
  /// **'Ungültiges XML: verschachtelte Tags stimmen nicht überein (invalid)'**
  String get bankInvalidXmlMismatched;

  /// No description provided for @bankInvalidXmlTagUnclosed.
  ///
  /// In de, this message translates to:
  /// **'Ungültiges XML: Tag nicht geschlossen (invalid)'**
  String get bankInvalidXmlTagUnclosed;

  /// No description provided for @bankAmountMissingNtry.
  ///
  /// In de, this message translates to:
  /// **'Betrag fehlt in Ntry'**
  String get bankAmountMissingNtry;

  /// No description provided for @bankDateMissingNtry.
  ///
  /// In de, this message translates to:
  /// **'Datum fehlt in Ntry'**
  String get bankDateMissingNtry;

  /// No description provided for @bankAmountMissing.
  ///
  /// In de, this message translates to:
  /// **'Betrag fehlt'**
  String get bankAmountMissing;

  /// Localized copy for bankDateInvalidRaw.
  ///
  /// In de, this message translates to:
  /// **'Datum ungültig: {raw}'**
  String bankDateInvalidRaw(String raw);

  /// Localized copy for bankAmountInvalidRaw.
  ///
  /// In de, this message translates to:
  /// **'Betrag ungültig: {raw}'**
  String bankAmountInvalidRaw(String raw);

  /// Localized copy for bankAmountOutOfRange.
  ///
  /// In de, this message translates to:
  /// **'Betrag außerhalb NUMERIC(12,2): {raw}'**
  String bankAmountOutOfRange(String raw);

  /// No description provided for @setupErrorNameRequired.
  ///
  /// In de, this message translates to:
  /// **'Name ist Pflicht'**
  String get setupErrorNameRequired;

  /// No description provided for @setupErrorAccountRequired.
  ///
  /// In de, this message translates to:
  /// **'Mindestens ein Konto erforderlich'**
  String get setupErrorAccountRequired;

  /// Localized copy for setupErrorIbanInvalid.
  ///
  /// In de, this message translates to:
  /// **'IBAN ungültig: {iban}'**
  String setupErrorIbanInvalid(String iban);

  /// No description provided for @setupErrorCashNegative.
  ///
  /// In de, this message translates to:
  /// **'Kassenbestand darf nicht negativ sein'**
  String get setupErrorCashNegative;

  /// No description provided for @setupErrorCashInvalid.
  ///
  /// In de, this message translates to:
  /// **'Kassenbestand ungültig'**
  String get setupErrorCashInvalid;

  /// No description provided for @setupErrorCategoryRequired.
  ///
  /// In de, this message translates to:
  /// **'Mindestens eine Kategorie erforderlich'**
  String get setupErrorCategoryRequired;

  /// No description provided for @setupErrorDatabaseStatus.
  ///
  /// In de, this message translates to:
  /// **'Datenbank konnte für den Setup-Status nicht gelesen werden'**
  String get setupErrorDatabaseStatus;

  /// No description provided for @dashboardCustomize.
  ///
  /// In de, this message translates to:
  /// **'Dashboard anpassen'**
  String get dashboardCustomize;

  /// No description provided for @dashboardIncome.
  ///
  /// In de, this message translates to:
  /// **'Einnahmen'**
  String get dashboardIncome;

  /// No description provided for @dashboardExpenses.
  ///
  /// In de, this message translates to:
  /// **'Ausgaben'**
  String get dashboardExpenses;

  /// No description provided for @dashboardEmptyNoWarnings.
  ///
  /// In de, this message translates to:
  /// **'Keine Warnungen'**
  String get dashboardEmptyNoWarnings;

  /// No description provided for @dashboardEmptyNoStock.
  ///
  /// In de, this message translates to:
  /// **'Kein Lagerbestand'**
  String get dashboardEmptyNoStock;

  /// No description provided for @dashboardEmptyNoReminders.
  ///
  /// In de, this message translates to:
  /// **'Keine Mahnungen'**
  String get dashboardEmptyNoReminders;

  /// No description provided for @dashboardEmptyNoDeadlines.
  ///
  /// In de, this message translates to:
  /// **'Keine Fristen'**
  String get dashboardEmptyNoDeadlines;

  /// No description provided for @dashboardEmptyNoActivities.
  ///
  /// In de, this message translates to:
  /// **'Keine Aktivitäten'**
  String get dashboardEmptyNoActivities;

  /// No description provided for @dashboardEmptyNoPayments.
  ///
  /// In de, this message translates to:
  /// **'Keine Zahlungen'**
  String get dashboardEmptyNoPayments;

  /// Localized copy for quickLinkUnavailable.
  ///
  /// In de, this message translates to:
  /// **'{label} (nicht verfügbar)'**
  String quickLinkUnavailable(String label);

  /// Localized copy for dashboardUstvaDue.
  ///
  /// In de, this message translates to:
  /// **'UStVA fällig am {date}'**
  String dashboardUstvaDue(String date);

  /// No description provided for @quickLinkJournal.
  ///
  /// In de, this message translates to:
  /// **'Journal'**
  String get quickLinkJournal;

  /// No description provided for @quickLinkItems.
  ///
  /// In de, this message translates to:
  /// **'Artikel'**
  String get quickLinkItems;

  /// No description provided for @dashboardWidgetOpenInvoices.
  ///
  /// In de, this message translates to:
  /// **'Offene Rechnungen'**
  String get dashboardWidgetOpenInvoices;

  /// No description provided for @dashboardWidgetIncomingPayments.
  ///
  /// In de, this message translates to:
  /// **'Zahlungseingänge'**
  String get dashboardWidgetIncomingPayments;

  /// No description provided for @dashboardWidgetReminderWarning.
  ///
  /// In de, this message translates to:
  /// **'Mahnung-Warnung'**
  String get dashboardWidgetReminderWarning;

  /// No description provided for @dashboardWidgetDeadlines.
  ///
  /// In de, this message translates to:
  /// **'Fristen'**
  String get dashboardWidgetDeadlines;

  /// No description provided for @dashboardWidgetUstvaDeadline.
  ///
  /// In de, this message translates to:
  /// **'UStVA-Frist'**
  String get dashboardWidgetUstvaDeadline;

  /// No description provided for @dashboardWidgetQuickLinks.
  ///
  /// In de, this message translates to:
  /// **'Schnellzugriff'**
  String get dashboardWidgetQuickLinks;

  /// No description provided for @dashboardWidgetIncomeExpenses.
  ///
  /// In de, this message translates to:
  /// **'Einnahmen/Ausgaben'**
  String get dashboardWidgetIncomeExpenses;

  /// No description provided for @dashboardWidgetOverdueInvoices.
  ///
  /// In de, this message translates to:
  /// **'Überfällige Rechnungen'**
  String get dashboardWidgetOverdueInvoices;

  /// No description provided for @dashboardWidgetOpenLiabilities.
  ///
  /// In de, this message translates to:
  /// **'Offene Verbindlichkeiten'**
  String get dashboardWidgetOpenLiabilities;

  /// No description provided for @dashboardWidgetBalance.
  ///
  /// In de, this message translates to:
  /// **'Kontostand'**
  String get dashboardWidgetBalance;

  /// No description provided for @dashboardWidgetActivityLog.
  ///
  /// In de, this message translates to:
  /// **'Aktivitäts-Log'**
  String get dashboardWidgetActivityLog;

  /// No description provided for @bankColImport.
  ///
  /// In de, this message translates to:
  /// **'Import'**
  String get bankColImport;

  /// No description provided for @bankColAmount.
  ///
  /// In de, this message translates to:
  /// **'Betrag'**
  String get bankColAmount;

  /// No description provided for @bankColCategory.
  ///
  /// In de, this message translates to:
  /// **'Kategorie'**
  String get bankColCategory;

  /// No description provided for @bankPathHintExample.
  ///
  /// In de, this message translates to:
  /// **'/Pfad/zum/Kontoauszug.csv'**
  String get bankPathHintExample;

  /// Localized copy for invoiceDraftNumber.
  ///
  /// In de, this message translates to:
  /// **'Entwurf #{number}'**
  String invoiceDraftNumber(int number);

  /// No description provided for @bankDuplicateOverrideLimit.
  ///
  /// In de, this message translates to:
  /// **'Duplicate override limit reached (100) — manual cleanup required'**
  String get bankDuplicateOverrideLimit;

  /// No description provided for @bankConfidenceHigh.
  ///
  /// In de, this message translates to:
  /// **'Hohe Übereinstimmung'**
  String get bankConfidenceHigh;

  /// No description provided for @bankConfidenceMedium.
  ///
  /// In de, this message translates to:
  /// **'Mittlere Übereinstimmung'**
  String get bankConfidenceMedium;

  /// No description provided for @bankConfidenceLow.
  ///
  /// In de, this message translates to:
  /// **'Geringe Übereinstimmung'**
  String get bankConfidenceLow;

  /// No description provided for @bankConfidenceNone.
  ///
  /// In de, this message translates to:
  /// **'Keine Übereinstimmung'**
  String get bankConfidenceNone;

  /// No description provided for @bankCandidatesUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Treffer konnten nicht geladen werden. Automatische Verknüpfung ist deaktiviert.'**
  String get bankCandidatesUnavailable;

  /// No description provided for @bankRulesTitle.
  ///
  /// In de, this message translates to:
  /// **'Regeln'**
  String get bankRulesTitle;

  /// No description provided for @bankRulePattern.
  ///
  /// In de, this message translates to:
  /// **'Muster (Verwendungszweck)'**
  String get bankRulePattern;

  /// No description provided for @bankRuleCategory.
  ///
  /// In de, this message translates to:
  /// **'Kategorie'**
  String get bankRuleCategory;

  /// No description provided for @bankRulePriority.
  ///
  /// In de, this message translates to:
  /// **'Priorität'**
  String get bankRulePriority;

  /// No description provided for @bankRuleActive.
  ///
  /// In de, this message translates to:
  /// **'Aktiv'**
  String get bankRuleActive;

  /// No description provided for @bankRuleNew.
  ///
  /// In de, this message translates to:
  /// **'Neue Regel'**
  String get bankRuleNew;

  /// No description provided for @bankRuleEdit.
  ///
  /// In de, this message translates to:
  /// **'Regel bearbeiten'**
  String get bankRuleEdit;

  /// No description provided for @bankRuleDelete.
  ///
  /// In de, this message translates to:
  /// **'Regel löschen'**
  String get bankRuleDelete;

  /// No description provided for @bankRuleSave.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get bankRuleSave;

  /// No description provided for @bankRuleCancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get bankRuleCancel;

  /// No description provided for @bankRuleEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine Regeln vorhanden. Lege eine Regel an, um Importe automatisch zu kategorisieren.'**
  String get bankRuleEmpty;

  /// No description provided for @bankRuleDisabled.
  ///
  /// In de, this message translates to:
  /// **'Deaktiviert'**
  String get bankRuleDisabled;

  /// No description provided for @bankTemplatesTitle.
  ///
  /// In de, this message translates to:
  /// **'Vorlagen'**
  String get bankTemplatesTitle;

  /// No description provided for @bankTemplateNew.
  ///
  /// In de, this message translates to:
  /// **'Eigene Vorlage'**
  String get bankTemplateNew;

  /// No description provided for @bankTemplateEdit.
  ///
  /// In de, this message translates to:
  /// **'Vorlage bearbeiten'**
  String get bankTemplateEdit;

  /// No description provided for @bankTemplateName.
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get bankTemplateName;

  /// No description provided for @bankTemplateProtected.
  ///
  /// In de, this message translates to:
  /// **'Vordefiniert – geschützt'**
  String get bankTemplateProtected;

  /// No description provided for @bankTemplateDelete.
  ///
  /// In de, this message translates to:
  /// **'Vorlage löschen'**
  String get bankTemplateDelete;

  /// No description provided for @bankModeLabel.
  ///
  /// In de, this message translates to:
  /// **'Importmodus'**
  String get bankModeLabel;

  /// No description provided for @bankModeManual.
  ///
  /// In de, this message translates to:
  /// **'Manuell'**
  String get bankModeManual;

  /// No description provided for @bankModeAutomatic.
  ///
  /// In de, this message translates to:
  /// **'Automatisch'**
  String get bankModeAutomatic;

  /// No description provided for @bankModeOverride.
  ///
  /// In de, this message translates to:
  /// **'Einmalig für diesen Import überschreiben'**
  String get bankModeOverride;

  /// No description provided for @bankScoreLabel.
  ///
  /// In de, this message translates to:
  /// **'Treffer'**
  String get bankScoreLabel;

  /// No description provided for @bankViewImport.
  ///
  /// In de, this message translates to:
  /// **'Import'**
  String get bankViewImport;

  /// No description provided for @bankViewHistory.
  ///
  /// In de, this message translates to:
  /// **'Verlauf'**
  String get bankViewHistory;

  /// No description provided for @bankViewRules.
  ///
  /// In de, this message translates to:
  /// **'Regeln'**
  String get bankViewRules;

  /// No description provided for @bankViewTemplates.
  ///
  /// In de, this message translates to:
  /// **'Vorlagen'**
  String get bankViewTemplates;

  /// No description provided for @bankHistoryDetail.
  ///
  /// In de, this message translates to:
  /// **'Details'**
  String get bankHistoryDetail;

  /// No description provided for @bankHistoryRetry.
  ///
  /// In de, this message translates to:
  /// **'Wiederholen'**
  String get bankHistoryRetry;

  /// No description provided for @bankHistoryReview.
  ///
  /// In de, this message translates to:
  /// **'Prüfen'**
  String get bankHistoryReview;

  /// No description provided for @bankHistorySearch.
  ///
  /// In de, this message translates to:
  /// **'Suchen'**
  String get bankHistorySearch;

  /// No description provided for @bankHistorySearchHint.
  ///
  /// In de, this message translates to:
  /// **'Dateiname, Vorlage oder Status suchen'**
  String get bankHistorySearchHint;

  /// No description provided for @bankHistoryEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Importe vorhanden.'**
  String get bankHistoryEmpty;

  /// No description provided for @bankHistoryImportAction.
  ///
  /// In de, this message translates to:
  /// **'Datei wählen'**
  String get bankHistoryImportAction;

  /// No description provided for @bankHistoryNextPage.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get bankHistoryNextPage;

  /// No description provided for @bankHistoryPrevPage.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get bankHistoryPrevPage;

  /// No description provided for @bankDetailImported.
  ///
  /// In de, this message translates to:
  /// **'Importiert'**
  String get bankDetailImported;

  /// No description provided for @bankDetailDuplicates.
  ///
  /// In de, this message translates to:
  /// **'Duplikate'**
  String get bankDetailDuplicates;

  /// No description provided for @bankDetailFailed.
  ///
  /// In de, this message translates to:
  /// **'Fehler'**
  String get bankDetailFailed;

  /// No description provided for @bankDetailUnresolved.
  ///
  /// In de, this message translates to:
  /// **'Offen'**
  String get bankDetailUnresolved;

  /// No description provided for @bankDetailFileRejection.
  ///
  /// In de, this message translates to:
  /// **'Dateiabweisung'**
  String get bankDetailFileRejection;

  /// No description provided for @bankDetailErrorRows.
  ///
  /// In de, this message translates to:
  /// **'fehlerhafte Zeilen'**
  String get bankDetailErrorRows;

  /// No description provided for @bankDetailSeeHistory.
  ///
  /// In de, this message translates to:
  /// **'Details in der Historie'**
  String get bankDetailSeeHistory;

  /// No description provided for @bankDiagnosticFile.
  ///
  /// In de, this message translates to:
  /// **'Datei'**
  String get bankDiagnosticFile;

  /// No description provided for @bankDiagnosticRow.
  ///
  /// In de, this message translates to:
  /// **'Zeile'**
  String get bankDiagnosticRow;

  /// No description provided for @bankDetailsUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Details nicht verfügbar'**
  String get bankDetailsUnavailable;

  /// No description provided for @incomeTaxTitle.
  ///
  /// In de, this message translates to:
  /// **'Einkommensteuer-Anlagen'**
  String get incomeTaxTitle;

  /// No description provided for @incomeTaxScheduleS.
  ///
  /// In de, this message translates to:
  /// **'Anlage S'**
  String get incomeTaxScheduleS;

  /// No description provided for @incomeTaxScheduleG.
  ///
  /// In de, this message translates to:
  /// **'Anlage G'**
  String get incomeTaxScheduleG;

  /// No description provided for @incomeTaxSelectPrompt.
  ///
  /// In de, this message translates to:
  /// **'Anlage für die Verfügbarkeitsprüfung wählen'**
  String get incomeTaxSelectPrompt;

  /// No description provided for @incomeTaxUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Noch nicht verfügbar'**
  String get incomeTaxUnavailable;

  /// No description provided for @incomeTaxBlockerForm.
  ///
  /// In de, this message translates to:
  /// **'Kein akzeptierter Formular- und Quellvertrag'**
  String get incomeTaxBlockerForm;

  /// No description provided for @incomeTaxBlockerPeriod.
  ///
  /// In de, this message translates to:
  /// **'Kein akzeptierter Zeitraumvertrag'**
  String get incomeTaxBlockerPeriod;

  /// No description provided for @incomeTaxBlockerClassification.
  ///
  /// In de, this message translates to:
  /// **'Keine akzeptierte Klassifizierung'**
  String get incomeTaxBlockerClassification;

  /// No description provided for @incomeTaxBlockerSource.
  ///
  /// In de, this message translates to:
  /// **'Keine vollständige Buchhaltungsquelle'**
  String get incomeTaxBlockerSource;

  /// No description provided for @fiscalYearTitle.
  ///
  /// In de, this message translates to:
  /// **'Geschäftsjahr'**
  String get fiscalYearTitle;

  /// No description provided for @fiscalYearStartMonth.
  ///
  /// In de, this message translates to:
  /// **'Startmonat des Geschäftsjahres'**
  String get fiscalYearStartMonth;

  /// No description provided for @fiscalYearHint.
  ///
  /// In de, this message translates to:
  /// **'Legt die Grenzen historischer und künftiger Geschäftsjahresberichte fest. Buchungen und Exporte bleiben unverändert.'**
  String get fiscalYearHint;

  /// No description provided for @fiscalYearSave.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get fiscalYearSave;

  /// No description provided for @fiscalYearSaved.
  ///
  /// In de, this message translates to:
  /// **'Geschäftsjahr gespeichert'**
  String get fiscalYearSaved;

  /// No description provided for @fiscalYearError.
  ///
  /// In de, this message translates to:
  /// **'Speichern fehlgeschlagen. Erneut versuchen.'**
  String get fiscalYearError;

  /// No description provided for @fiscalYearInvalid.
  ///
  /// In de, this message translates to:
  /// **'Monat muss zwischen 1 und 12 liegen'**
  String get fiscalYearInvalid;

  /// No description provided for @quickBookingsTitle.
  ///
  /// In de, this message translates to:
  /// **'Schnellbuchungen'**
  String get quickBookingsTitle;

  /// No description provided for @quickBookingNew.
  ///
  /// In de, this message translates to:
  /// **'Neue Schnellbuchung'**
  String get quickBookingNew;

  /// No description provided for @quickBookingEdit.
  ///
  /// In de, this message translates to:
  /// **'Schnellbuchung bearbeiten'**
  String get quickBookingEdit;

  /// No description provided for @quickBookingDelete.
  ///
  /// In de, this message translates to:
  /// **'Schnellbuchung löschen'**
  String get quickBookingDelete;

  /// No description provided for @quickBookingSave.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get quickBookingSave;

  /// No description provided for @quickBookingCancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get quickBookingCancel;

  /// No description provided for @quickBookingName.
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get quickBookingName;

  /// No description provided for @quickBookingDirection.
  ///
  /// In de, this message translates to:
  /// **'Richtung'**
  String get quickBookingDirection;

  /// No description provided for @quickBookingDirectionIn.
  ///
  /// In de, this message translates to:
  /// **'Einnahme'**
  String get quickBookingDirectionIn;

  /// No description provided for @quickBookingDirectionOut.
  ///
  /// In de, this message translates to:
  /// **'Ausgabe'**
  String get quickBookingDirectionOut;

  /// No description provided for @quickBookingAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto'**
  String get quickBookingAccount;

  /// No description provided for @quickBookingCategory.
  ///
  /// In de, this message translates to:
  /// **'Kategorie'**
  String get quickBookingCategory;

  /// No description provided for @quickBookingTaxRate.
  ///
  /// In de, this message translates to:
  /// **'Steuersatz'**
  String get quickBookingTaxRate;

  /// No description provided for @quickBookingModus.
  ///
  /// In de, this message translates to:
  /// **'Eingabemodus'**
  String get quickBookingModus;

  /// No description provided for @quickBookingModusNetto.
  ///
  /// In de, this message translates to:
  /// **'Netto'**
  String get quickBookingModusNetto;

  /// No description provided for @quickBookingModusBrutto.
  ///
  /// In de, this message translates to:
  /// **'Brutto'**
  String get quickBookingModusBrutto;

  /// No description provided for @quickBookingAmount.
  ///
  /// In de, this message translates to:
  /// **'Betrag'**
  String get quickBookingAmount;

  /// No description provided for @quickBookingDescription.
  ///
  /// In de, this message translates to:
  /// **'Beschreibung'**
  String get quickBookingDescription;

  /// No description provided for @quickBookingExecute.
  ///
  /// In de, this message translates to:
  /// **'Ausführen'**
  String get quickBookingExecute;

  /// No description provided for @quickBookingReviewRequired.
  ///
  /// In de, this message translates to:
  /// **'Prüfung erforderlich'**
  String get quickBookingReviewRequired;

  /// No description provided for @quickBookingUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Ausführung nicht verfügbar'**
  String get quickBookingUnavailable;

  /// No description provided for @quickBookingEnterAmount.
  ///
  /// In de, this message translates to:
  /// **'Betrag eingeben'**
  String get quickBookingEnterAmount;

  /// No description provided for @quickBookingEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine Schnellbuchungen vorhanden.'**
  String get quickBookingEmpty;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
