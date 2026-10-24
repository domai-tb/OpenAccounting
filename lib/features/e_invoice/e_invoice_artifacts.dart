import 'package:openaccounting/features/e_invoice/e_invoice_output_format.dart';

/// Pinned structured-invoice releases (initial targets, not latest-release
/// claims). A newer official release requires an explicit compatibility
/// change with updated fixtures; runtime never downloads or switches.
class EInvoicePinnedVersions {
  const EInvoicePinnedVersions._();

  /// ZUGFeRD release effective 2026-09-01, based on UN/CEFACT CII D22B.
  static const String zugferdVersion = '2.5.2';

  /// Only supported ZUGFeRD profile. Never emit EXTENDED.
  static const String zugferdProfile = 'EN16931';

  /// Profile context parameter embedded in CII output.
  static const String zugferdContextParameter = 'urn:cen.eu:en16931:2017';

  /// Normative XRechnung format version (in force at least through 2027-07-31).
  static const String xrechnungVersion = '3.0';

  /// XRechnung output syntax for this increment.
  static const String xrechnungSyntax = 'UBL 2.1';

  /// Compatible technical validator bundle, dated 2026-08-31. This identifies
  /// the validator artifacts, never the normative format version.
  static const String xrechnungBundleVersion = '3.0.2';

  /// Human-readable bundle identity shown in UI and release metadata.
  static const String xrechnungBundleLabel = '3.0.2 Summer 2026';

  /// KoSIT validator engine used by the packaged offline XML validator.
  /// Linux real-engine evidence exists; Windows/macOS Java packaging and
  /// runtime evidence remain open. This version does not imply PDF/A proof.
  static const String kositValidatorVersion = '1.6.3';

  /// Pinned validator configuration release (commit `b436fc4`).
  static const String xrechnungConfigVersion = 'v2026-08-31';

  /// CEN Schematron rules used by the configuration.
  static const String cenSchematronVersion = '1.3.16';

  /// XRechnung Schematron used by the configuration.
  static const String xrechnungSchematronVersion = '2.6.0';
}

/// Availability of the packaged, hash-pinned offline XML validation assets.
///
/// This does not imply that a Java runtime is available on every platform or
/// that generated ZUGFeRD PDFs have passed formal PDF/A-3b validation.
class PinnedArtifactBundle {
  const PinnedArtifactBundle({this.available = false, this.reason});

  /// Local assets are hash-checked by EInvoiceOfflineXmlValidator before output.
  static const PinnedArtifactBundle packaged = PinnedArtifactBundle(available: true);

  final bool available;
  final String? reason;

  /// Release identity recorded in application/release metadata.
  String releaseIdentity(EInvoiceOutputFormat format) {
    return switch (format) {
      EInvoiceOutputFormat.zugferd =>
        'ZUGFeRD ${EInvoicePinnedVersions.zugferdVersion} ${EInvoicePinnedVersions.zugferdProfile} '
            '(CII D22B)',
      EInvoiceOutputFormat.xrechnung =>
        'XRechnung ${EInvoicePinnedVersions.xrechnungVersion} ${EInvoicePinnedVersions.xrechnungSyntax} '
            '(Bundle ${EInvoicePinnedVersions.xrechnungBundleLabel})',
      EInvoiceOutputFormat.pdf => 'PDF',
    };
  }
}
