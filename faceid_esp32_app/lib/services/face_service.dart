import 'package:dio/dio.dart';
import '../models/face_model.dart';
import 'api_client.dart';

class FaceService {
  final Dio _dio = ApiClient().dio;

  Future<List<FaceModel>> getAllFaces() async {
    try {
      final response = await _dio.get('/face/all');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => FaceModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> registerFace(String imageUrl, String label) async {
    try {
      await _dio.post(
        '/face/regis',
        data: {
          'imageUrl': imageUrl,
          'label': label,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteFace(int id, String hardwareId) async {
    try {
      await _dio.delete('/face/$id/$hardwareId');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateFace(int id, String label) async {
    try {
      await _dio.put(
        '/face/$id',
        data: {'label': label},
      );
    } catch (e) {
      rethrow;
    }
  }
}