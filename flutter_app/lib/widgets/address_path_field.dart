import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Path field shown while the address bar is being edited.
class AddressPathField extends StatefulWidget {
  const AddressPathField({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onCancel,
    this.height = 32,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;
  final double height;

  @override
  State<AddressPathField> createState() => _AddressPathFieldState();
}

class _AddressPathFieldState extends State<AddressPathField> {
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode(onKeyEvent: _onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      widget.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onCancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: PanoramaColors.ink,
        ),
        cursorColor: PanoramaColors.blue,
        cursorWidth: 1.5,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          prefixIcon: const Icon(Icons.edit_outlined, size: 15, color: PanoramaColors.blue),
          prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 0),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: BorderSide(
              color: PanoramaColors.blue.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: PanoramaColors.blue, width: 2),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
        ),
        onSubmitted: widget.onSubmit,
        onTapOutside: (_) => widget.onCancel(),
      ),
    );
  }
}
