import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String? _serverIp;
  static int? _serverPort;
  static String? _serverIpPublic;
  static String? _cloudinaryCloudName;
  static String? _cloudinaryUploadPreset;
  static String? _cloudinaryApiUrl;
  static String? _registerFaceEndpoint;
  static String? _loginEndpoint;
  static String? _profileEndpoint;
  static String? _registerEndpoint;
  static String? _refreshTokenEndpoint;

  // Private constructor
  AppConfig._();

  static String get serverIp => _getOrThrow(_serverIp, "SERVER_IP");
  static int get serverPort => _getOrThrow(_serverPort, "SERVER_PORT");
  static String get serverIpPublic => _getOrThrow(_serverIpPublic, "SERVER_IP_PUBLIC");
  static String get cloudinaryCloudName => _getOrThrow(_cloudinaryCloudName, "CLOUDINARY_CLOUD_NAME");
  static String get cloudinaryUploadPreset => _getOrThrow(_cloudinaryUploadPreset, "CLOUDINARY_UPLOAD_PRESET");
  static String get cloudinaryApiUrl => _getOrThrow(_cloudinaryApiUrl, "CLOUDINARY_API_URL");
  
  static String get serverBaseUrl => 'http://$serverIp:$serverPort';

  static String get registerFaceEndpoint => _getOrThrow(_registerFaceEndpoint, "API_REGISTER_FACE_ENDPOINT");
  static String get loginEndpoint => _getOrThrow(_loginEndpoint, "API_LOGIN_ENDPOINT");
  static String get profileEndpoint => _getOrThrow(_profileEndpoint, "API_PROFILE_ENDPOINT");
  static String get registerEndpoint => _getOrThrow(_registerEndpoint, "API_REGISTER_ENDPOINT");
  static String get refreshTokenEndpoint => _getOrThrow(_refreshTokenEndpoint, "API_REFRESH_TOKEN_ENDPOINT");

  static T _getOrThrow<T>(T? value, String name) {
    if (value == null) {
      throw Exception("AppConfig not initialized or '$name' not found in .env. Call AppConfig.load() first.");
    }
    return value;
  }

  /// Loads environment variables from the .env file.
  /// Must be called before accessing any config properties.
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: ".env");
      _serverIp = dotenv.env['SERVER_IP'];
      _serverPort = int.tryParse(dotenv.env['SERVER_PORT'] ?? '');
      _serverIpPublic = dotenv.env['SERVER_IP_PUBLIC'];
      _cloudinaryCloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
      _cloudinaryUploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];
      _cloudinaryApiUrl = dotenv.env['CLOUDINARY_API_URL'];
      _registerFaceEndpoint = dotenv.env['API_REGISTER_FACE_ENDPOINT'];
      _loginEndpoint = dotenv.env['API_LOGIN_ENDPOINT'];
      _profileEndpoint = dotenv.env['API_PROFILE_ENDPOINT'];
      _registerEndpoint = dotenv.env['API_REGISTER_ENDPOINT'];
      _refreshTokenEndpoint = dotenv.env['API_REFRESH_TOKEN_ENDPOINT'];

      if (_serverIp == null || _serverPort == null || _serverIpPublic == null || _cloudinaryCloudName == null || _cloudinaryUploadPreset == null || _cloudinaryApiUrl == null) {
        throw Exception("Missing required environment variables in .env file.");
      }
    } catch (e) {
      print("Error loading .env file: $e");
      rethrow;
    }
  }
}
