import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/document_delivery/document_delivery_context.dart';
import 'package:openaccounting/features/document_delivery/document_delivery_types.dart';
import 'package:openaccounting/features/document_delivery/email_template_service.dart';

void main() {
  group('Per-document-type message templates', () {
    late AppDatabase db;
    late EmailTemplateRepository templates;
    const EmailTemplateRenderer renderer = EmailTemplateRenderer();

    setUp(() async {
      db = AppDatabase.createTestDatabase();
      await db.ensureOpen();
      await db.executor.runInsert('INSERT INTO unternehmen (id, name) VALUES (?, ?)', <Object?>[1, 'Muster GmbH']);
      templates = EmailTemplateRepository(db.executor);
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> seedKunde({String email = 'kunde@example.de'}) async {
      return db.executor.runInsert(
        'INSERT INTO kunden (name, strasse, plz, ort, land, anrede, email) VALUES (?, ?, ?, ?, ?, ?, ?)',
        <Object?>['Muster GmbH', 'Musterstr 1', '10115', 'Berlin', 'DE', 'Frau', email],
      );
    }

    Future<int> seedDokument({
      required String typ,
      required int kundeId,
      bool entwurf = false,
      String nummer = 'RE-2026-1',
    }) async {
      return db.executor.runInsert(
        'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, kunde_id, datum, '
        'faelligkeit, brutto_betrag, original_pdf_pfad) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          nummer,
          typ,
          if (entwurf) 'entwurf' else 'offen',
          if (entwurf) 1 else 0,
          'netto',
          kundeId,
          '2026-03-01',
          '2026-03-15',
          '1199.00',
          'pdfs/RE-2026-1.pdf',
        ],
      );
    }

    test('test_render_a_document_template', () async {
      await templates.save(
        DocumentEmailType.rechnung,
        const DeliveryTemplateValues(
          subject: 'Rechnung {dokumentnummer} über {betrag}',
          body: 'Hallo {firma}, bitte zahlen Sie {betrag} für {dokumentnummer}.',
        ),
      );
      final RenderedTemplate rendered = renderer.render(
        template: await templates.loadOrSeed(DocumentEmailType.rechnung),
        dokumentnummer: 'RE-2026-1',
        betrag: 1199,
        firma: 'Muster GmbH',
      );
      expect(rendered.subject, contains('RE-2026-1'));
      expect(rendered.subject, contains('1.199,00'));
      expect(rendered.body, contains('Muster GmbH'));
      expect(rendered.body, isNot(contains('{')));
    });

    test('test_supported_document_types_use_the_production_detail_route', () async {
      final int kundeId = await seedKunde();
      const List<String> types = <String>[
        DocumentEmailType.rechnung,
        DocumentEmailType.angebot,
        DocumentEmailType.auftrag,
        DocumentEmailType.proforma,
      ];
      final DocumentDeliveryContextProvider contexts = DocumentDeliveryContextProvider(db.executor);
      for (final String typ in types) {
        final int id = await seedDokument(typ: typ, kundeId: kundeId, nummer: 'RE-2026-$typ');
        final DocumentDeliveryContext context = await contexts.load(id);
        expect(context.dokumentTyp, typ);
        expect(context.versandbereit, isTrue);
        final DeliveryTemplateValues template = await templates.loadOrSeed(typ);
        final RenderedTemplate rendered = renderer.render(
          template: template,
          dokumentnummer: context.dokumentnummer,
          betrag: context.betrag,
          faelligkeit: context.faelligkeit,
          firma: context.firma,
        );
        expect(rendered.subject, contains('RE-2026-$typ'));
      }
    });

    test('test_deferred_document_types_have_no_first_release_template_action', () async {
      try {
        await templates.loadOrSeed(DocumentEmailType.lieferschein);
        fail('Lieferschein must have no template action');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, 'typ_zurueckgestellt');
      }
      try {
        await templates.loadOrSeed(DocumentEmailType.mahnung);
        fail('Mahnung must have no template action');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, 'typ_zurueckgestellt');
      }
      final int kundeId = await seedKunde();
      final int lieferscheinId = await seedDokument(typ: DocumentEmailType.lieferschein, kundeId: kundeId);
      final DocumentDeliveryContext context = await DocumentDeliveryContextProvider(db.executor).load(lieferscheinId);
      expect(context.versandbereit, isFalse);
      expect(context.blockierGrund(), 'zurueckgestellt');
    });

    test('test_reject_unsupported_or_unavailable_placeholder', () async {
      await templates.save(
        DocumentEmailType.rechnung,
        const DeliveryTemplateValues(subject: 'Rechnung {dokumentnummer}', body: 'Zahlen bis {faelligkeit}.'),
      );
      final DeliveryTemplateValues template = await templates.loadOrSeed(DocumentEmailType.rechnung);
      try {
        renderer.render(template: template, dokumentnummer: 'RE-1', betrag: 10, firma: 'Firma');
        fail('missing faelligkeit must block');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, 'platzhalter_fehlt');
      }
      try {
        await templates.save(
          DocumentEmailType.angebot,
          const DeliveryTemplateValues(subject: 'Angebot {referenz}', body: 'Text'),
        );
        fail('unknown token must be rejected on save');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, 'platzhalter_unbekannt');
      }
    });

    test('test_per_send_edit_leaves_template_unchanged', () async {
      const DeliveryTemplateValues saved = DeliveryTemplateValues(
        subject: 'Rechnung {dokumentnummer}',
        body: 'Bitte zahlen Sie {betrag}.',
      );
      await templates.save(DocumentEmailType.rechnung, saved);
      final RenderedTemplate oneSend = renderer.render(
        template: DeliveryTemplateValues(subject: 'Eilig: Rechnung {dokumentnummer}', body: saved.body),
        dokumentnummer: 'RE-9',
        betrag: 50,
      );
      expect(oneSend.subject, startsWith('Eilig:'));
      final DeliveryTemplateValues stored = await templates.loadOrSeed(DocumentEmailType.rechnung);
      expect(stored.subject, saved.subject);
      expect(stored.body, saved.body);
    });

    test('test_reject_header_line_breaks', () async {
      try {
        await templates.save(
          DocumentEmailType.rechnung,
          const DeliveryTemplateValues(subject: 'Rechnung\nBcc: x@y.de', body: 'Text'),
        );
        fail('line break in subject must be rejected');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, 'kopfzeilenumbruch');
      }
      try {
        renderer.render(
          template: const DeliveryTemplateValues(subject: 'Rechnung\r\nX: y', body: 'Text'),
          dokumentnummer: 'RE-1',
          betrag: 1,
        );
        fail('per-send line break must be rejected before MIME');
      } on DocumentDeliveryException catch (error) {
        expect(error.code, 'kopfzeilenumbruch');
      }
    });
  });
}
