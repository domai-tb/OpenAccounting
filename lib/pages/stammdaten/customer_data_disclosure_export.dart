import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:ffi/ffi.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/core/db/migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

typedef _PosixLinkNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _PosixLinkDart = int Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _CreateHardLinkNative = Int32 Function(Pointer<Utf16>, Pointer<Utf16>, Pointer<Void>);
typedef _CreateHardLinkDart = int Function(Pointer<Utf16>, Pointer<Utf16>, Pointer<Void>);

void _createNoReplaceHardLink(String stagedPath, String destinationPath) {
  if (Platform.isWindows) {
    final _CreateHardLinkDart createHardLink = DynamicLibrary.open('kernel32.dll')
        .lookupFunction<_CreateHardLinkNative, _CreateHardLinkDart>('CreateHardLinkW');
    final Pointer<Utf16> destination = destinationPath.toNativeUtf16();
    final Pointer<Utf16> staged = stagedPath.toNativeUtf16();
    try {
      if (createHardLink(destination, staged, nullptr) == 0) {
        throw FileSystemException('Could not publish archive without replacement', destinationPath);
      }
    } finally {
      malloc.free(destination);
      malloc.free(staged);
    }
    return;
  }
  if (!Platform.isLinux && !Platform.isMacOS) {
    throw UnsupportedError('Atomic no-replace archive publication is unsupported on this platform');
  }
  final _PosixLinkDart createHardLink = DynamicLibrary.process().lookupFunction<_PosixLinkNative, _PosixLinkDart>(
    'link',
  );
  final Pointer<Utf8> staged = stagedPath.toNativeUtf8();
  final Pointer<Utf8> destination = destinationPath.toNativeUtf8();
  try {
    if (createHardLink(staged, destination) != 0) {
      throw FileSystemException('Could not publish archive without replacement', destinationPath);
    }
  } finally {
    malloc.free(staged);
    malloc.free(destination);
  }
}

/// Status of one customer disclosure export attempt.
enum CustomerDisclosureExportStatus {
  /// Archive was verified and published with no known gap.
  complete,

  /// Archive was published but is not a complete disclosure.
  incomplete,

  /// No archive was published; the attempt is retryable.
  failed,

  /// The user cancelled; no archive was published.
  cancelled,
}

/// A record, field, file, or table excluded from the customer archive.
///
/// Only stable identifiers are stored: never absolute host paths, source
/// filenames, or field values.
class CustomerDisclosureExclusion {
  const CustomerDisclosureExclusion({
    required this.recordType,
    required this.recordId,
    required this.field,
    required this.reason,
  });

  final String recordType;
  final String recordId;
  final String field;

  /// One of `missing`, `unreadable`, `outside_profile`, `unsupported`,
  /// `unclassified_field`, `conflicting_identity`, `missing_table`,
  /// `unknown_table`, `unknown_state`, `version_pending`,
  /// `omitted_cross_party`, `omitted_unrelated`.
  final String reason;

  Map<String, Object?> toJson() => <String, Object?>{
    'record_type': recordType,
    'record_id': recordId,
    'field': field,
    'reason': reason,
  };
}

/// Outcome of one customer disclosure export attempt.
class CustomerDisclosureResult {
  const CustomerDisclosureResult({
    required this.status,
    this.archivePath,
    this.message,
    this.exclusions = const <CustomerDisclosureExclusion>[],
    this.recordCounts = const <String, int>{},
    this.complete = false,
  });

  final CustomerDisclosureExportStatus status;

  /// Final archive location; only set for complete/incomplete results.
  final String? archivePath;

  /// Localized (German-first) human-readable outcome.
  final String? message;

  final List<CustomerDisclosureExclusion> exclusions;
  final Map<String, int> recordCounts;
  final bool complete;
}

/// Reviewed relationship and projection inventory for the scoped customer
/// export. All paths are stable foreign keys; free-text matches are never
/// traversed. Version rules follow the landed runtime migrations
/// (payment table at v8, category history at v9, shared markers and mileage
/// tables at v13, mileage posting at v25, and cashbook opening sources at v26);
/// the supported export schema is [MigrationRunner.currentVersion].
class CustomerDisclosureInventory {
  /// The v19 inventory remains 55 names; mileage posting adds two at v25 and cashbook adds one at v26.
  static const Set<String> knownTableNames = <String>{
    ...AppDatabase.allTableNames,
    'feature_table_state',
    'forderung_zahlungen',
    'buchungsvorlagen_occurrences',
    'rechnungsvorlagen_occurrences',
    'mileage_trips',
    'mileage_trip_corrections',
    'mileage_posting_account_mapping',
    'mileage_posting_period_closures',
    'account_opening_balance_sources',
    'category_mapping_history',
    'master_data_import_templates',
    'anlage_afa_jahreswerte',
    'dokument_email_templates',
    'dokument_email_versuche',
  };

  /// Schema version from which a migration-required table must exist.
  static const Map<String, int> requiredSinceVersion = <String, int>{
    'forderung_zahlungen': 8,
    'category_mapping_history': 9,
    'feature_table_state': 13,
    'mileage_trips': 13,
    'mileage_trip_corrections': 13,
    'mileage_posting_account_mapping': 25,
    'mileage_posting_period_closures': 25,
    'account_opening_balance_sources': 26,
    'master_data_import_templates': 16,
    'anlage_afa_jahreswerte': 17,
    'inventuren': 18,
    'inventur_positionen': 18,
    'settlement_groups': 19,
    'settlement_allocations': 19,
    'statutory_timing_rules': 19,
  };

  /// Lazily created occurrence tables guarded by feature_table_state markers.
  static const Set<String> lazyOccurrenceTables = <String>{
    'buchungsvorlagen_occurrences',
    'rechnungsvorlagen_occurrences',
  };

  /// Tables checked for schema health but never projected: no accepted typed
  /// relationship links them to a customer. Their omission never forces an
  /// incomplete outcome, and free-text purpose/context/history is never used
  /// to infer a customer link.
  /// Optional document-email tables are validated when present.
  static const Set<String> optionalSchemaTables = <String>{'dokument_email_templates', 'dokument_email_versuche'};

  static const Set<String> payloadExcludedTables = <String>{
    'feature_table_state',
    'mileage_trips',
    'mileage_trip_corrections',
    'mileage_posting_account_mapping',
    'mileage_posting_period_closures',
    'category_mapping_history',
  };

  /// Record types projected into `records/<table>.jsonl`.
  static const List<String> payloadTables = <String>[
    'kunden',
    'kunden_lieferadressen',
    'rechnungen',
    'rechnungspositionen',
    'mahnungen',
    'forderungen',
    'forderung_zahlungen',
    'journal',
    'vorsteuer_ansprueche',
    'rechnungsvorlagen',
    'rechnungsvorlagen_occurrences',
    'kunden_belege',
    'belege',
    'buchungsvorlagen_occurrences',
  ];

  /// Versioned per-table field allowlists (record projection version 1).
  /// Unknown columns are never serialized.
  static const Map<String, Set<String>> fieldAllowlists = <String, Set<String>>{
    'kunden': <String>{
      'id',
      'kundennummer',
      'debitor_nr',
      'anrede',
      'name',
      'firma',
      'strasse',
      'hausnummer',
      'plz',
      'ort',
      'land',
      'email',
      'telefon',
      'ust_idnr',
      'steuernummer_ausland',
      'zahlungsziel',
      'skonto_prozent',
      'skonto_tage',
      'kreditlimit',
      'mahngesperrt',
      'mahngesperrt_bis',
      'mahngesperrt_grund',
      'zugferd_aktiv',
      'note',
      'notiz',
      'archived_at',
      'erstellungsdatum',
    },
    'kunden_lieferadressen': <String>{'id', 'kunde_id', 'bezeichnung', 'strasse', 'plz', 'ort', 'land'},
    'rechnungen': <String>{
      'id',
      'rechnungsnummer',
      'typ',
      'status',
      'ist_entwurf',
      'eingabemodus',
      'kunde_id',
      'datum',
      'faelligkeit',
      'netto_betrag',
      'brutto_betrag',
      'ust_betrag',
      'skonto_prozent',
      'skonto_faelligkeit',
      'notiz',
      'unternehmen_id',
      'nummernkreis_id',
      'storno_von',
      'absender_snapshot',
      'ausgegeben_am',
      'mahnstufe_aktuell',
      'vorlage_id',
      'storno_grund',
      'storno_datum',
      'gutschrift_von',
      'ersatz_fuer',
      'ersatzrechnung_id',
      'konvertiert_von',
      'konvertiert_zu',
      'rabatt_prozent',
      'rabatt_betrag',
      'lieferadresse_id',
    },
    'rechnungspositionen': <String>{
      'id',
      'rechnung_id',
      'artikel_id',
      'bezeichnung',
      'menge',
      'einzelpreis',
      'gesamt',
      'ust_satz',
      'position',
      'rabatt_prozent',
    },
    'mahnungen': <String>{
      'id',
      'rechnung_id',
      'kunde_id',
      'stufe_id',
      'datum',
      'betrag',
      'gebuehr',
      'zinsen',
      'status',
      'snapshot',
      'gebuehr_bezahlt',
      'zinsen_bezahlt',
      'uebernommene_gebuehr',
      'uebernommene_zinsen',
      'versendet_am',
    },
    'forderungen': <String>{
      'id',
      'kunde_id',
      'rechnung_id',
      'betrag',
      'anfangsbetrag',
      'status',
      'faelligkeit',
      'beschreibung',
      'typ',
      'partner_typ',
      'partner_id',
      'journal_id',
      'ausgleich_journal_id',
      'erstellt_am',
      'aktualisiert_am',
    },
    'forderung_zahlungen': <String>{
      'id',
      'forderung_id',
      'journal_id',
      'betrag',
      'typ',
      'datum',
      'idempotency_key',
      'requested_betrag_cents',
      'fingerprint_direction',
      'fingerprint_date_policy',
    },
    'journal': <String>{
      'id',
      'datum',
      'beleg_nr',
      'kategorie_id',
      'konto_id',
      'betrag',
      'soll',
      'haben',
      'beschreibung',
      'immutable',
      'beleg_typ',
      'soll_konto_id',
      'haben_konto_id',
      'rechnung_id',
      'erstellungsdatum',
      'storno_von',
      'ust_satz_id',
      'konto_skr03_snapshot',
      'konto_skr04_snapshot',
      'ust_satz',
      'ust_sonderfall',
      'marge_25a_brutto',
      'ust_satz_25a',
      'ist_eu_lieferung',
      'vorsteuer_betrag',
      'km_anzahl',
      'gruppe_id',
      'legacy_unverified',
    },
    'vorsteuer_ansprueche': <String>{
      'id',
      'rechnung_id',
      'betrag',
      'status',
      'faelligkeit',
      'unternehmen_id',
      'ust_sonderfall',
    },
    'rechnungsvorlagen': <String>{
      'id',
      'name',
      'kunde_id',
      'intervall',
      'naechste_faelligkeit',
      'aktiv',
      'vorlage_daten',
      'status',
      'auftrag_id',
    },
    'rechnungsvorlagen_occurrences': <String>{'id', 'vorlage_id', 'faelligkeit', 'rechnung_id'},
    'kunden_belege': <String>{'id', 'kunde_id', 'beleg_id', 'rolle'},
    'belege': <String>{
      'id',
      'belegnummer',
      'typ',
      'datum',
      'betrag',
      'konto_id',
      'kategorie_id',
      'unternehmen_id',
      'status',
      'beschreibung',
      'dateiname',
      'original_name',
      'mime_type',
      'dateigroesse',
      'sha256',
      'hochgeladen_am',
      'loeschdatum',
    },
    'buchungsvorlagen_occurrences': <String>{'id', 'faelligkeit', 'journal_id', 'rechnung_id'},
  };

