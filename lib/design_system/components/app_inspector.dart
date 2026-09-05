import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openaccounting/design_system/tokens/duration.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';

/// Inspector — DESIGN §14, §34: 360–440 px, overlay <900, Esc, focus trap.
/// 400 px default, AnimatedContainer 200 ms, MediaQuery <900 -> Stack overlay.
class AppInspector extends StatelessWidget {
  const AppInspector({required this.child, required this.isOpen, required this.onClose, this.title, super.key});

  final Widget child;
  final bool isOpen;
  final VoidCallback onClose;
  final String? title;

  @override
  Widget build(BuildContext context) {
    if (!isOpen) {
      return const SizedBox.shrink();
    }
    final bool isOverlay = MediaQuery.sizeOf(context).width < 900;
    final Widget panel = _panel(context);
    if (isOverlay) {
      return Stack(
        children: <Widget>[
          Positioned.fill(
            child: ModalBarrier(color: Colors.black54, onDismiss: onClose),
          ),
          Positioned(top: 0, right: 0, bottom: 0, child: panel),
        ],
      );
    }
    return panel;
  }

  Widget _panel(BuildContext context) {
    return FocusScope(
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 440),
        child: AnimatedContainer(
          duration: AppDuration.normal,
          width: 400,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (title != null) Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(title!)),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
