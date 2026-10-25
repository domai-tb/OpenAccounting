import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_output_format.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

const String _assetPrefix = 'assets/e_invoice_validator/';
const String _manifestAsset = '${_assetPrefix}manifest.json';
const String _reportNamespace = 'http://www.xoev.de/de/validator/varl/1';
const String _scenarioNamespace = 'http://www.xoev.de/de/validator/framework/1/scenarios';
const String _expectedManifestSha256 = '50ab8f735bb338761fe2db4c580220a714cde6e1d55c789aa89cc6e17d5fd894';

/// Result state for validation by the packaged offline XML rules.
enum EInvoiceOfflineXmlValidationStatus { valid, invalid, unavailable }

/// One finding returned by KoSIT and the selected profile rules.
class EInvoiceOfflineXmlDiagnostic {
  const EInvoiceOfflineXmlDiagnostic({required this.code, required this.level, required this.message});

  final String code;
  final String level;
  final String message;
}

/// One schema or business-rule step reported by the pinned engine.
class EInvoiceOfflineXmlValidationStep {
  const EInvoiceOfflineXmlValidationStep({required this.id, required this.valid});

  final String id;
  final bool valid;
}

/// Outcome of validating one generated invoice XML document.
class EInvoiceOfflineXmlValidationResult {
  const EInvoiceOfflineXmlValidationResult({
    required this.status,
    required this.message,
    this.engineVersion,
    this.scenarioName,
    this.diagnostics = const <EInvoiceOfflineXmlDiagnostic>[],
    this.steps = const <EInvoiceOfflineXmlValidationStep>[],
  });

  final EInvoiceOfflineXmlValidationStatus status;
  final String message;
  final String? engineVersion;
  final String? scenarioName;
  final List<EInvoiceOfflineXmlDiagnostic> diagnostics;
  final List<EInvoiceOfflineXmlValidationStep> steps;

  bool get valid => status == EInvoiceOfflineXmlValidationStatus.valid;
  bool get available => status != EInvoiceOfflineXmlValidationStatus.unavailable;
}

/// Runs the packaged KoSIT engine and selected XRechnung / Factur-X profiles.
///
/// Runtime validation never downloads rules. The external Java 11+ runtime
/// must be installed separately; missing assets, Java, or a usable process
/// result return [EInvoiceOfflineXmlValidationStatus.unavailable]. Call
/// [dispose] after the owner's last validation to remove extracted assets.
class EInvoiceOfflineXmlValidator {
  EInvoiceOfflineXmlValidator({
    AssetBundle? assetBundle,
    this.javaExecutable = 'java',
    this.timeout = const Duration(seconds: 90),
    this.maxXmlBytes = 16 * 1024 * 1024,
  }) : _assetBundle = assetBundle ?? rootBundle;

  final AssetBundle _assetBundle;
  final String javaExecutable;
  final Duration timeout;
  final int maxXmlBytes;

  Future<Directory>? _workspaceFuture;
  static int _runNumber = 0;

