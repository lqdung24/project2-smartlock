import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final AuthStatus authStatus;
  final UserModel? user;

  AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.authStatus = AuthStatus.unknown,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    AuthStatus? authStatus,
    UserModel? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      authStatus: authStatus ?? this.authStatus,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _authRepository;

  @override
  AuthState build() {
    _authRepository = AuthRepository(AuthService());
    return AuthState();
  }

  Future<void> checkInitialAuth() async {
    state = state.copyWith(isLoading: true, authStatus: AuthStatus.unknown);
    final token = await _authRepository.getAccessToken();
    if (token == null) {
      state = state.copyWith(isLoading: false, authStatus: AuthStatus.unauthenticated);
      return;
    }

    final user = await _authRepository.getProfile();
    if (user != null) {
      state = state.copyWith(isLoading: false, authStatus: AuthStatus.authenticated, user: user);
    } else {
      await logout();
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final error = await _authRepository.login(username, password);

    if (error == null) {
      final user = await _authRepository.getProfile();
      state = state.copyWith(isLoading: false, authStatus: AuthStatus.authenticated, user: user);
      return true;
    } else {
      state = state.copyWith(isLoading: false, errorMessage: error, authStatus: AuthStatus.unauthenticated);
      return false;
    }
  }
  
  Future<void> logout() async {
    await _authRepository.logout();
    state = AuthState(authStatus: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