  /// Cross-party or unrelated references that are always omitted. A non-empty
  /// value is listed in the manifest and makes the archive incomplete.
  static const Map<String, Set<String>> omittedFields = <String, Set<String>>{
    'rechnungen': <String>{'lieferant_id'},
    'belege': <String>{'lieferant_id'},
    'journal': <String>{'vorlage_id'},
    'vorsteuer_ansprueche': <String>{'beleg_id'},
    'buchungsvorlagen_occurrences': <String>{'vorlage_id'},
  };

  static const Map<String, Set<String>> lazyPayloadColumns = <String, Set<String>>{
    'rechnungen': <String>{
      'storno_grund',
      'storno_datum',
      'gutschrift_von',
      'ersatz_fuer',
      'ersatzrechnung_id',
      'konvertiert_von',
      'konvertiert_zu',
      'original_pdf_pfad',
      'rabatt_prozent',
      'rabatt_betrag',
      'lieferadresse_id',
    },
    'rechnungspositionen': <String>{'rabatt_prozent'},
  };

  static Set<String> requiredPayloadColumns(String table, {int schemaVersion = MigrationRunner.currentVersion}) {
    final Set<String> columns = <String>{
      ...?fieldAllowlists[table],
      ...?omittedFields[table],
      ...?relationshipColumns[table],
      for (final (String, String) evidence in evidenceColumns)
        if (evidence.$1 == table) evidence.$2,
    };
    columns.removeAll(lazyPayloadColumns[table] ?? const <String>{});
    if (table == 'journal' && schemaVersion < 19) {
      columns.remove('legacy_unverified');
    }
    if (table == 'mileage_posting_account_mapping' && schemaVersion >= 25) {
      columns.addAll(<String>{'role', 'konto_id', 'kategorie_id', 'reviewed_at'});
    }
    if (table == 'mileage_posting_period_closures' && schemaVersion >= 25) {
      columns.addAll(<String>{'id', 'closed_from', 'closed_through', 'closed_at'});
    }
    if (table == 'journal' && schemaVersion >= 25) {
      columns.addAll(<String>{
        'mileage_role_snapshot',
        'mileage_kategorie_id_snapshot',
        'mileage_kategorie_name_snapshot',
        'mileage_kategorie_art_snapshot',
        'mileage_euer_zeile_snapshot',
        'mileage_kategorie_skr03_snapshot',
        'mileage_kategorie_skr04_snapshot',
        'mileage_mapping_status_snapshot',
        'mileage_mapping_source_reference_snapshot',
        'mileage_mapping_source_version_snapshot',
        'mileage_mapping_history_id_snapshot',
      });
    }
    return columns;
  }

  static const Map<String, Set<String>> relationshipColumns = <String, Set<String>>{
    'journal': <String>{'beleg_id'},
  };

  /// Persisted file references resolved against the profile root.
  static const List<(String, String)> evidenceColumns = <(String, String)>[
    ('rechnungen', 'original_pdf_pfad'),
    ('belege', 'dateipfad'),
    ('belege', 'beleg_pdfa_pfad'),
  ];

  /// Verified relationship paths, also published in the manifest.
  static const List<String> relationshipPaths = <String>[
    'kunden.id',
    'kunden_lieferadressen.kunde_id',
    'rechnungen.kunde_id',
    'rechnungen.lieferadresse_id',
    'rechnungen.storno_von/gutschrift_von/ersatz_fuer/ersatzrechnung_id/konvertiert_von/konvertiert_zu (beidseitig)',
    'rechnungspositionen.rechnung_id',
    'mahnungen.kunde_id/rechnung_id',
    'forderungen.kunde_id/partner_typ+partner_id/rechnung_id',
    'forderung_zahlungen.forderung_id (+journal_id)',
    'journal.rechnung_id/journal_id/ausgleich_journal_id/zahlung-journal_id',
    'vorsteuer_ansprueche.rechnung_id',
    'rechnungsvorlagen.kunde_id/vorlage_id/auftrag_id',
    'rechnungsvorlagen_occurrences.vorlage_id/rechnung_id',
    'kunden_belege.kunde_id->belege.id',
    'buchungsvorlagen_occurrences.rechnung_id/journal_id (Ereignisprojektion ohne vorlage_id)',
  ];

  /// Invoice self-link columns traversed in both directions.
  static const List<String> invoiceLineageColumns = <String>[
    'storno_von',
    'gutschrift_von',
    'ersatz_fuer',
    'ersatzrechnung_id',
    'konvertiert_von',
    'konvertiert_zu',
  ];
}

/// Scoped disclosure export for exactly one persisted customer.
///
/// Layout mirrors the profile export lifecycle: UTF-8 `manifest.json`, UTF-8
/// JSON Lines at `records/<table>.jsonl`, copied evidence beneath
/// `evidence/`. Reads from a WAL-safe snapshot, writes through an
/// application-owned partial sibling, publishes only after structural
/// verification with an atomic no-replace link, and never modifies source
/// data. The exporter never creates or repairs tables.
class CustomerDataDisclosureExportService {
  CustomerDataDisclosureExportService({
    required QueryExecutor executor,
    required String profileDir,
    String? profileLabel,
    DateTime Function()? clock,
  }) : _executor = executor, // ignore: prefer_initializing_formals
       profileDir = p.normalize(p.absolute(profileDir)),
       profileLabel = _resolveLabel(profileLabel, profileDir),
       _clock = clock ?? DateTime.now;

  final QueryExecutor _executor;

  /// Canonical active profile root; evidence copies must resolve inside it.
  final String profileDir;
  final String profileLabel;
  final DateTime Function() _clock;

  static const int archiveVersion = 1;
  static const int recordVersion = 1;

  /// Version of the per-table record projection (field allowlists).
  static const int recordProjectionVersion = 1;

  static const String _messageCancelled = 'Export abgebrochen. Es wurde kein Archiv erstellt.';
  static const String _messageComplete = 'Export abgeschlossen und geprüft.';
  static const String _messageIncomplete = 'Export unvollständig gespeichert. Bitte Hinweise prüfen.';
  static const String _messageRetry = 'Bitte Ziel prüfen und erneut versuchen.';
  static const String _messageUnavailable = 'Auskunfts-Export ist nicht verfügbar.';
  static const String _messageNotFound = 'Kunde nicht gefunden. Es wurde kein Archiv erstellt.';
  static const String _messageNoCustomer = 'Kein Kunde ausgewählt. Es wurde kein Archiv erstellt.';
  static const String _messageExists = 'Zieldatei existiert bereits. Bitte anderen Namen wählen.';
  static const String _legalNote =
      'Dieser Export erhebt keinen Anspruch auf rechtliche Vollständigkeit; '
      'Freitext-Treffer wurden nicht gesucht.';

