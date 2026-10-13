import 'package:openaccounting/features/recurring/buchungsvorlagen_repository.dart';

/// Category provenance probe for the recurring workspace.
///
/// Only `catalog_verified` and `user_confirmed` carry a trusted mapping;
/// `legacy_unverified` and `review_required` stay blocked when the posting
/// needs the mapping; `unmapped` proceeds only with independent account and
/// tax data plus a warning. Deactivation never changes provenance.
class RecurringCategoryProbe {
  const RecurringCategoryProbe({required this.aktiv, required this.mappingStatus});

  final bool aktiv;
  final String mappingStatus;
}

typedef RecurringCategoryLookup = Future<RecurringCategoryProbe?> Function(int? kategorieId);

/// Current article price for review data. Returns the display price string
/// (e.g. `'12.34'`) or null when the article is unknown.
typedef RecurringArticlePriceLookup = Future<String?> Function(int artikelId);

/// Result of a shared-boundary posting. The boundary owns posting status
/// and idempotency; the workspace only links the result.
class SharedPostingResult {
  const SharedPostingResult({this.journalId, this.sourceId});

  final int? journalId;
  final String? sourceId;
}

/// Accepted shared accounting posting boundary for direct-mode instances.
/// No accepted contract exists yet, so the production gateway reports
/// unavailable and direct execution fails closed.
abstract class SharedPostingGateway {
  bool get isAvailable;

  String get unavailableReason;

  Future<SharedPostingResult> postDirect({
    required int vorlageId,
    required String faelligkeit,
    required BuchungsVorlage vorlage,
    required String effektiverBetrag,
  });
}

/// Fail-closed production gateway: the shared posting contract is under
/// review, so direct-mode occurrences stay pending with a durable reason.
class UnavailableSharedPostingGateway implements SharedPostingGateway {
  const UnavailableSharedPostingGateway();

  @override
  bool get isAvailable => false;

  @override
  String get unavailableReason => 'Gemeinsamer Buchungsvertrag ist nicht verfügbar';

  @override
  Future<SharedPostingResult> postDirect({
    required int vorlageId,
    required String faelligkeit,
    required BuchungsVorlage vorlage,
    required String effektiverBetrag,
  }) async {
    throw StateError(unavailableReason);
  }
}

/// One draft position handed to the incoming-invoice draft workflow.
class BelegDraftPosition {
  const BelegDraftPosition({
    required this.bezeichnung,
    required this.menge,
    required this.einzelpreis,
    required this.ustSatz,
    this.artikelId,
  });

  final String bezeichnung;
  final String menge;
  final String einzelpreis;
  final String ustSatz;
  final int? artikelId;
}

/// Incoming-invoice draft workflow boundary. Each request supplies the
/// occurrence identity `(vorlage_id, faelligkeit)` as its idempotency
/// source; at most one draft links to an occurrence.
abstract class BelegDraftGateway {
  bool get isAvailable;

  String get unavailableReason;

  Future<int> createDraft({
    required int vorlageId,
    required String faelligkeit,
    required String datum,
    required List<BelegDraftPosition> positionen,
    required String eingabemodus,
    int? lieferantId,
  });

  Future<int?> findByIdentity(int vorlageId, String faelligkeit);
}

/// Unavailable production fallback: keeps Beleg instances reviewable with
/// a persisted `handoff_error` instead of writing invoice SQL directly.
class UnavailableBelegDraftGateway implements BelegDraftGateway {
  const UnavailableBelegDraftGateway();

  @override
  bool get isAvailable => false;

  @override
  String get unavailableReason => 'Entwurfs-Übergabe ist nicht verfügbar';

  @override
  Future<int> createDraft({
    required int vorlageId,
    required String faelligkeit,
    required String datum,
    required List<BelegDraftPosition> positionen,
    required String eingabemodus,
    int? lieferantId,
  }) async {
    throw StateError(unavailableReason);
  }

  @override
  Future<int?> findByIdentity(int vorlageId, String faelligkeit) async => null;
}

