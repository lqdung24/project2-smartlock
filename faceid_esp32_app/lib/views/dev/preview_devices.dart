import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../devices_screen.dart';
import '../../core/theme.dart';
import '../../providers/theme_provider.dart';

void main() {
  runApp(
    const ProviderScope(
      child: PreviewApp(),
    ),
  );
}

class PreviewApp extends ConsumerWidget {
  const PreviewApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeProvider);

    return DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => MaterialApp(
        useInheritedMediaQuery: true, 
        locale: DevicePreview.locale(context),
        builder: DevicePreview.appBuilder,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: currentThemeMode,
        // Đã đổi tên thành HomeScreenContent
        home: const Scaffold(body: HomeScreenContent()),
      ),
    );
  }
}
