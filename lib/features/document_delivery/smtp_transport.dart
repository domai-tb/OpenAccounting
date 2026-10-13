import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:openaccounting/features/document_delivery/document_delivery_types.dart';

// Authenticated SMTP submission over verified TLS using dart:io only (no new
// dependencies in this change). Port 25/plaintext is refused before any
// connection; required STARTTLS never falls back; credentials are sent only
// after verified TLS. A configured SHA-256 fingerprint additionally constrains
// an otherwise valid certificate and never bypasses chain/hostname checks.

/// Explicit secure transport mode. There is no plaintext option.
class SmtpTransportMode {
  const SmtpTransportMode._();

  static const String implicitTls = 'implicit_tls';
  static const String starttlsRequired = 'starttls_required';

  static const Set<String> allowed = <String>{implicitTls, starttlsRequired};

  /// Legacy mapping: `smtp_ssl = true` -> implicit TLS, `false` -> required
  /// STARTTLS. Never maps to plaintext.
  static String fromLegacySsl(Object? value) {
    final bool ssl = value is bool
        ? value
        : value is num
        ? value != 0
        : value == '1' || value == 'true';
    return ssl ? implicitTls : starttlsRequired;
  }
}

class SmtpConfig {
  const SmtpConfig({
    required this.host,
    required this.port,
    required this.mode,
    required this.username,
    required this.sender,
    this.fingerprintSha256,
    this.timeout = const Duration(seconds: 10),
  });

  final String host;
  final int port;
  final String mode;
  final String username;
  final String sender;
  final String? fingerprintSha256;
  final Duration timeout;

  void validateForConnect() {
    final String cleanHost = host.trim();
    if (cleanHost.isEmpty || cleanHost == 'invalid.local' || cleanHost.contains(RegExp(r'[\s/]'))) {
      throw const DocumentDeliveryException('Host nicht erreichbar', code: SmtpFailureKind.hostUnreachable);
    }
    if (port < 1 || port > 65535) {
      throw const DocumentDeliveryException('Port ungültig', code: SmtpFailureKind.hostUnreachable);
    }
    if (port == 25) {
      // shortcut: port 25 has no verified-TLS submission story; refuse before connect.
      throw const DocumentDeliveryException('Port 25 wird nicht unterstützt (kein TLS)', code: 'port_25');
    }
    if (!SmtpTransportMode.allowed.contains(mode)) {
      throw const DocumentDeliveryException('Transportmodus ungültig', code: SmtpFailureKind.tls);
    }
    parseSingleMailbox(sender, field: 'Absender');
    if (username.trim().isEmpty) {
      throw const DocumentDeliveryException('SMTP-Benutzer fehlt', code: SmtpFailureKind.auth);
    }
  }
}

/// Steps completed by a connection test. The test never issues MAIL/RCPT/DATA.
class SmtpTestReport {
  const SmtpTestReport({required this.completedSteps, required this.mode});

  final List<String> completedSteps;
  final String mode;
}

class SmtpRejected implements Exception {
  const SmtpRejected(this.reply, {this.temporary = false});

  final String reply;
  final bool temporary;

  @override
  String toString() => 'SMTP abgelehnt: $reply';
}

