import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Global manager that tracks whether the latest user interaction was via keyboard/D-Pad or mouse.
/// When keyboard/D-Pad navigation is active, lingering mouse hover states are suppressed so that
/// only the actively focused item is highlighted.
class TvInputModeManager {
  static final TvInputModeManager instance = TvInputModeManager._();

  TvInputModeManager._() {
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);
  }

  final ValueNotifier<bool> isKeyboardMode = ValueNotifier<bool>(false);

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (!isKeyboardMode.value) {
        isKeyboardMode.value = true;
      }
    }
    return false;
  }

  void _handlePointerEvent(PointerEvent event) {
    if (event is PointerMoveEvent || event is PointerHoverEvent) {
      // Only switch to mouse mode if physical pointer displacement occurred
      if (event.delta.dx.abs() > 1 || event.delta.dy.abs() > 1) {
        if (isKeyboardMode.value) {
          isKeyboardMode.value = false;
        }
      }
    }
  }
}

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
    this.focusScale = 1.02,
    this.focusBorderColor = const Color(0xFFB388FF),
    this.glowColor = const Color(0x33B388FF),
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
  void initState() {
    super.initState();
    TvInputModeManager.instance.isKeyboardMode.addListener(_onInputModeChanged);
  }

  @override
  void dispose() {
    TvInputModeManager.instance.isKeyboardMode.removeListener(_onInputModeChanged);
    _internalNode?.dispose();
    super.dispose();
  }

  void _onInputModeChanged() {
    if (mounted) setState(() {});
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
          duration: const Duration(milliseconds: 200),
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
    final isKeyboardMode = TvInputModeManager.instance.isKeyboardMode.value;
    // In keyboard/TV remote mode, ignore lingering mouse hover to ensure only 1 active highlight
    final isHighlighted = isKeyboardMode ? _isFocused : (_isFocused || _isHovered);
    final scale = isHighlighted ? widget.focusScale : 1.0;
    // Fast response when highlighted, instant cleanup when losing focus to prevent ghosting
    final animDuration = isHighlighted
        ? const Duration(milliseconds: 70)
        : const Duration(milliseconds: 30);

    return Focus(
      focusNode: _effectiveNode,
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        onEnter: (_) {
          TvInputModeManager.instance.isKeyboardMode.value = false;
          setState(() => _isHovered = true);
        },
        onExit: (_) => setState(() => _isHovered = false),
        cursor: widget.onPressed != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: scale,
            duration: animDuration,
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: animDuration,
              curve: Curves.easeOutCubic,
              padding: widget.padding,
              decoration: BoxDecoration(
                borderRadius: effectiveRadius,
                border: isHighlighted
                    ? Border.all(color: widget.focusBorderColor, width: 1.4)
                    : Border.all(color: Colors.transparent, width: 1.4),
                boxShadow: isHighlighted && widget.glowColor != Colors.transparent
                    ? [
                        BoxShadow(
                          color: widget.glowColor,
                          blurRadius: 4,
                          spreadRadius: 0,
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
