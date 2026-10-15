import 'package:flutter_test/flutter_test.dart';
import 'package:openaccounting/core/db/database.dart';
import 'package:openaccounting/features/dashboard/dashboard_entity.dart';
import 'package:openaccounting/features/dashboard/dashboard_period.dart';
import 'package:openaccounting/features/dashboard/dashboard_repository.dart';
import 'package:openaccounting/features/dashboard/dashboard_usecases.dart';

Future<AppDatabase> _openDb() async {
  final AppDatabase db = AppDatabase.createTestDatabase();
  await db.ensureOpen();
  return db;
}

Future<int> _insertRechnung(
  AppDatabase db, {
  required String nummer,
  required String typ,
  required String status,
  required int entwurf,
  required String datum,
  String? faelligkeit,
  required String brutto,
}) async {
  return db.executor.runInsert(
    'INSERT INTO rechnungen (rechnungsnummer, typ, status, ist_entwurf, eingabemodus, datum, faelligkeit, '
    'brutto_betrag, netto_betrag) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    <Object?>[nummer, typ, status, entwurf, 'netto', datum, faelligkeit, brutto, brutto],
  );
}

Future<int> _insertForderung(
  AppDatabase db, {
  required int rechnungId,
  required String typ,
  required String betrag,
}) async {
  final String partnerTyp = typ == 'rechnung_eingang' ? 'lieferant' : 'kunde';
  return db.executor.runInsert(
    'INSERT INTO forderungen (typ, status, betrag, anfangsbetrag, partner_typ, partner_id, rechnung_id) '
    'VALUES (?, ?, ?, ?, ?, ?, ?)',
    <Object?>[typ, 'offen', betrag, betrag, partnerTyp, 1, rechnungId],
  );
}

Future<void> _ensureZahlungenTable(AppDatabase db) async {
  await db.executor.runCustom(
    'CREATE TABLE IF NOT EXISTS forderung_zahlungen (id INTEGER PRIMARY KEY AUTOINCREMENT, '
    'forderung_id INTEGER NOT NULL, journal_id INTEGER NOT NULL UNIQUE, betrag NUMERIC(12,2) NOT NULL, '
    'typ TEXT NOT NULL, datum TEXT NOT NULL, idempotency_key TEXT UNIQUE)',
  );
}

