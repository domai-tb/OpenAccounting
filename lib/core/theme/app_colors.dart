import 'package:flutter/material.dart';

/// Semantic accounting colors per DESIGN §43.
/// Separate from [ColorScheme] — finance status needs dedicated tokens.
///
/// Light/dark variants keep meaning but adapt luminance for contrast.
@immutable
class AccountingColors extends ThemeExtension<AccountingColors> {
  const AccountingColors({
    required this.paid,
    required this.overdue,
    required this.draft,
    required this.warning,
    required this.income,
    required this.expense,
    required this.info,
    required this.neutral,
  });

  final Color paid;
  final Color overdue;
  final Color draft;
  final Color warning;
  final Color income;
  final Color expense;
  final Color info;
  final Color neutral;

  static const light = AccountingColors(
    paid: Color(0xFF16A34A),
    overdue: Color(0xFFDC2626),
    draft: Color(0xFF6B7280),
    warning: Color(0xFFD97706),
    income: Color(0xFF16A34A),
    expense: Color(0xFFDC2626),
    info: Color(0xFF2563EB),
    neutral: Color(0xFF9CA3AF),
  );

  static const dark = AccountingColors(
    paid: Color(0xFF86EFAC),
    overdue: Color(0xFFFCA5A5),
    draft: Color(0xFF9CA3AF),
    warning: Color(0xFFFCD34D),
    income: Color(0xFF86EFAC),
    expense: Color(0xFFFCA5A5),
    info: Color(0xFF93C5FD),
    neutral: Color(0xFF6B7280),
  );

  @override
  AccountingColors copyWith({
    Color? paid,
    Color? overdue,
    Color? draft,
    Color? warning,
    Color? income,
    Color? expense,
    Color? info,
    Color? neutral,
  }) {
    return AccountingColors(
      paid: paid ?? this.paid,
      overdue: overdue ?? this.overdue,
      draft: draft ?? this.draft,
      warning: warning ?? this.warning,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      info: info ?? this.info,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  AccountingColors lerp(ThemeExtension<AccountingColors>? other, double t) {
    if (other is! AccountingColors) return this;
    return AccountingColors(
      paid: Color.lerp(paid, other.paid, t)!,
      overdue: Color.lerp(overdue, other.overdue, t)!,
      draft: Color.lerp(draft, other.draft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      info: Color.lerp(info, other.info, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}