  /// Runs the scoped export for [customerId] to [destinationPath].
  ///
  /// The destination must not exist at finalization; an existing destination
  /// fails without overwriting it. [isCancelled] is polled between stages;
  /// [onStaged] runs after verification and the destination check but before
  /// publication.
  Future<CustomerDisclosureResult> exportCustomer({
    required int? customerId,
    required String destinationPath,
    bool Function()? isCancelled,
    FutureOr<void> Function(String stagedPath)? onStaged,
  }) async {
    bool cancelled() => isCancelled?.call() ?? false;
    if (cancelled()) {
      return const CustomerDisclosureResult(
        status: CustomerDisclosureExportStatus.cancelled,
        message: _messageCancelled,
      );
    }
    if (customerId == null) {
      return const CustomerDisclosureResult(status: CustomerDisclosureExportStatus.failed, message: _messageNoCustomer);
    }
    final String destination = p.normalize(p.absolute(destinationPath));
    final String? destinationError = _validateDestination(destination);
    if (destinationError != null) {
      return CustomerDisclosureResult(status: CustomerDisclosureExportStatus.failed, message: destinationError);
    }
    if (!Directory(profileDir).existsSync()) {
      return const CustomerDisclosureResult(
        status: CustomerDisclosureExportStatus.failed,
        message: '$_messageUnavailable Profilverzeichnis wurde nicht gefunden.',
      );
    }
    // Read-point gate (profile export convention): refuse while a transaction
    // holds the database so the snapshot below is consistent.
    try {
      await _executor.runCustom('BEGIN IMMEDIATE');
      await _executor.runCustom('ROLLBACK');
    } catch (_) {
      return const CustomerDisclosureResult(
        status: CustomerDisclosureExportStatus.failed,
        message: 'Export erfordert ein Wartungsfenster ohne aktive Transaktion. $_messageRetry',
      );
    }
    if (cancelled()) {
      return const CustomerDisclosureResult(
        status: CustomerDisclosureExportStatus.cancelled,
        message: _messageCancelled,
      );
    }
    final _CustomerSnapshot snapshot;
    try {
      snapshot = await _readSnapshot();
    } catch (_) {
      return const CustomerDisclosureResult(
        status: CustomerDisclosureExportStatus.failed,
        message: 'Export konnte keinen konsistenten Stand lesen. $_messageRetry',
      );
    }
    if (cancelled()) {
      return const CustomerDisclosureResult(
        status: CustomerDisclosureExportStatus.cancelled,
        message: _messageCancelled,
      );
    }
    final Map<String, Object?>? customer = snapshot.customerById(customerId);
    if (customer == null) {
      return const CustomerDisclosureResult(status: CustomerDisclosureExportStatus.failed, message: _messageNotFound);
    }
    final String resolvedRoot;
    try {
      resolvedRoot = Directory(profileDir).resolveSymbolicLinksSync();
    } catch (_) {
      return const CustomerDisclosureResult(
        status: CustomerDisclosureExportStatus.failed,
        message: 'Profilverzeichnis konnte nicht aufgelöst werden. $_messageRetry',
      );
    }

    final _DisclosureCollector collector = _DisclosureCollector(customerId: customerId, customer: customer);
    collector.checkSchemaHealth(snapshot);
    if (collector.snapshotUsable) {
      collector.traverse(snapshot);
      collector.projectEvidence(snapshot, resolvedRoot, profileDir);
    }

    final Map<String, String> recordPayloads = collector.recordPayloads();
    final Map<String, Object?> manifest = collector.manifest(
      profileLabel: profileLabel,
      clock: _clock,
      recordPayloads: recordPayloads,
    );

    final List<_CustomerZipEntry> zipEntries = <_CustomerZipEntry>[
      _CustomerZipEntry(name: 'manifest.json', data: utf8.encode(jsonEncode(manifest))),
      for (final MapEntry<String, String> payload in recordPayloads.entries)
        _CustomerZipEntry(name: payload.key, data: utf8.encode(payload.value)),
      for (final _CustomerEvidenceFile item in collector.evidence)
        _CustomerZipEntry(name: item.archivePath, data: item.bytes),
    ];
    final Uint8List archiveBytes = _encodeCustomerZip(zipEntries);

    if (cancelled()) {
      return const CustomerDisclosureResult(
        status: CustomerDisclosureExportStatus.cancelled,
        message: _messageCancelled,
      );
    }
    File? stagedFile;
    try {
      stagedFile = _reservePartial(destination, customerId);
      stagedFile.writeAsBytesSync(archiveBytes, flush: true);
    } catch (_) {
      if (stagedFile != null) await _deleteQuietly(stagedFile.path);
      return const CustomerDisclosureResult(
        status: CustomerDisclosureExportStatus.failed,
        message: 'Export konnte nicht geschrieben werden. $_messageRetry',
      );
    }
    final File reservedStagedFile = stagedFile;
    try {
      _verifyStaged(
        reservedStagedFile.readAsBytesSync(),
        requiredEntries: <String>['manifest.json', ...recordPayloads.keys],
        counts: collector.recordCounts,
        evidence: collector.evidence,
      );
    } catch (_) {
      await _deleteQuietly(reservedStagedFile.path);
      return const CustomerDisclosureResult(
        status: CustomerDisclosureExportStatus.failed,
        message: 'Export-Prüfung fehlgeschlagen. $_messageRetry',
      );
    }
    if (FileSystemEntity.typeSync(destination, followLinks: false) != FileSystemEntityType.notFound) {
      await _deleteQuietly(reservedStagedFile.path);
      return const CustomerDisclosureResult(status: CustomerDisclosureExportStatus.failed, message: _messageExists);
    }
    await onStaged?.call(reservedStagedFile.path);
    if (cancelled()) {
      await _deleteQuietly(reservedStagedFile.path);
      return const CustomerDisclosureResult(
        status: CustomerDisclosureExportStatus.cancelled,
        message: _messageCancelled,
      );
    }
    try {
      _createNoReplaceHardLink(reservedStagedFile.path, destination);
    } catch (_) {
      await _deleteQuietly(reservedStagedFile.path);
      if (FileSystemEntity.typeSync(destination, followLinks: false) != FileSystemEntityType.notFound) {
        return const CustomerDisclosureResult(status: CustomerDisclosureExportStatus.failed, message: _messageExists);
      }
      return const CustomerDisclosureResult(
        status: CustomerDisclosureExportStatus.failed,
        message: 'Export konnte nicht veröffentlicht werden. $_messageRetry',
      );
    }
    await _deleteQuietly(reservedStagedFile.path);
    if (collector.complete) {
      return CustomerDisclosureResult(
        status: CustomerDisclosureExportStatus.complete,
        archivePath: destination,
        message: _messageComplete,
        exclusions: collector.exclusions,
        recordCounts: collector.recordCounts,
        complete: true,
      );
    }
    return CustomerDisclosureResult(
      status: CustomerDisclosureExportStatus.incomplete,
      archivePath: destination,
      message: _messageIncomplete,
      exclusions: collector.exclusions,
      recordCounts: collector.recordCounts,
    );
  }

  /// Reads the manifest of a previously written archive.
  Future<Map<String, Object?>> readManifest(String archivePath) async {
    final List<_CustomerZipEntry> entries = _decodeCustomerZip(File(archivePath).readAsBytesSync());
    for (final _CustomerZipEntry entry in entries) {
      if (entry.name == 'manifest.json') {
        return Map<String, Object?>.from(jsonDecode(utf8.decode(entry.data))! as Map);
      }
    }
    throw StateError('manifest.json fehlt im Archiv');
  }

  /// Lists entry names of a previously written archive.
  Future<List<String>> listEntries(String archivePath) async {
    return <String>[
      for (final _CustomerZipEntry entry in _decodeCustomerZip(File(archivePath).readAsBytesSync())) entry.name,
    ];
  }

  /// Reads one entry of a previously written archive.
  Future<Uint8List> readEntry(String archivePath, String entryName) async {
    final List<_CustomerZipEntry> entries = _decodeCustomerZip(File(archivePath).readAsBytesSync());
    for (final _CustomerZipEntry entry in entries) {
      if (entry.name == entryName) {
        return Uint8List.fromList(entry.data);
      }
    }
    throw StateError('Eintrag $entryName fehlt im Archiv');
  }

  String? _validateDestination(String destination) {
    final FileSystemEntityType type = FileSystemEntity.typeSync(destination, followLinks: false);
    if (type == FileSystemEntityType.link) {
      return 'Export-Ziel darf kein Link sein. $_messageRetry';
    }
    if (type == FileSystemEntityType.directory) {
      return 'Export-Ziel ist ein Verzeichnis. Bitte eine Datei wählen und erneut versuchen.';
    }
    if (type == FileSystemEntityType.file) {
      return _messageExists;
    }
    final String parent = p.dirname(destination);
    if (FileSystemEntity.typeSync(parent, followLinks: false) == FileSystemEntityType.link) {
      return 'Zielverzeichnis darf kein Link sein. $_messageRetry';
    }
    try {
      Directory(parent).createSync(recursive: true);
    } catch (_) {
      return 'Export-Ziel ist nicht schreibbar. $_messageRetry';
    }
    return null;
  }

  File _reservePartial(String destination, int customerId) {
    final String prefix = p.join(
      p.dirname(destination),
      '.openaccounting-customer-export-$customerId-${p.basename(destination)}-${_stamp()}',
    );
    final Random random = Random.secure();
    for (var attempt = 0; attempt < 5; attempt++) {
      final File partial = File('$prefix-${random.nextInt(1 << 32).toRadixString(16)}.partial');
      try {
        partial.createSync(exclusive: true);
        return partial;
      } on FileSystemException {
        if (!partial.existsSync()) rethrow;
      }
    }
    throw FileSystemException('Could not reserve a unique export partial', prefix);
  }

