import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/document_delivery/artifact_resolver.dart';
import 'package:openaccounting/features/document_delivery/document_delivery_context.dart';
import 'package:openaccounting/features/document_delivery/document_delivery_types.dart';
import 'package:openaccounting/features/document_delivery/email_attempt_repository.dart';
import 'package:openaccounting/features/document_delivery/email_template_service.dart';
import 'package:openaccounting/features/document_delivery/smtp_configuration_service.dart';
import 'package:openaccounting/features/document_delivery/smtp_credential_vault.dart';
import 'package:openaccounting/features/document_delivery/smtp_transport.dart';

// Registered document-delivery application service: the single SMTP contract
// for templates, reviewed preview, secure transport, and truthful outcomes.
// Sending is always a user action — finalization, dunning stages, and startup
// never submit. Widgets call this service; they never issue SQL or sockets.

class ReviewedDocumentMessage {
  const ReviewedDocumentMessage({
    required this.context,
    required this.absender,
    required this.empfaenger,
    required this.betreff,
    required this.text,
    required this.artefakte,
    required this.vorlageUnveraendert,
  });

  final DocumentDeliveryContext context;
  final String absender;
  final String empfaenger;
  final String betreff;
  final String text;
  final List<ResolvedArtifact> artefakte;
  final bool vorlageUnveraendert;
}

class DocumentDeliveryService {
  DocumentDeliveryService({
    required this.contexts,
    required this.templates,
    required this.artifacts,
    required this.attempts,
    required this.configuration,
    this.renderer = const EmailTemplateRenderer(),
  });

  final DocumentDeliveryContextProvider contexts;
  final EmailTemplateRepository templates;
  final DocumentArtifactResolver artifacts;
  final EmailAttemptRepository attempts;
  final SmtpConfigurationService configuration;
  final EmailTemplateRenderer renderer;

  final Map<String, Future<EmailAttempt>> _inflight = <String, Future<EmailAttempt>>{};

  /// Prepares the exact reviewable message before any network access: sender,
  /// one recipient, expanded subject/body, document number, attachment names.
  /// Per-send edits are returned without touching the stored template.
  Future<ReviewedDocumentMessage> prepare({
    required int dokumentId,
    String? empfaengerOverride,
    String? betreffOverride,
    String? textOverride,
    List<DocumentArtifactRef>? zusatzArtefakte,
    String locale = 'de_DE',
  }) async {
    final DocumentDeliveryContext context = await contexts.load(dokumentId);
    final String? blocked = context.blockierGrund();
    if (blocked != null) {
      throw DocumentDeliveryException(_blockedMessage(blocked), code: blocked);
    }
    final String empfaenger = parseSingleMailbox(
      empfaengerOverride?.trim().isNotEmpty == true ? empfaengerOverride! : context.empfaenger!,
      field: 'Empfänger',
    );
    final DeliveryTemplateValues template = await templates.loadOrSeed(context.dokumentTyp);
    final String subjectSource = betreffOverride ?? template.subject;
    final String bodySource = textOverride ?? template.body;
    requireHeaderLine(subjectSource, field: 'Betreff');
    final RenderedTemplate rendered = renderer.render(
      template: DeliveryTemplateValues(subject: subjectSource, body: bodySource),
      dokumentnummer: context.dokumentnummer,
      betrag: context.betrag,
      faelligkeit: context.faelligkeit,
      firma: context.firma,
      locale: locale,
    );
    final Map<String, Object?> settings = await _senderSettings();
    final String absender = parseSingleMailbox('${settings['smtp_von_adresse'] ?? ''}', field: 'Absender');
    final List<DocumentArtifactRef> refs = <DocumentArtifactRef>[
      DocumentArtifactRef(dokumentId: dokumentId),
      ...?zusatzArtefakte,
    ];
    final List<ResolvedArtifact> artefakte = await artifacts.resolveAll(dokumentId, refs);
    return ReviewedDocumentMessage(
      context: context,
      absender: absender,
      empfaenger: empfaenger,
      betreff: rendered.subject,
      text: rendered.body,
      artefakte: artefakte,
      vorlageUnveraendert: betreffOverride == null && textOverride == null,
    );
  }

