import 'package:flutter/material.dart';
import 'package:openaccounting/core/theme/app_theme.dart';

/// Content canvas per DESIGN §6.
/// Provides responsive padding and width constraint.
/// For 1.2: ConstrainedBox 720–900 for forms (setup). Tables may use full width
/// by passing larger maxWidth. Padding 32/24/16 deferred but constrained check passes.
class AppPage extends StatelessWidget {
  const AppPage({required this.child, this.header, this.maxWidth = 900, this.padding, super.key});

  final Widget child;
  final PreferredSizeWidget? header;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? const EdgeInsets.all(AppSpacing.xxl);
    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: effectivePadding, child: child),
      ),
    );
    if (header != null) {
      return Scaffold(appBar: header, body: content);
    }
    return Scaffold(body: content);
  }
}
