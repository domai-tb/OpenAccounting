import 'package:openaccounting/features/contextual_accounting_tax_guidance/contextual_guidance_entry.dart';
import 'package:openaccounting/l10n/l10n.dart';

/// Resolves visible guidance copy from localized resources only.
///
/// No fallback text is fabricated: unknown IDs resolve to the stable ID so a
/// missing entry stays visible to maintainers instead of inventing content.
String guidanceTitle(ContextualGuidanceEntry entry, AppLocalizations l10n) {
  return switch (entry.stableId) {
    'accounting.category.skr-mapping' => l10n.guidanceTitleSkrMapping,
    'accounting.journal.immutability' => l10n.guidanceTitleJournalImmutability,
    'accounting.journal.storno' => l10n.guidanceTitleJournalStorno,
    'accounting.journal.group' => l10n.guidanceTitleJournalGroup,
    'accounting.euer.input-tax-claim' => l10n.guidanceTitleEuerInputTaxClaim,
    'einkommen.forderung.status' => l10n.guidanceTitleForderungStatus,
    'einkommen.forderung.overpayment' => l10n.guidanceTitleForderungOverpayment,
    'einkommen.verbindlichkeit.payment' => l10n.guidanceTitleVerbindlichkeitPayment,
    'mahnwesen.fee-interest' => l10n.guidanceTitleMahnungFeeInterest,
    'bank-import.match-status' => l10n.guidanceTitleBankMatchStatus,
    'bank-import.classification' => l10n.guidanceTitleBankClassification,
    'documents.angebot.status' => l10n.guidanceTitleAngebotStatus,
    'documents.auftrag.status' => l10n.guidanceTitleAuftragStatus,
    'accounting.correction.credit-sign' => l10n.guidanceTitleCorrectionCreditSign,
    'accounting.tax.special-25a' => l10n.guidanceTitleTaxSpecial25a,
    _ => entry.stableId,
  };
}

/// Resolves the full reviewed explanation for [entry] in the active locale.
String guidanceBody(ContextualGuidanceEntry entry, AppLocalizations l10n) {
  return switch (entry.stableId) {
    'accounting.category.skr-mapping' => l10n.guidanceBodySkrMapping,
    'accounting.journal.immutability' => l10n.guidanceBodyJournalImmutability,
    'accounting.journal.storno' => l10n.guidanceBodyJournalStorno,
    'accounting.journal.group' => l10n.guidanceBodyJournalGroup,
    'accounting.euer.input-tax-claim' => l10n.guidanceBodyEuerInputTaxClaim,
    'einkommen.forderung.status' => l10n.guidanceBodyForderungStatus,
    'einkommen.forderung.overpayment' => l10n.guidanceBodyForderungOverpayment,
    'einkommen.verbindlichkeit.payment' => l10n.guidanceBodyVerbindlichkeitPayment,
    'mahnwesen.fee-interest' => l10n.guidanceBodyMahnungFeeInterest,
    'bank-import.match-status' => l10n.guidanceBodyBankMatchStatus,
    'bank-import.classification' => l10n.guidanceBodyBankClassification,
    'documents.angebot.status' => l10n.guidanceBodyAngebotStatus,
    'documents.auftrag.status' => l10n.guidanceBodyAuftragStatus,
    'accounting.correction.credit-sign' => l10n.guidanceBodyCorrectionCreditSign,
    'accounting.tax.special-25a' => l10n.guidanceBodyTaxSpecial25a,
    _ => entry.stableId,
  };
}
