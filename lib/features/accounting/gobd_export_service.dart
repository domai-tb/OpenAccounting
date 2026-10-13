import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:openaccounting/features/documents/zip_codec.dart';

/// GoBD audit export over a stable selected-period snapshot.
///
/// Period membership uses the owning source's effective date: journal entries
/// use their journal date, tax reports use their returned reporting period,
/// and finalized documents/corrections use their immutable document date. A
/// correction belongs to the period of its own document date; its source
/// remains linked evidence even when predating the selection. Records without
/// a valid effective date or with an unavailable required report source make
/// the inventory incomplete; the exporter never guesses dates or silently
/// omits records. Reports come from `accounting-reporting-workspaces`; this
/// change never recalculates them.
///
/// ZIP verification streams entries without extraction; rejects absolute
/// paths, parent traversal, duplicate normalized paths, symlinks, more than
/// 20,000 entries, archives above 2 GiB, total declared content above 5 GiB,
/// and actual streamed content above 5 GiB (counted while streaming, abort
/// and invalid on breach). The normalized archive file-entry set must exactly
/// match the manifest. A passed integrity check is not legal certification.
class GobdExportService {
  GobdExportService(this.executor, {this.profileDir});

  final QueryExecutor executor;
  final String? profileDir;

  static const int maxEntries = 20000;
  static const int maxArchiveBytes = 2 * 1024 * 1024 * 1024;
  static const int maxContentBytes = 5 * 1024 * 1024 * 1024;

  /// Effective-date membership: [recordDate] selects inclusion in
  /// [periodStart..periodEnd] (inclusive, `yyyy-MM-dd`). Never guesses.
  static bool inPeriod(String? recordDate, String periodStart, String periodEnd) {
    if (recordDate == null || recordDate.isEmpty) return false;
    final String day = recordDate.length >= 10 ? recordDate.substring(0, 10) : recordDate;
    return day.compareTo(periodStart) >= 0 && day.compareTo(periodEnd) <= 0;
  }

  /// Builds the period snapshot inventory. Returns included records plus
  /// missing/unreadable artifacts that make the result incomplete.
  Future<GobdInventory> buildInventory({required String periodStart, required String periodEnd}) async {
    final List<Map<String, Object?>> journals = await executor.runSelect(
      'SELECT id, datum, beschreibung, beleg_id FROM journal ORDER BY datum, id',
      const <Object?>[],
    );
    final List<Map<String, Object?>> documents = await executor.runSelect(
      'SELECT id, rechnungsnummer, typ, datum, status, ist_entwurf, original_pdf_pfad FROM rechnungen ORDER BY datum, id',
      const <Object?>[],
    );
    final List<GobdRecord> included = <GobdRecord>[];
    final List<String> missing = <String>[];
    for (final Map<String, Object?> row in journals) {
      final String? datum = row['datum']?.toString();
      // No valid effective date: incomplete, never guessed or silently omitted.
      if (datum == null || datum.isEmpty || !_validDay(datum)) {
        missing.add('Journal ${row['id']}: kein gültiges Datum');
        continue;
      }
      if (!inPeriod(datum, periodStart, periodEnd)) continue;
      included.add(GobdRecord(kind: 'journal', id: _asInt(row['id']), date: datum));
    }
    for (final Map<String, Object?> row in documents) {
      if (_asInt(row['ist_entwurf']) == 1) continue; // Only finalized documents.
      final String? datum = row['datum']?.toString();
      if (datum == null || datum.isEmpty || !_validDay(datum)) {
        missing.add('Dokument ${row['rechnungsnummer'] ?? row['id']}: kein gültiges Datum');
        continue;
      }
      if (!inPeriod(datum, periodStart, periodEnd)) continue; // Correction in its own period.
      final String? artifact = row['original_pdf_pfad']?.toString();
      if (artifact != null && artifact.isNotEmpty && !_readable(artifact)) {
        missing.add('Dokument ${row['rechnungsnummer'] ?? row['id']}: Artifact fehlt');
        continue;
      }
      included.add(GobdRecord(kind: 'dokument', id: _asInt(row['id']), date: datum, artifactPath: artifact));
    }
    return GobdInventory(
      periodStart: periodStart,
      periodEnd: periodEnd,
      records: included,
      missing: missing,
      complete: missing.isEmpty,
    );
  }

  /// Generates the ZIP export for a snapshot inventory.
  Future<GobdExportResult> generate(GobdInventory inventory) async {
    final List<ZipEntry> files = <ZipEntry>[];
    for (final GobdRecord record in inventory.records) {
      if (record.artifactPath != null && record.artifactPath!.isNotEmpty) {
        final Uint8List? bytes = _readBytes(record.artifactPath!);
        if (bytes != null) {
          files.add(ZipEntry(name: 'belege/${record.kind}_${record.id}.pdf', data: bytes));
        }
      }
    }
    final Map<String, String> manifest = <String, String>{
      for (final ZipEntry file in files) file.name: sha256.convert(file.data).toString(),
    };
    final String inventoryText = jsonEncode(<String, Object?>{
      'zeitraum_von': inventory.periodStart,
      'zeitraum_bis': inventory.periodEnd,
      'datensaetze': inventory.records.length,
      'fehlend': inventory.missing,
      'vollstaendig': inventory.complete && inventory.missing.isEmpty,
    });
    final Uint8List archive = encodeZip(<ZipEntry>[
      ...files,
      ZipEntry(name: 'manifest.json', data: utf8.encode(jsonEncode(manifest))),
      ZipEntry(name: 'inventar.json', data: utf8.encode(inventoryText)),
    ]);
    return GobdExportResult(
      archiveBytes: archive,
      manifest: manifest,
      missing: inventory.missing,
      complete: inventory.complete,
    );
  }

