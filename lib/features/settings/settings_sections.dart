/// Settings capability index per DESIGN §19. Company, account, tax-rate,
/// number-range, and report/export actions navigate to their owning production
/// workspaces; Settings never duplicates their forms or calculations.
enum SettingsSection {
  allgemein('Allgemein', null),
  unternehmen('Unternehmen', '/settings/company'),
  steuern('Steuern', '/taxes'),
  rechnungen('Rechnungen', '/invoices'),
  bankIntegrationen('Bank & Integrationen', '/banking'),
  datenDatenschutz('Daten & Datenschutz', null),
  sicherung('Sicherung', null),
  darstellung('Darstellung', null),
  spracheRegion('Sprache & Region', null),
  erweitert('Erweitert', null),
  ueber('Über', null);

  const SettingsSection(this.label, this.route);

  final String label;
  final String? route;

  /// Owning production route for link-out sections, if any.
  String? get ownerRoute => route;
}
