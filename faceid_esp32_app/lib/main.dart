import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:faceid_esp32_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_preview/device_preview.dart';
import 'package:faceid_esp32_app/config.dart'; // Import AppConfig

import 'app_route.dart';
import 'core/theme.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Use the AppConfig loader
    await AppConfig.load();

    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('Caught Flutter error: ${details.exception}');
      debugPrint(details.stack.toString());
    };

    runApp(
      ProviderScope(
        child: DevicePreview(
          enabled: !kReleaseMode,
          builder: (context) => const FaceIdEsp32App(),
        ),
      ),
    );
  }, (error, stack) {
    debugPrint('Caught async error: $error');
    debugPrint(stack.toString());
  });
}

class FaceIdEsp32App extends ConsumerWidget {
  const FaceIdEsp32App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentThemeMode = ref.watch(themeProvider);
    final currentLocale = ref.watch(localeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Smart Lock App',
      
      locale: DevicePreview.locale(context) ?? currentLocale,
      builder: DevicePreview.appBuilder,

      themeMode: currentThemeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      supportedLocales: const [
        Locale('en'),
        Locale('vi'),
      ],

      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}