  /// Consistent read point: WAL-safe snapshot via `VACUUM INTO`.
  Future<_CustomerSnapshot> _readSnapshot() async {
    final Directory stagingDirectory = await Directory(profileDir).createTemp('.customer-disclosure-snapshot-');
    final String staging = p.join(stagingDirectory.path, 'snapshot.db');
    sqlite.Database? snapshot;
    try {
      await _executor.runCustom('VACUUM INTO ?', <Object?>[staging]);
      snapshot = sqlite.sqlite3.open(staging, mode: sqlite.OpenMode.readOnly);
      return _readFromSnapshot(snapshot);
    } finally {
      try {
        snapshot?.close();
      } finally {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  _CustomerSnapshot _readFromSnapshot(sqlite.Database snapshot) {
    final sqlite.ResultSet names = snapshot.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    );
    final Set<String> actual = <String>{for (final sqlite.Row row in names) row['name'].toString()};
    final Map<String, _SnapTable> tables = <String, _SnapTable>{};
    for (final String table in <String>{...CustomerDisclosureInventory.knownTableNames}) {
      if (!actual.contains(table)) {
        tables[table] = const _SnapTable(
          columns: <String>[],
          schemaColumns: <Map<String, Object?>>[],
          rows: <Map<String, Object?>>[],
          present: false,
        );
        continue;
      }
      final List<Map<String, Object?>> schemaColumns = <Map<String, Object?>>[
        for (final sqlite.Row row in snapshot.select('PRAGMA table_info("$table")'))
          <String, Object?>{'name': row['name'], 'type': row['type'], 'notnull': row['notnull'], 'pk': row['pk']},
      ];
      final List<String> columns = <String>[
        for (final Map<String, Object?> row in schemaColumns) row['name']! as String,
      ];
      final bool openingSourceTable = table == 'account_opening_balance_sources';
      final sqlite.ResultSet? result = openingSourceTable ? null : snapshot.select('SELECT * FROM "$table"');
      final bool mileageSchemaTable =
          table == 'mileage_posting_account_mapping' || table == 'mileage_posting_period_closures';
      final String? createSql = mileageSchemaTable || openingSourceTable
          ? snapshot
                .select("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = '$table'")
                .first['sql']
                ?.toString()
          : null;
      final bool captureForeignKeys = table == 'mileage_posting_account_mapping' || openingSourceTable;
      final List<Map<String, Object?>> foreignKeys = captureForeignKeys
          ? <Map<String, Object?>>[
              for (final sqlite.Row row in snapshot.select('PRAGMA foreign_key_list("$table")'))
                <String, Object?>{
                  'table': row['table'],
                  'from': row['from'],
                  'to': row['to'],
                  'on_delete': row['on_delete'],
                },
            ]
          : const <Map<String, Object?>>[];
      final List<_SnapUniqueIndex> uniqueIndexes = <_SnapUniqueIndex>[];
      if (openingSourceTable) {
        for (final sqlite.Row index in snapshot.select('PRAGMA index_list("$table")')) {
          if (_asInt(index['unique']) != 1) continue;
          final String name = index['name'].toString().replaceAll('"', '""');
          final List<sqlite.Row> keyColumns = <sqlite.Row>[
            for (final sqlite.Row column in snapshot.select('PRAGMA index_xinfo("$name")'))
              if (_asInt(column['key']) == 1) column,
          ];
          uniqueIndexes.add(
            _SnapUniqueIndex(
              columns: <String>[for (final sqlite.Row column in keyColumns) column['name']?.toString() ?? ''],
              collations: <String>[for (final sqlite.Row column in keyColumns) column['coll']?.toString() ?? ''],
              partial: _asInt(index['partial']) != 0,
            ),
          );
        }
      }
      final List<Map<String, Object?>> triggers = openingSourceTable
          ? <Map<String, Object?>>[
              for (final sqlite.Row row in snapshot.select(
                "SELECT name, sql FROM sqlite_master WHERE type = 'trigger' AND tbl_name = '$table' ORDER BY name",
              ))
                <String, Object?>{'name': row['name'], 'sql': row['sql']},
            ]
          : const <Map<String, Object?>>[];
      tables[table] = _SnapTable(
        columns: columns,
        schemaColumns: schemaColumns,
        hasUniqueAttemptKey:
            table == 'dokument_email_versuche' && _hasUniqueColumnIndex(snapshot, table, 'idempotenz_schluessel'),
        createSql: createSql,
        foreignKeys: foreignKeys,
        uniqueIndexes: uniqueIndexes,
        triggers: triggers,
        rows: result == null
            ? const <Map<String, Object?>>[]
            : <Map<String, Object?>>[
                for (final sqlite.Row row in result)
                  <String, Object?>{for (final String column in result.columnNames) column: _jsonSafe(row[column])},
              ],
        present: true,
      );
    }
    final sqlite.ResultSet version = snapshot.select('PRAGMA user_version');
    return _CustomerSnapshot(tables: tables, actualTables: actual, userVersion: _asInt(version.first['user_version']));
  }

  bool _hasUniqueColumnIndex(sqlite.Database snapshot, String table, String column) {
    final sqlite.ResultSet indexes = snapshot.select('PRAGMA index_list("$table")');
    for (final sqlite.Row index in indexes) {
      if (_asInt(index['unique']) != 1) continue;
      final String name = index['name'].toString().replaceAll('"', '""');
      final sqlite.ResultSet fields = snapshot.select('PRAGMA index_info("$name")');
      if (fields.length == 1 && fields.first['name'] == column) return true;
    }
    return false;
  }

  String _stamp() {
    final DateTime now = _clock().toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}_'
        '${now.microsecondsSinceEpoch}';
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final File file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }

  static String _resolveLabel(String? label, String directory) {
    if (label != null && label.trim().isNotEmpty) {
      return label.trim();
    }
    final String base = p.basename(p.normalize(p.absolute(directory)));
    return base.isEmpty ? 'Profil' : base;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Object? _jsonSafe(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Uint8List) {
      return base64Encode(value);
    }
    if (value is List<int>) {
      return base64Encode(value);
    }
    return value.toString();
  }

  static void _verifyStaged(
    List<int> bytes, {
    required List<String> requiredEntries,
    required Map<String, int> counts,
    required List<_CustomerEvidenceFile> evidence,
  }) {
    final List<_CustomerZipEntry> entries = _decodeCustomerZip(bytes);
    final Map<String, _CustomerZipEntry> byName = <String, _CustomerZipEntry>{
      for (final _CustomerZipEntry entry in entries) entry.name: entry,
    };
    for (final String required in requiredEntries) {
      if (!byName.containsKey(required)) {
        throw StateError('Export-Prüfung fehlgeschlagen: $required fehlt');
      }
    }
    final _CustomerZipEntry manifestEntry = byName['manifest.json']!;
    final Map<String, Object?> manifest = Map<String, Object?>.from(
      jsonDecode(utf8.decode(manifestEntry.data))! as Map,
    );
    if (manifest['archive_version'] != archiveVersion || manifest['record_version'] != recordVersion) {
      throw StateError('Export-Prüfung fehlgeschlagen: unbekannte Archivversion');
    }
    final Map<String, Object?> manifestCounts = Map<String, Object?>.from(manifest['record_counts']! as Map);
    for (final MapEntry<String, int> count in counts.entries) {
      final Object? stored = manifestCounts[count.key];
      if (stored is! num || stored.toInt() != count.value) {
        throw StateError('Export-Prüfung fehlgeschlagen: Zähler ${count.key} weicht ab');
      }
    }
    for (final _CustomerEvidenceFile item in evidence) {
      final _CustomerZipEntry? file = byName[item.archivePath];
      if (file == null) {
        throw StateError('Export-Prüfung fehlgeschlagen: Nachweis fehlt');
      }
      if (sha256.convert(file.data).toString() != item.sha256) {
        throw StateError('Export-Prüfung fehlgeschlagen: Integrität verletzt');
      }
    }
  }
}

class _SnapTable {
  const _SnapTable({
    required this.columns,
    required this.schemaColumns,
    required this.rows,
    required this.present,
    this.hasUniqueAttemptKey = false,
    this.createSql,
    this.foreignKeys = const <Map<String, Object?>>[],
    this.uniqueIndexes = const <_SnapUniqueIndex>[],
    this.triggers = const <Map<String, Object?>>[],
  });
  final List<String> columns;
  final List<Map<String, Object?>> schemaColumns;
  final List<Map<String, Object?>> rows;
  final bool present;
  final bool hasUniqueAttemptKey;
  final String? createSql;
  final List<Map<String, Object?>> foreignKeys;
  final List<_SnapUniqueIndex> uniqueIndexes;
  final List<Map<String, Object?>> triggers;

  Map<String, bool> get uniqueIndexesByColumns {
    final Map<String, bool> indexes = <String, bool>{};
    for (final _SnapUniqueIndex index in uniqueIndexes) {
      final String columns = index.columns.join(',');
      if (indexes.containsKey(columns)) return const <String, bool>{};
      indexes[columns] = index.partial;
    }
    return indexes;
  }

  bool get hasCanonicalUniqueIndexCollations {
    for (final _SnapUniqueIndex index in uniqueIndexes) {
      if (index.columns.join(',') == 'source_reference' &&
          (index.collations.length != 1 || index.collations.single.toUpperCase() != 'BINARY')) {
        return false;
      }
    }
    return true;
  }
}

class _SnapUniqueIndex {
  const _SnapUniqueIndex({required this.columns, required this.collations, required this.partial});

  final List<String> columns;
  final List<String> collations;
  final bool partial;
}

class _CustomerSnapshot {
  const _CustomerSnapshot({required this.tables, required this.actualTables, required this.userVersion});

  final Map<String, _SnapTable> tables;
  final Set<String> actualTables;
  final int userVersion;

  Map<String, Object?>? customerById(int id) {
    final _SnapTable? customers = tables['kunden'];
    if (customers == null || !customers.present) return null;
    final List<Map<String, Object?>> matches = <Map<String, Object?>>[
      for (final Map<String, Object?> row in customers.rows)
        if (row['id'] == id) row,
    ];
    return matches.length == 1 ? matches.single : null;
  }

  List<Map<String, Object?>> rowsOf(String table) => tables[table]?.rows ?? const <Map<String, Object?>>[];
}

/// Traversal, projection, and completeness collector over one snapshot.
///
/// Never touches the database or the file system except through the evidence
/// step, which only reads. Never creates or repairs tables.
class _DisclosureCollector {
  _DisclosureCollector({required this.customerId, required this.customer});

  final int customerId;
  final Map<String, Object?> customer;

  final List<CustomerDisclosureExclusion> exclusions = <CustomerDisclosureExclusion>[];
  final List<Map<String, Object?>> omittedFields = <Map<String, Object?>>[];
  final List<_CustomerEvidenceFile> evidence = <_CustomerEvidenceFile>[];
  final Map<String, int> recordCounts = <String, int>{};
  final Map<String, List<Map<String, Object?>>> included = <String, List<Map<String, Object?>>>{};
  final Map<String, String> tableHealth = <String, String>{};

  bool _complete = true;
  bool _snapshotUsable = true;
  bool _lazyMarkerInventoryValid = true;

  bool get complete => _complete && _snapshotUsable;
  bool get snapshotUsable => _snapshotUsable;
  List<_CustomerEvidenceFile> get evidenceFiles => evidence;

  void _fail(String reason, {String recordType = 'schema', Object? recordId, String field = ''}) {
    _complete = false;
    final CustomerDisclosureExclusion exclusion = CustomerDisclosureExclusion(
      recordType: recordType,
      recordId: recordId?.toString() ?? '',
      field: field,
      reason: reason,
    );
    if (!exclusions.any(
      (CustomerDisclosureExclusion item) =>
          item.recordType == exclusion.recordType &&
          item.recordId == exclusion.recordId &&
          item.field == exclusion.field &&
          item.reason == exclusion.reason,
    )) {
      exclusions.add(exclusion);
    }
  }