  /// Validates an XML invoice using the profile emitted for [format].
  ///
  /// PDF has no XML profile. CII BASIC/EXTENDED and other XRechnung syntax or
  /// document types are outside the packaged profiles and are not accepted by
  /// this API. Inputs containing a DTD are rejected before Java is launched so
  /// XML cannot request local-file or network entity resolution.
  Future<EInvoiceOfflineXmlValidationResult> validateXml({
    required EInvoiceOutputFormat format,
    required String xml,
  }) async {
    final String? expectedScenarioName = switch (format) {
      EInvoiceOutputFormat.xrechnung => 'EN16931 XRechnung (UBL Invoice)',
      EInvoiceOutputFormat.zugferd => 'ZUGFeRD 2.5.2 EN16931 (CII D22B)',
      EInvoiceOutputFormat.pdf => null,
    };
    if (expectedScenarioName == null) {
      return _unavailable('The selected output format has no packaged XML validation profile.');
    }

    final List<int> xmlBytes = utf8.encode(xml);
    if (xmlBytes.length > maxXmlBytes) {
      return _invalid('INPUT_TOO_LARGE', 'error', 'XML exceeds the $maxXmlBytes byte validation limit.');
    }
    if (RegExp(r'<!\s*(DOCTYPE|ENTITY)\b', caseSensitive: false).hasMatch(xml)) {
      return _invalid('DTD_NOT_ALLOWED', 'error', 'XML DTD and entity declarations are not accepted.');
    }
    final XmlDocument inputDocument;
    try {
      inputDocument = XmlDocument.parse(xml);
    } on Object catch (error) {
      return _invalid('MALFORMED_XML', 'error', 'XML is not well formed: $error');
    }
    final Iterable<XmlElement> inputElements = <XmlElement>[
      inputDocument.rootElement,
      ...inputDocument.rootElement.descendants.whereType<XmlElement>(),
    ];
    final bool hasSchemaHint = inputElements.any(
      (XmlElement element) => element.attributes.any(
        (XmlAttribute attribute) =>
            attribute.name.local == 'schemaLocation' || attribute.name.local == 'noNamespaceSchemaLocation',
      ),
    );
    if (hasSchemaHint) {
      return _invalid(
        'EXTERNAL_SCHEMA_REFERENCE',
        'error',
        'XML schema-location attributes are not accepted; only the pinned local schema is used.',
      );
    }

    Directory? runDirectory;
    try {
      final Directory workspace = await (_workspaceFuture ??= _createWorkspace());
      final Directory runsDirectory = Directory(p.join(workspace.path, 'runs'));
      await runsDirectory.create(recursive: true);
      runDirectory = await runsDirectory.createTemp('invoice-');
      final Directory reportDirectory = Directory(p.join(runDirectory.path, 'reports'));
      await reportDirectory.create();
      final String inputName = 'invoice-${_nextRunNumber()}.xml';
      final File inputFile = File(p.join(runDirectory.path, inputName));
      await inputFile.writeAsBytes(xmlBytes, flush: true);

      final Process process = await Process.start(javaExecutable, <String>[
        '-jar',
        p.join(workspace.path, 'validator-1.6.3-standalone.jar'),
        '-s',
        p.join(workspace.path, 'scenarios.xml'),
        '-r',
        workspace.path,
        '-o',
        reportDirectory.path,
        inputFile.path,
      ], workingDirectory: workspace.path);
      final Future<String> stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final Future<String> stderrFuture = process.stderr.transform(utf8.decoder).join();
      final int exitCode;
      try {
        exitCode = await process.exitCode.timeout(timeout);
      } on TimeoutException {
        process.kill();
        await Future.wait<String>(<Future<String>>[stdoutFuture, stderrFuture]);
        return _unavailable('The offline XML validator exceeded its $timeout timeout.');
      }
      final String stdout = await stdoutFuture;
      final String stderr = await stderrFuture;
      final File reportFile = File(p.join(reportDirectory.path, '${p.basenameWithoutExtension(inputName)}-report.xml'));
      if (!reportFile.existsSync()) {
        final String details = _trimProcessOutput(stderr.isEmpty ? stdout : stderr);
        return _unavailable(
          details.isEmpty
              ? 'The offline XML validator did not produce a validation report.'
              : 'The offline XML validator did not produce a validation report: $details',
        );
      }

      final EInvoiceOfflineXmlValidationResult report = _parseReport(await reportFile.readAsString());
      if (report.scenarioName != expectedScenarioName) {
        return _invalid(
          'PROFILE_MISMATCH',
          'error',
          'The invoice did not match the requested $expectedScenarioName profile.',
        );
      }
      if (report.status == EInvoiceOfflineXmlValidationStatus.valid && exitCode == 0) {
        return report;
      }
      if (report.status == EInvoiceOfflineXmlValidationStatus.invalid && (exitCode == 1 || exitCode == 2)) {
        return report;
      }
      return _unavailable('The validator process and its report did not agree (exit code $exitCode).');
    } on Object catch (error) {
      return _unavailable('The offline XML validator could not run: $error');
    } finally {
      if (runDirectory != null && runDirectory.existsSync()) {
        runDirectory.deleteSync(recursive: true);
      }
    }
  }

