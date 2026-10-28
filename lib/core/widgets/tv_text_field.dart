import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/platform_utils.dart';
import 'tv_focusable.dart';

class TvTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final InputBorder? border;
  final InputBorder? focusedBorder;
  final EdgeInsetsGeometry? contentPadding;
  final bool isDense;
  final bool autofocus;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent;
  final InputDecoration? decoration;

  const TvTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.style,
    this.hintStyle,
    this.prefixIcon,
    this.suffixIcon,
    this.border,
    this.focusedBorder,
    this.contentPadding,
    this.isDense = true,
    this.autofocus = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.onKeyEvent,
    this.decoration,
  });

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode => widget.focusNode ?? (_internalFocusNode ??= FocusNode(debugLabel: 'tv_text_field'));
  final FocusNode _editFocusNode = FocusNode(debugLabel: 'tv_text_field_editing');

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(TvTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _editFocusNode.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _openKeyboard() {
    if (!_isEditing) {
      setState(() => _isEditing = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _editFocusNode.requestFocus();
          SystemChannels.textInput.invokeMethod('TextInput.show');
        }
      });
    }
  }

  void _closeKeyboard() {
    if (_isEditing) {
      setState(() => _isEditing = false);
      SystemChannels.textInput.invokeMethod('TextInput.hide');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _effectiveFocusNode.canRequestFocus) {
          _effectiveFocusNode.requestFocus();
        }
      });
    }
  }

  InputDecoration _buildDecoration() {
    if (widget.decoration != null) {
      return widget.decoration!;
    }
    final effectiveBorder = widget.border ?? const OutlineInputBorder();
    final effectiveFocusedBorder = widget.focusedBorder ??
        (widget.border == InputBorder.none
            ? InputBorder.none
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFB388FF), width: 2),
              ));

    return InputDecoration(
      labelText: widget.labelText,
      hintText: widget.hintText,
      hintStyle: widget.hintStyle,
      prefixIcon: widget.prefixIcon,
      suffixIcon: widget.suffixIcon,
      border: effectiveBorder,
      focusedBorder: effectiveFocusedBorder,
      contentPadding: widget.contentPadding,
      isDense: widget.isDense,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!GoatPlatform.isTv) {
      return TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        style: widget.style,
        decoration: _buildDecoration(),
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        validator: widget.validator,
      );
    }

    if (_isEditing) {
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _closeKeyboard,
          const SingleActivator(LogicalKeyboardKey.goBack): _closeKeyboard,
          const SingleActivator(LogicalKeyboardKey.arrowDown): () {
            _closeKeyboard();
            widget.onKeyEvent?.call(_effectiveFocusNode, const KeyDownEvent(
              physicalKey: PhysicalKeyboardKey.arrowDown,
              logicalKey: LogicalKeyboardKey.arrowDown,
              timeStamp: Duration.zero,
            ));
          },
          const SingleActivator(LogicalKeyboardKey.arrowUp): () {
            _closeKeyboard();
            widget.onKeyEvent?.call(_effectiveFocusNode, const KeyDownEvent(
              physicalKey: PhysicalKeyboardKey.arrowUp,
              logicalKey: LogicalKeyboardKey.arrowUp,
              timeStamp: Duration.zero,
            ));
          },
        },
        child: TextFormField(
          controller: widget.controller,
          focusNode: _editFocusNode,
          autofocus: true,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction ?? TextInputAction.search,
          style: widget.style,
          decoration: _buildDecoration(),
          onChanged: widget.onChanged,
          onEditingComplete: _closeKeyboard,
          onFieldSubmitted: (val) {
            _closeKeyboard();
            widget.onSubmitted?.call(val);
          },
          validator: widget.validator,
        ),
      );
    }

    final hasText = widget.controller?.text.isNotEmpty ?? false;
    final displayText = hasText ? widget.controller!.text : '';
    final displayStyle = widget.style ?? const TextStyle(color: Colors.white, fontSize: 13);

    return TvFocusable(
      focusNode: _effectiveFocusNode,
      autofocus: widget.autofocus,
      borderRadius: BorderRadius.circular(10),
      focusScale: 1.01,
      focusBorderColor: const Color(0xFFB388FF),
      glowColor: const Color(0x33B388FF),
      onPressed: _openKeyboard,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final isSelect = event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonSelect;
          if (isSelect) {
            _openKeyboard();
            return KeyEventResult.handled;
          }
        }
        if (widget.onKeyEvent != null) {
          final res = widget.onKeyEvent!(node, event);
          if (res != KeyEventResult.ignored) return res;
        }
        return KeyEventResult.ignored;
      },
      child: InputDecorator(
        decoration: _buildDecoration(),
        isEmpty: !hasText,
        child: Text(
          displayText,
          style: displayStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
