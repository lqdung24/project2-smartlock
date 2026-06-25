import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:faceid_esp32_app/l10n/app_localizations.dart';
import 'widgets/login_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy theme và text hiện tại từ context
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context)!; // <--- Dùng đa ngôn ngữ ở đây

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56.0),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ColorFilter.mode(
              colorScheme.surface.withAlpha(204), // 0.8 * 255
              BlendMode.srcOver
            ),
            child: AppBar(
              backgroundColor: Colors.transparent, // Đã có backdrop filter ở trên
              title: Text(
                l10n.appTitle, // Dùng l10n.appTitle thay cho 'Smart Lock' (nếu muốn) hoặc để nguyên tên riêng
                style: textTheme.headlineMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    // Sử dụng một màu nhạt mô phỏng surfaceContainerLow, fallback bằng primary.withAlpha
                    color: colorScheme.primary.withAlpha(26), // 0.1 * 255
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.help_outline, 
                      color: theme.iconTheme.color,
                    ),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  
                  // Logo & Hero Image
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(26), // 0.1 * 255
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.lock,
                      color: colorScheme.onPrimary,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    l10n.welcomeBack, // <--- Dùng đa ngôn ngữ
                    style: textTheme.displayLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  Text(
                    l10n.loginToManageHome, // <--- Dùng đa ngôn ngữ
                    style: textTheme.bodyLarge?.copyWith(
                      color: textTheme.labelSmall?.color, // Dùng màu textSecondary
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Login Form Widget
                  const LoginForm(),

                  const SizedBox(height: 16),

                  // FaceID Auth
                  GestureDetector(
                    onTap: () {},
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            // Bề mặt nổi (high) cho nền icon
                            color: theme.dividerTheme.color?.withAlpha(51) ?? colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.face,
                            color: colorScheme.primary,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.loginWithFaceID, // <--- Dùng đa ngôn ngữ
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Secondary Links
                  TextButton(
                    onPressed: () {
                      context.push('/register');
                    },
                    child: Text(l10n.registerAccount), // <--- Dùng đa ngôn ngữ
                    // Style của TextButton đã được định nghĩa trong theme.dart
                  ),
                  TextButton(
                    onPressed: () {
                      context.push('/forgot-password');
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: textTheme.labelSmall?.color, // Màu textSecondary
                    ),
                    child: Text(l10n.forgotPassword), // <--- Dùng đa ngôn ngữ
                  ),
                  const SizedBox(height: 120), // Padding for bottom nav
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}