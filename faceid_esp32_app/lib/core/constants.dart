import 'package:faceid_esp32_app/config.dart';
import 'package:flutter/material.dart';

// 1. Hằng số về Mạng (Dành cho kết nối ESP32)
class ApiConstants {
  // Lấy địa chỉ IP từ biến môi trường
  static String get esp32Ip => AppConfig.serverIp;

  // URL cho video stream từ ESP32, port 81 thường là mặc định cho camera stream
  static String get streamUrl => "http://$esp32Ip:81/stream";
  
  // Endpoint để điều khiển mở khóa
  static String get unlockEndpoint => "http://$esp32Ip/control?relay=on";
}

// 2. Hằng số về Giao diện (Màu sắc, Khoảng cách)
class AppDesign {
  // Màu sắc chủ đạo
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);

  // Khoảng cách chuẩn (Padding/Margin)
  static const double defaultPadding = 16.0;
  static const double borderRadius = 12.0;
}

// 3. Hằng số về Text (Thông báo dùng chung)
class AppMessages {
  static const String connectSuccess = "Đã kết nối với khóa cửa!";
  static const String accessDenied = "Khuôn mặt không hợp lệ!";
}