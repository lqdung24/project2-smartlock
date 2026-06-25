import 'package:flutter/material.dart';

class PasswordInputField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final FormFieldValidator<String>? validator;
  final bool hasBorder;

  const PasswordInputField({
    super.key,
    required this.controller,
    this.hintText,
    this.labelText,
    this.validator,
    this.hasBorder = true, // Default to true for standard TextFormFields
  });

  @override
  State<PasswordInputField> createState() => _PasswordInputFieldState();
}

class _PasswordInputFieldState extends State<PasswordInputField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      validator: widget.validator,
      style: textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        isDense: !widget.hasBorder,
        contentPadding: widget.hasBorder ? null : EdgeInsets.zero,
        border: widget.hasBorder ? const UnderlineInputBorder() : InputBorder.none,
        enabledBorder: widget.hasBorder ? UnderlineInputBorder(borderSide: BorderSide(color: theme.dividerTheme.color ?? Colors.grey)) : InputBorder.none,
        focusedBorder: widget.hasBorder ? UnderlineInputBorder(borderSide: BorderSide(color: theme.primaryColor)) : InputBorder.none,
        suffixIcon: GestureDetector(
          onTap: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
          child: Icon(
            _obscureText ? Icons.visibility_off : Icons.visibility,
            color: textTheme.labelSmall?.color,
            size: 20,
          ),
        ),
        suffixIconConstraints: const BoxConstraints(minHeight: 20, minWidth: 20),
      ),
    );
  }
}