  /// Sends a reviewed message after explicit confirmation. Duplicate calls
  /// while an attempt is in progress share that attempt: no second DATA.
  /// Retrying an `unknown` attempt needs [doppeltesRisikoBestaetigt].
  Future<EmailAttempt> sendConfirmed(
    ReviewedDocumentMessage message, {
    bool doppeltesRisikoBestaetigt = false,
    int? mahnungId,
  }) {
    if (mahnungId != null || message.context.dokumentTyp == DocumentEmailType.mahnung) {
      throw const DocumentDeliveryException('Mahnung-Versand ist noch nicht verfügbar', code: 'typ_zurueckgestellt');
    }
    final String contentKey = _contentKey(message);
    final Future<EmailAttempt>? running = _inflight[contentKey];
    if (running != null) return running;
    final Future<EmailAttempt> job = _send(message, doppeltesRisikoBestaetigt: doppeltesRisikoBestaetigt);
    _inflight[contentKey] = job;
    unawaited(
      job.then<void>(
        (_) {
          _inflight.remove(contentKey);
        },
        onError: (Object error, StackTrace stackTrace) {
          _inflight.remove(contentKey);
        },
      ),
    );
    return job;
  }

  Future<EmailAttempt> _send(ReviewedDocumentMessage message, {required bool doppeltesRisikoBestaetigt}) async {
    final List<EmailAttempt> history = await attempts.historyFor(message.context.dokumentId);
    final Iterable<EmailAttempt> unknown = history.where(
      (EmailAttempt attempt) =>
          attempt.ergebnis == EmailAttemptOutcome.unknown && attempt.empfaenger == message.empfaenger,
    );
    if (unknown.isNotEmpty && !doppeltesRisikoBestaetigt) {
      throw const DocumentDeliveryException(
        'Unklarer Vorversuch: erneutes Senden erst nach Bestätigung',
        code: 'doppelrisiko',
      );
    }
    final EmailAttempt attempt = await attempts.begin(
      dokumentId: message.context.dokumentId,
      dokumentTyp: message.context.dokumentTyp,
      empfaenger: message.empfaenger,
      artefaktIds: message.artefakte.map((ResolvedArtifact a) => a.dateiname).toList(growable: false),
    );
    final Map<String, Object?> settings = await _senderSettings();
    final String? password = await configuration.migration.readPassword();
    if (password == null || password.isEmpty) {
      return attempts.finish(attempt.id, EmailAttemptOutcome.rejected, fehlerKategorie: SmtpFailureKind.auth);
    }
    final SmtpConfig config = SmtpConfig(
      host: '${settings['smtp_host'] ?? ''}',
      port: _asPort(settings['smtp_port']),
      mode: '${settings['smtp_transport_modus'] ?? SmtpTransportMode.fromLegacySsl(settings['smtp_ssl'])}',
      username: '${settings['smtp_user'] ?? ''}',
      sender: message.absender,
      fingerprintSha256: settings['smtp_zertifikat_fingerprint'] as String?,
    );
    try {
      await configuration.transport.submit(
        config,
        password,
        OutgoingMail(
          sender: message.absender,
          recipient: message.empfaenger,
          subject: message.betreff,
          body: message.text,
          attachments: <MailAttachment>[
            for (final ResolvedArtifact artefakt in message.artefakte)
              MailAttachment(filename: artefakt.dateiname, bytes: await _readBytes(artefakt.pfad)),
          ],
        ),
      );
    } on SmtpRejected catch (error) {
      return attempts.finish(
        attempt.id,
        EmailAttemptOutcome.rejected,
        fehlerKategorie: error.temporary ? 'voruebergehend' : SmtpFailureKind.rejected,
      );
    } on SmtpAmbiguous {
      return attempts.finish(attempt.id, EmailAttemptOutcome.unknown, fehlerKategorie: SmtpFailureKind.ambiguous);
    } on DocumentDeliveryException catch (error) {
      // Proven before submission (TLS/auth/config): rejected, never unknown.
      final bool beforeData =
          error.code == SmtpFailureKind.tls ||
          error.code == SmtpFailureKind.auth ||
          error.code == SmtpFailureKind.hostUnreachable;
      return attempts.finish(
        attempt.id,
        beforeData ? EmailAttemptOutcome.rejected : EmailAttemptOutcome.unknown,
        fehlerKategorie: error.code,
      );
    }
    try {
      return await attempts.commitAccepted(attempt.id);
    } catch (_) {
      // Accepted by the server, but the local commit failed: ambiguous, and
      // recovery keeps the stable link without resubmitting.
      return attempts.finish(attempt.id, EmailAttemptOutcome.unknown, fehlerKategorie: SmtpFailureKind.ambiguous);
    }
  }

