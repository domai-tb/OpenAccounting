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
  static const String zugferdContextParameter = 'urn:factur-x.eu:1p0:en16931';

  /// Normative XRechnung format version (in force at least through 2027-07-31).
  static const String xrechnungVersion = '3.0';

  /// XRechnung output syntax for this increment.
  static const String xrechnungSyntax = 'UBL 2.1';

  /// Compatible technical validator bundle, dated 2026-08-31. This identifies
  /// the validator artifacts, never the normative format version.
  static const String xrechnungBundleVersion = '3.0.2';

  /// Human-readable bundle identity shown in UI and release metadata.
  static const String xrechnungBundleLabel = '3.0.2 Summer 2026';
}

/// Availability of the offline validation artifacts.
///
/// The production bundle stays unavailable until the official validator is
/// actually packaged and verified on each supported desktop platform.
class PinnedArtifactBundle {
  const PinnedArtifactBundle({this.available = false, this.reason});

  /// No validator artifacts are currently packaged.
  static const PinnedArtifactBundle packaged = PinnedArtifactBundle();

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
