import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Quản lý trạng thái ngôn ngữ (Tiếng Anh / Tiếng Việt)
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    // Giá trị mặc định là Tiếng Anh
    return const Locale('en'); 
  }

  // Hàm để chuyển đổi ngôn ngữ
  void setLocale(Locale locale) {
    if (!['en', 'vi'].contains(locale.languageCode)) return;
    state = locale;
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