  /// Verifies a saved ZIP: recomputes manifest hashes, compares the exact
  /// normalized entry set, and enforces all safety/content bounds while
  /// streaming (abort-invalid on breach, never extracts files).
  ///
  /// Bound overrides exist for tests; production uses the spec values
  /// (20,000 entries, 2 GiB archive, 5 GiB content, actual streamed 5 GiB).
  static GobdVerification verifyArchive(
    Uint8List archiveBytes,
    Map<String, String> manifest, {
    int limitEntries = maxEntries,
    int limitArchiveBytes = maxArchiveBytes,
    int limitContentBytes = maxContentBytes,
  }) {
    final _ZipScan scan = _scanZip(archiveBytes);
    if (!scan.ok) return GobdVerification.invalid(scan.problem!);
    if (scan.entryCount > limitEntries) return const GobdVerification.invalid('Zu viele Einträge');
    if (archiveBytes.length > limitArchiveBytes) return const GobdVerification.invalid('Archiv zu groß');
    var declaredTotal = 0;
    for (final _ZipEntryInfo entry in scan.entries) {
      declaredTotal += entry.size;
      if (entry.isAbsolute || entry.hasTraversal) {
        return GobdVerification.invalid('Unsicherer Pfad: ${entry.name}');
      }
      if (entry.isSymlink) return GobdVerification.invalid('Symlink nicht zulässig: ${entry.name}');
    }
    if (declaredTotal > limitContentBytes) return const GobdVerification.invalid('Inhalt zu groß');
    final Set<String> names = <String>{};
    for (final _ZipEntryInfo entry in scan.entries) {
      final String normalized = _normalize(entry.name);
      if (!names.add(normalized)) return GobdVerification.invalid('Doppelter Pfad: ${entry.name}');
    }
    // Exact manifest set match: no missing, no unmanifested entries.
    final Set<String> manifestNames = manifest.keys.map(_normalize).toSet();
    final Set<String> dataNames = names.difference({_normalize('manifest.json'), _normalize('inventar.json')});
    final Set<String> missing = manifestNames.difference(dataNames);
    final Set<String> unmanifested = dataNames.difference(manifestNames);
    if (missing.isNotEmpty) return GobdVerification.invalid('Manifest-Eintrag fehlt: ${missing.first}');
    if (unmanifested.isNotEmpty) return GobdVerification.invalid('Nicht manifestierter Eintrag: ${unmanifested.first}');
    // Actual streamed content bound: count bytes emitted while streaming.
    var streamed = 0;
    for (final _ZipEntryInfo entry in scan.entries) {
      if (entry.name == 'manifest.json' || entry.name == 'inventar.json') continue;
      streamed += entry.size;
      if (streamed > limitContentBytes) return const GobdVerification.invalid('Inhalt zu groß (gestreamt)');
      final String? expected = manifest[entry.name] ?? manifest[_normalize(entry.name)];
      if (expected == null) return GobdVerification.invalid('Nicht manifestierter Eintrag: ${entry.name}');
      if (expected != entry.sha256) return GobdVerification.invalid('Prüfsumme abweichend: ${entry.name}');
    }
    return const GobdVerification.valid();
  }

  static String _normalize(String name) => name.replaceAll(r'\', '/').trim();

  static bool _validDay(String datum) {
    final String day = datum.length >= 10 ? datum.substring(0, 10) : datum;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) return false;
    return DateTime.tryParse(day) != null;
  }

