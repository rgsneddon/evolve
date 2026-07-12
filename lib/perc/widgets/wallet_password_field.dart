import 'package:flutter/material.dart';

/// Password input with press-and-hold eye icon to reveal while held.
class WalletPasswordField extends StatefulWidget {
  const WalletPasswordField({
    super.key,
    required this.controller,
    this.labelText,
    this.filled = false,
    this.fillColor,
    this.onSubmitted,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String? labelText;
  final bool filled;
  final Color? fillColor;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  State<WalletPasswordField> createState() => WalletPasswordFieldState();
}

class WalletPasswordFieldState extends State<WalletPasswordField> {
  bool _holdingReveal = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: !_holdingReveal,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.labelText,
        filled: widget.filled,
        fillColor: widget.fillColor,
        suffixIcon: Listener(
          onPointerDown: (_) => setState(() => _holdingReveal = true),
          onPointerUp: (_) => setState(() => _holdingReveal = false),
          onPointerCancel: (_) => setState(() => _holdingReveal = false),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              _holdingReveal ? Icons.visibility : Icons.visibility_off,
              semanticLabel: 'Reveal password',
            ),
          ),
        ),
      ),
    );
  }
}