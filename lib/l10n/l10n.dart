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