/// Review data for one due instance. Amount, tax, category, account, and
/// supplier are stored template data; nothing here infers a posting result.
/// [effektiverBetrag] carries the current article price when the template
/// references one; [warnung] carries the deactivation/provenance notice.
class DueInstanceView {
  const DueInstanceView({
    required this.vorlage,
    required this.occurrence,
    required this.effektiverBetrag,
    this.warnung,
  });

  final BuchungsVorlage vorlage;
  final BuchungsOccurrence occurrence;
  final String effektiverBetrag;
  final String? warnung;

  String get faelligkeit => occurrence.faelligkeit;
  String get modus => vorlage.modus;
  String get art => vorlage.art;
  String get reviewStatus => occurrence.reviewStatus;
  String? get blockReason => occurrence.blockReason;
  String? get handoffError => occurrence.handoffError;
  int? get journalId => occurrence.journalId;
  int? get rechnungId => occurrence.rechnungId;
  bool get isCompleted => occurrence.isCompleted;
}

/// Application use-case seam for the canonical `/recurring` workspace.
/// Coordinates template storage, review-first due instances, and explicitly
/// requested handoffs. Never writes journal rows or invoice SQL directly.
class RecurringBookingWorkspaceUseCases {
  RecurringBookingWorkspaceUseCases(
    this._vorlagen, {
    SharedPostingGateway? sharedPosting,
    BelegDraftGateway? belegDrafts,
    RecurringCategoryLookup? kategorien,
    RecurringArticlePriceLookup? artikelpreise,
  }) : _sharedPosting = sharedPosting ?? const UnavailableSharedPostingGateway(),
       _belegDrafts = belegDrafts ?? const UnavailableBelegDraftGateway(),
       _kategorien = kategorien ?? ((_) async => null),
       _artikelpreise = artikelpreise ?? ((_) async => null);

  final BuchungsVorlagenRepository _vorlagen;
  final SharedPostingGateway _sharedPosting;
  final BelegDraftGateway _belegDrafts;
  final RecurringCategoryLookup _kategorien;
  final RecurringArticlePriceLookup _artikelpreise;

  Future<BuchungsVorlage> createTemplate({
    required String name,
    required String art,
    required String modus,
    required String intervall,
    required String naechsteFaelligkeit,
    int? kategorieId,
    int? kontoId,
    String betrag = '0.00',
    String? beschreibung,
    int? lieferantId,
    num ustSatz = 19,
    String eingabemodus = 'brutto',
    List<Map<String, dynamic>> positionen = const <Map<String, dynamic>>[],
  }) {
    // Creating or viewing a template never creates a financial event; the
    // repository validates name/type/mode/interval/next-due and throws with
    // the invalid field named.
    return _vorlagen.create(
      name: name,
      art: art,
      modus: modus,
      intervall: intervall,
      naechsteFaelligkeit: naechsteFaelligkeit,
      kategorieId: kategorieId,
      kontoId: kontoId,
      betrag: betrag,
      beschreibung: beschreibung,
      lieferantId: lieferantId,
      ustSatz: ustSatz,
      eingabemodus: eingabemodus,
      positionen: positionen,
    );
  }

  Future<List<BuchungsVorlage>> listTemplates() => _vorlagen.list();

  Future<BuchungsVorlage?> getTemplate(int id) => _vorlagen.findById(id);

  Future<BuchungsVorlage> pauseTemplate(int id) => _vorlagen.pause(id);

  Future<BuchungsVorlage> resumeTemplate(int id) => _vorlagen.resume(id);

  /// Refreshes the due list. Display-only: reuses the persisted
  /// `review_status`/`block_reason`/`handoff_error` values without changing
  /// them, creates no financial record, and never advances a stored date.
  Future<List<DueInstanceView>> refreshDueInstances({DateTime? heute}) async {
    final List<BuchungsOccurrence> staged = await _vorlagen.stageDueInstances(heute: heute);
    final List<DueInstanceView> views = <DueInstanceView>[];
    for (final BuchungsOccurrence occurrence in staged) {
      final BuchungsVorlage? vorlage = await _vorlagen.findById(occurrence.vorlageId);
      if (vorlage == null) continue;
      views.add(await _toView(vorlage, occurrence));
    }
    return views;
  }

