import 'package:openaccounting/features/e_invoice/e_invoice_output_format.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_snapshot.dart';

/// One typed validation finding with a stable identifier.
///
/// [ruleId] is either a field/business-term path (e.g. `seller.street`) or a
/// stable pinned-rule identifier (e.g. `BR-SUM-01`). Messages are stored in
/// both UI languages and selected with [messageFor]; [route] names the
/// corrective surface where available.
class EInvoiceDiagnostic {
  const EInvoiceDiagnostic({required this.ruleId, required this.messageDe, required this.messageEn, this.route});

  final String ruleId;
  final String messageDe;
  final String messageEn;
  final String? route;

  String messageFor(String locale) => locale.startsWith('en') ? messageEn : messageDe;
}

/// Outcome of pinned validation for one snapshot and format.
class EInvoiceValidationResult {
  const EInvoiceValidationResult._({required this.valid, required this.diagnostics});

  const EInvoiceValidationResult.valid() : this._(valid: true, diagnostics: const <EInvoiceDiagnostic>[]);

  const EInvoiceValidationResult.invalid(List<EInvoiceDiagnostic> diagnostics)
    : this._(valid: false, diagnostics: diagnostics);

  final bool valid;
  final List<EInvoiceDiagnostic> diagnostics;
}

/// Validates a snapshot against the pinned format rules without network
/// access and without touching the invoice.
///
/// Required-field findings map to field/business-term identifiers; structural
/// findings map to stable `BR-` rule identifiers. Any finding fails the
/// output: no partial artifact may be exposed when this result is invalid.
class EInvoiceValidator {
  const EInvoiceValidator();

  EInvoiceValidationResult validate(FinalizationSnapshot snapshot, EInvoiceOutputFormat format) {
    final List<EInvoiceDiagnostic> findings = <EInvoiceDiagnostic>[];
    _checkParties(snapshot, findings, format);
    _checkDocument(snapshot, findings, format);
    _checkTotals(snapshot, findings);
    _checkCurrency(snapshot, findings);
    if (findings.isEmpty) return const EInvoiceValidationResult.valid();
    return EInvoiceValidationResult.invalid(List<EInvoiceDiagnostic>.unmodifiable(findings));
  }

  void _checkParties(FinalizationSnapshot snapshot, List<EInvoiceDiagnostic> findings, EInvoiceOutputFormat format) {
    _requiredText(snapshot.seller.name, 'seller.name', findings, route: 'stammdaten');
    _requiredText(snapshot.seller.street, 'seller.street', findings, route: 'stammdaten');
    _requiredText(snapshot.seller.postalCode, 'seller.postalCode', findings, route: 'stammdaten');
    _requiredText(snapshot.seller.city, 'seller.city', findings, route: 'stammdaten');
    _requiredText(snapshot.seller.country, 'seller.country', findings, route: 'stammdaten');
    // §14 UStG: issuer tax number OR VAT ID. The profile accepts either; only
    // the absence of both is a finding. No value is ever defaulted.
    if (_blank(snapshot.seller.taxNumber) && _blank(snapshot.seller.vatId)) {
      findings.add(
        const EInvoiceDiagnostic(
          ruleId: 'seller.taxIdentifier',
          messageDe: 'Steuernummer oder USt-IdNr. des Ausstellers fehlt',
          messageEn: 'Issuer tax number or VAT ID is missing',
          route: 'stammdaten',
        ),
      );
    }
    _requiredText(snapshot.buyer.name, 'buyer.name', findings, route: 'rechnungen');
    _requiredText(snapshot.buyer.street, 'buyer.street', findings, route: 'rechnungen');
    _requiredText(snapshot.buyer.postalCode, 'buyer.postalCode', findings, route: 'rechnungen');
    _requiredText(snapshot.buyer.city, 'buyer.city', findings, route: 'rechnungen');
    _requiredText(snapshot.buyer.country, 'buyer.country', findings, route: 'rechnungen');
    if (format == EInvoiceOutputFormat.xrechnung) {
      if (_blank(snapshot.seller.endpointId)) {
        findings.add(
          const EInvoiceDiagnostic(
            ruleId: 'seller.endpoint',
            messageDe: 'Elektronische Adresse des Ausstellers fehlt (USt-IdNr. erforderlich)',
            messageEn: 'Seller electronic address is missing (VAT ID required)',
            route: 'stammdaten',
          ),
        );
      }
      if (_blank(snapshot.buyer.endpointId)) {
        findings.add(
          const EInvoiceDiagnostic(
            ruleId: 'buyer.endpoint',
            messageDe: 'Elektronische Adresse des Käufers fehlt (E-Mail oder Käuferreferenz erforderlich)',
            messageEn: 'Buyer electronic address is missing (email or buyer reference required)',
            route: 'rechnungen',
          ),
        );
      }
      if (_blank(snapshot.seller.iban)) {
        findings.add(
          const EInvoiceDiagnostic(
            ruleId: 'seller.payment',
            messageDe: 'Zahlungsdaten fehlen (IBAN des Ausstellers erforderlich)',
            messageEn: 'Payment data is missing (seller IBAN required)',
            route: 'stammdaten',
          ),
        );
      }
      if (_blank(snapshot.deliveryDate)) {
        findings.add(
          const EInvoiceDiagnostic(
            ruleId: 'invoice.deliveryDate',
            messageDe: 'Lieferdatum fehlt (Leistungsdatum erforderlich)',
            messageEn: 'Delivery date is missing (leistungsdatum required)',
            route: 'rechnungen',
          ),
        );
      }
    }
  }

