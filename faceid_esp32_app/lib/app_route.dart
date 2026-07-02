import 'package:faceid_esp32_app/views/face_registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'views/splash_screen.dart';
import 'views/login_screen.dart';
import 'views/main_shell.dart';
import 'providers/auth_provider.dart';
import 'views/register_screen.dart';
import 'views/forgot_password_screen.dart';
import 'views/setup_house_screen.dart';
import 'views/join_requests_screen.dart';
import 'views/add_device_intro_screen.dart';
import 'views/scan_devices_screen.dart';
import 'views/change_password_screen.dart';
import 'views/faces_screen.dart';

// Các màn hình nội dung của các tab
import 'views/devices_screen.dart'; 
import 'views/activity_screen.dart';
import 'views/settings_screen.dart';

// 1. Tạo một GlobalKey cho Navigator gốc
final _rootNavigatorKey = GlobalKey<NavigatorState>();

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authStatus = _ref.read(authProvider).authStatus;
    final isSplash = state.matchedLocation == '/';
    final isAuthRoute = state.matchedLocation == '/login' || 
                        state.matchedLocation == '/register' || 
                        state.matchedLocation == '/setup-house' || 
                        state.matchedLocation == '/forgot-password';

    if (authStatus == AuthStatus.unknown) return isSplash ? null : '/';
    
    if (authStatus == AuthStatus.authenticated) {
      if (isAuthRoute || isSplash) return '/home';
    }
    
    if (authStatus == AuthStatus.unauthenticated) {
      if (isAuthRoute) return null;
      return '/login';
    }
    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) => RouterNotifier(ref));

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/setup-house', builder: (context, state) => const SetupHouseScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      
      GoRoute(
        path: '/join-requests',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const JoinRequestsScreen(),
      ),
      GoRoute(
        path: '/face-registration',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FaceRegistrationScreen(),
      ),
      GoRoute(
        path: '/change-password',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ChangePasswordScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home', 
              builder: (context, state) => const HomeScreenContent(),
              routes: [
                GoRoute(
                  path: 'add-device-intro',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const AddDeviceIntroScreen(),
                ),
                GoRoute(
                  path: 'scan-devices',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const ScanDevicesScreen(),
                ),
              ]
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/activity', builder: (context, state) => const ActivityScreenContent()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/faces', builder: (context, state) => const FacesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (context, state) => const SettingsScreenContent()),
          ]),
        ],
      ),
    ],
  );
});