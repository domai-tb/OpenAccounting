import 'dart:io';

import 'package:drift/drift.dart';
import 'package:openaccounting/features/document_delivery/document_delivery_types.dart';
import 'package:openaccounting/features/document_delivery/email_attempt_repository.dart';
import 'package:openaccounting/features/document_delivery/smtp_configuration_service.dart';
import 'package:openaccounting/features/document_delivery/smtp_transport.dart';
import 'package:openaccounting/features/mahnwesen/dunning_balance_source.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_entity.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_exception.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_repository.dart';
import 'package:path/path.dart' as p;

/// Outcome of a dunning send: transport acceptance or a retryable
/// unavailable result. A failed or unconfigured send leaves the Mahnung
/// unsent and retryable on the same record; it never advances the level.
sealed class DunningSendOutcome {
  const DunningSendOutcome();
}

class DunningSendAccepted extends DunningSendOutcome {
  const DunningSendAccepted(this.mahnung);

  final Mahnung mahnung;
}

class DunningSendUnavailable extends DunningSendOutcome {
  const DunningSendUnavailable(this.unavailable);

  final DunningUnavailable unavailable;
}

/// Sends a dunning letter only when SMTP is configured and a readable
/// generated PDF artifact is available. Records transport acceptance only
/// after the mail transport accepts the message with the expected attachment.
/// UI and history say "transport accepted", never delivered or read.
class DunningSendService {
  DunningSendService({
    required this.executor,
    required this.mahnungen,
    required this.configuration,
    required this.attempts,
    this.profileDir,
    this._transport,
  });

  final QueryExecutor executor;
  final MahnungenRepository mahnungen;
  final SmtpConfigurationService configuration;
  final EmailAttemptRepository attempts;
  final String? profileDir;
  final SmtpTransportAdapter? _transport;

  SmtpTransportAdapter get _adapter => _transport ?? configuration.transport;

  Future<DunningSendOutcome> sendMahnung({required int mahnungId, required String empfaenger}) async {
    final Mahnung? existing = await mahnungen.getById(mahnungId);
    if (existing == null) throw const MahnungException('Mahnung nicht gefunden');
    if (existing.status == 'versendet') {
      return DunningSendAccepted(existing);
    }
    // Idempotent recovery: an accepted attempt without a marked letter must
    // not resubmit; it only completes the local state.
    if (await _hasAcceptedAttempt(mahnungId)) {
      final Mahnung accepted = await mahnungen.markTransportAccepted(mahnungId, stufeNummer: _stufeNummer(existing));
      return DunningSendAccepted(accepted);
    }
    final _SmtpReady ready = await _smtpReady();
    if (!ready.ok) {
      return DunningSendUnavailable(DunningUnavailable(code: ready.code, message: ready.message));
    }
    late final String recipient;
    try {
      recipient = parseSingleMailbox(empfaenger, field: 'Empfänger');
    } on DocumentDeliveryException {
      return const DunningSendUnavailable(
        DunningUnavailable(
          code: 'empfaenger_ungueltig',
          message: 'Kein gültiger Empfänger. Prüfen und erneut versuchen.',
        ),
      );
    }
    final File? artifact = _readableArtifact(mahnungId);
    if (artifact == null) {
      return const DunningSendUnavailable(
        DunningUnavailable(
          code: 'artefakt_fehlt',
          message: 'Kein lesbares Mahn-PDF. PDF erzeugen und erneut versuchen.',
        ),
      );
    }
    final EmailAttempt attempt = await attempts.begin(
      dokumentId: existing.rechnungId,
      dokumentTyp: 'mahnung',
      empfaenger: recipient,
      artefaktIds: <String>[p.basename(artifact.path)],
      mahnungId: mahnungId,
    );
    try {
      await _adapter.submit(
        ready.config!,
        ready.password!,
        OutgoingMail(
          sender: ready.sender!,
          recipient: recipient,
          subject: 'Mahnung ${existing.id}',
          body: 'Sehr geehrte Damen und Herren,\n\nanbei erhalten Sie Ihre Mahnung.\n',
          attachments: <MailAttachment>[
            MailAttachment(filename: p.basename(artifact.path), bytes: await artifact.readAsBytes()),
          ],
        ),
      );
    } on SmtpRejected catch (error) {
      await attempts.finish(
        attempt.id,
        EmailAttemptOutcome.rejected,
        fehlerKategorie: error.temporary ? 'voruebergehend' : SmtpFailureKind.rejected,
      );
      return DunningSendUnavailable(
        DunningUnavailable(
          code: 'transport_abgelehnt',
          message: 'Versand abgelehnt (${error.reply}). Erneut versuchen.',
        ),
      );
    } on SmtpAmbiguous {
      await attempts.finish(attempt.id, EmailAttemptOutcome.unknown, fehlerKategorie: SmtpFailureKind.ambiguous);
      return const DunningSendUnavailable(
        DunningUnavailable(
          code: 'ergebnis_unklar',
          message: 'Versand unklar — vor erneutem Senden prüfen. Es wurde kein zweiter Datensatz angelegt.',
        ),
      );
    } on DocumentDeliveryException catch (error) {
      await attempts.finish(attempt.id, EmailAttemptOutcome.rejected, fehlerKategorie: error.code);
      return DunningSendUnavailable(
        DunningUnavailable(code: error.code, message: 'Versand fehlgeschlagen: ${error.message}'),
      );
    }
    // Record order: attempt accepted first, then the letter. A crash between
    // the two is recovered idempotently without a second DATA submission.
    await executor.runUpdate(
      "UPDATE dokument_email_versuche SET ergebnis = 'accepted', abgeschlossen_am = ? WHERE id = ?",
      <Object?>[DateTime.now().toUtc().toIso8601String(), attempt.id],
    );
    final Mahnung accepted = await mahnungen.markTransportAccepted(mahnungId, stufeNummer: _stufeNummer(existing));
    return DunningSendAccepted(accepted);
  }

