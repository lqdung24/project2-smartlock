import 'package:faceid_esp32_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import 'widgets/styled_password_text_field.dart';
import 'widgets/error_message.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authService = ref.read(authServiceProvider);
      final error = await authService.changePassword(
        _oldPasswordController.text,
        _newPasswordController.text,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (error == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đổi mật khẩu thành công!'),
                backgroundColor: Colors.green,
              ),
            );
            context.pop();
          } else {
            _errorMessage = error;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.changePassword)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ErrorMessage(message: _errorMessage),
              StyledPasswordTextField(
                controller: _oldPasswordController,
                labelText: l10n.oldPassword,
                hintText: l10n.enterOldPassword,
                validator: (value) => value!.isEmpty ? l10n.pleaseEnterOldPassword : null,
              ),
              const SizedBox(height: 20),
              StyledPasswordTextField(
                controller: _newPasswordController,
                labelText: l10n.newPassword,
                hintText: l10n.enterNewPassword,
                validator: (value) {
                  if (value!.isEmpty) return l10n.pleaseEnterNewPassword;
                  if (value.length < 6) return l10n.passwordTooShort;
                  return null;
                },
              ),
              const SizedBox(height: 20),
              StyledPasswordTextField(
                controller: _confirmPasswordController,
                labelText: l10n.confirmNewPassword,
                hintText: l10n.enterConfirmNewPassword,
                validator: (value) {
                  if (value != _newPasswordController.text) return l10n.passwordsDoNotMatch;
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(l10n.changePassword),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}