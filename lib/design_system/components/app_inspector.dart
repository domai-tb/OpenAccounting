import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openaccounting/design_system/tokens/duration.dart';
import 'package:openaccounting/design_system/tokens/spacing.dart';

/// Inspector — DESIGN §14, §34: 360–440 px, overlay <900, Esc, focus trap.
/// 400 px default, AnimatedContainer 200 ms, MediaQuery <900 -> Stack overlay.
class AppInspector extends StatefulWidget {
  const AppInspector({required this.child, required this.isOpen, required this.onClose, this.title, super.key});

  final Widget child;
  final bool isOpen;
  final VoidCallback onClose;
  final String? title;

  @override
  State<AppInspector> createState() => _AppInspectorState();
}

class _AppInspectorState extends State<AppInspector> {
  late final FocusScopeNode _focusScopeNode;
  FocusNode? _previousFocus;

  @override
  void initState() {
    super.initState();
    _focusScopeNode = FocusScopeNode(
      debugLabel: 'AppInspector',
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
    if (widget.isOpen) {
      _requestFocusAfterBuild();
    }
  }

  @override
  void didUpdateWidget(covariant AppInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isOpen && widget.isOpen) {
      _requestFocusAfterBuild();
    } else if (oldWidget.isOpen && !widget.isOpen) {
      _restoreFocus();
    }
  }

  @override
  void dispose() {
    _restoreFocus();
    _focusScopeNode.dispose();
    super.dispose();
  }

  void _requestFocusAfterBuild() {
    _previousFocus = FocusManager.instance.primaryFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isOpen) {
        return;
      }
      _focusScopeNode.requestFocus();
    });
  }

  void _restoreFocus() {
    final FocusNode? previous = _previousFocus;
    _previousFocus = null;
    if (previous != null && previous.canRequestFocus) {
      previous.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) {
      return const SizedBox.shrink();
    }
    final bool isOverlay = MediaQuery.sizeOf(context).width < 900;
    final Widget panel = _panel(context);
    final Widget semanticPanel = Semantics(
      container: true,
      explicitChildNodes: true,
      namesRoute: true,
      scopesRoute: true,
      label: widget.title ?? 'Inspector',
      child: panel,
    );
    if (isOverlay) {
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ModalBarrier(color: Colors.black54, semanticsLabel: 'Inspector schließen', onDismiss: widget.onClose),
          Positioned(top: 0, right: 0, bottom: 0, child: semanticPanel),
        ],
      );
    }
    return semanticPanel;
  }

  Widget _panel(BuildContext context) {
    final double viewportWidth = MediaQuery.sizeOf(context).width;
    final double maxPanelWidth = viewportWidth.clamp(0.0, 440.0);
    final double minPanelWidth = maxPanelWidth >= 360 ? 360 : maxPanelWidth;
    final double panelWidth = maxPanelWidth >= 400 ? 400 : maxPanelWidth;

    return FocusScope.withExternalFocusNode(
      focusScopeNode: _focusScopeNode,
      autofocus: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minPanelWidth, maxWidth: maxPanelWidth),
        child: AnimatedContainer(
          duration: AppDuration.normal,
          width: panelWidth,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.title ?? 'Inspector',
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Inspector schließen',
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(padding: const EdgeInsets.all(AppSpacing.lg), child: widget.child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