  void _checkDocument(FinalizationSnapshot snapshot, List<EInvoiceDiagnostic> findings, EInvoiceOutputFormat format) {
    _requiredText(snapshot.documentNumber, 'documentNumber', findings, route: 'rechnungen');
    if (!_isIsoDate(snapshot.issueDate)) {
      findings.add(
        const EInvoiceDiagnostic(
          ruleId: 'issueDate',
          messageDe: 'Rechnungsdatum ist ungültig (erwartet YYYY-MM-DD)',
          messageEn: 'Invoice date is invalid (expected YYYY-MM-DD)',
          route: 'rechnungen',
        ),
      );
    }
    if (snapshot.lines.isEmpty) {
      findings.add(
        const EInvoiceDiagnostic(
          ruleId: 'lines',
          messageDe: 'Rechnung enthält keine Positionen',
          messageEn: 'Invoice contains no lines',
          route: 'rechnungen',
        ),
      );
    }
    for (var index = 0; index < snapshot.lines.length; index++) {
      final EInvoiceLineSnapshot line = snapshot.lines[index];
      if (line.description.trim().isEmpty) {
        findings.add(
          EInvoiceDiagnostic(
            ruleId: 'line[$index].description',
            messageDe: 'Position ${index + 1}: Bezeichnung fehlt',
            messageEn: 'Line ${index + 1}: description is missing',
            route: 'rechnungen',
          ),
        );
      }
      if (line.netCents < 0 || line.taxCents < 0 || line.grossCents <= 0) {
        findings.add(
          EInvoiceDiagnostic(
            ruleId: 'BR-LINE-AMOUNT-01',
            messageDe: 'Position ${index + 1}: Beträge sind ungültig',
            messageEn: 'Line ${index + 1}: amounts are invalid',
            route: 'rechnungen',
          ),
        );
      }
      if (line.netCents + line.taxCents != line.grossCents) {
        findings.add(
          EInvoiceDiagnostic(
            ruleId: 'BR-LINE-SUM-01',
            messageDe: 'Position ${index + 1}: Netto + Steuer muss Brutto ergeben',
            messageEn: 'Line ${index + 1}: net plus tax must equal gross',
            route: 'rechnungen',
          ),
        );
      }
      if (line.classification.exemptionReason == null && _requiresReason(line.classification.category.name)) {
        findings.add(
          EInvoiceDiagnostic(
            ruleId: 'line[$index].exemptionReason',
            messageDe: 'Position ${index + 1}: Befreiungsgrund fehlt',
            messageEn: 'Line ${index + 1}: exemption reason is missing',
            route: 'rechnungen',
          ),
        );
      }
    }
    // XRechnung buyer reference (BT-10, e.g. Leitweg-ID): required for the
    // standalone export. It is an explicit export parameter, never inferred.
    if (format == EInvoiceOutputFormat.xrechnung && _blank(snapshot.buyerReference)) {
      findings.add(
        const EInvoiceDiagnostic(
          ruleId: 'buyerReference',
          messageDe: 'Käuferreferenz (z. B. Leitweg-ID) fehlt für den XRechnung-Export',
          messageEn: 'Buyer reference (e.g. Leitweg ID) is missing for XRechnung export',
          route: 'rechnungen',
        ),
      );
    }
  }

