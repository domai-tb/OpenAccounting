import 'package:flutter/material.dart';
import 'package:openaccounting/design_system/tokens/radius.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';

/// Dialog per DESIGN §10 + §26.
///
/// Radius 14 ([AppRadius.dialog]) with shadow (elevation/BoxShadow).
/// Shadows only for dialogs/menus/palette — dialogs MUST have elevation per §10.
class AppDialog extends StatelessWidget {
  const AppDialog({this.title, this.content, this.actions, this.onConfirm, this.onCancel, super.key});

  final String? title;
  final Widget? content;
  final List<Widget>? actions;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> effectiveActions =
        actions ??
        <Widget>[
          if (onCancel != null) TextButton(onPressed: onCancel, child: const Text('Abbrechen')),
          if (onConfirm != null) FilledButton(onPressed: onConfirm, child: const Text('Löschen')),
        ];

    // Container with BoxDecoration so tests can probe borderRadius + boxShadow
    // directly (Dialog/Material elevation probe is fragile). Keep Material for
    // semantics but primary surface is this decorated Container.
    return Dialog(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.dialog)),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.dialog),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 8)),
            BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(title!, style: theme.textTheme.titleLarge),
              ),
            // ignore: use_null_aware_elements — explicit null guard clearer
            if (content != null) content!,
            if (effectiveActions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: effectiveActions
                      .map(
                        (Widget w) => Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.sm),
                          child: w,
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Helper to show via showDialog — convenience, not required for tests.
  static Future<T?> show<T>(BuildContext context, {required AppDialog dialog}) {
    return showDialog<T>(context: context, builder: (_) => dialog);
  }
}
