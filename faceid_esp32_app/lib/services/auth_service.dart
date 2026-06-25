import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../providers/register_provider.dart';
import 'api_client.dart';
import '../config.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();

  Future<String?> login(String username, String password) async {
    try {
      final response = await _apiClient.dio.post(
        AppConfig.loginEndpoint,
        data: {'email': username, 'password': password},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'];
        if (data != null) {
          final accessToken = data['access_token'];
          final refreshToken = data['refresh_token'];
          if (accessToken != null && refreshToken != null) {
            await _apiClient.saveTokens(accessToken, refreshToken);
            _apiClient.setInMemoryToken(accessToken);
            return null;
          }
        }
        return 'Dữ liệu token không hợp lệ.';
      } else {
        return 'Đăng nhập thất bại: ${response.statusCode}';
      }
    } on DioException catch (e) {
      final errorData = e.response?.data;
      return errorData?['message'] ?? 'Tài khoản hoặc mật khẩu không chính xác.';
    } catch (e) {
      return 'Đã có lỗi xảy ra: $e';
    }
  }

  Future<UserModel?> getProfile() async {
    try {
      final response = await _apiClient.dio.get(AppConfig.profileEndpoint);
      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> register(RegisterState registerData) async {
    try {
      final Map<String, dynamic> payload = {
        'email': registerData.email,
        'password': registerData.password,
        'name': registerData.name,
      };

      if (registerData.houseOption == HouseSetupOption.create) {
        payload['houseName'] = registerData.newHouseName;
        payload['ownerEmail'] = 'none@none.com';
      } else if (registerData.houseOption == HouseSetupOption.join) {
        payload['houseName'] = 'none';
        payload['ownerEmail'] = registerData.ownerEmail;
      }

      final response = await _apiClient.dio.post(AppConfig.registerEndpoint, data: payload);

      if (response.statusCode == 201) {
        final data = response.data['data'];
        if (data != null) {
          final accessToken = data['access_token'];
          final refreshToken = data['refresh_token'];
          if (accessToken != null && refreshToken != null) {
            await _apiClient.saveTokens(accessToken, refreshToken);
            _apiClient.setInMemoryToken(accessToken);
            return null;
          }
        }
        return 'Đăng ký thành công nhưng không nhận được token.';
      } else {
        return 'Đăng ký thất bại: ${response.statusCode}';
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final errorData = e.response?.data;
        return errorData?['message'] ?? 'Email đã tồn tại hoặc dữ liệu không hợp lệ.';
      } else {
        return 'Không thể kết nối đến máy chủ.';
      }
    } catch (e) {
      return 'Đã có lỗi xảy ra: $e';
    }
  }

  Future<String?> changePassword(String oldPassword, String newPassword) async {
    try {
      final response = await _apiClient.dio.post(
        '/user/change-password',
        data: {'oldPassword': oldPassword, 'newPassword': newPassword},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return null;
      }
      return 'Đổi mật khẩu thất bại';
    } on DioException catch (e) {
      return e.response?.data['message'] ?? 'Đã có lỗi xảy ra';
    }
  }

  Future<void> logout() async {
    await _apiClient.performLogout();
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());