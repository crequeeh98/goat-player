import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable TV and Desktop focus wrapper.
///
/// Provides:
/// - 2D Spatial Focus traversal with TV remote D-Pad & keyboard arrows.
/// - Illuminated glowing border & subtle scale transform (1.03x) on focus.
/// - Mouse hover compatibility for desktop.
/// - Automatic smooth scroll-into-view when focused.
/// - Instant activation on OK / Enter / Select / Space keys.
class TvFocusable extends StatefulWidget {
  final Widget? child;
  final Widget Function(BuildContext context, bool isFocused, bool isHovered)? builder;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onFocusChange;
  final FocusNode? focusNode;
  final bool autofocus;
  final double focusScale;
  final Color focusBorderColor;
  final Color glowColor;
  final BorderRadius? borderRadius;
  final bool autoScroll;
  final double scrollAlignment;
  final EdgeInsetsGeometry? padding;
  final bool enabled;

  const TvFocusable({
    super.key,
    this.child,
    this.builder,
    this.onPressed,
    this.onLongPress,
    this.onFocusChange,
    this.focusNode,
    this.autofocus = false,
    this.focusScale = 1.03,
    this.focusBorderColor = const Color(0xFFB388FF),
    this.glowColor = const Color(0x66B388FF),
    this.borderRadius,
    this.autoScroll = true,
    this.scrollAlignment = 0.5,
    this.padding,
    this.enabled = true,
  }) : assert(child != null || builder != null, 'Either child or builder must be provided');

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  FocusNode? _internalNode;
  bool _isHovered = false;
  bool _isFocused = false;

  FocusNode get _effectiveNode => widget.focusNode ?? (_internalNode ??= FocusNode());

  @override
  void dispose() {
    _internalNode?.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool hasFocus) {
    if (_isFocused == hasFocus) return;
    setState(() => _isFocused = hasFocus);
    widget.onFocusChange?.call(hasFocus);

    if (hasFocus && widget.autoScroll && mounted) {
      // Defer slightly so layout settles before animating scroll
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_effectiveNode.hasFocus) return;
        Scrollable.ensureVisible(
          context,
          alignment: widget.scrollAlignment,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled || widget.onPressed == null) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      final isSelectKey = event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA;

      if (isSelectKey) {
        widget.onPressed!();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child ?? widget.builder!(context, false, false);
    }

    final effectiveRadius = widget.borderRadius ?? BorderRadius.circular(10);
    final isHighlighted = _isFocused || _isHovered;
    final scale = isHighlighted ? widget.focusScale : 1.0;

    return Focus(
      focusNode: _effectiveNode,
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: widget.onPressed != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: widget.padding,
              decoration: BoxDecoration(
                borderRadius: effectiveRadius,
                border: isHighlighted
                    ? Border.all(color: widget.focusBorderColor, width: 2.0)
                    : Border.all(color: Colors.transparent, width: 2.0),
                boxShadow: isHighlighted && widget.glowColor != Colors.transparent
                    ? [
                        BoxShadow(
                          color: widget.glowColor,
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: effectiveRadius,
                child: widget.builder != null
                    ? widget.builder!(context, _isFocused, _isHovered)
                    : widget.child!,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
