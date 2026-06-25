import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get apiBaseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'https://default.com/api';
  }

  // Add other environment variables here
}