import '../models/user_model.dart';
import '../providers/register_provider.dart';
import '../services/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  final AuthService _authService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  AuthRepository(this._authService);

  Future<String?> login(String username, String password) {
    if (username.trim().isEmpty || password.trim().isEmpty) {
      return Future.value('Vui lòng nhập đầy đủ thông tin');
    }
    return _authService.login(username, password);
  }

  Future<UserModel?> getProfile() {
    return _authService.getProfile();
  }

  Future<String?> register(RegisterState registerData) {
    return _authService.register(registerData);
  }
  
  Future<void> logout() {
    return _authService.logout();
  }
  
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'access_token');
  }
}