  /// Version-aware inventory check against the shared table inventory.
  /// Records one exclusion per failing table; never creates or repairs.
  void checkSchemaHealth(_CustomerSnapshot snapshot) {
    _validateLazyMarkerInventory(snapshot);
    final Set<String> knownTables = <String>{...CustomerDisclosureInventory.knownTableNames};
    final Set<String> unknown = <String>{
      for (final String table in snapshot.actualTables)
        if (!knownTables.contains(table)) table,
    };
    for (final String table in unknown.toList()..sort()) {
      tableHealth[table] = 'unknown';
      _fail('unknown_table', recordType: table, field: 'table');
    }
    for (final String table in <String>{...CustomerDisclosureInventory.knownTableNames}.toList()..sort()) {
      if (tableHealth.containsKey(table)) continue;
      final bool present = snapshot.tables[table]?.present ?? false;
      final int? requiredSince = CustomerDisclosureInventory.requiredSinceVersion[table];
      if (CustomerDisclosureInventory.optionalSchemaTables.contains(table)) {
        if (!present) {
          tableHealth[table] = 'optional_absent';
        } else if (!MigrationRunner.hasDeclaredOptionalSchema(
          table,
          snapshot.tables[table]?.schemaColumns ?? const <Map<String, Object?>>[],
          hasUniqueAttemptKey: snapshot.tables[table]?.hasUniqueAttemptKey ?? false,
        )) {
          tableHealth[table] = 'malformed';
          _fail('malformed_schema', recordType: table, field: 'table');
        } else {
          tableHealth[table] = 'ok';
        }
        continue;
      }
      if (CustomerDisclosureInventory.lazyOccurrenceTables.contains(table)) {
        tableHealth[table] = _lazyHealth(snapshot, table, present);
        if (present && tableHealth[table] == 'ok') {
          final Set<String> requiredPayloadColumns = CustomerDisclosureInventory.requiredPayloadColumns(
            table,
            schemaVersion: snapshot.userVersion,
          );
          if (!MigrationRunner.hasDeclaredRelationshipIdTypes(
                table,
                snapshot.tables[table]?.schemaColumns ?? const <Map<String, Object?>>[],
              ) ||
              !(snapshot.tables[table]?.columns.toSet() ?? const <String>{}).containsAll(requiredPayloadColumns)) {
            tableHealth[table] = 'malformed';
            _fail('malformed_schema', recordType: table, field: 'table');
          }
        }
        continue;
      }
      if (requiredSince != null && snapshot.userVersion < requiredSince) {
        tableHealth[table] = 'version_pending';
        continue;
      }
      final Set<String> requiredPayloadColumns = CustomerDisclosureInventory.requiredPayloadColumns(
        table,
        schemaVersion: snapshot.userVersion,
      );
      if (present &&
          (!MigrationRunner.hasDeclaredSchemaColumns(table, snapshot.tables[table]?.columns ?? const <String>[]) ||
              !MigrationRunner.hasDeclaredRelationshipIdTypes(
                table,
                snapshot.tables[table]?.schemaColumns ?? const <Map<String, Object?>>[],
              ) ||
              (requiredPayloadColumns.isNotEmpty &&
                  !(snapshot.tables[table]?.columns.toSet() ?? const <String>{}).containsAll(
                    requiredPayloadColumns,
                  )))) {
        tableHealth[table] = 'malformed';
        _fail('malformed_schema', recordType: table, field: 'table');
        continue;
      }
      if (snapshot.userVersion >= 25 && present) {
        final _SnapTable tableSnapshot = snapshot.tables[table]!;
        final bool specialConstraintsValid = switch (table) {
          'account_opening_balance_sources' =>
            tableSnapshot.hasCanonicalUniqueIndexCollations &&
                MigrationRunner.hasAccountOpeningBalanceSourceSchema(
                  tableSql: tableSnapshot.createSql,
                  columns: tableSnapshot.schemaColumns,
                  foreignKeys: tableSnapshot.foreignKeys,
                  uniqueIndexes: tableSnapshot.uniqueIndexesByColumns,
                  triggers: tableSnapshot.triggers,
                ),
          'mileage_posting_account_mapping' => MigrationRunner.hasMileagePostingMappingSchema(
            tableSql: tableSnapshot.createSql ?? '',
            columns: tableSnapshot.schemaColumns,
            foreignKeys: tableSnapshot.foreignKeys,
          ),
          'mileage_posting_period_closures' => MigrationRunner.hasMileagePostingPeriodClosureSchema(
            tableSql: tableSnapshot.createSql ?? '',
            columns: tableSnapshot.schemaColumns,
          ),
          _ => true,
        };
        if (!specialConstraintsValid) {
          tableHealth[table] = 'malformed';
          _fail('malformed_schema', recordType: table, field: 'table');
          continue;
        }
      }
      if (!AppDatabase.allTableNames.contains(table)) {
        // Feature-owned, migration-required table at or past its version.
        if (!present) {
          tableHealth[table] = 'missing';
          _fail('missing_table', recordType: table, field: 'table');
        } else {
          tableHealth[table] = 'ok';
        }
        continue;
      }
      if (!present) {
        tableHealth[table] = 'missing';
        _fail('missing_table', recordType: table, field: 'table');
      } else {
        tableHealth[table] = 'ok';
      }
    }
    if (snapshot.userVersion > MigrationRunner.currentVersion) {
      _fail('unsupported', recordId: snapshot.userVersion, field: 'schema_version');
      tableHealth['schema_version'] = 'unsupported';
      _snapshotUsable = false;
      return;
    }
    if (snapshot.userVersion < MigrationRunner.currentVersion) {
      // Older profiles stay valid for their own version but are never a
      // complete source for the supported export schema.
      _fail('version_pending', recordId: snapshot.userVersion, field: 'schema_version');
      tableHealth['schema_version'] = 'version_pending';
    }
    // A missing payment table at v8 or later is the durable incomplete
    // signal: preserve it, never recreate it here.
    final bool paymentPresent = snapshot.tables['forderung_zahlungen']?.present ?? false;
    if (!paymentPresent && snapshot.userVersion >= 8) {
      tableHealth['forderung_zahlungen'] = 'missing';
    }
  }

  void _validateLazyMarkerInventory(_CustomerSnapshot snapshot) {
    if (snapshot.userVersion < 13) return;
    final _SnapTable? markers = snapshot.tables['feature_table_state'];
    if (markers == null || !markers.present) return;
    final Set<String> names = <String>{};
    _lazyMarkerInventoryValid = markers.rows.length == CustomerDisclosureInventory.lazyOccurrenceTables.length;
    for (final Map<String, Object?> row in markers.rows) {
      final String? name = row['table_name']?.toString();
      if (name == null || !CustomerDisclosureInventory.lazyOccurrenceTables.contains(name) || !names.add(name)) {
        _lazyMarkerInventoryValid = false;
      }
    }
    if (names.length != CustomerDisclosureInventory.lazyOccurrenceTables.length) {
      _lazyMarkerInventoryValid = false;
    }
    if (!_lazyMarkerInventoryValid) {
      _fail('unknown_state', recordType: 'feature_table_state', field: 'table_name');
    }
  }

  String _lazyHealth(_CustomerSnapshot snapshot, String table, bool present) {
    final _SnapTable? markers = snapshot.tables['feature_table_state'];
    if (markers == null || !markers.present) {
      if (snapshot.userVersion < 13) {
        return 'version_pending';
      }
      _fail('missing_table', recordType: 'feature_table_state', field: 'table');
      return 'missing';
    }
    if (snapshot.userVersion >= 13 && !_lazyMarkerInventoryValid) {
      return 'unknown';
    }
    String? state;
    for (final Map<String, Object?> row in markers.rows) {
      if (row['table_name']?.toString() == table) {
        state = row['state']?.toString();
      }
    }
    if (state == null) {
      _fail('unknown_state', recordType: table, field: 'state');
      return 'unknown';
    }
    final bool valid =
        (state == 'never_initialized' && !present) ||
        (state == 'initialized' && present) ||
        (state == 'unknown' && !present);
    if (!valid) {
      _fail('unknown_state', recordType: table, field: 'state');
      return 'mismatch';
    }
    if (state == 'unknown') {
      _fail('unknown_state', recordType: table, field: 'state');
      return 'unknown';
    }
    return 'ok';
  }

