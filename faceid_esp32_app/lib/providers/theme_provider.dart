import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Quản lý trạng thái giao diện (Light/Dark/System)
class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Giá trị mặc định khi khởi động app là theo hệ thống
    return ThemeMode.system; 
  }

  // Hàm để chuyển đổi qua lại giữa Sáng và Tối
  void toggleTheme() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }

  // Hàm để set cụ thể một Theme
  void setTheme(ThemeMode mode) {
    state = mode;
  }
}

// Khai báo provider để các Widget khác có thể .watch() hoặc .read()
final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);
