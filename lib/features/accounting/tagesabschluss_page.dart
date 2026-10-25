import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:openaccounting/core/app_services.dart';
import 'package:openaccounting/core/localization.dart';
import 'package:openaccounting/design_system/components/app_card.dart';
import 'package:openaccounting/design_system/components/app_page.dart';
import 'package:openaccounting/design_system/components/app_page_header.dart';
import 'package:openaccounting/design_system/components/app_money.dart';
import 'package:openaccounting/features/accounting/tagesabschluss_creation.dart';
import 'package:openaccounting/features/cashbook/account_date_balance.dart';
import 'package:openaccounting/l10n/l10n.dart';

class TagesabschlussPage extends ConsumerWidget {
  const TagesabschlussPage({required this.balance, super.key});

  final CashbookBalanceResult? balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = appLocalizationsOf(context);
    final TagesabschlussCreation creation = ref.watch(appServicesProvider).tagesabschlussCreation;
    final CashbookBalanceResult? result = balance;
    final TagesabschlussDraft? draft = result == null ? null : creation.prepare(result);
    final String locale = Localizations.localeOf(context).toString();

    return AppPage(
      maxWidth: 1000,
      header: AppPageHeader(
        title: l10n.tagesabschlussTitle,
        subtitle: l10n.tagesabschlussSubtitle,
        showFilterToolbar: false,
      ),
      child: SingleChildScrollView(
        child: draft == null
            ? AppCard(child: Text(l10n.tagesabschlussUnavailable))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _field(l10n.tagesabschlussCompany, draft.companyId),
                        _field(l10n.tagesabschlussAccount, draft.accountId),
                        _field(l10n.tagesabschlussDate, formatDate(draft.asOfDate, locale: locale)),
                        _field(
                          l10n.tagesabschlussExpectedBalance,
                          _formatCents(draft.expectedBalanceCents, draft.currencyCode, locale),
                        ),
                        _field(l10n.tagesabschlussCurrency, draft.currencyCode),
                        _field(l10n.tagesabschlussSource, draft.sourceReference),
                        _field(
                          l10n.tagesabschlussCompleteness,
                          draft.complete ? l10n.tagesabschlussComplete : l10n.tagesabschlussUnavailable,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: TextField(
                      key: const ValueKey<String>('daily-close-counted-balance'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l10n.tagesabschlussCountedBalance),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value, softWrap: true),
      ],
    ),
  );

  String _formatCents(int cents, String currencyCode, String locale) {
    final NumberFormat numberFormat = NumberFormat.decimalPattern(locale);
    final int absoluteCents = cents.abs();
    final String whole = numberFormat.format(absoluteCents ~/ 100);
    final String fraction = (absoluteCents % 100).toString().padLeft(2, '0');
    final String sign = cents < 0 ? '-' : '';
    return '$sign$whole${numberFormat.symbols.DECIMAL_SEP}$fraction $currencyCode';
  }
}
