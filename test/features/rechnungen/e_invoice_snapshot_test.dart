import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_output_format.dart';
import 'package:openaccounting/features/e_invoice/e_invoice_snapshot.dart';

void main() {
  test('finalization snapshot uses canonical cent totals', () {
    final FinalizationSnapshot snapshot = const EInvoiceSnapshotBuilder().buildFinalization(
      documentNumber: 'RE-260001',
      outputFormat: EInvoiceOutputFormat.pdf,
      issueDate: '2026-03-10',
      companyRow: <String, Object?>{'ust_idnr': 'DE123456789'},
      customerRow: <String, Object?>{},
      posRows: const <Map<String, Object?>>[
        <String, Object?>{
          'bezeichnung': 'Beratung',
          'menge': 1,
          'einzelpreis': 100,
          'ust_satz': 19,
          'tax_treatment': 'standard_19',
          'tax_legal_basis': 'ustg_12_1',
          'e_invoice_tax_category_code': 'S',
          'position': 0,
        },
      ],
      preview: const EInvoiceCanonicalTotals(netCents: 10000, taxCents: 1900, grossCents: 11900),
      eingabemodus: 'netto',
    );

    expect(snapshot.netCents, 10000);
    expect(snapshot.taxCents, 1900);
    expect(snapshot.grossCents, 11900);
    expect(snapshot.lines.single.netCents, 10000);
    expect(snapshot.lines.single.taxCents, 1900);
    expect(snapshot.lines.single.grossCents, 11900);
  });
}
