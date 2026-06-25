// lib/services/cloudinary_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config.dart';

class CloudinaryService {
  Future<String> uploadImage(XFile image) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(AppConfig.cloudinaryApiUrl));
      request.fields['upload_preset'] = AppConfig.cloudinaryUploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      final streamResponse = await request.send();
      final response = await http.Response.fromStream(streamResponse);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final imageUrl = responseData['secure_url'];
        if (imageUrl != null) {
          print('CloudinaryService - Image uploaded successfully. URL: $imageUrl');
          return imageUrl;
        } else {
          throw Exception('Cloudinary response does not contain a secure_url.');
        }
      } else {
        throw Exception('Failed to upload image to Cloudinary: ${response.body}');
      }
    } catch (e) {
      // In lỗi ra console để debug và throw lại để lớp gọi xử lý
      print('CloudinaryService Error: $e');
      rethrow;
    }
  }
}