  /// Returns the review data for one due instance. Shows `art` as the
  /// configured classification without inferring VAT, account effects, or
  /// financial events from it.
  Future<DueInstanceView> reviewInstance({required int vorlageId, required String faelligkeit}) async {
    final BuchungsVorlage? vorlage = await _vorlagen.findById(vorlageId);
    if (vorlage == null) throw const BuchungsVorlagenException('Vorlage nicht gefunden');
    final BuchungsOccurrence? occurrence = await _vorlagen.findOccurrence(vorlageId, faelligkeit);
    if (occurrence == null) throw const BuchungsVorlagenException('Fälligkeit nicht gefunden');
    return _toView(vorlage, occurrence);
  }

  /// Requests execution of a reviewed direct-mode instance through the
  /// accepted shared posting boundary. Fails closed while the boundary or
  /// a required mapping/tax interpretation is unavailable: the instance
  /// stays pending/blocked with its durable reason, no journal row or
  /// input-tax claim is created, and the stored date does not advance.
  Future<DueInstanceView> requestDirectExecution({required int vorlageId, required String faelligkeit}) async {
    final BuchungsVorlage? vorlage = await _vorlagen.findById(vorlageId);
    if (vorlage == null) throw const BuchungsVorlagenException('Vorlage nicht gefunden');
    BuchungsOccurrence? occurrence = await _vorlagen.findOccurrence(vorlageId, faelligkeit);
    occurrence ??= await _vorlagen.stageDueInstance(vorlage);
    if (vorlage.modus != 'direkt') throw const BuchungsVorlagenException('Nur Direkt-Modus wird gebucht');
    if (occurrence.isCompleted) return _toView(vorlage, occurrence);

    final String? provenanceBlock = await _provenanceBlock(vorlage);
    if (provenanceBlock != null) {
      occurrence = await _vorlagen.markBlocked(vorlageId: vorlageId, faelligkeit: faelligkeit, reason: provenanceBlock);
      return _toView(vorlage, occurrence);
    }
    if (!_sharedPosting.isAvailable) {
      final String reason = 'Gemeinsamer Buchungsvertrag ist nicht verfügbar: ${_sharedPosting.unavailableReason}';
      occurrence = await _vorlagen.setReviewState(
        vorlageId: vorlageId,
        faelligkeit: faelligkeit,
        reviewStatus: 'pending',
        blockReason: reason,
      );
      return _toView(vorlage, occurrence);
    }
    final String effektiverBetrag = await _effektiverBetrag(vorlage);
    try {
      final SharedPostingResult result = await _sharedPosting.postDirect(
        vorlageId: vorlageId,
        faelligkeit: faelligkeit,
        vorlage: vorlage,
        effektiverBetrag: effektiverBetrag,
      );
      occurrence = await _vorlagen.markPosted(
        vorlageId: vorlageId,
        faelligkeit: faelligkeit,
        journalId: result.journalId,
      );
      await _vorlagen.advanceScheduleAfterCompletion(vorlageId);
      final BuchungsVorlage updated = (await _vorlagen.findById(vorlageId))!;
      return await _toView(updated, occurrence);
    } catch (error) {
      occurrence = await _vorlagen.markBlocked(
        vorlageId: vorlageId,
        faelligkeit: faelligkeit,
        reason: 'Buchung blockiert: $error',
      );
      return _toView(vorlage, occurrence);
    }
  }

