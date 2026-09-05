import 'package:flutter/material.dart';
import 'package:openaccounting/core/theme/app_colors.dart';

/// Semantic status chip per DESIGN §7 §43 §44.
///
/// Uses [AccountingColors] ThemeExtension (fallback safe) and pairs
/// color with icon+text (never color alone).
/// Defines default/hover/pressed/focused/selected/disabled in light+dark.
enum AppStatus { paid, overdue, draft, warning, income, expense, info, neutral }

class AppStatusChip extends StatefulWidget {
  const AppStatusChip({
    required this.status,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.onPressed,
    super.key,
  });

  final AppStatus status;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onPressed;

  /// Resolve semantic base color from [AccountingColors] (or fallback).
  static Color colorForStatus(AccountingColors colors, AppStatus status) {
    switch (status) {
      case AppStatus.paid:
        return colors.paid;
      case AppStatus.overdue:
        return colors.overdue;
      case AppStatus.draft:
        return colors.draft;
      case AppStatus.warning:
        return colors.warning;
      case AppStatus.income:
        return colors.income;
      case AppStatus.expense:
        return colors.expense;
      case AppStatus.info:
        return colors.info;
      case AppStatus.neutral:
        return colors.neutral;
    }
  }

  /// Public helper for tests: resolves status color from current Theme.
  /// Falls back to [AccountingColors.light] when extension missing.
  static Color statusColor(BuildContext context, AppStatus status) {
    final AccountingColors ext = Theme.of(context).extension<AccountingColors>() ?? AccountingColors.light;
    return colorForStatus(ext, status);
  }

  /// Icon per status — ensures icon+text, never color alone (§7).
  static IconData iconFor(AppStatus status) {
    switch (status) {
      case AppStatus.paid:
        return Icons.check_circle;
      case AppStatus.overdue:
        return Icons.error;
      case AppStatus.draft:
        return Icons.circle_outlined;
      case AppStatus.warning:
        return Icons.warning_amber;
      case AppStatus.income:
        return Icons.trending_up;
      case AppStatus.expense:
        return Icons.trending_down;
      case AppStatus.info:
        return Icons.info;
      case AppStatus.neutral:
        return Icons.circle;
    }
  }

  /// Background for a set of [WidgetState]s — distinct per §44.
  /// Hover uses theme-specific surface token (#F1F3F6 vs #1D2129) so
  /// light/dark hover differ.
  static Color backgroundForStates(Set<WidgetState> states, Color base, Brightness brightness) {
    if (states.contains(WidgetState.disabled)) {
      final Color disabledSurface = brightness == Brightness.dark ? const Color(0xFF2B3039) : const Color(0xFFE1E4E8);
      return disabledSurface.withValues(alpha: 0.4);
    }
    if (states.contains(WidgetState.selected)) {
      return base.withValues(alpha: brightness == Brightness.dark ? 0.30 : 0.18);
    }
    if (states.contains(WidgetState.pressed)) {
      return base.withValues(alpha: 0.24);
    }
    if (states.contains(WidgetState.focused)) {
      return base.withValues(alpha: 0.16);
    }
    if (states.contains(WidgetState.hovered)) {
      final Color hoverSurface = brightness == Brightness.dark ? const Color(0xFF1D2129) : const Color(0xFFF1F3F6);
      return Color.alphaBlend(base.withValues(alpha: 0.12), hoverSurface);
    }
    return base.withValues(alpha: brightness == Brightness.dark ? 0.22 : 0.12);
  }

  static Color fallbackColor() => AccountingColors.light.neutral;

  @override
  State<AppStatusChip> createState() => _AppStatusChipState();
}

class _AppStatusChipState extends State<AppStatusChip> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  Set<WidgetState> get _states {
    final Set<WidgetState> s = <WidgetState>{};
    if (!widget.enabled) s.add(WidgetState.disabled);
    if (widget.selected) s.add(WidgetState.selected);
    if (_hovered) s.add(WidgetState.hovered);
    if (_pressed) s.add(WidgetState.pressed);
    if (_focused) s.add(WidgetState.focused);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final AccountingColors ext = Theme.of(context).extension<AccountingColors>() ?? AccountingColors.light;
    final Color base = AppStatusChip.colorForStatus(ext, widget.status);
    final Brightness brightness = Theme.of(context).brightness;
    final Color bg = AppStatusChip.backgroundForStates(_states, base, brightness);
    final Color fg = widget.enabled ? base : base.withValues(alpha: 0.38);
    final bool isDisabled = !widget.enabled;

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(AppStatusChip.iconFor(widget.status), size: 16, color: fg),
        const SizedBox(width: 6),
        Text(
          widget.label,
          style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );

    final BoxDecoration decoration = BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: _states.contains(WidgetState.focused) ? base.withValues(alpha: 0.6) : base.withValues(alpha: 0.28),
        width: _states.contains(WidgetState.focused) ? 2 : 1,
      ),
    );

    final Widget chip = Semantics(
      label: widget.label,
      button: widget.onPressed != null,
      enabled: widget.enabled,
      selected: widget.selected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: decoration,
        child: content,
      ),
    );

    // Wrap with interaction handlers when enabled.
    if (isDisabled) {
      return Opacity(opacity: 0.6, child: chip);
    }

    return Focus(
      onFocusChange: (bool v) => setState(() => _focused = v),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: Material(color: Colors.transparent, child: chip),
        ),
      ),
    );
  }
}
