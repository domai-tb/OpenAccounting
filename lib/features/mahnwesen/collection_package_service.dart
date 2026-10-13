import 'dart:io';

import 'package:drift/drift.dart';
import 'package:openaccounting/features/accounting/money.dart' as money;
import 'package:openaccounting/features/einkommen/forderungen_repository.dart';
import 'package:openaccounting/features/mahnwesen/dunning_balance_source.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_entity.dart';
import 'package:openaccounting/features/mahnwesen/mahnungen_repository.dart';
import 'package:path/path.dart' as p;

/// One evidence artifact referenced by a collection package.
class CollectionEvidence {
  const CollectionEvidence({required this.art, required this.id, required this.pfad, required this.lesbar});

  final String art;
  final int id;
  final String pfad;
  final bool lesbar;
}

/// Customer-linked collection preparation manifest.
///
/// Read-only: posts no money, alters no invoice status, and never silently
/// includes every historical document — only selected invoices and their
/// linked prior reminders. Every artifact resolves to a readable stored
/// document; a missing required artifact is reported and the package stays
/// incomplete. An unavailable balance source blocks creation entirely.
class CollectionPackage {
  const CollectionPackage({
    required this.kundeId,
    required this.asOf,
    required this.saldoMomentaufnahme,
    required this.rechnungen,
    required this.mahnungen,
    required this.kontokorrent,
    required this.nachweise,
    required this.fehlende,
    required this.vollstaendig,
  });

  final int kundeId;
  final String asOf;
  final String saldoMomentaufnahme;
  final List<Map<String, Object?>> rechnungen;
  final List<Mahnung> mahnungen;
  final List<KontokorrentEintrag> kontokorrent;
  final List<CollectionEvidence> nachweise;
  final List<String> fehlende;
  final bool vollstaendig;
}

sealed class CollectionPackageResult {
  const CollectionPackageResult();
}

class CollectionPackageOk extends CollectionPackageResult {
  const CollectionPackageOk(this.package);

  final CollectionPackage package;
}

class CollectionPackageUnavailable extends CollectionPackageResult {
  const CollectionPackageUnavailable(this.unavailable);

  final DunningUnavailable unavailable;
}

class CollectionPackageService {
  CollectionPackageService({
    required this.executor,
    required this.mahnungen,
    required this.balances,
    required this.forderungen,
    this.profileDir,
  });

  final QueryExecutor executor;
  final MahnungenRepository mahnungen;
  final SettledBalanceSource balances;
  final ForderungenRepository forderungen;
  final String? profileDir;

  Future<CollectionPackageResult> create({
    required int kundeId,
    required List<int> rechnungIds,
    required String asOf,
  }) async {
    final String day = _requireDay(asOf);
    var totalCents = 0;
    final List<Map<String, Object?>> invoices = <Map<String, Object?>>[];
    for (final int id in rechnungIds) {
      final DunningBalanceResult result = await balances.forRechnung(id);
      if (result is DunningBalanceUnavailable) {
        return CollectionPackageUnavailable(result.unavailable);
      }
      final SettledBalance balance = (result as DunningBalanceOk).balance;
      totalCents += balance.outstandingCents;
      final List<Map<String, Object?>> rows = await executor.runSelect(
        'SELECT id, rechnungsnummer, kunde_id, brutto_betrag, original_pdf_pfad FROM rechnungen WHERE id = ? LIMIT 1',
        <Object?>[id],
      );
      if (rows.isEmpty) {
        return const CollectionPackageUnavailable(
          DunningUnavailable(code: 'beleg_fehlt', message: 'Rechnung wurde nicht gefunden. Auswahl prüfen.'),
        );
      }
      final Map<String, Object?> row = rows.single;
      if ((_asInt(row['kunde_id']) ?? 0) != kundeId) {
        return const CollectionPackageUnavailable(
          DunningUnavailable(code: 'kunde_fremd', message: 'Rechnung gehört zu einem anderen Kunden. Auswahl prüfen.'),
        );
      }
      invoices.add(row);
    }
    final List<Mahnung> reminders = <Mahnung>[];
    for (final int id in rechnungIds) {
      reminders.addAll(await mahnungen.listByRechnung(id));
    }
    final List<CollectionEvidence> evidences = <CollectionEvidence>[];
    final List<String> missing = <String>[];
    for (final Map<String, Object?> invoice in invoices) {
      final int id = _asInt(invoice['id']) ?? 0;
      final String? relative = invoice['original_pdf_pfad'] as String?;
      final String? resolved = _readableWithinProfile(relative);
      if (resolved == null) {
        missing.add('Rechnung ${invoice['rechnungsnummer'] ?? id}: Artifact fehlt');
        evidences.add(CollectionEvidence(art: 'rechnung', id: id, pfad: relative ?? '', lesbar: false));
      } else {
        evidences.add(CollectionEvidence(art: 'rechnung', id: id, pfad: resolved, lesbar: true));
      }
    }
    for (final Mahnung reminder in reminders) {
      final String? resolved = _readableWithinProfile('pdfs/Mahnung-${reminder.id}.pdf');
      if (resolved == null) {
        missing.add('Mahnung ${reminder.id}: Artifact fehlt');
        evidences.add(
          CollectionEvidence(art: 'mahnung', id: reminder.id, pfad: 'pdfs/Mahnung-${reminder.id}.pdf', lesbar: false),
        );
      } else {
        evidences.add(CollectionEvidence(art: 'mahnung', id: reminder.id, pfad: resolved, lesbar: true));
      }
    }
    List<KontokorrentEintrag> statement = const <KontokorrentEintrag>[];
    try {
      statement = await forderungen.kontokorrent(partnerTyp: 'kunde', partnerId: kundeId);
    } catch (_) {
      statement = const <KontokorrentEintrag>[];
    }
    return CollectionPackageOk(
      CollectionPackage(
        kundeId: kundeId,
        asOf: day,
        saldoMomentaufnahme: money.fromCents(totalCents),
        rechnungen: invoices,
        mahnungen: reminders,
        kontokorrent: statement,
        nachweise: evidences,
        fehlende: missing,
        vollstaendig: missing.isEmpty,
      ),
    );
  }

  String? _readableWithinProfile(String? relative) {
    final String? root = profileDir;
    if (root == null || root.trim().isEmpty || relative == null || relative.trim().isEmpty) return null;
    final String base = p.normalize(p.absolute(root));
    final String candidate = p.normalize(p.join(base, relative));
    if (!p.isWithin(base, candidate) && candidate != base) return null;
    if (FileSystemEntity.typeSync(candidate, followLinks: false) != FileSystemEntityType.file) return null;
    try {
      if (File(candidate).readAsBytesSync().isEmpty) return null;
    } catch (_) {
      return null;
    }
    return candidate;
  }

  static String _requireDay(String raw) {
    final String day = raw.length >= 10 ? raw.substring(0, 10) : raw;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
      throw ArgumentError('Datum ungültig: $raw (JJJJ-MM-TT erwartet)');
    }
    return day;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }
}
