import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;
import 'package:smb_connect/smb_connect.dart';
import 'package:sqlite3/sqlite3.dart';

typedef SmbBackupWriter = Future<void> Function(
  String smbUrl,
  String username,
  String password,
  String remotePath,
  Uint8List bytes,
);

class BackupService {
  BackupService({
    required this.profileDir,
    this.executor,
    String? databasePath,
    SmbBackupWriter? smbWriter,
    this.externalTargetApproved = false,
    this.allowSystemDrive = false,
  }) : databasePath = databasePath ?? p.join(profileDir, 'openinvoices.db'),
       smbWriter = smbWriter ?? _uploadToSmb;

  static const int maxBackups = 5;
  static const int _magicLength = 8;
  static const int _saltLength = 16;
  static const int _ivLength = 12;
  static const int _kdfIterations = 100000;
  static const List<int> _magic = <int>[79, 65, 66, 75, 48, 48, 48, 49];
  static const int _headerLength = _magicLength + _saltLength + _ivLength + 4;

  final String profileDir;
  final QueryExecutor? executor;
  final String databasePath;
  final SmbBackupWriter smbWriter;
  final bool externalTargetApproved;
  bool allowSystemDrive;

  String get backupDir => p.join(profileDir, 'backups');

  String get _statePath => p.join(profileDir, 'backup_state.json');

  Future<String> createLocalBackup() async {
    if (!File(databasePath).existsSync() && executor == null) {
      throw StateError('Datenbank nicht gefunden');
    }
    await Directory(backupDir).create(recursive: true);
    final destination = await _nextBackupPath();
    try {
      if (File(databasePath).existsSync()) {
        await _backupDatabase(databasePath, destination);
      } else {
        // In-memory migration tests have no source path; keep their snapshot real.
        await executor!.runCustom('VACUUM INTO ?', <Object?>[destination]);
      }
      await _rotate();
      await _writeLastBackup();
      return destination;
    } catch (error) {
      await _deleteFile(destination);
      throw StateError(_backupError(error));
    }
  }

  Future<String> createEncryptedBackup(String externalPath, String passphrase) async {
    _validateExternalPath(externalPath);
    if (passphrase.isEmpty) throw ArgumentError('Passphrase fehlt');

    final localPath = await createLocalBackup();
    final plain = await File(localPath).readAsBytes();
    final destination = externalPath.endsWith('.enc') ? externalPath : '$externalPath.enc';
    final staged = _temporaryPath(destination, 'encrypt');
    try {
      await Directory(p.dirname(destination)).create(recursive: true);
      final encrypted = _encrypt(plain, passphrase);
      await File(staged).writeAsBytes(encrypted, flush: true);
      final restored = _decrypt(await File(staged).readAsBytes(), passphrase);
      if (!_bytesEqual(restored, plain)) {
        throw StateError('Integritätsprüfung fehlgeschlagen');
      }
      await _atomicReplace(staged, destination);
      return destination;
    } catch (_) {
      await _deleteFile(staged);
      throw StateError('Verschlüsseltes Backup fehlgeschlagen');
    }
  }

  Future<String> createSmbBackup(String smbUrl, String username, String password) async {
    _requireExternalApproval();
    if (username.isEmpty || password.isEmpty) {
      throw StateError('SMB-Authentifizierung fehlgeschlagen');
    }
    final target = _parseSmbTarget(smbUrl);
    final localPath = await createLocalBackup();
    final bytes = await File(localPath).readAsBytes();
    final filename = p.basename(localPath);
    final remotePath = '${target.remotePath}/$filename';
    try {
      await smbWriter(smbUrl, username, password, remotePath, bytes);
    } catch (_) {
      throw StateError('SMB-Backup fehlgeschlagen');
    }
    return 'smb://${target.host}$remotePath';
  }

  Future<void> restoreFromBackup(String backupPath, String activeDbPath) async {
    if (!File(backupPath).existsSync()) {
      throw StateError('Backup-Datei nicht gefunden');
    }
    final staged = _temporaryPath(activeDbPath, 'restore');
    try {
      await _backupDatabase(backupPath, staged);
      await _validateSqliteFile(staged);
      await _atomicReplace(staged, activeDbPath);
    } catch (_) {
      await _deleteFile(staged);
      throw StateError('Wiederherstellung fehlgeschlagen');
    }
  }

  Future<void> restoreEncrypted(String encPath, String passphrase, String activeDbPath) async {
    if (!File(encPath).existsSync()) {
      throw StateError('Verschlüsselte Backup-Datei nicht gefunden');
    }
    final staged = _temporaryPath(activeDbPath, 'restore-encrypted');
    try {
      final plain = _decrypt(await File(encPath).readAsBytes(), passphrase);
      await Directory(p.dirname(activeDbPath)).create(recursive: true);
      await File(staged).writeAsBytes(plain, flush: true);
      await _validateSqliteFile(staged);
      await _atomicReplace(staged, activeDbPath);
    } catch (_) {
      await _deleteFile(staged);
      throw StateError('Entschlüsselung oder Wiederherstellung fehlgeschlagen');
    }
  }

