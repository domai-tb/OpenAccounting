// ignore_for_file: non_constant_identifier_names
// Immutable EKS result per spec §Anlage EKS 9-page.
// ponytail: string money keeps NUMERIC(12,2) precision, pure helpers, warns not throws.

class EksSectionD {
  const EksSectionD({
    required this.berufsbezeichnung,
    required this.kammerMitgliedschaft,
    required this.geburtsdatum,
    required this.bgNummer,
    required this.jobcenterName,
  });

  final String berufsbezeichnung;
  final String kammerMitgliedschaft;
  final String geburtsdatum;
  final String bgNummer;
  final String jobcenterName;
}

class EksPage9 {
  const EksPage9({required this.totalIncome, required this.totalCosts, required this.netResult});

  final String totalIncome;
  final String totalCosts;
  final String netResult;
}

class EksResult {
  const EksResult({
    required this.jahr,
    required this.sectionD,
    required this.sectionF,
    required this.b6_5,
    required this.b6_4_priv,
    required this.page9,
    required this.warnings,
  });

  final int jahr;

  /// Section D — company data (empty strings if missing, warnings via debugPrint + warnings list)
  final EksSectionD sectionD;

  /// Section F Zeilen 23-41 mapped via eks_kategorie -> sum betrag string '0.00'
  final Map<String, String> sectionF;

  /// B6_5 travel km*0.10
  final String b6_5;

  /// B6_4_priv private car deduction via anlageverzeichnis privatanteil
  final String b6_4_priv;

  /// Page 9 summary
  final EksPage9 page9;

  /// Warning messages (also debugPrint)
  final List<String> warnings;
}