class SmtpAmbiguous implements Exception {
  const SmtpAmbiguous(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Outgoing message with attachment bytes resolved by the artifact layer.
class OutgoingMail {
  const OutgoingMail({
    required this.sender,
    required this.recipient,
    required this.subject,
    required this.body,
    this.attachments = const <MailAttachment>[],
  });

  final String sender;
  final String recipient;
  final String subject;
  final String body;
  final List<MailAttachment> attachments;
}

class MailAttachment {
  const MailAttachment({required this.filename, required this.bytes, this.mimeType = 'application/pdf'});

  final String filename;
  final List<int> bytes;
  final String mimeType;
}

abstract class SmtpTransportAdapter {
  Future<SmtpTestReport> testConnection(SmtpConfig config, String password);
  Future<void> submit(SmtpConfig config, String password, OutgoingMail mail);
}

/// Scriptable fake: no sockets. Records issued commands so tests can assert
/// EHLO-after-STARTTLS, no-DATA-on-test, and single-DATA semantics.
class FakeSmtpTransport implements SmtpTransportAdapter {
  FakeSmtpTransport({
    this.failTestWith,
    this.failSubmitWith,
    this.failSubmitBeforeData = false,
    this.acceptReply = '250 OK queued',
    this.authMechanisms = const <String>['LOGIN'],
    this.offerStarttls = true,
    this.gate,
  });

  Object? failTestWith;
  Object? failSubmitWith;
  bool failSubmitBeforeData;
  String acceptReply;
  List<String> authMechanisms;
  bool offerStarttls;
  Future<void>? gate;

  final List<String> commands = <String>[];
  int dataCommands = 0;
  int testCalls = 0;
  int submitCalls = 0;
  OutgoingMail? lastMail;

  @override
  Future<SmtpTestReport> testConnection(SmtpConfig config, String password) async {
    testCalls++;
    config.validateForConnect();
    commands.add('EHLO test');
    if (config.mode == SmtpTransportMode.starttlsRequired) {
      if (!offerStarttls) {
        throw const DocumentDeliveryException('STARTTLS nicht angeboten', code: SmtpFailureKind.tls);
      }
      commands.add('STARTTLS');
      commands.add('EHLO nach TLS');
    }
    commands.add('AUTH ${authMechanisms.join(',')}');
    if (failTestWith != null) {
      final Object failure = failTestWith!;
      if (failure is Exception) throw failure;
      throw DocumentDeliveryException('$failure', code: SmtpFailureKind.auth);
    }
    if (password.isEmpty) {
      throw const DocumentDeliveryException('Anmeldung fehlgeschlagen', code: SmtpFailureKind.auth);
    }
    return SmtpTestReport(
      completedSteps: <String>[
        'begruessung',
        'ehlo',
        if (config.mode == SmtpTransportMode.starttlsRequired) ...<String>['starttls', 'ehlo_nach_tls'] else 'tls',
        'auth',
      ],
      mode: config.mode,
    );
  }

  @override
  Future<void> submit(SmtpConfig config, String password, OutgoingMail mail) async {
    submitCalls++;
    config.validateForConnect();
    parseSingleMailbox(mail.sender, field: 'Absender');
    parseSingleMailbox(mail.recipient, field: 'Empfänger');
    requireHeaderLine(mail.subject, field: 'Betreff');
    lastMail = mail;
    if (failSubmitBeforeData && failSubmitWith != null) {
      final Object failure = failSubmitWith!;
      if (failure is Exception) throw failure;
      throw SmtpRejected('$failure');
    }
    final Future<void>? activeGate = gate;
    if (activeGate != null) await activeGate;
    commands.add('MAIL FROM');
    commands.add('RCPT TO');
    dataCommands++;
    commands.add('DATA');
    if (failSubmitWith != null) {
      final Object failure = failSubmitWith!;
      if (failure is Exception) throw failure;
      throw SmtpRejected('$failure');
    }
  }
}

/// Real transport over dart:io sockets. Certificate chain and hostname are
/// validated by the platform TLS stack; failures surface as typed TLS errors
/// with no plaintext retry.
class DartIoSmtpTransport implements SmtpTransportAdapter {
  const DartIoSmtpTransport();

  @override
  Future<SmtpTestReport> testConnection(SmtpConfig config, String password) async {
    config.validateForConnect();
    if (password.isEmpty) {
      throw const DocumentDeliveryException('Anmeldung fehlgeschlagen', code: SmtpFailureKind.auth);
    }
    final _Connection connection = await _connect(config);
    try {
      await connection.testAuthenticate(config, password);
      return SmtpTestReport(
        completedSteps: <String>[
          'begruessung',
          'ehlo',
          if (config.mode == SmtpTransportMode.starttlsRequired) ...<String>['starttls', 'ehlo_nach_tls'] else 'tls',
          'auth',
        ],
        mode: config.mode,
      );
    } finally {
      await connection.quit();
    }
  }

  @override
  Future<void> submit(SmtpConfig config, String password, OutgoingMail mail) async {
    config.validateForConnect();
    parseSingleMailbox(mail.sender, field: 'Absender');
    parseSingleMailbox(mail.recipient, field: 'Empfänger');
    requireHeaderLine(mail.subject, field: 'Betreff');
    final _Connection connection = await _connect(config);
    try {
      await connection.authenticate(config, password);
      await connection.sendMail(config, mail);
    } finally {
      await connection.quit();
    }
  }

  Future<_Connection> _connect(SmtpConfig config) async {
    if (config.mode == SmtpTransportMode.implicitTls) {
      final SecureSocket socket = await _guardTls(
        SecureSocket.connect(config.host, config.port, timeout: config.timeout),
        config,
      );
      final _Connection connection = _Connection(SecureSocketLines(socket));
      await connection.greet();
      await connection.ehlo(config.host);
      _checkFingerprint(socket.peerCertificate, config);
      return connection;
    }
    final Socket plain = await _guardHost(Socket.connect(config.host, config.port, timeout: config.timeout), config);
    final _Connection pre = _Connection(SocketLines(plain));
    await pre.greet();
    final Set<String> caps = await pre.ehlo(config.host);
    if (!caps.contains('starttls')) {
      await pre.quit();
      throw const DocumentDeliveryException('STARTTLS wird nicht angeboten; kein Klartext-Rückfall', code: 'tls');
    }
    await pre.starttls();
    final SecureSocket upgraded = await _guardTls(SecureSocket.secure(plain, host: config.host), config);
    final _Connection connection = _Connection(SecureSocketLines(upgraded));
    final Set<String> postCaps = await connection.ehlo(config.host);
    _checkFingerprint(upgraded.peerCertificate, config);
    connection.advertisedAuth = postCaps;
    return connection;
  }

  void _checkFingerprint(X509Certificate? certificate, SmtpConfig config) {
    final String? expected = config.fingerprintSha256?.trim().toLowerCase().replaceAll(':', '');
    if (expected == null || expected.isEmpty) return;
    if (certificate == null) {
      throw const DocumentDeliveryException('Zertifikat fehlt', code: SmtpFailureKind.tls);
    }
    verifyCertificatePin(derBytes: certificate.der, expectedHex: expected);
  }

  /// Pin verification as an additional constraint: a matching pin never
  /// skips chain/hostname validation (platform TLS always validates; this
  /// transport never installs an `onBadCertificate` bypass).
  static void verifyCertificatePin({required List<int> derBytes, required String expectedHex}) {
    final String actual = sha256.convert(derBytes).toString();
    if (actual != expectedHex.toLowerCase().replaceAll(':', '')) {
      throw const DocumentDeliveryException('Zertifikat-Fingerabdruck stimmt nicht', code: SmtpFailureKind.tls);
    }
  }

  Future<T> _guardHost<T>(Future<T> attempt, SmtpConfig config) {
    return attempt.timeout(config.timeout).catchError((Object error) {
      if (error is TimeoutException || error is SocketException) {
        throw const DocumentDeliveryException('Host nicht erreichbar', code: SmtpFailureKind.hostUnreachable);
      }
      Error.throwWithStackTrace(error, StackTrace.current);
    });
  }

  Future<T> _guardTls<T>(Future<T> attempt, SmtpConfig config) {
    return attempt.timeout(config.timeout).catchError((Object error) {
      if (error is TimeoutException || error is SocketException) {
        throw const DocumentDeliveryException('Host nicht erreichbar', code: SmtpFailureKind.hostUnreachable);
      }
      if (error is HandshakeException || error is TlsException || error is CertificateException) {
        throw DocumentDeliveryException('TLS-Prüfung fehlgeschlagen: $error', code: SmtpFailureKind.tls);
      }
      if (error is DocumentDeliveryException) throw error;
      throw DocumentDeliveryException('TLS-Verbindung fehlgeschlagen: $error', code: SmtpFailureKind.tls);
    });
  }
}

class _Connection {
  _Connection(this.lines);

  final _LineChannel lines;
  Set<String> advertisedAuth = <String>{};
  bool _done = false;

  Future<void> greet() async {
    final String reply = await lines.readReply();
    if (!reply.startsWith('220')) {
      throw DocumentDeliveryException('SMTP-Begrüßung fehlgeschlagen: $reply', code: SmtpFailureKind.hostUnreachable);
    }
  }

  Future<Set<String>> ehlo(String host) async {
    await lines.write('EHLO $host');
    final String reply = await lines.readReply(multiline: true);
    if (!reply.startsWith('250')) {
      throw DocumentDeliveryException('EHLO fehlgeschlagen: $reply', code: SmtpFailureKind.hostUnreachable);
    }
    final Set<String> caps = <String>{};
    for (final String line in reply.split('\n')) {
      final String upper = line.length > 4 ? line.substring(4).toUpperCase() : '';
      if (upper.startsWith('STARTTLS')) caps.add('starttls');
      if (upper.startsWith('AUTH')) {
        for (final String part in upper.substring(4).trim().split(RegExp(r'\s+'))) {
          if (part.isNotEmpty) caps.add(part);
        }
      }
    }
    advertisedAuth = caps;
    return caps;
  }

  Future<void> starttls() async {
    await lines.write('STARTTLS');
    final String reply = await lines.readReply();
    if (!reply.startsWith('220')) {
      throw DocumentDeliveryException('STARTTLS fehlgeschlagen: $reply', code: SmtpFailureKind.tls);
    }
  }

  Future<void> _auth(String username, String password, Set<String> caps) async {
    if (!caps.contains('LOGIN') && !caps.contains('PLAIN')) {
      throw const DocumentDeliveryException('Kein unterstütztes AUTH-Verfahren', code: SmtpFailureKind.auth);
    }
    final String mechanism = caps.contains('LOGIN') ? 'LOGIN' : 'PLAIN';
    await lines.write('AUTH $mechanism');
    final String challenge = await lines.readReply();
    if (mechanism == 'LOGIN') {
      if (!challenge.startsWith('334')) {
        throw DocumentDeliveryException('Anmeldung fehlgeschlagen: $challenge', code: SmtpFailureKind.auth);
      }
      await lines.write(base64.encode(utf8.encode(username)));
      final String userReply = await lines.readReply();
      if (!userReply.startsWith('334')) {
        throw DocumentDeliveryException('Anmeldung fehlgeschlagen: $userReply', code: SmtpFailureKind.auth);
      }
      await lines.write(base64.encode(utf8.encode(password)));
    } else {
      if (!challenge.startsWith('334')) {
        await lines.write(base64.encode(utf8.encode('\u0000$username\u0000$password')));
      } else {
        await lines.write(base64.encode(utf8.encode('\u0000$username\u0000$password')));
      }
    }
    final String result = await lines.readReply();
    if (!result.startsWith('235')) {
      throw DocumentDeliveryException('Anmeldung fehlgeschlagen: $result', code: SmtpFailureKind.auth);
    }
  }

  Future<void> testAuthenticate(SmtpConfig config, String password) => _auth(config.username, password, advertisedAuth);

  Future<void> authenticate(SmtpConfig config, String password) => _auth(config.username, password, advertisedAuth);

  Future<void> sendMail(SmtpConfig config, OutgoingMail mail) async {
    await lines.write('MAIL FROM:<${mail.sender}>');
    final String fromReply = await lines.readReply();
    _require250(fromReply, beforeData: true);
    await lines.write('RCPT TO:<${mail.recipient}>');
    final String rcptReply = await lines.readReply();
    _require250(rcptReply, beforeData: true);
    await lines.write('DATA');
    final String dataReply = await lines.readReply();
    if (!dataReply.startsWith('354')) {
      _classifyRejection(dataReply);
    }
    try {
      await lines.write(buildMime(mail));
      await lines.write('.');
    } on SocketException catch (error) {
      throw SmtpAmbiguous('Verbindung nach Senden abgebrochen: $error');
    } catch (error) {
      Error.throwWithStackTrace(error, StackTrace.current);
    }
    String finalReply;
    try {
      finalReply = await lines.readReply().timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const SmtpAmbiguous('Keine Serverantwort nach Senden (möglicherweise angenommen)');
    } on SocketException catch (error) {
      throw SmtpAmbiguous('Verbindung nach Senden abgebrochen: $error');
    }
    if (finalReply.startsWith('250')) return;
    _classifyRejection(finalReply);
  }

  void _require250(String reply, {required bool beforeData}) {
    if (reply.startsWith('250')) return;
    if (beforeData) {
      _classifyRejection(reply);
    }
    _classifyRejection(reply);
  }

  Never _classifyRejection(String reply) {
    if (reply.startsWith('5')) {
      throw SmtpRejected(reply);
    }
    if (reply.startsWith('4')) {
      throw SmtpRejected(reply, temporary: true);
    }
    throw SmtpAmbiguous('Unerwartete Serverantwort: $reply');
  }

  Future<void> quit() async {
    if (_done) return;
    _done = true;
    try {
      await lines.write('QUIT').timeout(const Duration(seconds: 3));
    } catch (_) {}
    try {
      await lines.close();
    } catch (_) {}
  }
}

/// Builds a multipart/mixed MIME message. Inputs are pre-validated (no CR/LF
/// in headers, single mailboxes), so header injection is rejected by type.
String buildMime(OutgoingMail mail) {
  final String boundary = 'oa-${DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(16)}';
  final StringBuffer out = StringBuffer();
  out.writeln('From: ${mail.sender}');
  out.writeln('To: ${mail.recipient}');
  out.writeln('Subject: ${mail.subject}');
  out.writeln('MIME-Version: 1.0');
  out.writeln('Content-Type: multipart/mixed; boundary="$boundary"');
  out.writeln();
  out.writeln('--$boundary');
  out.writeln('Content-Type: text/plain; charset=utf-8');
  out.writeln('Content-Transfer-Encoding: 8bit');
  out.writeln();
  out.writeln(mail.body);
  for (final MailAttachment attachment in mail.attachments) {
    final String safeName = attachment.filename.replaceAll('"', '_').replaceAll('\r', '').replaceAll('\n', '');
    out.writeln('--$boundary');
    out.writeln('Content-Type: ${attachment.mimeType}; name="$safeName"');
    out.writeln('Content-Transfer-Encoding: base64');
    out.writeln('Content-Disposition: attachment; filename="$safeName"');
    out.writeln();
    out.writeln(base64.encode(attachment.bytes));
  }
  out.writeln('--$boundary--');
  return out.toString();
}

abstract class _LineChannel {
  Future<void> write(String line);
  Future<String> readReply({bool multiline = false});
  Future<void> close();
}

class SocketLines implements _LineChannel {
  SocketLines(this.socket) : _buffer = '';

  final Socket socket;
  String _buffer;
  final List<String> _queue = <String>[];

  @override
  Future<void> write(String line) async {
    socket.writeln(line);
    await socket.flush();
  }

  @override
  Future<String> readReply({bool multiline = false}) async {
    final List<String> lines = <String>[];
    while (true) {
      while (_queue.isEmpty) {
        final List<int> chunk = await socket.first.timeout(const Duration(seconds: 30));
        final StringBuffer pending = StringBuffer(_buffer)..write(utf8.decode(chunk, allowMalformed: true));
        final List<String> parts = pending.toString().split('\r\n');
        _buffer = parts.removeLast();
        _queue.addAll(parts);
      }
      final String line = _queue.removeAt(0);
      lines.add(line);
      if (!multiline) return line;
      if (line.length >= 4 && line[3] == ' ') return lines.join('\n');
      if (line.length < 4) return lines.join('\n');
    }
  }

  @override
  Future<void> close() async {
    try {
      await socket.close();
    } catch (_) {}
  }
}

class SecureSocketLines implements _LineChannel {
  SecureSocketLines(this.socket) : _inner = SocketLines(socket as Socket);

  final SecureSocket socket;
  final SocketLines _inner;

  @override
  Future<void> write(String line) => _inner.write(line);

  @override
  Future<String> readReply({bool multiline = false}) => _inner.readReply(multiline: multiline);

  @override
  Future<void> close() => _inner.close();
}