  bool isSystemDrive(String target) {
    final normalized = p.normalize(target).replaceAll(r'\', '/');
    if (normalized == '/' || normalized == '/boot' || normalized.startsWith('/boot/')) {
      return true;
    }
    return normalized.startsWith('C:/') || RegExp(r'^[A-Za-z]:/$').hasMatch(normalized);
  }

  Future<bool> isScheduledDue({Duration interval = const Duration(hours: 24)}) async {
    final state = File(_statePath);
    if (state.existsSync()) {
      try {
        final decoded = jsonDecode(await state.readAsString());
        if (decoded is Map<String, dynamic> && decoded['lastBackup'] is String) {
          final lastBackup = DateTime.tryParse(decoded['lastBackup'] as String);
          if (lastBackup != null) {
            return DateTime.now().toUtc().difference(lastBackup.toUtc()) >= interval;
          }
        }
      } catch (_) {}
    }

    final backups = await _backupFiles();
    if (backups.isEmpty) return true;
    return DateTime.now().difference(backups.last.lastModifiedSync()) >= interval;
  }

  Future<void> _backupDatabase(String sourcePath, String destinationPath) async {
    Database? source;
    Database? destination;
    try {
      source = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
      destination = sqlite3.open(destinationPath);
      await source.backup(destination, nPage: -1).drain();
    } finally {
      destination?.close();
      source?.close();
    }
  }

  Future<void> _validateSqliteFile(String path) async {
    Database? database;
    try {
      database = sqlite3.open(path, mode: OpenMode.readOnly);
      final result = database.select('PRAGMA quick_check');
      if (result.isEmpty || result.first.values.first != 'ok') {
        throw StateError('Ungültige SQLite-Datei');
      }
    } finally {
      database?.close();
    }
  }

  Future<String> _nextBackupPath() async {
    final timestamp = _timestamp();
    var path = p.join(backupDir, 'openinvoices_$timestamp.db');
    var suffix = 0;
    while (File(path).existsSync()) {
      suffix++;
      path = p.join(backupDir, 'openinvoices_${timestamp}_$suffix.db');
    }
    return path;
  }

  Future<List<File>> _backupFiles() async {
    final directory = Directory(backupDir);
    if (!directory.existsSync()) return <File>[];
    final files = await directory
        .list()
        .where((entry) => entry is File && _isBackupFile(p.basename(entry.path)))
        .cast<File>()
        .toList();
    final entries = files.map((file) => (file: file, modified: file.lastModifiedSync())).toList();
    entries.sort((a, b) => a.modified.compareTo(b.modified));
    return entries.map((entry) => entry.file).toList();
  }

  Future<void> _rotate() async {
    final files = await _backupFiles();
    final excess = files.length - maxBackups;
    if (excess <= 0) return;
    for (final file in files.take(excess)) {
      await file.delete();
    }
  }

  Future<void> _writeLastBackup() async {
    await File(
      _statePath,
    ).writeAsString(jsonEncode(<String, String>{'lastBackup': DateTime.now().toUtc().toIso8601String()}), flush: true);
  }

  Uint8List _encrypt(Uint8List plain, String passphrase) {
    final salt = Uint8List.fromList(enc.Key.fromSecureRandom(_saltLength).bytes);
    final iv = Uint8List.fromList(enc.IV.fromSecureRandom(_ivLength).bytes);
    final header = BytesBuilder()
      ..add(_magic)
      ..add(salt)
      ..add(iv)
      ..add(_uint32(_kdfIterations));
    final associatedData = header.toBytes();
    final key = enc.Key(_deriveKey(passphrase, salt));
    final encrypted = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm))
        .encryptBytes(plain, iv: enc.IV(iv), associatedData: associatedData);
    return (BytesBuilder()
          ..add(associatedData)
          ..add(encrypted.bytes))
        .takeBytes();
  }

  Uint8List _decrypt(Uint8List data, String passphrase) {
    if (data.length <= _headerLength || !_bytesEqual(data.sublist(0, _magicLength), _magic)) {
      throw StateError('Ungültiges Backup-Format');
    }
    final header = Uint8List.fromList(data.sublist(0, _headerLength));
    final iterations = ByteData.sublistView(header, _headerLength - 4).getUint32(0);
    if (iterations != _kdfIterations) throw StateError('Nicht unterstützte KDF-Version');
    final salt = Uint8List.fromList(header.sublist(_magicLength, _magicLength + _saltLength));
    final iv = Uint8List.fromList(header.sublist(_magicLength + _saltLength, _headerLength - 4));
    final key = enc.Key(_deriveKey(passphrase, salt));
    final encrypted = enc.Encrypted(Uint8List.fromList(data.sublist(_headerLength)));
    final plain = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm))
        .decryptBytes(encrypted, iv: enc.IV(iv), associatedData: header);
    return Uint8List.fromList(plain);
  }

  Uint8List _deriveKey(String passphrase, Uint8List salt) {
    final hmac = Hmac(sha256, utf8.encode(passphrase));
    var block = Uint8List.fromList(hmac.convert(<int>[...salt, 0, 0, 0, 1]).bytes);
    final key = Uint8List.fromList(block);
    for (var iteration = 1; iteration < _kdfIterations; iteration++) {
      block = Uint8List.fromList(hmac.convert(block).bytes);
      for (var index = 0; index < key.length; index++) {
        key[index] ^= block[index];
      }
    }
    return key;
  }

  Future<void> _atomicReplace(String stagedPath, String destinationPath) async {
    await Directory(p.dirname(destinationPath)).create(recursive: true);
    // Restore runs during restart; stale WAL/SHM files must not replay over the snapshot.
    await _removeSqliteSidecars(destinationPath);
    try {
      await File(stagedPath).rename(destinationPath);
      return;
    } on FileSystemException {
      final previousPath = _temporaryPath(destinationPath, 'previous');
      await File(destinationPath).rename(previousPath);
      try {
        await File(stagedPath).rename(destinationPath);
        await _deleteFile(previousPath);
      } catch (_) {
        if (!File(destinationPath).existsSync() && File(previousPath).existsSync()) {
          await File(previousPath).rename(destinationPath);
        }
        rethrow;
      }
    }
  }

  Future<void> _removeSqliteSidecars(String databasePath) async {
    for (final suffix in <String>['-wal', '-shm']) {
      final sidecar = File('$databasePath$suffix');
      if (sidecar.existsSync()) {
        await sidecar.delete();
      }
    }
  }

  void _validateExternalPath(String externalPath) {
    _requireExternalApproval();
    if (externalPath.trim().isEmpty) throw ArgumentError('Externer Pfad fehlt');
    final profileRoot = p.normalize(p.absolute(profileDir));
    final externalRoot = p.normalize(p.absolute(externalPath));
    if (externalRoot == profileRoot || p.isWithin(profileRoot, externalRoot)) {
      throw StateError('Externes Backup-Ziel muss außerhalb APP_DATA_DIR liegen');
    }
    if (isSystemDrive(externalPath) && !allowSystemDrive) {
      throw StateError('Systemlaufwerk als Backup-Ziel nicht erlaubt');
    }
  }

  void _requireExternalApproval() {
    if (!externalTargetApproved) {
      throw StateError('Externes Backup-Ziel nicht freigegeben');
    }
  }

  String _backupError(Object error) {
    if (error.toString().toLowerCase().contains('full')) {
      return 'Nicht genügend Speicherplatz für Backup';
    }
    return 'Lokales Backup fehlgeschlagen';
  }

  String _temporaryPath(String path, String purpose) => '$path.$purpose-${_timestamp()}';

  String _timestamp() {
    final now = DateTime.now().toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<void> _deleteFile(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  static bool _isBackupFile(String name) => name.startsWith('openinvoices_') && name.endsWith('.db');

  static Uint8List _uint32(int value) {
    final bytes = Uint8List(4);
    ByteData.sublistView(bytes).setUint32(0, value);
    return bytes;
  }

  static bool _bytesEqual(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static ({String host, String remotePath}) _parseSmbTarget(String smbUrl) {
    final uri = Uri.tryParse(smbUrl);
    final segments = uri?.pathSegments.where((segment) => segment.isNotEmpty).toList() ?? <String>[];
    if (uri == null || uri.scheme.toLowerCase() != 'smb' || uri.host.isEmpty || segments.isEmpty) {
      throw ArgumentError('SMB URL muss smb://host/share enthalten');
    }
    if (segments.any((segment) => segment == '.' || segment == '..')) {
      throw ArgumentError('Ungültiger SMB-Pfad');
    }
    return (host: uri.host, remotePath: '/${segments.join('/')}');
  }

  static Future<void> _uploadToSmb(
    String smbUrl,
    String username,
    String password,
    String remotePath,
    Uint8List bytes,
  ) async {
    final target = _parseSmbTarget(smbUrl);
    final connection = await SmbConnect.connectAuth(
      host: target.host,
      domain: '',
      username: username,
      password: password,
    );
    try {
      final remoteFile = await connection.createFile(remotePath);
      final writer = await connection.openWrite(remoteFile);
      try {
        writer.add(bytes);
        await writer.flush();
      } finally {
        await writer.close();
      }
      final verifiedFile = await connection.file(remotePath);
      final reader = await connection.openRead(verifiedFile);
      final received = BytesBuilder();
      await for (final chunk in reader) {
        received.add(chunk);
      }
      if (!_bytesEqual(received.takeBytes(), bytes)) {
        throw StateError('SMB-Integritätsprüfung fehlgeschlagen');
      }
    } finally {
      await connection.close();
    }
  }
}