  Future<bool> _hasAcceptedAttempt(int mahnungId) async {
    try {
      await attempts.ensureSchema();
      final List<Map<String, Object?>> rows = await executor.runSelect(
        "SELECT id FROM dokument_email_versuche WHERE mahnung_id = ? AND ergebnis = 'accepted' LIMIT 1",
        <Object?>[mahnungId],
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<_SmtpReady> _smtpReady() async {
    Map<String, Object?> row = const <String, Object?>{};
    try {
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT smtp_host, smtp_port, smtp_ssl, smtp_user, smtp_von_adresse, smtp_zertifikat_fingerprint, '
        'smtp_transport_modus FROM unternehmen WHERE id = 1',
        const <Object?>[],
      );
      if (rows.isNotEmpty) row = rows.single;
    } catch (_) {
      try {
        final List<Map<String, Object?>> rows = await executor.runSelect(
          'SELECT smtp_host, smtp_port, smtp_ssl, smtp_user, smtp_von_adresse, smtp_zertifikat_fingerprint '
          'FROM unternehmen WHERE id = 1',
          const <Object?>[],
        );
        if (rows.isNotEmpty) row = rows.single;
      } catch (_) {}
    }
    final String host = '${row['smtp_host'] ?? ''}'.trim();
    final String user = '${row['smtp_user'] ?? ''}'.trim();
    final String sender = '${row['smtp_von_adresse'] ?? ''}'.trim();
    if (host.isEmpty || user.isEmpty || sender.isEmpty) {
      return const _SmtpReady.notOk('smtp_nicht_konfiguriert', 'SMTP ist nicht konfiguriert. Einstellungen prüfen.');
    }
    String? password;
    try {
      password = await configuration.migration.readPassword();
    } catch (_) {
      password = null;
    }
    if (password == null || password.isEmpty) {
      return const _SmtpReady.notOk('smtp_nicht_konfiguriert', 'SMTP ist nicht konfiguriert. Einstellungen prüfen.');
    }
    final Object? portRaw = row['smtp_port'];
    final int port = portRaw is int ? portRaw : int.tryParse('$portRaw') ?? 587;
    final String? storedMode = row['smtp_transport_modus'] as String?;
    final String mode = storedMode != null && SmtpTransportMode.allowed.contains(storedMode)
        ? storedMode
        : SmtpTransportMode.fromLegacySsl(row['smtp_ssl']);
    try {
      final SmtpConfig config = SmtpConfig(
        host: host,
        port: port,
        mode: mode,
        username: user,
        sender: sender,
        fingerprintSha256: row['smtp_zertifikat_fingerprint'] as String?,
      );
      config.validateForConnect();
      parseSingleMailbox(sender, field: 'Absender');
      return _SmtpReady.ok(config, password, sender);
    } on DocumentDeliveryException catch (error) {
      return _SmtpReady.notOk(error.code, error.message);
    }
  }

  File? _readableArtifact(int mahnungId) {
    final String? root = profileDir;
    if (root == null || root.trim().isEmpty) return null;
    final String base = p.normalize(p.absolute(root));
    final String candidate = p.normalize(p.join(base, 'pdfs', 'Mahnung-$mahnungId.pdf'));
    if (!p.isWithin(base, candidate)) return null;
    if (FileSystemEntity.typeSync(candidate, followLinks: false) != FileSystemEntityType.file) return null;
    try {
      if (File(candidate).readAsBytesSync().isEmpty) return null;
    } catch (_) {
      return null;
    }
    return File(candidate);
  }

  int _stufeNummer(Mahnung mahnung) {
    final Map<String, dynamic>? snapshot = mahnung.snapshotData;
    final Object? stufe = snapshot?['stufe'];
    if (stufe is num) return stufe.toInt();
    return int.tryParse('$stufe') ?? 0;
  }
}

class _SmtpReady {
  const _SmtpReady.ok(this.config, this.password, this.sender) : ok = true, code = '', message = '';
  const _SmtpReady.notOk(this.code, this.message) : ok = false, config = null, password = null, sender = null;

  final bool ok;
  final SmtpConfig? config;
  final String? password;
  final String? sender;
  final String code;
  final String message;
}
