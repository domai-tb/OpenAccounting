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