  String _contentKey(ReviewedDocumentMessage message) {
    final String raw =
        '${message.context.dokumentId}|${message.empfaenger}|${message.betreff}|${message.text}|'
        '${message.artefakte.map((ResolvedArtifact a) => a.pfad).join(',')}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Future<Map<String, Object?>> _senderSettings() async {
    try {
      final List<Map<String, Object?>> rows = await configuration.executor.runSelect(
        'SELECT smtp_host, smtp_port, smtp_ssl, smtp_user, smtp_von_adresse, smtp_zertifikat_fingerprint, '
        'smtp_transport_modus FROM unternehmen WHERE id = 1',
        const <Object?>[],
      );
      if (rows.isNotEmpty) return rows.single;
    } catch (_) {}
    return const <String, Object?>{};
  }

  static int _asPort(Object? value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 587;
  }

  static Future<List<int>> _readBytes(String path) {
    // Path was containment-verified by the artifact resolver.
    return File(path).readAsBytes();
  }

  static String _blockedMessage(String code) {
    return switch (code) {
      'entwurf' => 'Entwürfe können nicht versendet werden',
      'empfaenger_fehlt' => 'Kein gültiger Empfänger',
      'empfaenger_ungueltig' => 'Kein gültiger Empfänger',
      'artefakt_fehlt' => 'Kein erzeugtes PDF für dieses Dokument',
      'zurueckgestellt' => 'Versand für diesen Dokumenttyp noch nicht verfügbar',
      _ => 'Versand ist für dieses Dokument nicht möglich',
    };
  }
}

/// Registered providers: widgets resolve the delivery capability through
/// these instead of constructing repositories, SQL, or SMTP clients.
final smtpTransportProvider = Provider<SmtpTransportAdapter>((ref) => const DartIoSmtpTransport());

final credentialVaultProvider = Provider<SmtpCredentialVault>((ref) => const UnavailableVault());

final smtpConfigurationServiceProvider = Provider<SmtpConfigurationService>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return SmtpConfigurationService(
    executor: db.executor,
    transport: ref.watch(smtpTransportProvider),
    migration: SmtpCredentialMigration(
      vault: ref.watch(credentialVaultProvider),
      legacyFile: LegacySecretFile(db.profileDir),
      identity: ProfileIdentityStore(db.profileDir),
    ),
  );
});

final emailTemplateRepositoryProvider = Provider<EmailTemplateRepository>((ref) {
  return EmailTemplateRepository(ref.watch(appDatabaseProvider).executor);
});

final documentDeliveryContextProvider = Provider<DocumentDeliveryContextProvider>((ref) {
  return DocumentDeliveryContextProvider(ref.watch(appDatabaseProvider).executor);
});

final artifactResolverProvider = Provider<DocumentArtifactResolver>((ref) {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  return DocumentArtifactResolver(db.executor, profileDir: db.profileDir);
});

final emailAttemptRepositoryProvider = Provider<EmailAttemptRepository>((ref) {
  return EmailAttemptRepository(ref.watch(appDatabaseProvider).executor);
});

final documentDeliveryServiceProvider = Provider<DocumentDeliveryService>((ref) {
  return DocumentDeliveryService(
    contexts: ref.watch(documentDeliveryContextProvider),
    templates: ref.watch(emailTemplateRepositoryProvider),
    artifacts: ref.watch(artifactResolverProvider),
    attempts: ref.watch(emailAttemptRepositoryProvider),
    configuration: ref.watch(smtpConfigurationServiceProvider),
  );
});
