import 'dart:io';

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
import 'package:openaccounting/pages/rechnungen/rechnungen_datasource.dart';

void main() {
  group('Review a safe document message before sending', () {
    late AppDatabase db;
    late Directory profileDir;
    late FakeSmtpTransport transport;
    late InMemoryVault vault;
    late DocumentDeliveryService service;

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      await RechnungenDataSource(db.executor).findRechnungById(0);
      await db.executor.runInsert('INSERT INTO unternehmen (id, name) VALUES (?, ?)', <Object?>[1, 'Muster GmbH']);
      profileDir = await Directory.systemTemp.createTemp('doc-review-test-');
      await Directory('${profileDir.path}/pdfs').create(recursive: true);
      transport = FakeSmtpTransport();
      vault = InMemoryVault();
      service = DocumentDeliveryService(
        contexts: DocumentDeliveryContextProvider(db.executor),
        templates: EmailTemplateRepository(db.executor),
        artifacts: DocumentArtifactResolver(db.executor, profileDir: profileDir.path),
        attempts: EmailAttemptRepository(db.executor),
        configuration: SmtpConfigurationService(
          executor: db.executor,
          transport: transport,
          migration: SmtpCredentialMigration(
            vault: vault,
            legacyFile: LegacySecretFile(profileDir.path),
            identity: ProfileIdentityStore(profileDir.path),
          ),
        ),
      );
      final SmtpCredentialMigration migration = SmtpCredentialMigration(
        vault: vault,
        legacyFile: LegacySecretFile(profileDir.path),
        identity: ProfileIdentityStore(profileDir.path),
      );
      await migration.vault.write(profileId: await migration.identity.ensureProfileId(), password: 'review-geheim-1');
      await db.executor.runUpdate(
        'UPDATE unternehmen SET smtp_host = ?, smtp_port = ?, smtp_ssl = ?, smtp_user = ?, '
        'smtp_von_adresse = ? WHERE id = 1',
        <Object?>['mail.example.de', 587, 0, 'sender@example.de', 'sender@example.de'],
      );
      await service.configuration.migrateBeforeDatabaseOpen();
    });

    tearDown(() async {
      await db.close();
      try {
        await profileDir.delete(recursive: true);
      } catch (_) {}
    });

    Future<int> seedKunde({String email = 'kunde@example.de'}) async {
      return db.executor.runInsert(
        'INSERT INTO kunden (name, strasse, plz, ort, land, anrede, email) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>['Muster GmbH', 'Musterstr 1', '10115', 'Berlin', 'DE', 'Frau', email],
      );
    }

    Future<int> seedRechnung({
      required int kundeId,
      String typ = 'rechnung',
      bool entwurf = false,
      String? pdfName = 're-1.pdf',
    }) async {
      final int id = await db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, '
        'faelligkeit, brutto_betrag, original_pdf_pfad) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          'RE-2026-7',
          typ,
          if (entwurf) 'entwurf' else 'offen',
          if (entwurf) 1 else 0,
          'netto',
          kundeId,
          '2026-03-01',
          '2026-03-15',
          '299.00',
          if (pdfName == null) null else 'pdfs/$pdfName',
        ],
      );
      if (pdfName != null) {
        await File('${profileDir.path}/pdfs/$pdfName').writeAsBytes(<int>[0x25, 0x50, 0x44, 0x46]);
      }
      return id;
    }

    test('test_confirm_a_reviewed_document_message', () async {
      final int kundeId = await seedKunde();
      final int id = await seedRechnung(kundeId: kundeId);
      final ReviewedDocumentMessage preview = await service.prepare(dokumentId: id);
      expect(preview.empfaenger, 'kunde@example.de');
      expect(preview.betreff, contains('RE-2026-7'));
      expect(preview.absender, 'sender@example.de');
      expect(preview.artefakte, hasLength(1));
      final EmailAttempt attempt = await service.sendConfirmed(preview);
      expect(attempt.ergebnis, EmailAttemptOutcome.accepted);
      expect(transport.submitCalls, 1);
      expect(transport.lastMail?.recipient, 'kunde@example.de');
      expect(transport.lastMail?.subject, preview.betreff);
      expect(transport.lastMail?.body, preview.text);
      expect(transport.lastMail?.sender, 'sender@example.de');
      expect(transport.lastMail?.attachments, hasLength(1));
    });

    test('test_block_draft_invalid_recipient_or_missing_artifact', () async {
      final int kundeId = await seedKunde();
      final int draftId = await seedRechnung(kundeId: kundeId, entwurf: true);
      try {
        await service.prepare(dokumentId: draftId);
        fail('draft must block');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, 'entwurf');
      }
      final int badMailKunde = await seedKunde(email: 'keine-adresse');
      final int badMailId = await seedRechnung(kundeId: badMailKunde, pdfName: 're-bad.pdf');
      try {
        await service.prepare(dokumentId: badMailId);
        fail('invalid recipient must block');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, anyOf('empfaenger_ungueltig', 'empfaenger_fehlt'));
      }
      final int noPdfId = await seedRechnung(kundeId: kundeId, pdfName: null);
      try {
        await service.prepare(dokumentId: noPdfId);
        fail('missing artifact must block');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, 'artefakt_fehlt');
      }
      expect(transport.submitCalls, 0);
      expect(transport.dataCommands, 0);
    });

    test('test_reject_arbitrary_filesystem_attachment', () async {
      final int kundeId = await seedKunde();
      final int id = await seedRechnung(kundeId: kundeId);
      try {
        await service.prepare(
          dokumentId: id,
          zusatzArtefakte: <DocumentArtifactRef>[DocumentArtifactRef(dokumentId: id + 9999)],
        );
        fail('arbitrary reference must be rejected');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, anyOf('artefakt_fremd', 'dokument_fehlt'));
      }
      final ReviewedDocumentMessage preview = await service.prepare(dokumentId: id);
      expect(preview.artefakte, hasLength(1));
      expect(transport.submitCalls, 0);
    });

    test('test_reject_attachment_owned_by_another_document', () async {
      final int kundeId = await seedKunde();
      final int first = await seedRechnung(kundeId: kundeId, pdfName: 're-first.pdf');
      final int second = await seedRechnung(kundeId: kundeId, pdfName: 're-second.pdf');
      try {
        await service.prepare(
          dokumentId: first,
          zusatzArtefakte: <DocumentArtifactRef>[DocumentArtifactRef(dokumentId: first, bezugDokumentId: second)],
        );
        fail('foreign artifact must be rejected');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, 'artefakt_fremd');
      }
      expect(transport.submitCalls, 0);
    });

    test('test_reject_artifact_symlink_escaping_the_profile_root', () async {
      final Directory outside = await Directory.systemTemp.createTemp('doc-escape-');
      try {
        final File target = File('${outside.path}/evil.pdf');
        await target.writeAsBytes(<int>[0x25, 0x50, 0x44, 0x46]);
        final Link link = Link('${profileDir.path}/pdfs/link.pdf');
        await link.create(target.path);
        final int kundeId = await seedKunde();
        final int id = await seedRechnung(kundeId: kundeId, pdfName: 'link.pdf');
        try {
          await service.prepare(dokumentId: id);
          fail('escaping symlink must be rejected');
        } on DocumentDeliveryException catch (error) {
          expect(error.code, anyOf('artefakt_symlink', 'artefakt_fehlt', 'artefakt_ausserhalb'));
        }
        expect(transport.submitCalls, 0);
      } finally {
        try {
          await outside.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('test_reject_invalid_sender_or_recipient_mailbox_headers', () async {
      final int kundeId = await seedKunde();
      final int id = await seedRechnung(kundeId: kundeId);
      await db.executor.runUpdate('UPDATE unternehmen SET smtp_von_adresse = ? WHERE id = 1', const <Object?>[
        'sender@example.de\nBcc: evil@example.de',
      ]);
      try {
        await service.prepare(dokumentId: id);
        fail('sender line break must be rejected before MIME');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, 'kopfzeilenumbruch');
      }
      await db.executor.runUpdate('UPDATE unternehmen SET smtp_von_adresse = ? WHERE id = 1', const <Object?>[
        'sender@example.de',
      ]);
      try {
        await service.prepare(dokumentId: id, empfaengerOverride: 'a@example.de, b@example.de');
        fail('recipient list must be rejected');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, 'adresse_mehrfach');
      }
      try {
        await service.prepare(dokumentId: id, empfaengerOverride: 'evil@example.de\nBcc: x@y.de');
        fail('recipient line break must be rejected');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, anyOf('kopfzeilenumbruch', 'adresse_ungueltig'));
      }
      expect(transport.submitCalls, 0);
      expect(transport.dataCommands, 0);
    });

    test('test_send_supported_document_from_its_detail_route', () async {
      final int kundeId = await seedKunde();
      for (final String typ in <String>['rechnung', 'angebot', 'auftrag', 'proforma']) {
        final int id = await seedRechnung(kundeId: kundeId, typ: typ, pdfName: 're-$typ.pdf');
        final ReviewedDocumentMessage preview = await service.prepare(dokumentId: id);
        expect(preview.context.dokumentId, id);
        expect(preview.context.dokumentTyp, typ);
        final EmailAttempt attempt = await service.sendConfirmed(preview);
        expect(attempt.ergebnis, EmailAttemptOutcome.accepted);
        expect(attempt.dokumentId, id);
      }
    });
  });
}