  /// Deletes the temporary copy of the pinned validator bundle.
  Future<void> dispose() async {
    final Future<Directory>? workspaceFuture = _workspaceFuture;
    if (workspaceFuture == null) return;
    try {
      final Directory workspace = await workspaceFuture;
      if (workspace.existsSync()) workspace.deleteSync(recursive: true);
    } on Object {
      // Cleanup failure must not turn a completed validation into success or
      // invalidate the validation result already returned to the caller.
    }
    _workspaceFuture = null;
  }

  Future<Directory> _createWorkspace() async {
    final ByteData manifestData = await _assetBundle.load(_manifestAsset);
    final Uint8List manifestBytes = _byteDataBytes(manifestData);
    final String manifestDigest = sha256.convert(manifestBytes).toString();
    if (manifestDigest != _expectedManifestSha256) {
      throw const FormatException('The packaged validator manifest checksum does not match.');
    }
    final Map<String, Object?> manifest = jsonDecode(utf8.decode(manifestBytes)) as Map<String, Object?>;
    final Object? runtimeFiles = manifest['runtimeFiles'];
    if (runtimeFiles is! List<Object?> || runtimeFiles.isEmpty) {
      throw const FormatException('The packaged validator manifest has no runtime files.');
    }

    final Directory workspace = await Directory.systemTemp.createTemp('openaccounting-einvoice-validator-');
    try {
      for (final Object? rawEntry in runtimeFiles) {
        if (rawEntry is! Map<String, Object?>) {
          throw const FormatException('The packaged validator manifest contains an invalid file entry.');
        }
        final Object? pathValue = rawEntry['path'];
        final Object? digestValue = rawEntry['sha256'];
        if (pathValue is! String || digestValue is! String || !_isSafeAssetPath(pathValue)) {
          throw const FormatException('The packaged validator manifest contains an unsafe file entry.');
        }
        final ByteData data = await _assetBundle.load('$_assetPrefix$pathValue');
        final Uint8List bytes = _byteDataBytes(data);
        if (sha256.convert(bytes).toString() != digestValue) {
          throw FormatException('The packaged validator file checksum does not match: $pathValue');
        }
        final File output = File(p.join(workspace.path, pathValue));
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes, flush: true);
      }
      return workspace;
    } on Object {
      if (workspace.existsSync()) workspace.deleteSync(recursive: true);
      rethrow;
    }
  }

  EInvoiceOfflineXmlValidationResult _parseReport(String source) {
    final XmlElement root = XmlDocument.parse(source).rootElement;
    if (root.name.local != 'report' || root.name.namespaceUri != _reportNamespace) {
      throw const FormatException('The offline validator returned an unrecognized report.');
    }
    final String? validValue = root.getAttribute('valid');
    if (validValue != 'true' && validValue != 'false') {
      throw const FormatException('The offline validator report has no validity result.');
    }
    final List<EInvoiceOfflineXmlDiagnostic> diagnostics = root.descendants
        .whereType<XmlElement>()
        .where((XmlElement element) => element.name.local == 'message' && element.name.namespaceUri == _reportNamespace)
        .map(
          (XmlElement element) => EInvoiceOfflineXmlDiagnostic(
            code: element.getAttribute('code') ?? 'VALIDATION_MESSAGE',
            level: element.getAttribute('level') ?? 'information',
            message: element.innerText.trim(),
          ),
        )
        .toList(growable: false);
    final List<EInvoiceOfflineXmlValidationStep> steps = root.descendants
        .whereType<XmlElement>()
        .where(
          (XmlElement element) =>
              element.name.local == 'validationStepResult' && element.name.namespaceUri == _reportNamespace,
        )
        .map(
          (XmlElement element) => EInvoiceOfflineXmlValidationStep(
            id: element.getAttribute('id') ?? 'unknown',
            valid: element.getAttribute('valid') == 'true',
          ),
        )
        .toList(growable: false);
    final String? engineVersion = root.descendants
        .whereType<XmlElement>()
        .where((XmlElement element) => element.name.local == 'name' && element.name.namespaceUri == _reportNamespace)
        .map((XmlElement element) => element.innerText.trim())
        .firstOrNull;
    final XmlElement? matchedScenario = root.descendants
        .whereType<XmlElement>()
        .where(
          (XmlElement element) => element.name.local == 'scenario' && element.name.namespaceUri == _scenarioNamespace,
        )
        .firstOrNull;
    final String? scenarioName = matchedScenario?.children
        .whereType<XmlElement>()
        .where((XmlElement element) => element.name.local == 'name' && element.name.namespaceUri == _scenarioNamespace)
        .map((XmlElement element) => element.innerText.trim())
        .firstOrNull;
    final XmlElement? assessment = root.children
        .whereType<XmlElement>()
        .where(
          (XmlElement element) => element.name.local == 'assessment' && element.name.namespaceUri == _reportNamespace,
        )
        .firstOrNull;
    final List<XmlElement> verdicts =
        assessment?.children
            .whereType<XmlElement>()
            .where(
              (XmlElement element) =>
                  element.name.namespaceUri == _reportNamespace &&
                  (element.name.local == 'accept' || element.name.local == 'reject'),
            )
            .toList(growable: false) ??
        const <XmlElement>[];
    if (verdicts.length != 1) {
      throw const FormatException('The offline validator report has no unambiguous acceptance verdict.');
    }
    final bool accepted = verdicts.single.name.local == 'accept';

    // KoSIT's generic validity attribute follows finding severity; the explicit
    // assessment verdict honors warnings that the selected scenario accepts.
    if (accepted) {
      return EInvoiceOfflineXmlValidationResult(
        status: EInvoiceOfflineXmlValidationStatus.valid,
        message: 'XML passed the pinned schema and business-rule validation.',
        engineVersion: engineVersion,
        scenarioName: scenarioName,
        diagnostics: diagnostics,
        steps: steps,
      );
    }
    final List<EInvoiceOfflineXmlDiagnostic> findings = diagnostics.isEmpty
        ? const <EInvoiceOfflineXmlDiagnostic>[
            EInvoiceOfflineXmlDiagnostic(
              code: 'VALIDATION_REJECTED',
              level: 'error',
              message: 'The selected profile rejected the XML document.',
            ),
          ]
        : diagnostics;
    return EInvoiceOfflineXmlValidationResult(
      status: EInvoiceOfflineXmlValidationStatus.invalid,
      message: 'XML did not pass the pinned schema and business-rule validation.',
      engineVersion: engineVersion,
      scenarioName: scenarioName,
      diagnostics: findings,
      steps: steps,
    );
  }

  EInvoiceOfflineXmlValidationResult _invalid(String code, String level, String message) {
    return EInvoiceOfflineXmlValidationResult(
      status: EInvoiceOfflineXmlValidationStatus.invalid,
      message: message,
      diagnostics: <EInvoiceOfflineXmlDiagnostic>[
        EInvoiceOfflineXmlDiagnostic(code: code, level: level, message: message),
      ],
    );
  }

  EInvoiceOfflineXmlValidationResult _unavailable(String message) {
    return EInvoiceOfflineXmlValidationResult(status: EInvoiceOfflineXmlValidationStatus.unavailable, message: message);
  }

  int _nextRunNumber() => ++_runNumber;

  bool _isSafeAssetPath(String value) {
    final String normalized = p.normalize(value);
    return value.isNotEmpty &&
        !p.isAbsolute(value) &&
        normalized == value &&
        normalized != '.' &&
        !normalized.startsWith('..');
  }

  Uint8List _byteDataBytes(ByteData data) => Uint8List.view(data.buffer, data.offsetInBytes, data.lengthInBytes);

  String _trimProcessOutput(String output) {
    final String trimmed = output.trim();
    if (trimmed.length <= 500) return trimmed;
    return '${trimmed.substring(0, 500)}…';
  }
}