  /// Follows the declared relationship inventory from the customer row.
  void traverse(_CustomerSnapshot snapshot) {
    final Set<int> addressIds = <int>{};
    for (final Map<String, Object?> row in snapshot.rowsOf('kunden_lieferadressen')) {
      if (row['kunde_id'] == customerId && row['id'] is int) {
        addressIds.add(row['id']! as int);
      }
    }

    final Set<int> invoiceIds = <int>{};
    for (final Map<String, Object?> row in snapshot.rowsOf('rechnungen')) {
      final Object? kundeId = row['kunde_id'];
      final Object? adresseId = row['lieferadresse_id'];
      if (kundeId == customerId || (adresseId is int && addressIds.contains(adresseId))) {
        _verifySeedInvoice(row, addressIds, invoiceIds);
      }
    }
    _closeInvoiceLineage(snapshot, addressIds, invoiceIds);

    final Set<int> templateIds = <int>{};
    final Set<int> occurrenceIds = <int>{};
    for (final Map<String, Object?> row in snapshot.rowsOf('rechnungsvorlagen')) {
      final Object? vorlageId = row['id'];
      if (vorlageId is! int) continue;
      bool owned = row['kunde_id'] == customerId;
      if (!owned) {
        for (final int invoiceId in invoiceIds) {
          final Map<String, Object?>? invoice = _byId(snapshot.rowsOf('rechnungen'), invoiceId);
          if (invoice != null && invoice['vorlage_id'] == vorlageId) {
            owned = true;
          }
        }
      }
      if (!owned) continue;
      if (row['kunde_id'] != null && row['kunde_id'] != customerId) {
        _fail('conflicting_identity', recordType: 'rechnungsvorlagen', recordId: vorlageId, field: 'kunde_id');
        continue;
      }
      if (!_verifyTemplateSource(snapshot, row, addressIds, invoiceIds)) {
        continue;
      }
      templateIds.add(vorlageId);
    }
    // Invoices generated from or sourced by owned templates still require a
    // matching customer or delivery-address identity.
    for (final Map<String, Object?> row in snapshot.rowsOf('rechnungen')) {
      final Object? id = row['id'];
      if (id is! int || invoiceIds.contains(id)) continue;
      final Object? vorlageId = row['vorlage_id'];
      if (vorlageId is int && templateIds.contains(vorlageId)) {
        _verifySeedInvoice(row, addressIds, invoiceIds);
      }
    }
    _closeInvoiceLineage(snapshot, addressIds, invoiceIds);
    templateIds.removeWhere((int templateId) {
      final Map<String, Object?>? template = _byId(snapshot.rowsOf('rechnungsvorlagen'), templateId);
      if (template == null || template['kunde_id'] == customerId) return false;
      return !invoiceIds.any((int invoiceId) {
        final Map<String, Object?>? invoice = _byId(snapshot.rowsOf('rechnungen'), invoiceId);
        return invoice?['vorlage_id'] == templateId;
      });
    });
    for (final Map<String, Object?> row in snapshot.rowsOf('rechnungsvorlagen_occurrences')) {
      // Occurrence rows follow owned templates; their invoice must verify.
      // A conflicting or dangling invoice excludes the occurrence.
      if (row['vorlage_id'] is int && templateIds.contains(row['vorlage_id'])) {
        final Object? rechnungId = row['rechnung_id'];
        final Object? occId = row['id'];
        if (rechnungId is! int || occId is! int) {
          continue;
        }
        final Map<String, Object?>? invoice = _byId(snapshot.rowsOf('rechnungen'), rechnungId);
        if (invoice == null) {
          _fail('missing', recordType: 'rechnungsvorlagen_occurrences', recordId: occId, field: 'rechnung_id');
          continue;
        }
        _verifySeedInvoice(invoice, addressIds, invoiceIds);
        if (invoiceIds.contains(rechnungId)) {
          occurrenceIds.add(occId);
        }
      }
    }

    final Set<int> receivableIds = <int>{};
    for (final Map<String, Object?> row in snapshot.rowsOf('forderungen')) {
      _verifyReceivable(row, invoiceIds, receivableIds);
    }
    for (final Map<String, Object?> row in snapshot.rowsOf('settlement_allocations')) {
      if (row['forderung_id'] is int && receivableIds.contains(row['forderung_id'])) {
        _fail('unsupported', recordType: 'settlement_allocations', recordId: row['id']);
      }
    }

    final Set<int> journalIds = <int>{};
    for (final Map<String, Object?> row in snapshot.rowsOf('journal')) {
      final Object? id = row['id'];
      if (id is! int) continue;
      if (row['rechnung_id'] is int && invoiceIds.contains(row['rechnung_id'])) {
        journalIds.add(id);
      }
    }
    for (final int receivableId in receivableIds) {
      final Map<String, Object?>? receivable = _byId(snapshot.rowsOf('forderungen'), receivableId);
      if (receivable == null) continue;
      for (final String column in <String>['journal_id', 'ausgleich_journal_id']) {
        final Object? journalId = receivable[column];
        if (journalId == null) continue;
        if (journalId is! int || _byId(snapshot.rowsOf('journal'), journalId) == null) {
          _fail('missing', recordType: 'forderungen', recordId: receivableId, field: column);
          continue;
        }
        journalIds.add(journalId);
      }
    }
    for (final Map<String, Object?> row in snapshot.rowsOf('forderung_zahlungen')) {
      if (row['forderung_id'] is int && receivableIds.contains(row['forderung_id'])) {
        final Object? journalId = row['journal_id'];
        if (journalId == null) continue;
        if (journalId is! int || _byId(snapshot.rowsOf('journal'), journalId) == null) {
          _fail('missing', recordType: 'forderung_zahlungen', recordId: row['id'], field: 'journal_id');
          continue;
        }
        journalIds.add(journalId);
      }
    }

    final Set<int> belegIds = <int>{};
    final Set<int> customerBelegLinkIds = <int>{};
    for (final Map<String, Object?> row in snapshot.rowsOf('kunden_belege')) {
      if (row['kunde_id'] != customerId) continue;
      final Object? linkId = row['id'];
      final Object? belegId = row['beleg_id'];
      if (belegId is int && _byId(snapshot.rowsOf('belege'), belegId) != null) {
        belegIds.add(belegId);
        if (linkId is int) customerBelegLinkIds.add(linkId);
      } else {
        _fail('missing', recordType: 'kunden_belege', recordId: linkId, field: 'beleg_id');
      }
    }

    final Set<int> reminderIds = <int>{};
    for (final Map<String, Object?> row in snapshot.rowsOf('mahnungen')) {
      final Object? id = row['id'];
      if (id is! int) continue;
      final Object? invoiceId = row['rechnung_id'];
      final bool linkedInvoice = invoiceId is int && invoiceIds.contains(invoiceId);
      final bool linkedCustomer = row['kunde_id'] == customerId;
      if (!linkedInvoice && !linkedCustomer) continue;
      if (linkedInvoice && row['kunde_id'] != null && row['kunde_id'] != customerId) {
        _fail('conflicting_identity', recordType: 'mahnungen', recordId: id, field: 'kunde_id');
        continue;
      }
      if (linkedCustomer && invoiceId != null && !linkedInvoice) {
        final bool targetExists = invoiceId is int && _byId(snapshot.rowsOf('rechnungen'), invoiceId) != null;
        _fail(
          targetExists ? 'conflicting_identity' : 'missing',
          recordType: 'mahnungen',
          recordId: id,
          field: 'rechnung_id',
        );
        continue;
      }
      reminderIds.add(id);
    }
    for (final Map<String, Object?> row in snapshot.rowsOf('dokument_email_versuche')) {
      final Object? documentId = row['dokument_id'];
      final bool linkedInvoice = documentId is int && invoiceIds.contains(documentId);
      final Object? reminderId = row['mahnung_id'];
      final bool linkedReminder =
          (reminderId is int && reminderIds.contains(reminderId)) ||
          (documentId is int && reminderIds.contains(documentId));
      if (linkedInvoice || linkedReminder) {
        _fail('unsupported', recordType: 'dokument_email_versuche', recordId: row['id']);
      }
    }

    included['kunden'] = <Map<String, Object?>>[customer];
    included['kunden_lieferadressen'] = <Map<String, Object?>>[
      for (final Map<String, Object?> row in snapshot.rowsOf('kunden_lieferadressen'))
        if (row['kunde_id'] == customerId) row,
    ];
    included['rechnungen'] = <Map<String, Object?>>[
      for (final Map<String, Object?> row in snapshot.rowsOf('rechnungen'))
        if (row['id'] is int && invoiceIds.contains(row['id'])) row,
    ];
    included['rechnungspositionen'] = <Map<String, Object?>>[
      for (final Map<String, Object?> row in snapshot.rowsOf('rechnungspositionen'))
        if (row['rechnung_id'] is int && invoiceIds.contains(row['rechnung_id'])) row,
    ];
    included['mahnungen'] = <Map<String, Object?>>[
      for (final Map<String, Object?> row in snapshot.rowsOf('mahnungen'))
        if (row['id'] is int && reminderIds.contains(row['id'])) row,
    ];
    included['forderungen'] = <Map<String, Object?>>[
      for (final Map<String, Object?> row in snapshot.rowsOf('forderungen'))
        if (row['id'] is int && receivableIds.contains(row['id'])) row,
    ];
    included['forderung_zahlungen'] = <Map<String, Object?>>[
      for (final Map<String, Object?> row in snapshot.rowsOf('forderung_zahlungen'))
        if (row['forderung_id'] is int && receivableIds.contains(row['forderung_id'])) row,
    ];
    included['journal'] = <Map<String, Object?>>[
      for (final Map<String, Object?> row in snapshot.rowsOf('journal'))
        if (row['id'] is int && journalIds.contains(row['id'])) row,
    ];
    included['vorsteuer_ansprueche'] = <Map<String, Object?>>[
      for (final Map<String, Object?> row in snapshot.rowsOf('vorsteuer_ansprueche'))
        if (row['rechnung_id'] is int && invoiceIds.contains(row['rechnung_id'])) row,
    ];
    included['rechnungsvorlagen'] = <Map<String, Object?>>[
      for (final Map<String, Object?> row in snapshot.rowsOf('rechnungsvorlagen'))
        if (row['id'] is int && templateIds.contains(row['id'])) row,
    ];
    included['rechnungsvorlagen_occurrences'] = <Map<String, Object?>>[
      for (final Map<String, Object?> row in snapshot.rowsOf('rechnungsvorlagen_occurrences'))
        if (row['id'] is int && occurrenceIds.contains(row['id'])) row,
    ];
    included['kunden_belege'] = <Map<String, Object?>>[
      for (final Map<String, Object?> row in snapshot.rowsOf('kunden_belege'))
        if (row['id'] is int && customerBelegLinkIds.contains(row['id'])) row,
    ];
    included['belege'] = <Map<String, Object?>>[
      for (final Map<String, Object?> row in snapshot.rowsOf('belege'))
        if (row['id'] is int && belegIds.contains(row['id'])) row,
    ];
    // Booking-template occurrences are projected only as event rows reached
    // through an included invoice or journal row; their unrelated
    // booking-template relationship is never traversed.
    included['buchungsvorlagen_occurrences'] = <Map<String, Object?>>[
      for (final Map<String, Object?> row in snapshot.rowsOf('buchungsvorlagen_occurrences'))
        if ((row['rechnung_id'] is int && invoiceIds.contains(row['rechnung_id'])) ||
            (row['journal_id'] is int && journalIds.contains(row['journal_id'])))
          row,
    ];
  }

  void _verifySeedInvoice(Map<String, Object?> row, Set<int> addressIds, Set<int> invoiceIds) {
    final Object? id = row['id'];
    if (id is! int) return;
    final Object? kundeId = row['kunde_id'];
    if (kundeId != null && kundeId != customerId) {
      _fail('conflicting_identity', recordType: 'rechnungen', recordId: id, field: 'kunde_id');
      return;
    }
    final Object? adresseId = row['lieferadresse_id'];
    if (adresseId != null && !(adresseId is int && addressIds.contains(adresseId))) {
      _fail('conflicting_identity', recordType: 'rechnungen', recordId: id, field: 'lieferadresse_id');
      return;
    }
    invoiceIds.add(id);
  }

  void _closeInvoiceLineage(_CustomerSnapshot snapshot, Set<int> addressIds, Set<int> invoiceIds) {
    final List<Map<String, Object?>> invoices = snapshot.rowsOf('rechnungen');
    final Map<int, Map<String, Object?>> byId = <int, Map<String, Object?>>{
      for (final Map<String, Object?> row in invoices)
        if (row['id'] is int) row['id']! as int: row,
    };
    final Map<int, Set<int>> neighbors = <int, Set<int>>{for (final int id in byId.keys) id: <int>{}};
    for (final Map<String, Object?> row in invoices) {
      final Object? id = row['id'];
      if (id is! int) continue;
      for (final String column in CustomerDisclosureInventory.invoiceLineageColumns) {
        final Object? target = row[column];
        if (target is! int) continue;
        neighbors[id]!.add(target);
        neighbors[target]?.add(id);
      }
    }

    final List<int> queue = invoiceIds.toList(growable: true);
    for (int cursor = 0; cursor < queue.length; cursor++) {
      for (final int neighborId in neighbors[queue[cursor]] ?? const <int>{}) {
        if (invoiceIds.contains(neighborId)) continue;
        final Map<String, Object?>? row = byId[neighborId];
        if (row == null || !_verifyLineagePointers(row, byId)) continue;
        final int before = invoiceIds.length;
        _verifySeedInvoice(row, addressIds, invoiceIds);
        if (invoiceIds.length > before) queue.add(neighborId);
      }
    }

    final Set<int> excluded = <int>{};
    for (final int id in invoiceIds) {
      final Map<String, Object?>? row = byId[id];
      if (row == null) continue;
      if (!_verifyLineagePointers(row, byId)) {
        excluded.add(id);
        continue;
      }
      for (final String column in CustomerDisclosureInventory.invoiceLineageColumns) {
        final Object? targetId = row[column];
        if (targetId == null) continue;
        final Map<String, Object?>? target = targetId is int ? byId[targetId] : null;
        if (target == null) {
          _fail('missing', recordType: 'rechnungen', recordId: id, field: column);
          excluded.add(id);
          break;
        }
        final Object? targetCustomerId = target['kunde_id'];
        final Object? targetAddressId = target['lieferadresse_id'];
        if (!invoiceIds.contains(targetId) ||
            (targetCustomerId != null && targetCustomerId != customerId) ||
            (targetAddressId != null && !(targetAddressId is int && addressIds.contains(targetAddressId)))) {
          _fail('conflicting_identity', recordType: 'rechnungen', recordId: id, field: column);
          excluded.add(id);
          break;
        }
      }
    }

    final List<int> invalidQueue = excluded.toList(growable: true);
    for (int cursor = 0; cursor < invalidQueue.length; cursor++) {
      final int invalidId = invalidQueue[cursor];
      for (final int candidateId in neighbors[invalidId] ?? const <int>{}) {
        if (!invoiceIds.contains(candidateId) || excluded.contains(candidateId)) {
          continue;
        }
        final Map<String, Object?> candidate = byId[candidateId]!;
        final String? dependentField = CustomerDisclosureInventory.invoiceLineageColumns
            .where((String column) => candidate[column] == invalidId)
            .firstOrNull;
        if (dependentField == null) continue;
        _fail('conflicting_identity', recordType: 'rechnungen', recordId: candidateId, field: dependentField);
        excluded.add(candidateId);
        invalidQueue.add(candidateId);
      }
    }
    invoiceIds.removeAll(excluded);
  }

