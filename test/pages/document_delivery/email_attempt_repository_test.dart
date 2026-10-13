import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/document_delivery/artifact_resolver.dart';
import 'package:openaccounting/features/document_delivery/document_delivery_context.dart';
import 'package:openaccounting/features/document_delivery/document_delivery_service.dart';
import 'package:openaccounting/features/document_delivery/document_delivery_types.dart';
import 'package:openaccounting/features/document_delivery/email_attempt_repository.dart';
import 'package:openaccounting/features/document_delivery/email_template_service.dart';
import 'package:openaccounting/features/document_delivery/smtp_configuration_service.dart';
import 'package:openaccounting/features/document_delivery/smtp_credential_vault.dart';
import 'package:openaccounting/features/document_delivery/smtp_transport.dart';
import 'package:openaccounting/features/mahnwesen/mahnstufen_repository.dart';

void main() {
  group('Record truthful SMTP send outcomes', () {
    late AppDatabase db;
    late EmailAttemptRepository attempts;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      attempts = EmailAttemptRepository(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> seedRechnung({String? ausgegebenAm}) async {
      final int kundeId = await db.executor.runInsert(
        'INSERT INTO kunden (name, strasse, plz, ort, land, anrede, email) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>['Muster GmbH', 'Musterstr 1', '10115', 'Berlin', 'DE', 'Frau', 'kunde@example.de'],
      );
      return db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, '
        'faelligkeit, brutto_betrag, ausgegeben_am) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>['RE-9', 'rechnung', 'offen', 0, 'netto', kundeId, '2026-03-01', '2026-03-15', '100.00', ausgegebenAm],
      );
    }

    Future<int> defaultMahnstufeId() async {
      final levels = await MahnstufenRepository(db.executor).list();
      return levels.first.id;
    }

    Future<String?> ausgegebenAm(int rechnungId) async {
      final List<Map<String, Object?>> rows = await db.executor.runSelect(
        'SELECT ausgegeben_am FROM rechnungen WHERE id = ?',
        <Object?>[rechnungId],
      );
      return rows.single['ausgegeben_am'] as String?;
    }

    test('test_smtp_acceptance_is_recorded_without_delivery_claim', () async {
      final int rechnungId = await seedRechnung();
      final EmailAttempt pending = await attempts.begin(
        dokumentId: rechnungId,
        dokumentTyp: 'rechnung',
        empfaenger: 'kunde@example.de',
        artefaktIds: const <String>['RE-9.pdf'],
      );
      expect(pending.ergebnis, EmailAttemptOutcome.submitting);
      final EmailAttempt done = await attempts.commitAccepted(pending.id);
      expect(done.ergebnis, EmailAttemptOutcome.accepted);
      final String? outputTime = await ausgegebenAm(rechnungId);
      expect(outputTime, isNotNull);
      final EmailAttempt repeated = await attempts.commitAccepted(pending.id);
      expect(repeated.ergebnis, EmailAttemptOutcome.accepted);
      expect(await ausgegebenAm(rechnungId), outputTime);
      await expectLater(
        db.executor.runUpdate('UPDATE rechnungen SET ausgegeben_am = ? WHERE id = ?', <Object?>[
          '2026-05-01T00:00:00.000Z',
          rechnungId,
        ]),
        throwsA(predicate<Object>((Object error) => error.toString().contains('Dokument ist bereits finalisiert'))),
      );
      final List<Map<String, Object?>> columns = await db.executor.runSelect(
        'PRAGMA table_info(dokument_email_versuche)',
        const <Object?>[],
      );
      final Set<String> names = <String>{for (final Map<String, Object?> c in columns) '${c['name']}'};
      expect(names.intersection(<String>{'text', 'koerper', 'body', 'anhang_bytes', 'passwort', 'password'}), isEmpty);
    });

    test('test_missing_firma_placeholder_still_blocks_message_preparation', () {
      expect(
        () => const EmailTemplateRenderer().render(
          template: const DeliveryTemplateValues(subject: 'RE-9', body: '{firma}'),
          dokumentnummer: 'RE-9',
          betrag: 100,
        ),
        throwsA(
          isA<DocumentDeliveryException>().having(
            (DocumentDeliveryException error) => error.code,
            'code',
            'platzhalter_fehlt',
          ),
        ),
      );
    });

    test('test_explicit_server_rejection_is_recorded', () async {
      final int rechnungId = await seedRechnung();
      final EmailAttempt pending = await attempts.begin(
        dokumentId: rechnungId,
        dokumentTyp: 'rechnung',
        empfaenger: 'kunde@example.de',
        artefaktIds: const <String>['RE-9.pdf'],
      );
      final EmailAttempt done = await attempts.finish(
        pending.id,
        EmailAttemptOutcome.rejected,
        fehlerKategorie: SmtpFailureKind.rejected,
      );
      expect(done.ergebnis, EmailAttemptOutcome.rejected);
      expect(done.fehlerKategorie, SmtpFailureKind.rejected);
      expect(await ausgegebenAm(rechnungId), isNull);
    });

    test('test_unknown_attempt_does_not_claim_invoice_output', () async {
      final int rechnungId = await seedRechnung();
      final EmailAttempt pending = await attempts.begin(
        dokumentId: rechnungId,
        dokumentTyp: 'rechnung',
        empfaenger: 'kunde@example.de',
        artefaktIds: const <String>['RE-9.pdf'],
      );
      final EmailAttempt done = await attempts.finish(
        pending.id,
        EmailAttemptOutcome.unknown,
        fehlerKategorie: SmtpFailureKind.ambiguous,
      );
      expect(done.ergebnis, EmailAttemptOutcome.unknown);
      expect(await ausgegebenAm(rechnungId), isNull);
    });

    test('test_lost_response_after_submission_is_ambiguous', () async {
      final int rechnungId = await seedRechnung();
      final EmailAttempt pending = await attempts.begin(
        dokumentId: rechnungId,
        dokumentTyp: 'rechnung',
        empfaenger: 'kunde@example.de',
        artefaktIds: const <String>['RE-9.pdf'],
      );
      final EmailAttempt done = await attempts.finish(
        pending.id,
        EmailAttemptOutcome.unknown,
        fehlerKategorie: SmtpFailureKind.ambiguous,
      );
      expect(done.ergebnis, EmailAttemptOutcome.unknown);
      expect(done.fehlerKategorie, SmtpFailureKind.ambiguous);
      expect(await ausgegebenAm(rechnungId), isNull);
    });

    test('test_no_automatic_retry_follows_a_temporary_failure', () async {
      final int rechnungId = await seedRechnung();
      final EmailAttempt pending = await attempts.begin(
        dokumentId: rechnungId,
        dokumentTyp: 'rechnung',
        empfaenger: 'kunde@example.de',
        artefaktIds: const <String>['RE-9.pdf'],
      );
      await attempts.finish(pending.id, EmailAttemptOutcome.rejected, fehlerKategorie: 'voruebergehend');
      final int recovered = await attempts.recoverIncomplete();
      expect(recovered, 0);
      expect(await attempts.historyFor(rechnungId), hasLength(1));
    });

    test('test_incomplete_attempt_recovers_as_unknown', () async {
      final int rechnungId = await seedRechnung();
      await attempts.begin(
        dokumentId: rechnungId,
        dokumentTyp: 'rechnung',
        empfaenger: 'kunde@example.de',
        artefaktIds: const <String>['RE-9.pdf'],
      );
      final int recovered = await attempts.recoverIncomplete();
      expect(recovered, 1);
      final List<EmailAttempt> history = await attempts.historyFor(rechnungId);
      expect(history, hasLength(1));
      expect(history.single.ergebnis, EmailAttemptOutcome.unknown);
      expect(await ausgegebenAm(rechnungId), isNull);
    });

    test('test_duplicate_ui_submission_does_not_send_twice', () async {
      final Directory profile = await Directory.systemTemp.createTemp('doc-dedup-test-');
      try {
        await Directory('${profile.path}/pdfs').create(recursive: true);
        await File('${profile.path}/pdfs/re-1.pdf').writeAsBytes(<int>[0x25, 0x50, 0x44, 0x46]);
        final FakeSmtpTransport transport = FakeSmtpTransport();
        final Completer<void> gate = Completer<void>();
        transport.gate = gate.future;
        final InMemoryVault vault = InMemoryVault();
        final DocumentDeliveryService service = DocumentDeliveryService(
          contexts: DocumentDeliveryContextProvider(db.executor),
          templates: EmailTemplateRepository(db.executor),
          artifacts: DocumentArtifactResolver(db.executor, profileDir: profile.path),
          attempts: attempts,
          configuration: SmtpConfigurationService(
            executor: db.executor,
            transport: transport,
            migration: SmtpCredentialMigration(
              vault: vault,
              legacyFile: LegacySecretFile(profile.path),
              identity: ProfileIdentityStore(profile.path),
            ),
          ),
        );
        await db.executor.runInsert('INSERT INTO unternehmen (id, name) VALUES (?, ?)', <Object?>[1, 'Muster GmbH']);
        await db.executor.runUpdate(
          'UPDATE unternehmen SET smtp_host = ?, smtp_port = ?, smtp_ssl = ?, smtp_user = ?, '
          'smtp_von_adresse = ? WHERE id = 1',
          <Object?>['mail.example.de', 587, 0, 'sender@example.de', 'sender@example.de'],
        );
        final SmtpCredentialMigration migration = SmtpCredentialMigration(
          vault: vault,
          legacyFile: LegacySecretFile(profile.path),
          identity: ProfileIdentityStore(profile.path),
        );
        await migration.vault.write(profileId: await migration.identity.ensureProfileId(), password: 'dedup-geheim-1');
        await service.configuration.migrateBeforeDatabaseOpen();
        final int kundeId = await db.executor.runInsert(
          'INSERT INTO kunden (name, strasse, plz, ort, land, anrede, email) VALUES (?, ?, ?, ?, ?, ?, ?)',
          <Object?>['Muster GmbH', 'Musterstr 1', '10115', 'Berlin', 'DE', 'Frau', 'kunde@example.de'],
        );
        final int rechnungId = await db.executor.runInsert(
          'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, '
          'faelligkeit, brutto_betrag, original_pdf_pfad) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            'RE-1',
            'rechnung',
            'offen',
            0,
            'netto',
            kundeId,
            '2026-03-01',
            '2026-03-15',
            '50.00',
            'pdfs/re-1.pdf',
          ],
        );
        final ReviewedDocumentMessage preview = await service.prepare(dokumentId: rechnungId);
        final Future<EmailAttempt> first = service.sendConfirmed(preview);
        final Future<EmailAttempt> second = service.sendConfirmed(preview);
        gate.complete();
        final List<EmailAttempt> both = await Future.wait(<Future<EmailAttempt>>[first, second]);
        expect(both[0].id, both[1].id);
        expect(transport.submitCalls, 1);
        expect(transport.dataCommands, 1);
      } finally {
        try {
          await profile.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('test_accepted_dunning_outcome_and_owner_projection_commit_atomically', () async {
      final int rechnungId = await seedRechnung();
      final int stufeId = await defaultMahnstufeId();
      final List<Map<String, Object?>> kunden = await db.executor.runSelect(
        'SELECT kunde_id FROM rechnungen WHERE id = ?',
        <Object?>[rechnungId],
      );
      final int mahnungId = await db.executor.runInsert(
        'INSERT INTO mahnungen (rechnung_id, kunde_id, stufe_id, datum, betrag, gebuehr, zinsen, status) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[rechnungId, kunden.single['kunde_id'], stufeId, '2026-04-01', '100.00', '5.00', '0.00', 'offen'],
      );
      final EmailAttempt pending = await attempts.begin(
        dokumentId: rechnungId,
        dokumentTyp: 'rechnung',
        empfaenger: 'kunde@example.de',
        artefaktIds: const <String>['RE-9.pdf'],
        mahnungId: mahnungId,
        idempotenzSchluessel: 'mahnung-$mahnungId-versuch-1',
      );
      final EmailAttempt done = await attempts.commitAccepted(
        pending.id,
        ownerProjection: (TransactionExecutor transaction) async {
          await transaction.runUpdate("UPDATE mahnungen SET status = 'versendet' WHERE id = ?", <Object?>[mahnungId]);
          await transaction.runUpdate('UPDATE rechnungen SET mahnstufe_aktuell = 1 WHERE id = ?', <Object?>[
            rechnungId,
          ]);
        },
      );
      expect(done.ergebnis, EmailAttemptOutcome.accepted);
      final List<Map<String, Object?>> mahnung = await db.executor.runSelect(
        'SELECT status FROM mahnungen WHERE id = ?',
        <Object?>[mahnungId],
      );
      expect(mahnung.single['status'], 'versendet');

      final EmailAttempt pending2 = await attempts.begin(
        dokumentId: rechnungId,
        dokumentTyp: 'rechnung',
        empfaenger: 'kunde@example.de',
        artefaktIds: const <String>['RE-9.pdf'],
        idempotenzSchluessel: 'mahnung-$mahnungId-versuch-2',
      );
      Object? projectionError;
      try {
        await attempts.commitAccepted(
          pending2.id,
          ownerProjection: (TransactionExecutor transaction) async {
            await transaction.runUpdate("UPDATE mahnungen SET status = 'versendet' WHERE id = ?", <Object?>[mahnungId]);
            throw StateError('Projektion abgestürzt');
          },
        );
      } catch (error) {
        projectionError = error;
      }
      expect(projectionError, isStateError);
      final EmailAttempt? rolledBack = await attempts.findById(pending2.id);
      expect(rolledBack?.ergebnis, EmailAttemptOutcome.submitting);
    });

    test('test_crash_after_smtp_acceptance_does_not_retry_or_duplicate_a_reminder', () async {
      final int rechnungId = await seedRechnung();
      final int stufeId = await defaultMahnstufeId();
      final List<Map<String, Object?>> kunden = await db.executor.runSelect(
        'SELECT kunde_id FROM rechnungen WHERE id = ?',
        <Object?>[rechnungId],
      );
      final int mahnungId = await db.executor.runInsert(
        'INSERT INTO mahnungen (rechnung_id, kunde_id, stufe_id, datum, betrag, gebuehr, zinsen, status) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[rechnungId, kunden.single['kunde_id'], stufeId, '2026-04-01', '100.00', '5.00', '0.00', 'offen'],
      );
      await attempts.begin(
        dokumentId: rechnungId,
        dokumentTyp: 'rechnung',
        empfaenger: 'kunde@example.de',
        artefaktIds: const <String>['RE-9.pdf'],
        mahnungId: mahnungId,
        idempotenzSchluessel: 'mahnung-$mahnungId-absturz-1',
      );
      // Crash before the accepted-outcome transaction commits.
      expect(await attempts.recoverIncomplete(), 1);
      final List<EmailAttempt> history = await attempts.historyFor(rechnungId);
      expect(history, hasLength(1));
      expect(history.single.ergebnis, EmailAttemptOutcome.unknown);
      expect(history.single.mahnungId, mahnungId);
      final List<Map<String, Object?>> mahnungen = await db.executor.runSelect(
        'SELECT COUNT(*) AS anzahl FROM mahnungen WHERE rechnung_id = ?',
        <Object?>[rechnungId],
      );
      expect(mahnungen.single['anzahl'], 1);

      final DocumentDeliveryService service = DocumentDeliveryService(
        contexts: DocumentDeliveryContextProvider(db.executor),
        templates: EmailTemplateRepository(db.executor),
        artifacts: DocumentArtifactResolver(db.executor),
        attempts: attempts,
        configuration: SmtpConfigurationService(
          executor: db.executor,
          transport: FakeSmtpTransport(),
          migration: SmtpCredentialMigration(
            vault: InMemoryVault(),
            legacyFile: const _NoLegacy(),
            identity: const _NoIdentity(),
          ),
        ),
      );
      final ReviewedDocumentMessage retry = ReviewedDocumentMessage(
        context: DocumentDeliveryContext(
          dokumentId: rechnungId,
          dokumentTyp: 'rechnung',
          dokumentnummer: 'RE-9',
          betrag: 100,
          faelligkeit: null,
          firma: null,
          empfaenger: 'kunde@example.de',
          hauptArtefaktPfad: 'pdfs/RE-9.pdf',
          istEntwurf: false,
        ),
        absender: 'sender@example.de',
        empfaenger: 'kunde@example.de',
        betreff: 'Rechnung RE-9',
        text: 'Bitte zahlen.',
        artefakte: const <ResolvedArtifact>[],
        vorlageUnveraendert: true,
      );
      try {
        await service.sendConfirmed(retry);
        fail('unknown attempt requires duplicate-risk confirmation');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, 'doppelrisiko');
      }
    });
  });
}

class _NoLegacy extends LegacySecretFile {
  const _NoLegacy() : super(null);
}

class _NoIdentity extends ProfileIdentityStore {
  const _NoIdentity() : super(null);
}
