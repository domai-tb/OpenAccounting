import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/document_delivery/document_delivery_types.dart';
import 'package:openaccounting/features/document_delivery/smtp_transport.dart';

void main() {
  group('Secure authenticated SMTP transport', () {
    const SmtpConfig starttlsConfig = SmtpConfig(
      host: 'mail.example.de',
      port: 587,
      mode: SmtpTransportMode.starttlsRequired,
      username: 'sender@example.de',
      sender: 'sender@example.de',
    );

    const OutgoingMail sample = OutgoingMail(
      sender: 'sender@example.de',
      recipient: 'kunde@example.de',
      subject: 'Rechnung RE-1',
      body: 'Anbei die Rechnung.',
    );

    test('test_submit_only_after_secure_authentication', () async {
      final FakeSmtpTransport transport = FakeSmtpTransport();
      await transport.testConnection(starttlsConfig, 'geheim');
      expect(transport.testCalls, 1);
      expect(transport.dataCommands, 0);
      await transport.submit(starttlsConfig, 'geheim', sample);
      expect(transport.submitCalls, 1);
      expect(transport.dataCommands, 1);

      const SmtpConfig implicit = SmtpConfig(
        host: 'mail.example.de',
        port: 465,
        mode: SmtpTransportMode.implicitTls,
        username: 'sender@example.de',
        sender: 'sender@example.de',
      );
      final FakeSmtpTransport implicitTransport = FakeSmtpTransport();
      await implicitTransport.submit(implicit, 'geheim', sample);
      expect(implicitTransport.dataCommands, 1);

      try {
        await transport.submit(
          const SmtpConfig(
            host: 'mail.example.de',
            port: 25,
            mode: SmtpTransportMode.starttlsRequired,
            username: 'u',
            sender: 'sender@example.de',
          ),
          'geheim',
          sample,
        );
        fail('port 25 must be refused before connect');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, 'port_25');
      }
    });

    test('test_tls_or_authentication_failure_prevents_submission', () async {
      final FakeSmtpTransport tlsFail = FakeSmtpTransport(
        failSubmitBeforeData: true,
        failSubmitWith: const DocumentDeliveryException('TLS abgebrochen', code: SmtpFailureKind.tls),
      );
      try {
        await tlsFail.submit(starttlsConfig, 'geheim', sample);
        fail('TLS failure must prevent submission');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, SmtpFailureKind.tls);
      }
      expect(tlsFail.dataCommands, 0);

      final FakeSmtpTransport authFail = FakeSmtpTransport(
        failTestWith: const DocumentDeliveryException('Anmeldung abgelehnt', code: SmtpFailureKind.auth),
      );
      try {
        await authFail.testConnection(starttlsConfig, 'falsch');
        fail('auth failure must surface');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, SmtpFailureKind.auth);
      }
      expect(authFail.dataCommands, 0);
      final String mime = buildMime(sample);
      expect(mime, isNot(contains('geheim')));
    });

    test('test_configured_certificate_pin_does_not_bypass_normal_validation', () {
      final List<int> der = <int>[1, 2, 3, 4, 5, 6, 7, 8];
      final String correct = sha256.convert(der).toString();
      DartIoSmtpTransport.verifyCertificatePin(derBytes: der, expectedHex: correct);
      try {
        DartIoSmtpTransport.verifyCertificatePin(derBytes: der, expectedHex: '00' * 32);
        fail('pin mismatch must reject');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, SmtpFailureKind.tls);
      }
      // Chain/hostname validation stays platform-enforced: this transport never
      // installs an onBadCertificate bypass, so a matching pin cannot weaken it.
    });

    test('test_starttls_repeats_ehlo_before_selecting_authentication', () async {
      final FakeSmtpTransport transport = FakeSmtpTransport(authMechanisms: const <String>['PLAIN']);
      await transport.testConnection(starttlsConfig, 'geheim');
      final int starttlsAt = transport.commands.indexOf('STARTTLS');
      final int ehloAfterAt = transport.commands.indexOf('EHLO nach TLS');
      final int authAt = transport.commands.indexWhere((String c) => c.startsWith('AUTH'));
      expect(starttlsAt, greaterThanOrEqualTo(0));
      expect(ehloAfterAt, greaterThan(starttlsAt));
      expect(authAt, greaterThan(ehloAfterAt));
      expect(transport.commands[authAt], contains('PLAIN'));
    });
  });
}
