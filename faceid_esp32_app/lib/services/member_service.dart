import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../models/join_request_model.dart'; // Thêm import
import 'api_client.dart';

class MemberService {
  final Dio _dio = ApiClient().dio;

  Future<List<UserModel>> getAllMembers() async {
    try {
      final response = await _dio.get('/user/all');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => UserModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Thêm hàm lấy danh sách yêu cầu
  Future<List<JoinRequestModel>> getJoinRequests() async {
    try {
      final response = await _dio.get('/user/request');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => JoinRequestModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> acceptRequest(int requesterId) async {
    try {
      final response = await _dio.post(
        '/user/accept',
        data: {'requesterId': requesterId},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeMember(int memberId) async {
    try {
      final response = await _dio.post(
        '/user/remove-member',
        data: {'memberId': memberId},
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}