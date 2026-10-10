import 'package:drift/drift.dart';
import 'package:openaccounting/pages/stammdaten/artikel_repository.dart';
import 'package:openaccounting/pages/stammdaten/kategorien_repository.dart';
import 'package:openaccounting/pages/stammdaten/kunden_repository.dart';
import 'package:openaccounting/pages/stammdaten/lieferanten_repository.dart';
import 'package:openaccounting/pages/stammdaten/unternehmen_repository.dart';

/// Typed master-data workspace owners per the route matrix in design.md.
/// Thin use cases over the active-profile repositories; widgets resolve them
/// through the app-wide services aggregate, never through raw SQL or direct GetIt access.

enum ContactKind { customer, supplier }

enum ArticleKind { item, group }

typedef CustomerPage = ({List<Kunde> items, int totalCount, bool hasMore, int page, String effectiveSearch});

typedef SupplierPage = ({List<Lieferant> items, int totalCount, bool hasMore, int page, String effectiveSearch});

typedef ArticlePage = ({List<Artikel> items, int totalCount, bool hasMore, int page, String effectiveSearch});

typedef ArticleGroupPage = ({
  List<ArtikelGruppe> items,
  int totalCount,
  bool hasMore,
  int page,
  String effectiveSearch,
});

class CustomerWorkspaceUseCase {
  const CustomerWorkspaceUseCase(this._repository);

  final KundenRepository _repository;

  Future<CustomerPage> query({
    String search = '',
    bool includeArchived = true,
    bool archivedOnly = false,
    int limit = 25,
    int page = 1,
  }) {
    return _repository.query(
      search: search,
      includeArchived: includeArchived,
      archivedOnly: archivedOnly,
      limit: limit,
      page: page,
    );
  }

  Future<List<Kunde>> listForPicker({String search = '', bool includeArchived = false}) {
    return _repository.listForPicker(search: search, includeArchived: includeArchived);
  }

  Future<List<Kunde>> listArchived() => _repository.listArchived();

  Future<Kunde?> findById(int id) => _repository.findById(id);

  Future<Kunde> update(int id, Map<String, dynamic> values) => _repository.update(id, values);

  Future<Kunde> archive(int id) => _repository.archive(id);

  Future<Kunde> restore(int id) => _repository.restore(id);

  Future<void> bulkArchive(Iterable<int> ids) => _repository.bulkArchive(ids);
}

class SupplierWorkspaceUseCase {
  const SupplierWorkspaceUseCase(this._repository);

  final LieferantenRepository _repository;

  Future<SupplierPage> query({
    String search = '',
    bool includeArchived = true,
    bool archivedOnly = false,
    int limit = 25,
    int page = 1,
  }) {
    return _repository.query(
      search: search,
      includeArchived: includeArchived,
      archivedOnly: archivedOnly,
      limit: limit,
      page: page,
    );
  }

  Future<List<Lieferant>> listForPicker({String search = '', bool includeArchived = false}) {
    return _repository.listForPicker(search: search, includeArchived: includeArchived);
  }

  Future<List<Lieferant>> listArchived() => _repository.listArchived();

  Future<Lieferant?> findById(int id) => _repository.findById(id);

  Future<Lieferant> update(int id, Map<String, dynamic> values) => _repository.update(id, values);

  Future<Lieferant> archive(int id) => _repository.archive(id);

  Future<Lieferant> restore(int id) => _repository.restore(id);

  Future<void> bulkArchive(Iterable<int> ids) => _repository.bulkArchive(ids);
}

/// Kind-discriminated contact lookup: exactly one table per kind, never a guess.
class ContactDetailUseCase {
  const ContactDetailUseCase({required this.kunden, required this.lieferanten});

  final KundenRepository kunden;
  final LieferantenRepository lieferanten;

  Future<Kunde?> customerById(int id) => kunden.findById(id);

  Future<Lieferant?> supplierById(int id) => lieferanten.findById(id);
}

/// Typed contact forms. Numbering and local VAT validation stay in the
/// repositories: creation allocates one Debitor/Kreditor value into the
/// visible number field; no external verification is performed.
class ContactFormUseCase {
  const ContactFormUseCase({required this.kunden, required this.lieferanten});

  final KundenRepository kunden;
  final LieferantenRepository lieferanten;