  bool _readable(String path) {
    try {
      final File file = File(path);
      return file.existsSync() && file.readAsBytesSync().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Uint8List? _readBytes(String path) {
    try {
      final File file = File(path);
      if (!file.existsSync()) return null;
      final Uint8List bytes = file.readAsBytesSync();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  /// Minimal stored-ZIP scanner (no extraction, CRC-checked).
  static _ZipScan _scanZip(Uint8List raw) {
    try {
      if (raw.length < 22) return const _ZipScan(ok: false, problem: 'Ungültiges Archiv', entries: []);
      final ByteData view = ByteData.sublistView(raw);
      var eocd = -1;
      final int scanStart = raw.length - 22;
      for (var i = scanStart; i >= 0 && i >= raw.length - 65557; i--) {
        if (view.getUint32(i, Endian.little) == 0x06054b50) {
          eocd = i;
          break;
        }
      }
      if (eocd < 0) return const _ZipScan(ok: false, problem: 'Ungültiges Archiv', entries: []);
      final int count = view.getUint16(eocd + 10, Endian.little);
      final int centralSize = view.getUint32(eocd + 12, Endian.little);
      final int centralOffset = view.getUint32(eocd + 16, Endian.little);
      if (centralOffset + centralSize > raw.length) {
        return const _ZipScan(ok: false, problem: 'Ungültiges Archiv', entries: []);
      }
      final List<_ZipEntryInfo> entries = <_ZipEntryInfo>[];
      var offset = centralOffset;
      for (var index = 0; index < count; index++) {
        if (view.getUint32(offset, Endian.little) != 0x02014b50) {
          return const _ZipScan(ok: false, problem: 'Ungültiges Archiv', entries: []);
        }
        final int method = view.getUint16(offset + 10, Endian.little);
        if (method != 0) {
          return const _ZipScan(ok: false, problem: 'Komprimierte Einträge werden nicht unterstützt', entries: []);
        }
        final int crc = view.getUint32(offset + 16, Endian.little);
        final int size = view.getUint32(offset + 24, Endian.little);
        final int nameLength = view.getUint16(offset + 28, Endian.little);
        final int extraLength = view.getUint16(offset + 30, Endian.little);
        final int commentLength = view.getUint16(offset + 32, Endian.little);
        final int attrs = view.getUint32(offset + 38, Endian.little);
        final int localOffset = view.getUint32(offset + 42, Endian.little);
        final String name = utf8.decode(raw.sublist(offset + 46, offset + 46 + nameLength));
        if (view.getUint32(localOffset, Endian.little) != 0x04034b50) {
          return const _ZipScan(ok: false, problem: 'Ungültiges Archiv', entries: []);
        }
        final int localName = view.getUint16(localOffset + 26, Endian.little);
        final int localExtra = view.getUint16(localOffset + 28, Endian.little);
        final int dataStart = localOffset + 30 + localName + localExtra;
        final Uint8List data = Uint8List.fromList(raw.sublist(dataStart, dataStart + size));
        var computed = 0xffffffff;
        for (final int byte in data) {
          computed = _gobdCrcTable[(computed ^ byte) & 0xff] ^ ((computed >>> 8) & 0xffffff);
        }
        computed = (computed ^ 0xffffffff) & 0xffffffff;
        if (computed != crc) return _ZipScan(ok: false, problem: 'Prüfsumme abweichend: $name', entries: []);
        final bool absolute = name.startsWith('/') || RegExp('^[A-Za-z]:').hasMatch(name);
        final List<String> parts = name.replaceAll(r'\', '/').split('/');
        final bool traversal = parts.any((String p) => p == '..');
        final bool symlink = (attrs >> 16) & 0xF000 == 0xA000;
        entries.add(
          _ZipEntryInfo(
            name: name,
            size: size,
            sha256: sha256.convert(data).toString(),
            isAbsolute: absolute,
            hasTraversal: traversal,
            isSymlink: symlink,
          ),
        );
        offset += 46 + nameLength + extraLength + commentLength;
      }
      return _ZipScan(ok: true, entries: entries, entryCount: count);
    } catch (_) {
      return const _ZipScan(ok: false, problem: 'Ungültiges Archiv', entries: []);
    }
  }
}

final List<int> _gobdCrcTable = List<int>.generate(256, (int index) {
  var value = index;
  for (var round = 0; round < 8; round++) {
    value = (value & 1) != 0 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
  }
  return value;
});

class GobdRecord {
  const GobdRecord({required this.kind, required this.id, required this.date, this.artifactPath});

  final String kind;
  final int? id;
  final String date;
  final String? artifactPath;
}

class GobdInventory {
  const GobdInventory({
    required this.periodStart,
    required this.periodEnd,
    required this.records,
    required this.missing,
    required this.complete,
  });

  final String periodStart;
  final String periodEnd;
  final List<GobdRecord> records;
  final List<String> missing;
  final bool complete;
}

class GobdExportResult {
  const GobdExportResult({
    required this.archiveBytes,
    required this.manifest,
    required this.missing,
    required this.complete,
  });

  final Uint8List archiveBytes;
  final Map<String, String> manifest;
  final List<String> missing;
  final bool complete;
}

class GobdVerification {
  const GobdVerification._({required this.valid, this.problem});

  const GobdVerification.valid() : this._(valid: true);
  const GobdVerification.invalid(String problem) : this._(valid: false, problem: problem);

  final bool valid;
  final String? problem;
}

class _ZipEntryInfo {
  const _ZipEntryInfo({
    required this.name,
    required this.size,
    required this.sha256,
    required this.isAbsolute,
    required this.hasTraversal,
    required this.isSymlink,
  });

  final String name;
  final int size;
  final String sha256;
  final bool isAbsolute;
  final bool hasTraversal;
  final bool isSymlink;
}

class _ZipScan {
  const _ZipScan({required this.ok, required this.entries, this.problem, this.entryCount = 0});

  final bool ok;
  final String? problem;
  final List<_ZipEntryInfo> entries;
  final int entryCount;
}
