// lib/services/api_service.dart

import 'package:dio/dio.dart';
import '../config.dart';
import 'api_client.dart';

class ApiService {
  final ApiClient _apiClient = ApiClient();

  Future<void> registerFace({
    required String hardwareId,
    required String imageUrl,
    required String userId,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        AppConfig.registerFaceEndpoint,
        data: {
          'hardwareID': hardwareId,
          'img_url': imageUrl,
          'userId': userId,
        },
      );

      // Dio sẽ tự động throw exception cho các status code không phải 2xx
      // nên chúng ta không cần kiểm tra response.statusCode nữa.
      
    } on DioException catch (e) {
      // Bắt lỗi từ Dio và throw lại một exception rõ ràng hơn
      final errorData = e.response?.data;
      final message = errorData?['message'] ?? e.message;
      print('ApiService Error: $message');
      throw Exception('Lỗi khi đăng ký khuôn mặt: $message');
    } catch (e) {
      print('ApiService Error: $e');
      rethrow;
    }
  }
}