  Future<Kunde> createCustomer({
    required String name,
    String anrede = 'Herr',
    String? firma,
    required String strasse,
    String? hausnummer,
    required String plz,
    required String ort,
    String land = 'DE',
    String? ustIdNr,
    String? foreignTaxNumber,
    String? telefon,
    String? email,
    int zahlungsziel = 14,
    num skontoProzent = 0,
    int skontoTage = 0,
    num? kreditlimit,
    String? note,
  }) {
    return kunden.create(
      name: name,
      anrede: anrede,
      firma: firma,
      strasse: strasse,
      hausnummer: hausnummer,
      plz: plz,
      ort: ort,
      land: land,
      ustIdNr: ustIdNr,
      foreignTaxNumber: foreignTaxNumber,
      telefon: telefon,
      email: email,
      zahlungsziel: zahlungsziel,
      skontoProzent: skontoProzent,
      skontoTage: skontoTage,
      kreditlimit: kreditlimit,
      note: note,
    );
  }

  Future<Lieferant> createSupplier({
    required String name,
    String anrede = 'Herr',
    String? firma,
    required String strasse,
    String? hausnummer,
    required String plz,
    required String ort,
    String land = 'DE',
    String? ustIdNr,
    String? foreignTaxNumber,
    String? telefon,
    String? email,
    String? iban,
    int zahlungsziel = 14,
    num skontoProzent = 0,
    int skontoTage = 0,
    String? note,
  }) {
    return lieferanten.create(
      name: name,
      anrede: anrede,
      firma: firma,
      strasse: strasse,
      hausnummer: hausnummer,
      plz: plz,
      ort: ort,
      land: land,
      ustIdNr: ustIdNr,
      foreignTaxNumber: foreignTaxNumber,
      telefon: telefon,
      email: email,
      iban: iban,
      zahlungsziel: zahlungsziel,
      skontoProzent: skontoProzent,
      skontoTage: skontoTage,
      note: note,
    );
  }

  Future<Kunde> updateCustomer(int id, Map<String, dynamic> values) => kunden.update(id, values);

  Future<Lieferant> updateSupplier(int id, Map<String, dynamic> values) => lieferanten.update(id, values);
}

class ArticleWorkspaceUseCase {
  const ArticleWorkspaceUseCase(this._repository);

  final ArtikelRepository _repository;

  Future<ArticlePage> query({String search = '', int limit = 25, int page = 1}) {
    return _repository.query(search: search, limit: limit, page: page);
  }

  Future<List<Artikel>> list() => _repository.list();

  Future<Artikel?> findById(int id) => _repository.findById(id);

  Future<Artikel> update(int id, Map<String, dynamic> values) => _repository.update(id, values);
}

class ArticleGroupWorkspaceUseCase {
  const ArticleGroupWorkspaceUseCase(this._repository);

  final ArtikelRepository _repository;

  Future<List<ArtikelGruppe>> list() => _repository.listGruppen();

  Future<ArticleGroupPage> query({String search = '', int limit = 25, int page = 1}) {
    return _repository.queryGruppen(search: search, limit: limit, page: page);
  }

  Future<ArtikelGruppe?> findById(int id) => _repository.findGruppeById(id);

  Future<ArtikelGruppe> create({required String name, String? beschreibung, String? typ, bool aktiv = true}) {
    return _repository.createGruppe(name: name, beschreibung: beschreibung, typ: typ, aktiv: aktiv);
  }

  Future<ArtikelGruppe> update(int id, {String? name, String? beschreibung, String? typ, bool? aktiv}) {
    return _repository.updateGruppe(id, name: name, beschreibung: beschreibung, typ: typ, aktiv: aktiv);
  }
}

/// Kind-discriminated article lookup: group IDs never pass through article lookup.
class ArticleDetailUseCase {
  const ArticleDetailUseCase(this._repository);

  final ArtikelRepository _repository;

  Future<Artikel?> itemById(int id) => _repository.findById(id);

  Future<ArtikelGruppe?> groupById(int id) => _repository.findGruppeById(id);
}

class CompanySettingsUseCase {
  const CompanySettingsUseCase(this._repository);

  final UnternehmenRepository _repository;

  Future<Unternehmen> load() => _repository.get();

  Future<Unternehmen> update(Map<String, dynamic> values) => _repository.update(values);
}

class CategoryWorkspaceUseCase {
  const CategoryWorkspaceUseCase(this._repository);

  final KategorienRepository _repository;

  Future<List<Kategorie>> list() => _repository.list();

  Future<Kategorie?> findById(int id) => _repository.findById(id);

