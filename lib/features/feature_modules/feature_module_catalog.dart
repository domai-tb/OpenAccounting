/// Closed, versioned module catalog (catalog version 1).
/// Exactly three maintained modules; every entry has no optional-module
/// dependency. Other legacy documentation flags stay outside until their
/// owning capability contract is accepted.
class FeatureModuleCatalog {
  const FeatureModuleCatalog._();

  /// Catalog version persisted in `unternehmen.feature_modules_json`.
  static const int version = 1;

  static const String profileManager = 'profile_manager';
  static const String inventory = 'inventory';
  static const String guv = 'guv';

  static const List<String> ids = <String>[profileManager, inventory, guv];

  /// Declared defaults: every catalog entry starts disabled.
  static const Map<String, bool> defaults = <String, bool>{profileManager: false, inventory: false, guv: false};

  /// Provider/dependency each entry requires. A missing provider or
  /// dependency makes the module unavailable with a localized reason.
  static const Map<String, Set<String>> requiredProviders = <String, Set<String>>{
    profileManager: <String>{FeatureModuleProviders.profileWorkspace},
    inventory: <String>{FeatureModuleProviders.articleCatalog, FeatureModuleProviders.invoiceStock},
    guv: <String>{FeatureModuleProviders.accountingJournal, FeatureModuleProviders.guvCalculator},
  };

  static bool isKnown(String id) => defaults.containsKey(id);
}

/// Provider ids the catalog entries depend on.
class FeatureModuleProviders {
  const FeatureModuleProviders._();

  static const String profileWorkspace = 'profile_workspace';
  static const String articleCatalog = 'article_catalog';
  static const String invoiceStock = 'invoice_stock';
  static const String accountingJournal = 'accounting_journal';
  static const String guvCalculator = 'guv_calculator';

  static const Set<String> all = <String>{
    profileWorkspace,
    articleCatalog,
    invoiceStock,
    accountingJournal,
    guvCalculator,
  };
}

/// Maintained accounting GuV threshold (§141 AO): turnover above
/// 800.000 € or profit above 80.000 € auto-activates GuV through the
/// catalog state writer. No independent `guv_aktiv` runtime flag exists.
class GuvThresholds {
  const GuvThresholds._();

  static const double turnoverLimit = 800000;
  static const double profitLimit = 80000;

  /// Reason reported when the threshold activates GuV.
  static const String reason = 'threshold';

  static bool applies({required double turnover, required double profit}) {
    return turnover > turnoverLimit || profit > profitLimit;
  }
}
