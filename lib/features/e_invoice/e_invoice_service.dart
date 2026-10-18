import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_artifacts.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_offline_xml_validator.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_output_format.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_snapshot.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_validation.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_xml.dart';

/// Readiness derived from validated artifacts only. Never claimed from schema
/// validation alone and never without generation succeeding first.
enum EInvoiceReadiness { notValidated, valid, invalid, unavailable }

/// Staged ZUGFeRD output pair. CII XML remains separate from PDF bytes; this
/// is not a compliant hybrid PDF container.
class ZugferdHybridArtifact {
  const ZugferdHybridArtifact({required this.pdfBytes, required this.ciiXml, required this.documentNumber});

  final List<int> pdfBytes;
  final String ciiXml;
  final String documentNumber;
}

/// Save-dialog adapter. Returns the chosen destination path, or null when the
/// user cancels. Injected in tests so cancellation and atomic-write behavior
/// verify without an interactive desktop session.
typedef EInvoiceSaveDialog = Future<String?> Function({required String suggestedName, required String extension});

typedef EInvoiceOfflineXmlValidationCallback = Future<EInvoiceOfflineXmlValidationResult> Function({
  required EInvoiceOutputFormat format,
  required String xml,
});

/// Production save dialog backed by the native file selector.
Future<String?> nativeEInvoiceSaveDialog({required String suggestedName, required String extension}) async {
  final FileSaveLocation? location = await getSaveLocation(
    acceptedTypeGroups: <XTypeGroup>[
      XTypeGroup(label: 'XML', extensions: <String>[extension]),
    ],
    suggestedName: suggestedName,
  );
  return location?.path;
}

/// Orchestrates structured-output generation and validation.
///
/// Pure with respect to invoice state: generation never mutates the invoice,
/// and export writes atomically (same-directory temp file plus rename) so a
/// failed write leaves no partial destination file.
class EInvoiceService {
  const EInvoiceService({
    this.validator = const EInvoiceValidator(),
    this.serializer = const EInvoiceXmlSerializer(),
    this.bundle = PinnedArtifactBundle.packaged,
    this.offlineXmlValidation,
  });

  static final EInvoiceOfflineXmlValidator _packagedOfflineXmlValidator = EInvoiceOfflineXmlValidator();

  final EInvoiceValidator validator;
  final EInvoiceXmlSerializer serializer;
  final PinnedArtifactBundle bundle;
  final EInvoiceOfflineXmlValidationCallback? offlineXmlValidation;

  bool get validatorAvailable => bundle.available;

  /// Applies the available validation rules to [snapshot] for [format].
  ///
  /// The production bundle is unavailable until pinned local artifacts are
  /// packaged and verified, so production calls fail closed.
  EInvoiceValidationResult validate(FinalizationSnapshot snapshot, EInvoiceOutputFormat format) {
    if (!bundle.available) {
      return const EInvoiceValidationResult.unavailable(<EInvoiceDiagnostic>[
        EInvoiceDiagnostic(
          ruleId: 'bundleUnavailable',
          messageDe:
              'Die erforderlichen Prüfartefakte sind nicht verfügbar. Es wurde kein E-Rechnungsartefakt ausgegeben.',
          messageEn: 'Required validation artifacts are unavailable. No e-invoice artifact was produced.',
        ),
      ]);
    }
    return validator.validate(snapshot, format);
  }

  /// Builds the staged PDF/XML pair from one canonical snapshot.
  ///
  /// Both outputs consume [snapshot]; callers must pass the same immutable
  /// instance they persist. CII XML passes the pinned offline profile before
  /// this returns. This does not embed XML or prove PDF/A-3b conformance.
  Future<ZugferdHybridArtifact> hybridFromPdf({
    required FinalizationSnapshot snapshot,
    required List<int> pdfBytes,
  }) async {
    final EInvoiceValidationResult result = validate(snapshot, EInvoiceOutputFormat.zugferd);
    if (!result.valid) {
      throw EInvoiceExportValidationException(result);
    }
    final String xml = serializer.zugferdCii(snapshot);
    _requirePdfStructure(pdfBytes);
    _requireXmlStructure(xml, 'rsm:CrossIndustryInvoice');
    await _requireOfflineXmlValidation(format: EInvoiceOutputFormat.zugferd, xml: xml);
    return ZugferdHybridArtifact(
      pdfBytes: List<int>.unmodifiable(pdfBytes),
      ciiXml: xml,
      documentNumber: snapshot.documentNumber,
    );
  }

  /// Serializes standalone XRechnung XML after validation. The invoice is
  /// never mutated by this call.
  Future<String> xrechnungXml(FinalizationSnapshot snapshot) async {
    final EInvoiceValidationResult result = validate(snapshot, EInvoiceOutputFormat.xrechnung);
    if (!result.valid) {
      throw EInvoiceExportValidationException(result);
    }
    final String xml = serializer.xrechnungUbl(snapshot);
    _requireXmlStructure(xml, 'Invoice');
    await _requireOfflineXmlValidation(format: EInvoiceOutputFormat.xrechnung, xml: xml);
    return xml;
  }

  /// Serializes and validates ZUGFeRD CII before a caller begins finalization side effects.
  Future<String> zugferdXml(FinalizationSnapshot snapshot) async {
    final EInvoiceValidationResult result = validate(snapshot, EInvoiceOutputFormat.zugferd);
    if (!result.valid) {
      throw EInvoiceExportValidationException(result);
    }
    final String xml = serializer.zugferdCii(snapshot);
    _requireXmlStructure(xml, 'rsm:CrossIndustryInvoice');
    await _requireOfflineXmlValidation(format: EInvoiceOutputFormat.zugferd, xml: xml);
    return xml;
  }