  Future<Kategorie> create({
    required String bezeichnung,
    String? beschreibung,
    String? kontoSkr03,
    String? kontoSkr04,
    int? euerZeile,
    String? eksKategorie,
  }) {
    return _repository.create(
      bezeichnung: bezeichnung,
      beschreibung: beschreibung,
      kontoSkr03: kontoSkr03,
      kontoSkr04: kontoSkr04,
      euerZeile: euerZeile,
      eksKategorie: eksKategorie,
    );
  }

  Future<Kategorie> update(int id, Map<String, dynamic> values) => _repository.update(id, values);

  Future<void> delete(int id) => _repository.delete(id);
}

class BankAccount {
  const BankAccount({required this.id, required this.name, this.iban, this.bic, this.waehrung = 'EUR', this.kontoart});

  final int id;
  final String name;
  final String? iban;
  final String? bic;
  final String? waehrung;
  final String? kontoart;
}

class BankAccountRepository {
  const BankAccountRepository(this.executor);

  final QueryExecutor executor;

  static const String _select = 'SELECT id, name, iban, bic, waehrung, kontoart FROM konten';

  Future<List<BankAccount>> list() async {
    final List<Map<String, Object?>> rows = await executor.runSelect('$_select ORDER BY id', const <Object?>[]);
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<BankAccount?> findById(int id) async {
    final List<Map<String, Object?>> rows = await executor.runSelect('$_select WHERE id = ?', <Object?>[id]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<BankAccount> create({
    required String name,
    String? iban,
    String? bic,
    String waehrung = 'EUR',
    String? kontoart,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Kontoname ist Pflicht');
    }
    final int id = await executor.runInsert(
      'INSERT INTO konten (name, iban, bic, waehrung, kontoart) VALUES (?, ?, ?, ?, ?)',
      <Object?>[name.trim(), iban, bic, waehrung, kontoart],
    );
    final BankAccount? stored = await findById(id);
    if (stored == null) {
      throw StateError('Bankkonto konnte nicht gespeichert werden');
    }
    return stored;
  }

  Future<BankAccount> update(int id, Map<String, dynamic> values) async {
    const Map<String, String> columns = <String, String>{
      'name': 'name',
      'iban': 'iban',
      'bic': 'bic',
      'waehrung': 'waehrung',
      'kontoart': 'kontoart',
    };
    final Map<String, Object?> assignments = <String, Object?>{};
    for (final MapEntry<String, dynamic> entry in values.entries) {
      final String? column = columns[entry.key];
      if (column == null) {
        throw ArgumentError.value(entry.key, 'field', 'Unbekanntes Kontofeld');
      }
      assignments[column] = entry.value;
    }
    if (assignments.isEmpty) {
      final BankAccount? current = await findById(id);
      if (current == null) {
        throw StateError('Bankkonto nicht gefunden');
      }
      return current;
    }
    if (assignments.containsKey('name') && (assignments['name']?.toString().trim().isEmpty ?? true)) {
      throw ArgumentError.value(assignments['name'], 'name', 'Kontoname ist Pflicht');
    }
    final String sql = assignments.keys.map((String column) => '$column = ?').join(', ');
    await executor.runUpdate('UPDATE konten SET $sql WHERE id = ?', <Object?>[...assignments.values, id]);
    final BankAccount? updated = await findById(id);
    if (updated == null) {
      throw StateError('Bankkonto nicht gefunden');
    }
    return updated;
  }

  /// Guarded deletion: referenced accounts are rejected, never silently removed.
  Future<void> delete(int id) async {
    for (final String sql in <String>[
      'SELECT id FROM belege WHERE konto_id = ? LIMIT 1',
      'SELECT id FROM journal WHERE konto_id = ? OR soll_konto_id = ? OR haben_konto_id = ? LIMIT 1',
      'SELECT id FROM bank_transaktionen WHERE konto_id = ? LIMIT 1',
    ]) {
      final List<Object?> args = sql.contains('? OR') ? <Object?>[id, id, id] : <Object?>[id];
      final List<Map<String, Object?>> refs = await executor.runSelect(sql, args);
      if (refs.isNotEmpty) {
        throw StateError('Bankkonto wird noch verwendet und kann nicht gelöscht werden');
      }
    }
    final int deleted = await executor.runDelete('DELETE FROM konten WHERE id = ?', <Object?>[id]);
    if (deleted == 0) {
      throw StateError('Bankkonto nicht gefunden');
    }
  }

  BankAccount _fromRow(Map<String, Object?> row) {
    final Object? rawId = row['id'];
    final int id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;
    return BankAccount(
      id: id,
      name: row['name']?.toString() ?? '',
      iban: row['iban']?.toString(),
      bic: row['bic']?.toString(),
      waehrung: row['waehrung']?.toString(),
      kontoart: row['kontoart']?.toString(),
    );
  }
}

class BankAccountWorkspaceUseCase {
  const BankAccountWorkspaceUseCase(this._repository);

  final BankAccountRepository _repository;

  Future<List<BankAccount>> list() => _repository.list();

  Future<BankAccount?> findById(int id) => _repository.findById(id);

  Future<BankAccount> create({required String name, String? iban, String? bic, String? kontoart}) {
    return _repository.create(name: name, iban: iban, bic: bic, kontoart: kontoart);
  }

  Future<BankAccount> update(int id, Map<String, dynamic> values) => _repository.update(id, values);

  Future<void> delete(int id) => _repository.delete(id);
}

class TaxRate {
  const TaxRate({required this.id, required this.satz, required this.bezeichnung, this.gueltigAb});

  final int id;
  final num satz;
  final String bezeichnung;
  final String? gueltigAb;
}

class TaxRateRepository {
  const TaxRateRepository(this.executor);

  final QueryExecutor executor;

  static const String _select = 'SELECT id, satz, bezeichnung, gueltig_ab FROM ust_saetze';

  Future<List<TaxRate>> list() async {
    final List<Map<String, Object?>> rows = await executor.runSelect('$_select ORDER BY satz, id', const <Object?>[]);
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<TaxRate?> findById(int id) async {
    final List<Map<String, Object?>> rows = await executor.runSelect('$_select WHERE id = ?', <Object?>[id]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<TaxRate> create({required num satz, required String bezeichnung, String? gueltigAb}) async {
    if (bezeichnung.trim().isEmpty) {
      throw ArgumentError.value(bezeichnung, 'bezeichnung', 'Bezeichnung ist Pflicht');
    }
    final int id = await executor.runInsert(
      'INSERT INTO ust_saetze (satz, bezeichnung, gueltig_ab) VALUES (?, ?, ?)',
      <Object?>[satz, bezeichnung.trim(), gueltigAb],
    );
    final TaxRate? stored = await findById(id);
    if (stored == null) {
      throw StateError('Steuersatz konnte nicht gespeichert werden');
    }
    return stored;
  }

  Future<TaxRate> update(int id, Map<String, dynamic> values) async {
    const Map<String, String> columns = <String, String>{
      'satz': 'satz',
      'bezeichnung': 'bezeichnung',
      'gueltigAb': 'gueltig_ab',
      'gueltig_ab': 'gueltig_ab',
    };
    final Map<String, Object?> assignments = <String, Object?>{};
    for (final MapEntry<String, dynamic> entry in values.entries) {
      final String? column = columns[entry.key];
      if (column == null) {
        throw ArgumentError.value(entry.key, 'field', 'Unbekanntes Steuersatzfeld');
      }
      assignments[column] = entry.value;
    }
    if (assignments.isEmpty) {
      final TaxRate? current = await findById(id);
      if (current == null) {
        throw StateError('Steuersatz nicht gefunden');
      }
      return current;
    }
    final String sql = assignments.keys.map((String column) => '$column = ?').join(', ');
    await executor.runUpdate('UPDATE ust_saetze SET $sql WHERE id = ?', <Object?>[...assignments.values, id]);
    final TaxRate? updated = await findById(id);
    if (updated == null) {
      throw StateError('Steuersatz nicht gefunden');
    }
    return updated;
  }

  /// Guarded deletion: rates in active use are rejected.
  Future<void> delete(int id) async {
    for (final String sql in <String>[
      'SELECT id FROM artikel WHERE ust_satz_id = ? LIMIT 1',
      'SELECT id FROM journal WHERE ust_satz_id = ? LIMIT 1',
      'SELECT id FROM schnellbuchungen WHERE ust_satz_id = ? LIMIT 1',
    ]) {
      final List<Map<String, Object?>> refs = await executor.runSelect(sql, <Object?>[id]);
      if (refs.isNotEmpty) {
        throw StateError('Steuersatz wird noch verwendet und kann nicht gelöscht werden');
      }
    }
    final int deleted = await executor.runDelete('DELETE FROM ust_saetze WHERE id = ?', <Object?>[id]);
    if (deleted == 0) {
      throw StateError('Steuersatz nicht gefunden');
    }
  }

  TaxRate _fromRow(Map<String, Object?> row) {
    final Object? rawId = row['id'];
    final Object? rawSatz = row['satz'];
    return TaxRate(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0,
      satz: rawSatz is num ? rawSatz : num.tryParse(rawSatz?.toString() ?? '') ?? 0,
      bezeichnung: row['bezeichnung']?.toString() ?? '',
      gueltigAb: row['gueltig_ab']?.toString(),
    );
  }
}

class TaxRateWorkspaceUseCase {
  const TaxRateWorkspaceUseCase(this._repository);

  final TaxRateRepository _repository;

  Future<List<TaxRate>> list() => _repository.list();

  Future<TaxRate?> findById(int id) => _repository.findById(id);

  Future<TaxRate> create({required num satz, required String bezeichnung}) {
    return _repository.create(satz: satz, bezeichnung: bezeichnung);
  }

  Future<TaxRate> update(int id, Map<String, dynamic> values) => _repository.update(id, values);

  Future<void> delete(int id) => _repository.delete(id);
}

class NumberRange {
  const NumberRange({
    required this.id,
    required this.typ,
    this.prefix,
    required this.format,
    required this.nextNumber,
    required this.aktiv,
  });

  final int id;
  final String typ;
  final String? prefix;
  final String format;
  final int nextNumber;
  final bool aktiv;
}

class NumberRangeRepository {
  const NumberRangeRepository(this.executor);

  final QueryExecutor executor;

  static const String _select = 'SELECT id, typ, prefix, format, naechste_nummer, aktiv FROM nummernkreise';

  Future<List<NumberRange>> list() async {
    final List<Map<String, Object?>> rows = await executor.runSelect('$_select ORDER BY id', const <Object?>[]);
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<NumberRange?> findByType(String typ) async {
    final List<Map<String, Object?>> rows = await executor.runSelect('$_select WHERE typ = ?', <Object?>[typ.trim()]);
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<NumberRange> create({required String typ, required String format, String? prefix, int nextNumber = 1}) async {
    if (typ.trim().isEmpty || format.trim().isEmpty) {
      throw ArgumentError.value(typ, 'typ', 'Typ und Format sind Pflicht');
    }
    if (nextNumber < 1) {
      throw ArgumentError.value(nextNumber, 'naechste_nummer', 'Die nächste Nummer muss mindestens 1 sein');
    }
    final int id = await executor.runInsert(
      'INSERT INTO nummernkreise (typ, prefix, format, naechste_nummer, aktiv) VALUES (?, ?, ?, ?, 1)',
      <Object?>[typ.trim(), prefix, format.trim(), nextNumber],
    );
    final NumberRange? stored = await findByType(typ.trim());
    if (stored == null || stored.id != id) {
      throw StateError('Nummernkreis konnte nicht gespeichert werden');
    }
    return stored;
  }

  Future<NumberRange> update(String typ, int nextNumber) async {
    if (nextNumber < 1) {
      throw ArgumentError.value(nextNumber, 'naechste_nummer', 'Die nächste Nummer muss mindestens 1 sein');
    }
    final int updated = await executor.runUpdate(
      'UPDATE nummernkreise SET naechste_nummer = ? WHERE typ = ?',
      <Object?>[nextNumber, typ.trim()],
    );
    if (updated == 0) {
      throw StateError('Nummernkreis nicht gefunden');
    }
    final NumberRange? stored = await findByType(typ.trim());
    if (stored == null) {
      throw StateError('Nummernkreis nicht gefunden');
    }
    return stored;
  }

  NumberRange _fromRow(Map<String, Object?> row) {
    final Object? rawId = row['id'];
    final Object? rawNext = row['naechste_nummer'];
    final Object? rawAktiv = row['aktiv'];
    return NumberRange(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0,
      typ: row['typ']?.toString() ?? '',
      prefix: row['prefix']?.toString(),
      format: row['format']?.toString() ?? '',
      nextNumber: rawNext is int ? rawNext : int.tryParse(rawNext?.toString() ?? '') ?? 1,
      aktiv: rawAktiv is bool ? rawAktiv : rawAktiv == 1 || rawAktiv == '1',
    );
  }
}

class NumberRangeWorkspaceUseCase {
  const NumberRangeWorkspaceUseCase(this._repository);

  final NumberRangeRepository _repository;

  Future<List<NumberRange>> list() => _repository.list();

  Future<NumberRange?> findByType(String typ) => _repository.findByType(typ);

  Future<NumberRange> create({required String typ, required String format, String? prefix}) {
    return _repository.create(typ: typ, format: format, prefix: prefix);
  }

  Future<NumberRange> update(String typ, int nextNumber) => _repository.update(typ, nextNumber);
}
