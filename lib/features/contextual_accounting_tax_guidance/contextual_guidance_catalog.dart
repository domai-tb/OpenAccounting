import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_entry.dart';
import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_texts.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Maintainer-facing coverage inventory for the finite first-release set.
///
/// Closed set of exactly the 15 stable IDs in `design.md`; later controls
/// require an explicit inventory addition. Only reviewed entries have a
/// user-visible affordance; missing/review-needed states never render
/// placeholders or warnings in the app.
class ContextualGuidanceCatalog {
  const ContextualGuidanceCatalog({required this.entries, this.reviewNeeded = const <String>{}});

  factory ContextualGuidanceCatalog.reviewed() {
    return const ContextualGuidanceCatalog(entries: _kEntries);
  }

  final List<ContextualGuidanceEntry> entries;
  final Set<String> reviewNeeded;

  /// Reviewed entries with a user-visible affordance.
  List<ContextualGuidanceEntry> get reviewedEntries {
    return <ContextualGuidanceEntry>[
      for (final ContextualGuidanceEntry entry in entries)
        if (!reviewNeeded.contains(entry.stableId)) entry,
    ];
  }

  /// Maintainer coverage states per stable ID; never rendered to end users.
  Map<String, GuidanceCoverageState> get coverage {
    return <String, GuidanceCoverageState>{
      for (final ContextualGuidanceEntry entry in entries)
        entry.stableId: reviewNeeded.contains(entry.stableId)
            ? GuidanceCoverageState.reviewNeeded
            : GuidanceCoverageState.reviewed,
    };
  }

  /// Maintainer state for a control; unknown controls report missing while
  /// their supported field behavior stays available.
  GuidanceCoverageState coverageStateForControl(String controlId) {
    for (final ContextualGuidanceEntry entry in entries) {
      if (entry.controlId == controlId) {
        return reviewNeeded.contains(entry.stableId)
            ? GuidanceCoverageState.reviewNeeded
            : GuidanceCoverageState.reviewed;
      }
    }
    return GuidanceCoverageState.missing;
  }

  /// Reviewed entry attached to [controlId], or null when none is approved.
  ContextualGuidanceEntry? forControl(String controlId) {
    for (final ContextualGuidanceEntry entry in reviewedEntries) {
      if (entry.controlId == controlId) {
        return entry;
      }
    }
    return null;
  }

  ContextualGuidanceEntry? byId(String stableId) {
    for (final ContextualGuidanceEntry entry in reviewedEntries) {
      if (entry.stableId == stableId) {
        return entry;
      }
    }
    return null;
  }

  /// Entries whose source or owning contract changed since review; they
  /// become review-needed and lose their end-user affordance until re-approved.
  List<ContextualGuidanceEntry> staleEntries({
    required DateTime now,
    required Map<String, String> currentContractRevisions,
  }) {
    return <ContextualGuidanceEntry>[
      for (final ContextualGuidanceEntry entry in entries)
        if (_isStale(entry, now, currentContractRevisions)) entry,
    ];
  }

  bool _isStale(ContextualGuidanceEntry entry, DateTime now, Map<String, String> currentContractRevisions) {
    final String? current = currentContractRevisions[entry.owningContract];
    if (current != null && current != entry.contractRevision) {
      return true;
    }
    if (entry.provenance != null) {
      final DateTime? end = DateTime.tryParse(entry.provenance!.applicabilityPeriod);
      if (end != null && now.isAfter(end)) {
        return true;
      }
    }
    return false;
  }

  /// Reviewed entries matching [query] in German or English title/body text,
  /// or in stable ID, route, control ID, or owning contract terms.
  List<ContextualGuidanceEntry> search(
    String query, {
    required AppLocalizations german,
    required AppLocalizations english,
  }) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return reviewedEntries;
    }
    return <ContextualGuidanceEntry>[
      for (final ContextualGuidanceEntry entry in reviewedEntries)
        if (_matches(entry, normalized, german, english)) entry,
    ];
  }

  bool _matches(ContextualGuidanceEntry entry, String normalized, AppLocalizations german, AppLocalizations english) {
    final List<String> candidates = <String>[
      entry.stableId,
      entry.route,
      entry.controlId,
      entry.owningContract,
      guidanceTitle(entry, german),
      guidanceBody(entry, german),
      guidanceTitle(entry, english),
      guidanceBody(entry, english),
    ];
    for (final String candidate in candidates) {
      if (candidate.toLowerCase().contains(normalized)) {
        return true;
      }
    }
    return false;
  }
}