void main() {
  group('dashboard period metrics and trends', () {
    late AppDatabase db;
    late DashboardUseCase useCase;
    late DashboardRepository repo;

    setUp(() async {
      db = await _openDb();
      useCase = DashboardUseCase(db.executor);
      repo = DashboardRepository(db.executor);
    });

    tearDown(() async => db.close());

    test('test_default_quick_links', () async {
      final DashboardConfig cfg = await repo.loadConfig();
      expect(cfg.quickLinks, hasLength(3));
      expect(
        cfg.quickLinks.map((QuickLink e) => e.route),
        containsAll(<String>['/invoices/new', '/reports', '/inventory']),
      );
      for (final QuickLink link in cfg.quickLinks) {
        expect(useCase.isAllowed(link.route), isTrue);
      }
    });

    test('test_custom_quick_link', () async {
      const QuickLink custom = QuickLink(label: 'Mein Shop', route: '/reports');
      expect(useCase.validateQuickLink(custom.route), isNull);
      await repo.addQuickLink(custom);
      final DashboardConfig cfg = await repo.loadConfig();
      expect(cfg.quickLinks.any((QuickLink l) => l.label == 'Mein Shop' && l.route == '/reports'), isTrue);
      expect(useCase.bankingRouteFor(42), '/banking?transactionId=42');
    });

    test('test_add_edit_and_reorder_a_quick_link', () async {
      await repo.addQuickLink(const QuickLink(label: 'Mein Shop', route: '/reports'));
      var cfg = await repo.loadConfig();
      final List<QuickLink> edited = <QuickLink>[
        for (final QuickLink l in cfg.quickLinks)
          if (l.route == '/reports' && l.label == 'Mein Shop')
            const QuickLink(label: 'Shop neu', route: '/reports')
          else
            l,
      ];
      await repo.setQuickLinks(edited);
      cfg = await repo.loadConfig();
      expect(cfg.quickLinks.any((QuickLink l) => l.label == 'Shop neu'), isTrue);
      final List<QuickLink> reordered = List<QuickLink>.from(cfg.quickLinks.reversed);
      await repo.setQuickLinks(reordered);
      cfg = await repo.loadConfig();
      expect(cfg.quickLinks.first.label, reordered.first.label);
      final DashboardConfig reloaded = await repo.loadConfig();
      expect(reloaded.quickLinks.first.label, reordered.first.label);
    });

    test('test_remove_a_quick_link', () async {
      await repo.addQuickLink(const QuickLink(label: 'Mein Shop', route: '/reports'));
      var cfg = await repo.loadConfig();
      expect(cfg.quickLinks.any((QuickLink l) => l.route == '/reports' && l.label == 'Mein Shop'), isTrue);
      final List<QuickLink> next = cfg.quickLinks
          .where((QuickLink l) => !(l.label == 'Mein Shop' && l.route == '/reports'))
          .toList();
      await repo.setQuickLinks(next);
      cfg = await repo.loadConfig();
      expect(cfg.quickLinks.any((QuickLink l) => l.label == 'Mein Shop' && l.route == '/reports'), isFalse);
    });

    test('test_quick_link_with_invalid_route', () async {
      const QuickLink bad = QuickLink(label: 'Böse', route: '/no-such-place');
      expect(useCase.validateQuickLink(bad.route), isNotNull);
      final DashboardConfig before = await repo.loadConfig();
      final int countBefore = before.quickLinks.length;
      if (useCase.validateQuickLink(bad.route) == null) {
        await repo.addQuickLink(bad);
      }
      final DashboardConfig after = await repo.loadConfig();
      expect(after.quickLinks.length, countBefore);
      expect(after.quickLinks.any((QuickLink l) => l.route == '/no-such-place'), isFalse);
    });

    test('test_legacy_persisted_quick_link_is_filtered_on_load', () async {
      final DashboardConfig cfg = DashboardConfig(
        order: List<String>.from(dashboardWidgetIds),
        visibility: <String, bool>{for (final String id in dashboardWidgetIds) id: true},
        quickLinks: const <QuickLink>[
          QuickLink(label: 'Alt', route: '/legacy-nowhere'),
          QuickLink(label: 'Berichte', route: '/reports'),
        ],
      );
      await repo.saveConfig(cfg);
      final DashboardConfig loaded = await repo.loadConfig();
      expect(loaded.quickLinks.any((QuickLink l) => l.route == '/legacy-nowhere'), isTrue);
      expect(useCase.validLinks(loaded.quickLinks).any((QuickLink l) => l.route == '/legacy-nowhere'), isFalse);
      expect(useCase.invalidLinks(loaded.quickLinks).single.route, '/legacy-nowhere');
    });

    test('test_select_a_reporting_period', () async {
      final DashboardPeriodResult result = useCase.selectYear(2025, supportedYears: <int>{2025});
      expect(result, isA<DashboardPeriodOk>());
      final DashboardYear period = (result as DashboardPeriodOk).period;
      expect(period.start, '2025-01-01');
      expect(period.endExclusive, '2026-01-01');
      expect(period.yearEnd, '2025-12-31');
      expect(period.label(), contains('2025'));
    });

    test('test_invalid_or_unavailable_period', () async {
      final DashboardPeriodResult bad = useCase.selectYear(999, supportedYears: <int>{2025});
      expect(bad, isA<DashboardPeriodUnavailable>());
      final DashboardPeriodResult noCal = useCase.selectYear(2025, calendarAvailable: false);
      expect((noCal as DashboardPeriodUnavailable).code, 'calendar-unavailable');
      expect(useCase.annualSummary(2025), isNull);
      expect(useCase.hasReportingPrerequisite, isFalse);
    });

    test('test_historical_open_balance_snapshot', () async {
      final int early = await _insertRechnung(
        db,
        nummer: 'RE-early',
        typ: 'rechnung',
        status: 'offen',
        entwurf: 0,
        datum: '2025-03-01',
        brutto: '100.00',
      );
      await _insertRechnung(
        db,
        nummer: 'RE-late',
        typ: 'rechnung',
        status: 'offen',
        entwurf: 0,
        datum: '2026-02-01',
        brutto: '999.00',
      );
      final int fId = await _insertForderung(db, rechnungId: early, typ: 'rechnung', betrag: '100.00');
      await _ensureZahlungenTable(db);
      await db.executor.runInsert(
        "INSERT INTO journal (id, datum, betrag, immutable, beschreibung) VALUES (9001, '2026-02-15', 40.00, 1, 'Seed')",
        const <Object?>[],
      );
      await db.executor.runInsert(
        'INSERT INTO forderung_zahlungen (forderung_id, journal_id, betrag, typ, datum) VALUES (?, ?, ?, ?, ?)',
        <Object?>[fId, 9001, '40.00', 'zahlung', '2026-02-15'],
      );
      final DashboardAsOfResult asOf = await useCase.receivablesAsOf('2025-12-31');
      expect(asOf, isA<DashboardAsOfOk>());
      final DashboardAsOfOk ok = asOf as DashboardAsOfOk;
      expect(ok.balanceCents, 10000);
      expect(ok.itemCount, 1);
    });

    test('test_unsupported_month_quarter_or_year', () async {
      final DashboardPeriodUnavailable month = useCase.unsupportedPeriod();
      expect(month.code, 'unsupported-period');
      final DashboardPeriodResult year = useCase.selectYear(2031, supportedYears: <int>{2025});
      expect((year as DashboardPeriodUnavailable).code, 'unsupported-period');
      expect(useCase.annualSummary(2031), isNull);
    });

    test('test_historical_payable_snapshot_uses_supplier_allocations', () async {
      final int sup = await _insertRechnung(
        db,
        nummer: 'EIN-1',
        typ: 'rechnung_eingang',
        status: 'offen',
        entwurf: 0,
        datum: '2025-04-01',
        brutto: '200.00',
      );
      await _insertRechnung(
        db,
        nummer: 'EIN-late',
        typ: 'rechnung_eingang',
        status: 'offen',
        entwurf: 0,
        datum: '2026-03-01',
        brutto: '500.00',
      );
      await _insertForderung(db, rechnungId: sup, typ: 'rechnung_eingang', betrag: '200.00');
      final DashboardAsOfResult asOf = await useCase.payablesAsOf('2025-12-31');
      expect(asOf, isA<DashboardAsOfOk>());
      expect((asOf as DashboardAsOfOk).balanceCents, 20000);
    });

    test('test_settlement_split_and_reversal_follow_allocation_dates', () async {
      final int inv = await _insertRechnung(
        db,
        nummer: 'RE-split',
        typ: 'rechnung',
        status: 'offen',
        entwurf: 0,
        datum: '2025-02-01',
        brutto: '100.00',
      );
      final int fId = await _insertForderung(db, rechnungId: inv, typ: 'rechnung', betrag: '100.00');
      final int konto = await db.executor.runInsert('INSERT INTO konten (name, saldo) VALUES (?, ?)', <Object?>[
        'Kasse',
        '0.00',
      ]);
      final int journal = await db.executor.runInsert(
        'INSERT INTO journal (datum, beschreibung, betrag, beleg_typ, legacy_unverified) VALUES (?, ?, ?, ?, 0)',
        <Object?>['2025-12-20', 'settlement', '100.00', 'Zahlung'],
      );
      await db.executor.runInsert(
        'INSERT INTO settlement_groups (source_kind, source_id, signed_amount_cents, settlement_date, '
        'group_root_journal_id) VALUES (?, ?, ?, ?, ?)',
        <Object?>['bank_transaction', 'split-1', 10000, '2025-12-20', journal],
      );
      final int g1 =
          ((await db.executor.runSelect('SELECT id FROM settlement_groups WHERE source_id = ?', <Object?>[
                    'split-1',
                  ])).first['id']!
                  as num)
              .toInt();
      await db.executor.runInsert(
        'INSERT INTO settlement_allocations (group_id, forderung_id, applied_cents, settlement_date) '
        'VALUES (?, ?, ?, ?)',
        <Object?>[g1, fId, 6000, '2025-12-20'],
      );
      await db.executor.runInsert(
        'INSERT INTO settlement_groups (source_kind, source_id, signed_amount_cents, settlement_date, '
        'group_root_journal_id) VALUES (?, ?, ?, ?, ?)',
        <Object?>['bank_transaction', 'split-2', 4000, '2026-01-05', journal],
      );
      final int g2 =
          ((await db.executor.runSelect('SELECT id FROM settlement_groups WHERE source_id = ?', <Object?>[
                    'split-2',
                  ])).first['id']!
                  as num)
              .toInt();
      await db.executor.runInsert(
        'INSERT INTO settlement_allocations (group_id, forderung_id, applied_cents, settlement_date) '
        'VALUES (?, ?, ?, ?)',
        <Object?>[g2, fId, 4000, '2026-01-05'],
      );
      DashboardAsOfResult before = await useCase.receivablesAsOf('2025-12-31');
      expect((before as DashboardAsOfOk).balanceCents, 4000);
      await db.executor.runInsert(
        'INSERT INTO settlement_groups (source_kind, source_id, signed_amount_cents, settlement_date, '
        'group_root_journal_id, reversal_of_group_id) VALUES (?, ?, ?, ?, ?, ?)',
        <Object?>['bank_transaction', 'split-1:storno', -6000, '2026-02-01', journal, g1],
      );
      await db.executor.runUpdate('UPDATE settlement_groups SET reversed_by_group_id = ? WHERE id = ?', <Object?>[
        ((await db.executor.runSelect('SELECT id FROM settlement_groups WHERE source_id = ?', <Object?>[
                  'split-1:storno',
                ])).first['id']!
                as num)
            .toInt(),
        g1,
      ]);
      expect(konto, greaterThan(0));
      before = await useCase.receivablesAsOf('2025-12-31');
      expect((before as DashboardAsOfOk).balanceCents, 10000);
      final DashboardAsOfResult after = await useCase.receivablesAsOf('2026-12-31');
      expect((after as DashboardAsOfOk).balanceCents, 6000);
    });

    test('test_write_off_or_legacy_history_without_an_effective_date_is_unavailable', () async {
      final int inv = await _insertRechnung(
        db,
        nummer: 'RE-wo',
        typ: 'rechnung',
        status: 'offen',
        entwurf: 0,
        datum: '2025-01-01',
        brutto: '50.00',
      );
      final int fId = await _insertForderung(db, rechnungId: inv, typ: 'rechnung', betrag: '50.00');
      await _ensureZahlungenTable(db);
      await db.executor.runInsert(
        'INSERT INTO journal (id, datum, betrag, immutable, beschreibung, legacy_unverified) '
        "VALUES (9101, '2025-06-01', 50.00, 1, 'Seed', 0)",
        const <Object?>[],
      );
      await db.executor.runInsert(
        'INSERT INTO forderung_zahlungen (forderung_id, journal_id, betrag, typ, datum) VALUES (?, ?, ?, ?, ?)',
        <Object?>[fId, 9101, '50.00', 'ausbuchen', '2025-06-01'],
      );
      final DashboardAsOfResult blocked = await useCase.receivablesAsOf('2025-12-31');
      expect(blocked, isA<DashboardAsOfUnavailable>());
      expect((blocked as DashboardAsOfUnavailable).code, 'incomplete-history');
      await db.executor.runInsert(
        "INSERT INTO journal (datum, betrag, beschreibung) VALUES ('2025-07-01', 1, 'Unverified legacy')",
        const <Object?>[],
      );
      final DashboardAsOfResult legacy = await useCase.receivablesAsOf('2025-12-31');
      expect((legacy as DashboardAsOfUnavailable).code, 'legacy-mix');
    });

    test('test_show_a_comparable_year_over_year_trend', () async {
      final DashboardChange change = useCase.changeFor(12000, 10000);
      expect(change.absoluteCents, 2000);
      expect(change.percent, closeTo(20.0, 0.001));
      expect(change.comparable, isTrue);
      expect(dashboardProfitCents(12000, 7000), 5000);
      expect(dashboardMarginPercent(5000, 12000), closeTo(41.666, 0.01));
    });

    test('test_handle_a_zero_comparison_baseline', () async {
      final DashboardChange change = useCase.changeFor(5000, 0);
      expect(change.comparable, isFalse);
      expect(change.percent, isNull);
      expect(change.absoluteCents, 5000);
    });

    test('test_compare_a_negative_prior_profit', () async {
      final DashboardChange change = useCase.changeFor(3000, -2000);
      expect(change.absoluteCents, 5000);
      expect(change.percent, closeTo(250.0, 0.001));
    });

    test('test_render_supported_trend_data', () async {
      final DashboardUseCase withTrend = DashboardUseCase(
        db.executor,
        trendOverride: const <DashboardTrendPoint>[
          DashboardTrendPoint(month: 1, incomeCents: 10000, expenseCents: 4000),
          DashboardTrendPoint(month: 2, incomeCents: 12000, expenseCents: 5000),
        ],
      );
      final List<DashboardTrendPoint> points = withTrend.monthlyTrend(2025);
      expect(withTrend.hasRenderableTrend(points), isTrue);
      expect(points.first.profitCents, 6000);
    });

    test('test_trend_data_is_missing_or_invalid', () async {
      expect(useCase.hasRenderableTrend(const <DashboardTrendPoint>[]), isFalse);
      expect(
        useCase.hasRenderableTrend(const <DashboardTrendPoint>[
          DashboardTrendPoint(month: 13, incomeCents: 1, expenseCents: 1),
        ]),
        isFalse,
      );
      expect(useCase.monthlyTrend(2025), isEmpty);
    });

    test('test_render_open_invoices_and_receipts', () async {
      await _insertRechnung(
        db,
        nummer: 'RE-open',
        typ: 'rechnung',
        status: 'offen',
        entwurf: 0,
        datum: '2025-01-01',
        brutto: '100.00',
      );
      await _insertRechnung(
        db,
        nummer: 'RE-cancel',
        typ: 'rechnung',
        status: 'storniert',
        entwurf: 0,
        datum: '2025-01-01',
        brutto: '999.00',
      );
      await _insertRechnung(
        db,
        nummer: 'RE-draft',
        typ: 'rechnung',
        status: 'entwurf',
        entwurf: 1,
        datum: '2025-01-01',
        brutto: '888.00',
      );
      await _insertRechnung(
        db,
        nummer: 'RE-paid',
        typ: 'rechnung',
        status: 'bezahlt',
        entwurf: 0,
        datum: '2025-01-01',
        brutto: '777.00',
      );
      final Map<String, Object?> open = await useCase.openInvoices();
      expect(open['count'], 1);
      expect('${open['sum']}', contains('100'));
      final int konto = await db.executor.runInsert('INSERT INTO konten (name, saldo) VALUES (?, ?)', <Object?>[
        'Bank',
        '0.00',
      ]);
      await db.executor.runInsert(
        'INSERT INTO bank_transaktionen (konto_id, datum, betrag, verwendungszweck) VALUES (?, ?, ?, ?)',
        <Object?>[konto, '2025-02-02', '70.00', 'Unmatched'],
      );
      expect(await repo.fetchZahlungseingaenge(), isEmpty);
      await db.executor.runInsert(
        "INSERT INTO journal (id, datum, betrag, immutable, beschreibung) VALUES (1, '2025-02-01', 50.00, 1, 'Seed')",
        const <Object?>[],
      );
      await db.executor.runInsert(
        'INSERT INTO bank_transaktionen (konto_id, datum, betrag, verwendungszweck, journal_id) '
        'VALUES (?, ?, ?, ?, ?)',
        <Object?>[konto, '2025-02-01', '50.00', 'Zahlung', 1],
      );
      expect((await repo.fetchZahlungseingaenge()).map((Map<String, Object?> row) => row['verwendungszweck']), <String>[
        'Zahlung',
      ]);
      final Map<String, Object?> receipts = await useCase.confirmedReceipts();
      expect(receipts['count'], 1);
      expect(await useCase.unmatchedCount(), greaterThanOrEqualTo(1));
    });

    test('test_accounting_source_is_incomplete', () async {
      final Map<String, Object?> receipts = await useCase.confirmedReceipts();
      expect(receipts['count'], isNotNull);
      expect(useCase.annualSummary(2025), isNull);
    });

    test('test_open_an_attention_item', () async {
      final String route = useCase.bankingRouteFor(42, <String, String>{'view': 'transactions'});
      expect(route, contains('/banking?'));
      expect(route, contains('transactionId=42'));
      expect(route, contains('view=transactions'));
      expect(useCase.isAllowed('/banking'), isTrue);
    });

    test('test_tax_calendar_is_unavailable', () async {
      expect(useCase.annualSummary(1999), isNull);
      expect(useCase.hasReportingPrerequisite, isFalse);
    });

    test('test_open_a_configured_tax_deadline', () async {
      expect(useCase.isAllowed('/taxes'), isTrue);
      expect(useCase.isAllowed('/reports'), isTrue);
    });

    test('test_unmatched_filter_is_applied_on_the_banking_route', () async {
      final int konto = await db.executor.runInsert('INSERT INTO konten (name, saldo) VALUES (?, ?)', <Object?>[
        'Bank',
        '0.00',
      ]);
      final int tx = await db.executor.runInsert(
        'INSERT INTO bank_transaktionen (konto_id, datum, betrag, verwendungszweck) VALUES (?, ?, ?, ?)',
        <Object?>[konto, '2025-05-01', '10.00', 'Offen'],
      );
      final String state = await useCase.bankingSelection(<String>['$tx']);
      expect(state, 'selected:$tx');
      final String route = useCase.bankingRouteFor(tx);
      expect(route, '/banking?transactionId=$tx');
    });

    test('test_invalid_transaction_id_shows_typed_not_found_state', () async {
      expect(await useCase.bankingSelection(null), 'none');
      expect(await useCase.bankingSelection(<String>['a', 'b']), 'invalid');
      expect(await useCase.bankingSelection(<String>['abc']), 'invalid');
      expect(await useCase.bankingSelection(<String>['-5']), 'invalid');
      expect(await useCase.bankingSelection(<String>['999999']), 'not-found');
    });

    test('test_render_metrics_in_the_selected_locale', () async {
      expect(dashboardProfitCents(100, 40), 60);
      expect(isDashboardTrendValue(12), isTrue);
      expect(isDashboardTrendValue(double.nan), isFalse);
      expect(dashboardRouteBase('/banking?transactionId=42'), '/banking');
    });

    test('test_no_data_for_a_selected_period', () async {
      final DashboardAsOfResult empty = await useCase.receivablesAsOf('2025-12-31');
      expect(empty, isA<DashboardAsOfOk>());
      expect((empty as DashboardAsOfOk).balanceCents, 0);
      expect(useCase.hasRenderableTrend(const <DashboardTrendPoint>[]), isFalse);
    });
  });
}