  /// Hands a reviewed Beleg-mode instance to the incoming-invoice draft
  /// workflow. At most one draft links to an occurrence; repeats reuse the
  /// linked draft, and recovery attaches a draft found by occurrence
  /// identity instead of creating a second one. Failures stay reviewable
  /// with a persisted `handoff_error` and never advance the stored date.
  Future<DueInstanceView> requestBelegHandoff({required int vorlageId, required String faelligkeit}) async {
    final BuchungsVorlage? vorlage = await _vorlagen.findById(vorlageId);
    if (vorlage == null) throw const BuchungsVorlagenException('Vorlage nicht gefunden');
    BuchungsOccurrence? occurrence = await _vorlagen.findOccurrence(vorlageId, faelligkeit);
    occurrence ??= await _vorlagen.stageDueInstance(vorlage);
    if (vorlage.modus != 'beleg') throw const BuchungsVorlagenException('Nur Beleg-Modus wird übergeben');
    if (occurrence.reviewStatus == 'handed_off' && occurrence.rechnungId != null) {
      return _toView(vorlage, occurrence);
    }
    if (occurrence.rechnungId != null) {
      occurrence = await _vorlagen.markHandedOff(
        vorlageId: vorlageId,
        faelligkeit: faelligkeit,
        rechnungId: occurrence.rechnungId,
      );
      await _vorlagen.advanceScheduleAfterCompletion(vorlageId);
      final BuchungsVorlage updated = (await _vorlagen.findById(vorlageId))!;
      return await _toView(updated, occurrence);
    }
    final int? recovered = await _findDraftByIdentity(vorlageId, faelligkeit);
    if (recovered != null) {
      occurrence = await _vorlagen.markHandedOff(vorlageId: vorlageId, faelligkeit: faelligkeit, rechnungId: recovered);
      await _vorlagen.advanceScheduleAfterCompletion(vorlageId);
      final BuchungsVorlage updated = (await _vorlagen.findById(vorlageId))!;
      return await _toView(updated, occurrence);
    }
    if (!_belegDrafts.isAvailable) {
      occurrence = await _vorlagen.markFailed(
        vorlageId: vorlageId,
        faelligkeit: faelligkeit,
        error: _belegDrafts.unavailableReason,
      );
      return _toView(vorlage, occurrence);
    }
    try {
      final List<BelegDraftPosition> positionen = await _belegPositionen(vorlage);
      final int draftId = await _belegDrafts.createDraft(
        vorlageId: vorlageId,
        faelligkeit: faelligkeit,
        datum: faelligkeit,
        positionen: positionen,
        eingabemodus: vorlage.eingabemodus,
        lieferantId: vorlage.lieferantId,
      );
      // Recovery race: the draft may have landed before the link was saved.
      final int? raced = await _findDraftByIdentity(vorlageId, faelligkeit);
      occurrence = await _vorlagen.markHandedOff(
        vorlageId: vorlageId,
        faelligkeit: faelligkeit,
        rechnungId: raced ?? draftId,
      );
      await _vorlagen.advanceScheduleAfterCompletion(vorlageId);
      final BuchungsVorlage updated = (await _vorlagen.findById(vorlageId))!;
      return await _toView(updated, occurrence);
    } catch (error) {
      occurrence = await _vorlagen.markFailed(vorlageId: vorlageId, faelligkeit: faelligkeit, error: '$error');
      return _toView(vorlage, occurrence);
    }
  }

  Future<int?> _findDraftByIdentity(int vorlageId, String faelligkeit) async {
    final int? viaGateway = await _belegDrafts.findByIdentity(vorlageId, faelligkeit);
    if (viaGateway != null) return viaGateway;
    return _vorlagen.findDraftIdByIdentity(vorlageId, faelligkeit);
  }

  /// Provenance gate for confirmed bookings. Returns the blocking reason or
  /// null when the booking may proceed. Deactivation warnings never change
  /// provenance; `legacy_unverified`/`review_required` stay blocked when the
  /// posting needs the mapping.
  Future<String?> _provenanceBlock(BuchungsVorlage vorlage) async {
    final RecurringCategoryProbe? probe = await _kategorien(vorlage.kategorieId);
    final bool mappingRequired = vorlage.kategorieId != null;
    if (probe == null) {
      if (!mappingRequired) return null;
      return 'Kategorie-Mapping fehlt und ist für die Buchung erforderlich';
    }
    final String status = probe.mappingStatus;
    final bool trusted = status == 'catalog_verified' || status == 'user_confirmed';
    final bool unresolved = status == 'legacy_unverified' || status == 'review_required';
    if (!probe.aktiv) {
      if (unresolved && mappingRequired) {
        return 'Kategorie-Mapping erfordert Prüfung (deaktivierte Kategorie umgeht die Prüfung nicht)';
      }
      if (status == 'unmapped') {
        if (_hasIndependentPostingData(vorlage)) return null;
        return 'Kategorie-Mapping fehlt und ist für die Buchung erforderlich';
      }
      if (trusted) return null;
      return 'Kategorie-Mapping erfordert Prüfung';
    }
    if (unresolved && mappingRequired) return 'Kategorie-Mapping erfordert Prüfung';
    if (status == 'unmapped' && mappingRequired && !_hasIndependentPostingData(vorlage)) {
      return 'Kategorie-Mapping fehlt und ist für die Buchung erforderlich';
    }
    return null;
  }

