import 'package:flutter/material.dart';

class StyledPasswordTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final FormFieldValidator<String>? validator;

  const StyledPasswordTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.validator,
  });

  @override
  State<StyledPasswordTextField> createState() => _StyledPasswordTextFieldState();
}

class _StyledPasswordTextFieldState extends State<StyledPasswordTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
        border: Border.all(color: theme.dividerTheme.color?.withAlpha(128) ?? Colors.grey.withAlpha(128)),
      ),
      child: Theme(
        data: theme.copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextFormField(
            controller: widget.controller,
            obscureText: _obscureText,
            validator: widget.validator,
            decoration: InputDecoration(
              border: InputBorder.none,
              labelText: widget.labelText,
              hintText: widget.hintText,
              labelStyle: textTheme.bodyMedium,
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  color: textTheme.labelSmall?.color,
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}