  Future<void> _requireOfflineXmlValidation({required EInvoiceOutputFormat format, required String xml}) async {
    final EInvoiceOfflineXmlValidationResult offlineResult =
        await (offlineXmlValidation ?? _packagedOfflineXmlValidator.validateXml)(format: format, xml: xml);
    if (offlineResult.valid) return;

    final bool unavailable = offlineResult.status == EInvoiceOfflineXmlValidationStatus.unavailable;
    final String messageDe = unavailable
        ? 'Die Offline-Prüfung ist nicht verfügbar. Es wurde kein E-Rechnungsartefakt ausgegeben.'
        : 'Die Offline-Prüfung hat das E-Rechnungs-XML abgelehnt.';
    final String messageEn = unavailable
        ? 'Offline validation is unavailable. No e-invoice artifact was produced.'
        : 'Offline validation rejected the e-invoice XML.';
    final List<EInvoiceDiagnostic> diagnostics = offlineResult.diagnostics
        .map(
          (diagnostic) => EInvoiceDiagnostic(
            ruleId: diagnostic.code,
            messageDe: messageDe,
            messageEn: messageEn,
            route: 'rechnungen',
          ),
        )
        .toList();
    if (diagnostics.isEmpty) {
      diagnostics.add(
        EInvoiceDiagnostic(
          ruleId: 'offlineValidator.${offlineResult.status.name}',
          messageDe: messageDe,
          messageEn: messageEn,
          route: 'rechnungen',
        ),
      );
    }
    final EInvoiceValidationResult result = unavailable
        ? EInvoiceValidationResult.unavailable(diagnostics)
        : EInvoiceValidationResult.invalid(diagnostics);
    throw EInvoiceExportValidationException(result, offlineXmlResult: offlineResult);
  }

  /// Validates, asks for a destination, and writes the XML atomically.
  ///
  /// Returns the destination path, or null when the user cancels (nothing is
  /// written then). Validation runs before the dialog opens, so a failing
  /// snapshot never shows a save dialog and never touches the filesystem.
  Future<String?> exportXRechnung({
    required FinalizationSnapshot snapshot,
    required EInvoiceSaveDialog saveDialog,
  }) async {
    final String xml = await xrechnungXml(snapshot);
    final String? destination = await saveDialog(suggestedName: '${snapshot.documentNumber}.xml', extension: 'xml');
    if (destination == null || destination.trim().isEmpty) return null;
    _writeAtomically(destination, xml);
    return destination;
  }

  /// Derives UI readiness from a validation result. `valid` requires both
  /// generation and validation to have succeeded for the selected format.
  EInvoiceReadiness readiness(EInvoiceValidationResult? result) {
    if (result == null) return EInvoiceReadiness.notValidated;
    return switch (result.status) {
      EInvoiceValidationStatus.valid => EInvoiceReadiness.valid,
      EInvoiceValidationStatus.invalid => EInvoiceReadiness.invalid,
      EInvoiceValidationStatus.unavailable => EInvoiceReadiness.unavailable,
    };
  }

  // Minimal structural guards for the packaged artifacts. Full PDF/A-3b
  // conformance and embedded-file relationship checks run in release
  // verification with the pinned offline validator; these guards only reject
  // truncated or non-PDF input before it can be stored as a hybrid.
  void _requirePdfStructure(List<int> pdfBytes) {
    if (pdfBytes.length < 8) {
      throw const EInvoiceSourceException(
        code: 'invalidPdfArtifact',
        messageDe: 'PDF-Artefakt ist unvollständig',
        messageEn: 'PDF artifact is incomplete',
        fields: ['original_pdf_pfad'],
      );
    }
    final String header = String.fromCharCodes(pdfBytes.take(5));
    if (!header.startsWith('%PDF-')) {
      throw const EInvoiceSourceException(
        code: 'invalidPdfArtifact',
        messageDe: 'PDF-Artefakt hat keinen gültigen PDF-Kopf',
        messageEn: 'PDF artifact has no valid PDF header',
        fields: ['original_pdf_pfad'],
      );
    }
  }

  void _requireXmlStructure(String xml, String rootElement) {
    if (!xml.contains('<?xml') || !xml.contains('<$rootElement') || !xml.contains('</$rootElement>')) {
      throw const EInvoiceSourceException(
        code: 'invalidXmlArtifact',
        messageDe: 'XML-Artefakt ist unvollständig',
        messageEn: 'XML artifact is incomplete',
        fields: ['ausgabeformat'],
      );
    }
  }

  void _writeAtomically(String destination, String xml) {
    final File target = File(destination);
    final Directory directory = target.parent;
    final File temp = File('${target.path}.tmp');
    try {
      directory.createSync(recursive: true);
      temp.writeAsStringSync(xml, flush: true);
      temp.renameSync(target.path);
    } catch (_) {
      try {
        if (temp.existsSync()) temp.deleteSync();
      } catch (_) {}
      rethrow;
    }
  }
}

/// Thrown when export validation fails before any dialog or file write.
class EInvoiceExportValidationException implements Exception {
  const EInvoiceExportValidationException(this.result, {this.offlineXmlResult});

  final EInvoiceValidationResult result;
  final EInvoiceOfflineXmlValidationResult? offlineXmlResult;

  @override
  String toString() => result.diagnostics.map((diagnostic) => diagnostic.messageDe).join('; ');
}