  /// Inverse konvertiert pointers must agree when both are populated.
  bool _verifyLineagePointers(Map<String, Object?> row, Map<int, Map<String, Object?>> invoicesById) {
    final Object? id = row['id'];
    for (final (String, String) pair in const <(String, String)>[('konvertiert_von', 'konvertiert_zu')]) {
      final Object? forward = row[pair.$2];
      if (forward is int) {
        final Map<String, Object?>? target = invoicesById[forward];
        final Object? back = target?[pair.$1];
        if (back != null && back != id) {
          _fail('conflicting_identity', recordType: 'rechnungen', recordId: id, field: pair.$2);
          return false;
        }
      }
      final Object? backward = row[pair.$1];
      if (backward is int) {
        final Map<String, Object?>? source = invoicesById[backward];
        final Object? forth = source?[pair.$2];
        if (forth != null && forth != id) {
          _fail('conflicting_identity', recordType: 'rechnungen', recordId: id, field: pair.$1);
          return false;
        }
      }
    }
    return true;
  }

  /// A template source invoice (auftrag_id) must resolve to the customer.
  bool _verifyTemplateSource(
    _CustomerSnapshot snapshot,
    Map<String, Object?> template,
    Set<int> addressIds,
    Set<int> invoiceIds,
  ) {
    final Object? auftragId = template['auftrag_id'];
    if (auftragId == null) return true;
    if (auftragId is! int) {
      _fail('conflicting_identity', recordType: 'rechnungsvorlagen', recordId: template['id'], field: 'auftrag_id');
      return false;
    }
    final Map<String, Object?>? source = _byId(snapshot.rowsOf('rechnungen'), auftragId);
    if (source == null) {
      _fail('missing', recordType: 'rechnungsvorlagen', recordId: template['id'], field: 'auftrag_id');
      return false;
    }
    if (!invoiceIds.contains(auftragId)) {
      _fail('conflicting_identity', recordType: 'rechnungsvorlagen', recordId: template['id'], field: 'auftrag_id');
      return false;
    }
    final Set<int> verifiedSource = <int>{};
    _verifySeedInvoice(source, addressIds, verifiedSource);
    return verifiedSource.contains(auftragId);
  }

  /// Typed receivable identity: kunde_id, the (partner_typ, partner_id) pair,
  /// and rechnung_id must agree with the selected customer and included
  /// invoices. Supplier, other-customer, unknown-partner, or dangling
  /// references exclude the row and make the archive incomplete.
  void _verifyReceivable(Map<String, Object?> row, Set<int> invoiceIds, Set<int> receivableIds) {
    final Object? id = row['id'];
    if (id is! int) return;
    final Object? kundeId = row['kunde_id'];
    final Object? partnerTyp = row['partner_typ'];
    final Object? partnerId = row['partner_id'];
    final Object? rechnungId = row['rechnung_id'];
    final bool byKunde = kundeId == customerId;
    // partner_id 0 is the schema placeholder for "no typed partner" and does
    // not establish or contradict identity; only a populated pair must agree.
    final bool pairPopulated = partnerId != null && partnerId != 0;
    final bool byPartner = pairPopulated && partnerTyp == 'kunde' && partnerId == customerId;
    final bool byRechnung = rechnungId is int && invoiceIds.contains(rechnungId);
    if (!byKunde && !byPartner && !byRechnung) return;
    if (kundeId != null && kundeId != customerId) {
      _fail('conflicting_identity', recordType: 'forderungen', recordId: id, field: 'kunde_id');
      return;
    }
    if (pairPopulated && !(partnerTyp == 'kunde' && partnerId == customerId)) {
      _fail('conflicting_identity', recordType: 'forderungen', recordId: id, field: 'partner_typ');
      return;
    }
    if (rechnungId != null && !(rechnungId is int && invoiceIds.contains(rechnungId))) {
      _fail('conflicting_identity', recordType: 'forderungen', recordId: id, field: 'rechnung_id');
      return;
    }
    receivableIds.add(id);
  }

  /// Projects included rows through the versioned field allowlists and
  /// resolves linked evidence against the canonical profile root.
  void projectEvidence(_CustomerSnapshot snapshot, String resolvedRoot, String profileDir) {
    final Set<int> linkedBelegIds = <int>{
      for (final Map<String, Object?> row in included['belege'] ?? const <Map<String, Object?>>[])
        if (row['id'] is int) row['id']! as int,
    };
    for (final String table in CustomerDisclosureInventory.payloadTables) {
      final List<Map<String, Object?>> projected = <Map<String, Object?>>[];
      for (final Map<String, Object?> row in included[table] ?? const <Map<String, Object?>>[]) {
        projected.add(_projectRow(snapshot, table, row, linkedBelegIds, resolvedRoot, profileDir));
      }
      included[table] = projected;
      recordCounts[table] = projected.length;
    }
  }

  Map<String, Object?> _projectRow(
    _CustomerSnapshot snapshot,
    String table,
    Map<String, Object?> row,
    Set<int> linkedBelegIds,
    String resolvedRoot,
    String profileDir,
  ) {
    final String recordId = row['id']?.toString() ?? '';
    final Map<String, Object?> exported = <String, Object?>{};
    final Set<String> allowlist = CustomerDisclosureInventory.fieldAllowlists[table] ?? const <String>{};
    final Set<String> omitted = CustomerDisclosureInventory.omittedFields[table] ?? const <String>{};
    final Set<String> evidenceFields = <String>{
      for (final (String, String) column in CustomerDisclosureInventory.evidenceColumns)
        if (column.$1 == table) column.$2,
    };
    // journal.beleg_id is retained only when it resolves to evidence already
    // linked to the selected customer.
    final bool keepJournalBeleg =
        table == 'journal' && row['beleg_id'] is int && linkedBelegIds.contains(row['beleg_id']);
    for (final MapEntry<String, Object?> cell in row.entries) {
      final String column = cell.key;
      final Object? value = cell.value;
      if (evidenceFields.contains(column)) continue;
      if (column == 'beleg_id' && table == 'journal') {
        if (keepJournalBeleg) {
          exported[column] = value;
        } else if (_hasValue(value)) {
          _noteOmitted(table, recordId, column, 'omitted_cross_party');
        }
        continue;
      }
      if (omitted.contains(column)) {
        if (_hasValue(value)) {
          final String reason = table == 'buchungsvorlagen_occurrences' && column == 'vorlage_id'
              ? 'omitted_unrelated'
              : 'omitted_cross_party';
          _noteOmitted(table, recordId, column, reason);
        }
        continue;
      }
      if (!allowlist.contains(column)) {
        // Unknown columns are never serialized; a non-empty value whose scope
        // cannot be proven outside this disclosure makes the result incomplete.
        if (_hasValue(value)) {
          _noteOmitted(table, recordId, column, 'unclassified_field');
        }
        continue;
      }
      if (table == 'rechnungen' &&
          column == 'vorlage_id' &&
          _hasValue(value) &&
          (value is! int || _byId(included['rechnungsvorlagen'] ?? const <Map<String, Object?>>[], value) == null)) {
        _noteOmitted(table, recordId, column, 'omitted_cross_party');
        continue;
      }
      if (((table == 'forderungen' && <String>{'journal_id', 'ausgleich_journal_id'}.contains(column)) ||
              (table == 'forderung_zahlungen' && column == 'journal_id')) &&
          _hasValue(value) &&
          (value is! int || _byId(included['journal'] ?? const <Map<String, Object?>>[], value) == null)) {
        // The traversal already records the missing target; omit its dangling key.
        continue;
      }
      exported[column] = value;
    }
    for (final (String, String) column in CustomerDisclosureInventory.evidenceColumns) {
      if (column.$1 != table) continue;
      final Object? raw = row[column.$2];
      if (!_hasValue(raw)) {
        exported[column.$2] = null;
        continue;
      }
      if (table == 'belege' && _hasValue(row['lieferant_id'])) {
        // Supplier-linked receipt: unresolved mixed-party scope.
        exclusions.add(
          CustomerDisclosureExclusion(recordType: table, recordId: recordId, field: column.$2, reason: 'unsupported'),
        );
        _complete = false;
        exported[column.$2] = null;
        continue;
      }
      final _CustomerArtifactResolution resolution = _resolveArtifact(
        table: table,
        recordId: recordId,
        field: column.$2,
        raw: raw.toString(),
        resolvedRoot: resolvedRoot,
        profileDir: profileDir,
      );
      if (resolution.exclusion != null) {
        exclusions.add(resolution.exclusion!);
        _complete = false;
        exported[column.$2] = null;
      } else if (resolution.evidence != null) {
        evidence.add(resolution.evidence!);
        exported[column.$2] = resolution.evidence!.archivePath;
      } else {
        exported[column.$2] = null;
      }
    }
    return exported;
  }

  void _noteOmitted(String table, String recordId, String field, String reason) {
    omittedFields.add(<String, Object?>{'record_type': table, 'record_id': recordId, 'field': field, 'reason': reason});
    exclusions.add(CustomerDisclosureExclusion(recordType: table, recordId: recordId, field: field, reason: reason));
    _complete = false;
  }

  /// Canonical-resolve plus inside-root check; copies nothing, only reads.
  _CustomerArtifactResolution _resolveArtifact({
    required String table,
    required String recordId,
    required String field,
    required String raw,
    required String resolvedRoot,
    required String profileDir,
  }) {
    CustomerDisclosureExclusion exclusion(String reason) =>
        CustomerDisclosureExclusion(recordType: table, recordId: recordId, field: field, reason: reason);
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return const _CustomerArtifactResolution.empty();
    final String candidate = p.isAbsolute(trimmed) ? p.normalize(trimmed) : p.normalize(p.join(profileDir, trimmed));
    if (FileSystemEntity.typeSync(candidate, followLinks: false) == FileSystemEntityType.notFound) {
      return _CustomerArtifactResolution.excluded(exclusion('missing'));
    }
    final String canonical;
    try {
      canonical = File(candidate).resolveSymbolicLinksSync();
    } catch (_) {
      return _CustomerArtifactResolution.excluded(exclusion('unreadable'));
    }
    if (canonical != resolvedRoot && !p.isWithin(resolvedRoot, canonical)) {
      return _CustomerArtifactResolution.excluded(exclusion('outside_profile'));
    }
    if (FileSystemEntity.typeSync(canonical, followLinks: false) != FileSystemEntityType.file) {
      return _CustomerArtifactResolution.excluded(exclusion('unreadable'));
    }
    final Uint8List bytes;
    try {
      bytes = File(canonical).readAsBytesSync();
    } catch (_) {
      return _CustomerArtifactResolution.excluded(exclusion('unreadable'));
    }
    final String digest = sha256.convert(bytes).toString();
    final String safeId = recordId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    final String archivePath =
        'evidence/${table}_${safeId}_${field}_${digest.substring(0, 12)}${_safeExtension(candidate)}';
    return _CustomerArtifactResolution.included(
      _CustomerEvidenceFile(archivePath: archivePath, sha256: digest, bytes: bytes),
    );
  }