  bool _hasIndependentPostingData(BuchungsVorlage vorlage) {
    return vorlage.kontoId != null && (vorlage.betrag ?? '').trim().isNotEmpty;
  }

  Future<String?> _provenanceWarning(BuchungsVorlage vorlage) async {
    final RecurringCategoryProbe? probe = await _kategorien(vorlage.kategorieId);
    if (probe == null) return null;
    if (!probe.aktiv) return 'Deaktivierte Kategorie wird mit Warnung verwendet';
    return null;
  }

  /// Review amount: the article's current price replaces the stored template
  /// price when the template references one. No event is posted here.
  Future<String> _effektiverBetrag(BuchungsVorlage vorlage) async {
    if (vorlage.positionen.isEmpty) return vorlage.betrag ?? '0.00';
    final List<String> teile = <String>[];
    for (final Map<String, dynamic> position in vorlage.positionen) {
      final Object? artikelId = position['artikel_id'];
      String? einzelpreis = position['einzelpreis']?.toString();
      if (artikelId is num) {
        final String? aktuell = await _artikelpreise(artikelId.toInt());
        if (aktuell != null && aktuell.trim().isNotEmpty) einzelpreis = aktuell;
      } else if (artikelId is String && int.tryParse(artikelId) != null) {
        final String? aktuell = await _artikelpreise(int.parse(artikelId));
        if (aktuell != null && aktuell.trim().isNotEmpty) einzelpreis = aktuell;
      }
      teile.add('${position['bezeichnung']}: $einzelpreis');
    }
    return teile.join('; ');
  }

  Future<List<BelegDraftPosition>> _belegPositionen(BuchungsVorlage vorlage) async {
    if (vorlage.positionen.isNotEmpty) {
      final List<BelegDraftPosition> positionen = <BelegDraftPosition>[];
      for (final Map<String, dynamic> position in vorlage.positionen) {
        final Object? artikelId = position['artikel_id'];
        int? artikelNum;
        if (artikelId is num) {
          artikelNum = artikelId.toInt();
        } else if (artikelId is String) {
          artikelNum = int.tryParse(artikelId);
        }
        String einzelpreis = position['einzelpreis']?.toString() ?? vorlage.betrag ?? '0.00';
        if (artikelNum != null) {
          final String? aktuell = await _artikelpreise(artikelNum);
          if (aktuell != null && aktuell.trim().isNotEmpty) einzelpreis = aktuell;
        }
        positionen.add(
          BelegDraftPosition(
            bezeichnung: position['bezeichnung']?.toString() ?? vorlage.name,
            menge: position['menge']?.toString() ?? '1.000',
            einzelpreis: einzelpreis,
            ustSatz: (position['ust_satz'] ?? position['ustSatz'] ?? vorlage.ustSatz)?.toString() ?? '19.00',
            artikelId: artikelNum,
          ),
        );
      }
      return positionen;
    }
    return <BelegDraftPosition>[
      BelegDraftPosition(
        bezeichnung: vorlage.beschreibung ?? vorlage.name,
        menge: '1.000',
        einzelpreis: await _einzelpreisFallback(vorlage),
        ustSatz: vorlage.ustSatz,
      ),
    ];
  }

  Future<String> _einzelpreisFallback(BuchungsVorlage vorlage) async => vorlage.betrag ?? '0.00';

  Future<DueInstanceView> _toView(BuchungsVorlage vorlage, BuchungsOccurrence occurrence) async {
    return DueInstanceView(
      vorlage: vorlage,
      occurrence: occurrence,
      effektiverBetrag: await _effektiverBetrag(vorlage),
      warnung: await _provenanceWarning(vorlage),
    );
  }
}