  void _checkTotals(FinalizationSnapshot snapshot, List<EInvoiceDiagnostic> findings) {
    var netSum = 0;
    var taxSum = 0;
    var grossSum = 0;
    for (final EInvoiceLineSnapshot line in snapshot.lines) {
      netSum += line.netCents;
      taxSum += line.taxCents;
      grossSum += line.grossCents;
    }
    // Pinned business rules: document sums equal the line sums and the
    // canonical snapshot totals. No tolerance, no silent correction.
    if (netSum != snapshot.netCents || taxSum != snapshot.taxCents || grossSum != snapshot.grossCents) {
      findings.add(
        const EInvoiceDiagnostic(
          ruleId: 'BR-SUM-01',
          messageDe: 'Dokumentensummen stimmen nicht mit den Positionssummen überein',
          messageEn: 'Document totals do not match the line sums',
          route: 'rechnungen',
        ),
      );
    }
    if (snapshot.netCents + snapshot.taxCents != snapshot.grossCents) {
      findings.add(
        const EInvoiceDiagnostic(
          ruleId: 'BR-SUM-02',
          messageDe: 'Netto + Steuer muss den Rechnungsbetrag ergeben',
          messageEn: 'Net plus tax must equal the invoice total',
          route: 'rechnungen',
        ),
      );
    }
    if (snapshot.grossCents <= 0) {
      findings.add(
        const EInvoiceDiagnostic(
          ruleId: 'BR-AMOUNT-01',
          messageDe: 'Rechnungsbetrag muss positiv sein',
          messageEn: 'Invoice total must be positive',
          route: 'rechnungen',
        ),
      );
    }
  }

  void _checkCurrency(FinalizationSnapshot snapshot, List<EInvoiceDiagnostic> findings) {
    // Initial scope is EUR-only; other currencies fail instead of being
    // converted or silently relabeled.
    if (snapshot.currency != 'EUR') {
      findings.add(
        const EInvoiceDiagnostic(
          ruleId: 'currency',
          messageDe: 'Nur EUR wird unterstützt',
          messageEn: 'Only EUR is supported',
          route: 'rechnungen',
        ),
      );
    }
  }

  void _requiredText(String? value, String ruleId, List<EInvoiceDiagnostic> findings, {String? route}) {
    if (!_blank(value)) return;
    findings.add(
      EInvoiceDiagnostic(
        ruleId: ruleId,
        messageDe: 'Pflichtfeld fehlt: $ruleId',
        messageEn: 'Required field is missing: $ruleId',
        route: route,
      ),
    );
  }

  bool _blank(String? value) => value == null || value.trim().isEmpty;

  bool _isIsoDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    return DateTime.tryParse(value) != null;
  }

  // No exempt-type category exists in the initial scope; the hook keeps the
  // contract stable when the approved map grows.
  bool _requiresReason(String categoryName) => categoryName != 'standard';
}