  Map<String, String> recordPayloads() {
    return <String, String>{
      for (final String table in CustomerDisclosureInventory.payloadTables)
        'records/$table.jsonl':
            <String>[
              for (final Map<String, Object?> row in included[table] ?? const <Map<String, Object?>>[]) jsonEncode(row),
            ].join('\n') +
            ((included[table] ?? const []).isEmpty ? '' : '\n'),
    };
  }

  Map<String, Object?> manifest({
    required String profileLabel,
    required DateTime Function() clock,
    required Map<String, String> recordPayloads,
  }) {
    final String display = customer['name']?.toString() ?? 'Kunde #$customerId';
    return <String, Object?>{
      'archive_version': CustomerDataDisclosureExportService.archiveVersion,
      'record_version': CustomerDataDisclosureExportService.recordVersion,
      'record_projection_version': CustomerDataDisclosureExportService.recordProjectionVersion,
      'schema_version': MigrationRunner.currentVersion,
      'profile_label': profileLabel,
      'customer': <String, Object?>{'id': customerId, 'display': display},
      'created_at': clock().toUtc().toIso8601String(),
      'complete': complete,
      'outcome': complete ? 'complete' : 'incomplete',
      'record_counts': Map<String, int>.from(recordCounts),
      'relationship_paths': CustomerDisclosureInventory.relationshipPaths,
      'table_health': Map<String, String>.from(tableHealth),
      'evidence': <Map<String, Object?>>[
        for (final _CustomerEvidenceFile item in evidence)
          <String, Object?>{'archive_path': item.archivePath, 'sha256': item.sha256},
      ],
      'record_files': <Map<String, Object?>>[
        for (final MapEntry<String, String> payload in recordPayloads.entries)
          <String, Object?>{
            'path': payload.key,
            'sha256': sha256.convert(utf8.encode(payload.value)).toString(),
            'rows': recordCounts[payload.key.substring('records/'.length, payload.key.length - '.jsonl'.length)] ?? 0,
          },
      ],
      'exclusions': <Map<String, Object?>>[for (final CustomerDisclosureExclusion item in exclusions) item.toJson()],
      'omitted_fields': omittedFields,
      'legal_note': CustomerDataDisclosureExportService._legalNote,
    };
  }

  static Map<String, Object?>? _byId(List<Map<String, Object?>> rows, int id) {
    for (final Map<String, Object?> row in rows) {
      if (row['id'] == id) return row;
    }
    return null;
  }

  static bool _hasValue(Object? value) => value != null && (value is! String || value.trim().isNotEmpty);

  static String _safeExtension(String sourcePath) {
    final String extension = p.extension(sourcePath).toLowerCase();
    if (RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(extension)) {
      return extension;
    }
    return '.bin';
  }
}

class _CustomerEvidenceFile {
  const _CustomerEvidenceFile({required this.archivePath, required this.sha256, required this.bytes});
  final String archivePath;
  final String sha256;
  final Uint8List bytes;
}

class _CustomerArtifactResolution {
  const _CustomerArtifactResolution._({this.exclusion, this.evidence});
  const _CustomerArtifactResolution.empty() : this._();
  _CustomerArtifactResolution.excluded(CustomerDisclosureExclusion exclusion) : this._(exclusion: exclusion);
  _CustomerArtifactResolution.included(_CustomerEvidenceFile evidence) : this._(evidence: evidence);

  final CustomerDisclosureExclusion? exclusion;
  final _CustomerEvidenceFile? evidence;
}

class _CustomerZipEntry {
  const _CustomerZipEntry({required this.name, required this.data});
  final String name;
  final List<int> data;
}

final List<int> _customerCrcTable = List<int>.generate(256, (int index) {
  var value = index;
  for (var round = 0; round < 8; round++) {
    value = (value & 1) != 0 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
  }
  return value;
});

int _customerCrc32(List<int> data) {
  var crc = 0xffffffff;
  for (final int byte in data) {
    crc = _customerCrcTable[(crc ^ byte) & 0xff] ^ ((crc >>> 8) & 0xffffff);
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

void _writeCustomerU16(BytesBuilder out, int value) {
  out.add(<int>[value & 0xff, (value >> 8) & 0xff]);
}

void _writeCustomerU32(BytesBuilder out, int value) {
  out.add(<int>[value & 0xff, (value >> 8) & 0xff, (value >> 16) & 0xff, (value >> 24) & 0xff]);
}

(int, int) _customerDosTime(DateTime time) {
  final int date = ((time.year - 1980) << 9) | (time.month << 5) | time.day;
  final int clock = (time.hour << 11) | (time.minute << 5) | (time.second ~/ 2);
  return (clock, date);
}

/// Minimal stored (uncompressed) ZIP writer; avoids a new dependency.
Uint8List _encodeCustomerZip(List<_CustomerZipEntry> entries) {
  final BytesBuilder out = BytesBuilder();
  final BytesBuilder central = BytesBuilder();
  final DateTime now = DateTime.now();
  final (int, int) stamp = _customerDosTime(now);
  var offset = 0;
  for (final _CustomerZipEntry entry in entries) {
    final List<int> name = utf8.encode(entry.name);
    final int crc = _customerCrc32(entry.data);
    final int size = entry.data.length;
    _writeCustomerU32(out, 0x04034b50);
    _writeCustomerU16(out, 20);
    _writeCustomerU16(out, 0x0800);
    _writeCustomerU16(out, 0);
    _writeCustomerU16(out, stamp.$1);
    _writeCustomerU16(out, stamp.$2);
    _writeCustomerU32(out, crc);
    _writeCustomerU32(out, size);
    _writeCustomerU32(out, size);
    _writeCustomerU16(out, name.length);
    _writeCustomerU16(out, 0);
    out.add(name);
    out.add(entry.data);
    _writeCustomerU32(central, 0x02014b50);
    _writeCustomerU16(central, 20);
    _writeCustomerU16(central, 20);
    _writeCustomerU16(central, 0x0800);
    _writeCustomerU16(central, 0);
    _writeCustomerU16(central, stamp.$1);
    _writeCustomerU16(central, stamp.$2);
    _writeCustomerU32(central, crc);
    _writeCustomerU32(central, size);
    _writeCustomerU32(central, size);
    _writeCustomerU16(central, name.length);
    _writeCustomerU16(central, 0);
    _writeCustomerU16(central, 0);
    _writeCustomerU16(central, 0);
    _writeCustomerU16(central, 0);
    _writeCustomerU32(central, 0);
    _writeCustomerU32(central, offset);
    central.add(name);
    offset += 30 + name.length + size;
  }
  final Uint8List centralBytes = central.takeBytes();
  final int centralOffset = offset;
  out.add(centralBytes);
  _writeCustomerU32(out, 0x06054b50);
  _writeCustomerU16(out, 0);
  _writeCustomerU16(out, 0);
  _writeCustomerU16(out, entries.length);
  _writeCustomerU16(out, entries.length);
  _writeCustomerU32(out, centralBytes.length);
  _writeCustomerU32(out, centralOffset);
  _writeCustomerU16(out, 0);
  return out.takeBytes();
}

/// Stored-ZIP reader with CRC verification; throws on any structural flaw.
List<_CustomerZipEntry> _decodeCustomerZip(List<int> bytes) {
  final Uint8List raw = Uint8List.fromList(bytes);
  if (raw.length < 22) {
    throw StateError('Ungültiges Export-Archiv');
  }
  final ByteData view = ByteData.sublistView(raw);
  var endOfCentral = -1;
  final int scanStart = raw.length - 22;
  for (var i = scanStart; i >= 0 && i >= raw.length - 65557; i--) {
    if (view.getUint32(i, Endian.little) == 0x06054b50) {
      endOfCentral = i;
      break;
    }
  }
  if (endOfCentral < 0) {
    throw StateError('Ungültiges Export-Archiv');
  }
  final int count = view.getUint16(endOfCentral + 10, Endian.little);
  final int centralSize = view.getUint32(endOfCentral + 12, Endian.little);
  final int centralOffset = view.getUint32(endOfCentral + 16, Endian.little);
  if (centralOffset + centralSize > raw.length) {
    throw StateError('Ungültiges Export-Archiv');
  }
  final List<_CustomerZipEntry> entries = <_CustomerZipEntry>[];
  var offset = centralOffset;
  for (var index = 0; index < count; index++) {
    if (view.getUint32(offset, Endian.little) != 0x02014b50) {
      throw StateError('Ungültiges Export-Archiv');
    }
    final int method = view.getUint16(offset + 10, Endian.little);
    if (method != 0) {
      throw StateError('Komprimierte Einträge werden nicht unterstützt');
    }
    final int crc = view.getUint32(offset + 16, Endian.little);
    final int compressedSize = view.getUint32(offset + 20, Endian.little);
    final int size = view.getUint32(offset + 24, Endian.little);
    if (compressedSize != size) {
      throw StateError('Ungültiges Export-Archiv');
    }
    final int nameLength = view.getUint16(offset + 28, Endian.little);
    final int extraLength = view.getUint16(offset + 30, Endian.little);
    final int commentLength = view.getUint16(offset + 32, Endian.little);
    final int localOffset = view.getUint32(offset + 42, Endian.little);
    final String name = utf8.decode(raw.sublist(offset + 46, offset + 46 + nameLength));
    if (view.getUint32(localOffset, Endian.little) != 0x04034b50) {
      throw StateError('Ungültiges Export-Archiv');
    }
    final int localNameLength = view.getUint16(localOffset + 26, Endian.little);
    final int localExtraLength = view.getUint16(localOffset + 28, Endian.little);
    final int dataStart = localOffset + 30 + localNameLength + localExtraLength;
    final List<int> data = raw.sublist(dataStart, dataStart + size);
    if (_customerCrc32(data) != crc) {
      throw StateError('Integritätsprüfung fehlgeschlagen');
    }
    entries.add(_CustomerZipEntry(name: name, data: data));
    offset += 46 + nameLength + extraLength + commentLength;
  }
  return entries;
}