const List<ContextualGuidanceEntry> _kEntries = <ContextualGuidanceEntry>[
  ContextualGuidanceEntry(
    stableId: 'accounting.category.skr-mapping',
    route: '/reports',
    controlId: 'konten.skrMappingField',
    owningContract: 'accounting/Kategorien',
    contractRevision: 'rev-1',
  ),
  ContextualGuidanceEntry(
    stableId: 'accounting.journal.immutability',
    route: '/reports',
    controlId: 'journal.immutabilityNotice',
    owningContract: 'accounting/Journal Entries',
    contractRevision: 'rev-1',
    lawDependent: true,
    provenance: GuidanceProvenance(
      jurisdiction: 'DE',
      sourceTitle: 'GoBD',
      provision: 'Grundsätze zur ordnungsmäßigen Führung und Aufbewahrung von Büchern',
      sourceVersion: 'Fassung 2019-11-28 (BMF-Schreiben)',
      retrievalDate: '2026-09-30',
      applicabilityPeriod: '2027-12-31',
    ),
  ),
  ContextualGuidanceEntry(
    stableId: 'accounting.journal.storno',
    route: '/reports',
    controlId: 'journal.stornoAction',
    owningContract: 'accounting/Storno Correction',
    contractRevision: 'rev-1',
  ),
  ContextualGuidanceEntry(
    stableId: 'accounting.journal.group',
    route: '/reports',
    controlId: 'journal.groupField',
    owningContract: 'accounting/Journal Entries',
    contractRevision: 'rev-1',
  ),
  ContextualGuidanceEntry(
    stableId: 'accounting.euer.input-tax-claim',
    route: '/taxes',
    controlId: 'euer.inputTaxClaimField',
    owningContract: 'accounting/Input-tax claim direction during generic finalization',
    contractRevision: 'rev-1',
    lawDependent: true,
    provenance: GuidanceProvenance(
      jurisdiction: 'DE',
      sourceTitle: 'Umsatzsteuergesetz',
      provision: '§ 15 UStG',
      sourceVersion: 'Steuerjahr 2026',
      retrievalDate: '2026-09-30',
      applicabilityPeriod: '2027-12-31',
    ),
  ),
  ContextualGuidanceEntry(
    stableId: 'einkommen.forderung.status',
    route: '/invoices',
    controlId: 'forderung.statusControl',
    owningContract: 'einkommen/Forderungen table for open items',
    contractRevision: 'rev-1',
  ),
  ContextualGuidanceEntry(
    stableId: 'einkommen.forderung.overpayment',
    route: '/invoices',
    controlId: 'forderung.overpaymentNotice',
    owningContract: 'einkommen/Überzahlungs-Protokoll',
    contractRevision: 'rev-1',
  ),
  ContextualGuidanceEntry(
    stableId: 'einkommen.verbindlichkeit.payment',
    route: '/invoices',
    controlId: 'verbindlichkeit.paymentControl',
    owningContract: 'einkommen/Verbindlichkeiten',
    contractRevision: 'rev-1',
  ),
  ContextualGuidanceEntry(
    stableId: 'mahnwesen.fee-interest',
    route: '/invoices',
    controlId: 'mahnung.feeInterestField',
    owningContract: 'mahnwesen/Mahngebühr Tracking and Verzugszinsen Tracking',
    contractRevision: 'rev-1',
    lawDependent: true,
    provenance: GuidanceProvenance(
      jurisdiction: 'DE',
      sourceTitle: 'Bürgerliches Gesetzbuch',
      provision: '§§ 286, 288 BGB',
      sourceVersion: 'Steuerjahr 2026',
      retrievalDate: '2026-09-30',
      applicabilityPeriod: '2027-12-31',
    ),
  ),
  ContextualGuidanceEntry(
    stableId: 'bank-import.match-status',
    route: '/banking',
    controlId: 'bankImport.matchStatusControl',
    owningContract: 'bank-import/Score-Based Matching',
    contractRevision: 'rev-1',
  ),
  ContextualGuidanceEntry(
    stableId: 'bank-import.classification',
    route: '/banking',
    controlId: 'bankImport.classificationControl',
    owningContract: 'bank-import/Transaction Classification Override',
    contractRevision: 'rev-1',
  ),
  ContextualGuidanceEntry(
    stableId: 'documents.angebot.status',
    route: '/invoices',
    controlId: 'angebot.statusControl',
    owningContract: 'documents/Angebot status lifecycle',
    contractRevision: 'rev-1',
  ),
  ContextualGuidanceEntry(
    stableId: 'documents.auftrag.status',
    route: '/invoices',
    controlId: 'auftrag.statusControl',
    owningContract: 'documents/Auftrag status lifecycle',
    contractRevision: 'rev-1',
  ),
  ContextualGuidanceEntry(
    stableId: 'accounting.correction.credit-sign',
    route: '/invoices',
    controlId: 'correction.creditSignField',
    owningContract: 'correction-document-accounting-integrity/Correction totals preserve signed VAT mathematics',
    contractRevision: 'rev-1',
    lawDependent: true,
    provenance: GuidanceProvenance(
      jurisdiction: 'DE',
      sourceTitle: 'Umsatzsteuergesetz',
      provision: '§§ 14, 17 UStG',
      sourceVersion: 'Steuerjahr 2026',
      retrievalDate: '2026-09-30',
      applicabilityPeriod: '2027-12-31',
    ),
  ),
  ContextualGuidanceEntry(
    stableId: 'accounting.tax.special-25a',
    route: '/taxes',
    controlId: 'tax.special25aField',
    owningContract: 'accounting/Differenzbesteuerung §25a Accounting',
    contractRevision: 'rev-1',
    lawDependent: true,
    provenance: GuidanceProvenance(
      jurisdiction: 'DE',
      sourceTitle: 'Umsatzsteuergesetz',
      provision: '§ 25a UStG',
      sourceVersion: 'Steuerjahr 2026',
      retrievalDate: '2026-09-30',
      applicabilityPeriod: '2027-12-31',
    ),
  ),
];
