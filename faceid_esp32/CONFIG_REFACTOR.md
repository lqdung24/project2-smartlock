# Configuration Refactoring Documentation

## Overview
Hệ thống config đã được refactor để lưu trữ cấu hình trong NVS (Non-Volatile Storage) thay vì hardcode.

## Struct Configuration

```c
typedef struct {
    char wifi_ssid[32];      // WiFi network name (max 31 chars)
    char wifi_pass[64];      // WiFi password (max 63 chars)
    char mqtt_host[128];     // MQTT broker address
    uint16_t mqtt_port;      // MQTT broker port
    char device_name[32];    // Device identifier (max 31 chars)
} app_config_t;
```

## Key Functions

### config_load(app_config_t *config)
- Tải cấu hình từ NVS
- Nếu không tìm thấy → dùng giá trị mặc định
- Return: ESP_OK hoặc ESP_ERR_NVS_NOT_FOUND

### config_save(app_config_t *config)
- Lưu cấu hình vào NVS
- Commit changes tự động
- Return: ESP_OK nếu thành công

### config_init_defaults(app_config_t *config)
- Khởi tạo struct với giá trị mặc định
- Dùng trong quá trình development

### config_print(app_config_t *config)
- In toàn bộ cấu hình ra log (debug)

## Usage in main.cpp

```cpp
static app_config_t g_app_config;  // Global config struct

void app_main(void) {
    // Load config from NVS (use defaults if not found)
    config_load(&g_app_config);
    config_print(&g_app_config);
    
    // Pass config to components
    wifi_init_sta(g_app_config.wifi_ssid, g_app_config.wifi_pass);
    mqtt_app_start(g_app_config.mqtt_host);
}
```

## Integration with Components

Các component nhận config thông qua parameters:
- **wifi_handler**: `wifi_init_sta(ssid, password)`
- **mqtt_connection**: `mqtt_app_start(mqtt_host)`

## Cách Update Config

### Option 1: Qua Web Interface (nếu có)
- Tạo endpoint để update config
- Call `config_save(&g_app_config)` để persist

### Option 2: Qua Serial CLI
- Nhận lệnh từ serial
- Update `g_app_config` fields
- Call `config_save(&g_app_config)`

### Option 3: Qua BLE (hiện tại)
- Implement BLE command handler
- Parse config từ BLE packet
- Call `config_save(&g_app_config)`

## Default Values (config.c)

```
WiFi SSID: "panda"
WiFi Pass: "mybirthday"
MQTT Host: "172.30.26.176"
MQTT Port: 1883
Device Name: "esp32s3_smartlock"
```

## File Structure

```
components/common/
├── CMakeLists.txt (updated)
├── config.c       (NEW - implementation)
├── include/
│   └── config.h   (NEW - header)
├── event.cpp
└── event.hpp

main/
└── main.cpp       (updated - use config system)
```

## Building & Testing

```bash
# Build project
idf.py build

# Flash
idf.py flash

# Monitor
idf.py monitor
```

Cấu hình sẽ được load từ NVS. Nếu lần đầu khởi động → dùng giá trị mặc định.

## Future Enhancements

1. **Web UI**: Trang web để config WiFi/MQTT
2. **BLE Config**: Gửi config thông qua ứng dụng mobile
3. **OTA Config**: Update config qua MQTT
4. **Config Validation**: Validate các field trước khi save
5. **Config Encryption**: Mã hóa password trong NVS
