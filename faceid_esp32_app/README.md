# faceid_esp32_app

A new Flutter project.

## Getting Started
```
lib/
├── main.dart                 // Điểm khởi chạy app, setup Theme và Route.
│
├── 📂 core/                  // Chứa các file dùng chung toàn app.
│   ├── constants.dart        // Chứa các biến tĩnh (Màu sắc, kích cỡ chữ, API URL...).
│   └── theme.dart            // Cấu hình giao diện (Sáng/Tối).
│   └── 📂 di/                  <-- [THÊM MỚI] Thư mục chứa Dependency Injection
│       └── locator.dart        // File duy nhất dùng để setup get_it
│
├── 📂 models/                // (Tương đương Data Class trong Kotlin)
│   ├── user_model.dart       // Class chứa thông tin user (tên, ID...).
│   └── esp_config_model.dart // Class chứa thông số kết nối của con ESP32.
│
├── 📂 services/              // (Tương đương Repository/API Client)
│   ├── api_service.dart      // Chuyên gọi API (HTTP GET/POST) lên server.
│   └── bluetooth_service.dart// Chuyên xử lý kết nối Bluetooth/Socket với ESP32.
│
├── 📂 providers/               <-- [THAY ĐỔI] Đổi tên từ view_models sang providers
│   ├── login_provider.dart     // Chứa logic và Riverpod Provider cho Đăng nhập
│   └── camera_provider.dart    // Chứa logic xử lý luồng Camera
│
└── 📂 views/                 // (Tương đương Activity/Fragment, chỉ chứa UI Widget)
    ├── login_screen.dart     // Màn hình đăng nhập.
    ├── camera_screen.dart    // Màn hình quét mặt.
    └── widgets/              // Chứa các UI dùng lại nhiều lần.
        └── custom_button.dart// Nút bấm dùng chung cho cả app.
```