import 'package:dio/dio.dart';
import '../models/device_model.dart';
import '../models/device_log_model.dart';
import 'api_client.dart';

class DeviceService {
  final Dio _dio = ApiClient().dio;

  Future<List<DeviceModel>> getDevices() async {
    try {
      final response = await _dio.get('/device');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => DeviceModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<DeviceLog>> getDeviceLogs() async {
    try {
      final response = await _dio.get('/device/log');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => DeviceLog.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting device logs: $e');
      return [];
    }
  }

  Future<String?> registerDevice(String name, String hardwareId, bool resetToken) async {
    try {
      final response = await _dio.post(
        '/device/regis',
        data: {
          'name': name,
          'hardwareId': hardwareId,
          'resetToken': resetToken,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data['data']['provisionToken'];
      }
      return null;
    } on DioException catch (e) {
      final errorData = e.response?.data;
      if (errorData != null && errorData is Map<String, dynamic>) {
        final message = errorData['message'];
        if (message != null) {
          throw Exception(message);
        }
      }
      throw Exception('Lỗi không xác định khi đăng ký thiết bị.');
    }
  }

  Future<void> openDevice(String hardwareId) async {
    try {
      await _dio.post(
        '/device/open',
        data: {'hardwareId': hardwareId},
      );
    } on DioException catch (e) {
      print('Error opening device: ${e.response?.data}');
      rethrow;
    }
  }

  // Lấy danh sách thiết bị đang online (tạm thời fix cứng)
  Future<String> getOnlineDevice() async {
    // TODO: Cập nhật logic gọi API thực tế để lấy hardwareId của thiết bị online
    return '1CDBD44AF8E2';
  }

  // Gọi API đăng ký khuôn mặt lên thiết bị
  Future<void> registerFace(String imageUrl) async {
    try {
      final hardwareId = await getOnlineDevice();
      
      await _dio.post(
        '/device/regisface',
        data: {
          'hardwareId': hardwareId,
          'imageUrl': imageUrl,
        },
      );
    } on DioException catch (e) {
      print('Error registering face on device: ${e.response?.data}');
      
      // Bóc tách message từ response của server để hiển thị rõ ràng hơn
      final errorData = e.response?.data;
      if (errorData != null && errorData is Map<String, dynamic>) {
        final message = errorData['message'];
        if (message != null) {
          throw Exception(message);
        }
      }
      throw Exception('Lỗi không xác định khi đăng ký khuôn mặt.');
    } catch (e) {
      throw Exception('Đã xảy ra lỗi: $e');
    }
  }
}