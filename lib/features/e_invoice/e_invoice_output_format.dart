/// Per-invoice structured-output choice for ordinary outgoing invoices.
///
/// `kunden.zugferd_aktiv` only preselects the draft default; the persisted
/// value is always the explicit per-invoice selection. Legacy finalized rows
/// without a saved value resolve to `pdf`.
enum EInvoiceOutputFormat { pdf, zugferd, xrechnung }

/// Raw storage value written to `rechnungen.ausgabeformat`.
String eInvoiceOutputFormatStorage(EInvoiceOutputFormat format) => format.name;

/// Parses a stored `ausgabeformat` value. Unknown values resolve to `pdf` so
/// a corrupt legacy value can never select a structured output.
EInvoiceOutputFormat parseEInvoiceOutputFormat(Object? raw) {
  final String normalized = raw?.toString().trim().toLowerCase() ?? '';
  return switch (normalized) {
    'zugferd' => EInvoiceOutputFormat.zugferd,
    'xrechnung' => EInvoiceOutputFormat.xrechnung,
    _ => EInvoiceOutputFormat.pdf,
  };
}

/// Resolves the effective format for a finalized invoice row.
///
/// A missing legacy value means PDF because the pre-change application never
/// produced structured output; the customer's current preference is never
/// consulted here.
EInvoiceOutputFormat resolveFinalizedOutputFormat(Object? stored) => parseEInvoiceOutputFormat(stored);

/// Draft default derived from the customer preference. True preselects
/// ZUGFeRD, false preselects PDF. Both keep every choice available.
EInvoiceOutputFormat defaultOutputFormat({required bool zugferdAktiv}) {
  return zugferdAktiv ? EInvoiceOutputFormat.zugferd : EInvoiceOutputFormat.pdf;
}
