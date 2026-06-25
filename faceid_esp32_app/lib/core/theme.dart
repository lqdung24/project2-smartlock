import 'package:flutter/material.dart';

/// Class quản lý toàn bộ mã màu của ứng dụng dựa trên file thiết kế.
class AppColors {
  final Color primary;
  final Color primaryContainer;
  final Color onPrimary;

  final Color background;
  final Color surface;
  final Color onSurface;
  final Color onSurfaceVariant;

  final Color textPrimary;
  final Color textSecondary;

  final Color outline;
  final Color outlineVariant;

  final Color success;
  final Color danger;

  final Color surfaceContainerHighest;

  const AppColors({
    required this.primary,
    required this.primaryContainer,
    required this.onPrimary,
    required this.background,
    required this.surface,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.outline,
    required this.outlineVariant,
    required this.success,
    required this.danger,
    required this.surfaceContainerHighest,
  });

  /// Bảng màu chuẩn cho Light Theme (Từ config YAML/MD)
  static const AppColors light = AppColors(
    primary: Color(0xFF0058BC),
    primaryContainer: Color(0xFF0070EB),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFFF2F2F7), // light-bg-primary
    surface: Color(0xFFFFFFFF),    // light-bg-secondary (Card trắng tinh)
    onSurface: Color(0xFF181C23),
    onSurfaceVariant: Color(0xFF414755),
    textPrimary: Color(0xFF000000), // text-primary-light
    textSecondary: Color(0xFF8E8E93), // text-secondary-light
    outline: Color(0xFF717786),
    outlineVariant: Color(0xFFC1C6D7),
    success: Color(0xFF34C759), // light-status-success
    danger: Color(0xFFFF3B30), // light-status-danger
    surfaceContainerHighest: Color(0xFFE0E2ED),
  );

  /// Bảng màu cho Dark Theme (Từ config YAML/MD)
  static const AppColors dark = AppColors(
    primary: Color(0xFF0A84FF),     // Màu xanh đặc trưng iOS Dark Mode từ MD
    primaryContainer: Color(0xFF004493),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFF000000),  // dark-bg-primary
    surface: Color(0xFF1C1C1E),     // dark-bg-secondary
    onSurface: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFFA0A0A5),
    textPrimary: Color(0xFFFFFFFF), // text-primary-dark
    textSecondary: Color(0xFF8E8E93), // text-secondary-dark
    outline: Color(0xFF8E8E93),
    outlineVariant: Color(0xFF38383A), // Viền tối (từ MD)
    success: Color(0xFF30D158),     // dark-status-success
    danger: Color(0xFFFF453A),      // dark-status-danger
    surfaceContainerHighest: Color(0xFF48484A),
  );
}

class AppTheme {
  static ThemeData _buildTheme(AppColors colors, Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      fontFamily: 'Plus Jakarta Sans',
      scaffoldBackgroundColor: colors.background,

      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.primary,
        onPrimary: colors.onPrimary,
        primaryContainer: colors.primaryContainer,
        secondary: colors.primary,
        onSecondary: colors.onPrimary,
        surface: colors.surface,
        onSurface: colors.onSurface,
        error: colors.danger,
        onError: Colors.white,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.primary),
        titleTextStyle: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          color: colors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Mapping Typography từ file YAML
      textTheme: TextTheme(
        // headline-lg
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          height: 41 / 34,
          color: colors.textPrimary,
        ),
        // headline-md
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 28 / 22,
          color: colors.textPrimary,
        ),
        // body-lg
        bodyLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          height: 22 / 17,
          color: colors.textPrimary,
        ),
        // body-sm
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 20 / 15,
          color: colors.textPrimary,
        ),
        // label-caps
        labelSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          height: 18 / 13,
          color: colors.textSecondary,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.transparent,
        hintStyle: TextStyle(color: colors.textSecondary, fontSize: 17),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),

      iconTheme: IconThemeData(
        color: colors.onSurfaceVariant,
        size: 24,
      ),

      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          return Colors.white; // Cả light và dark thumb đều trắng
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.success;
          }
          return colors.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }

  static ThemeData get lightTheme => _buildTheme(AppColors.light, Brightness.light);
  static ThemeData get darkTheme => _buildTheme(AppColors.dark, Brightness.dark);
}
