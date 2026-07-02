#include "event.hpp"
#include "config.h"
#include "esp_log.h"
#include "esp_mac.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "http_connect.h"
#include "mqtt_connection.hpp"
#include "wifi_handler.h"
#include <stdlib.h>

static const char *TAG = "app_event";
static char *provison_token;
static int retry_count = 0;
static app_event_enroll_done_cb_t s_enroll_done_callback = NULL;

// =======================================================
// HÀM HẸN GIỜ ĐỘNG (NHƯ SETTIMEOUT)
// =======================================================
void set_timeout(uint32_t delay_ms, timeout_cb_t callback_func, void *arg) {
  // 1. Dọn dẹp: Nếu timer cũ đang chạy dở, phải dừng và xóa nó đi
  if (reusable_timer_handle != NULL) {
    esp_timer_stop(reusable_timer_handle);
    esp_timer_delete(reusable_timer_handle);
    reusable_timer_handle = NULL;
  }

  // 2. Tạo cấu hình mới với hàm callback m truyền vào
  esp_timer_create_args_t timer_args = {
      .callback = callback_func,
      .arg = arg, // Truyền tham số phụ nếu cần (thường để NULL)
      .name = "dynamic_timeout"};

  // 3. Đăng ký với hệ điều hành
  ESP_ERROR_CHECK(esp_timer_create(&timer_args, &reusable_timer_handle));

  // 4. Bật đồng hồ đếm ngược
  // LƯU Ý: esp_timer dùng Micro-giây (us). Phải nhân 1000.
  // Dùng 1000ULL để ép kiểu 64-bit, chống lỗi tràn số khi delay lâu.
  ESP_ERROR_CHECK(
      esp_timer_start_once(reusable_timer_handle, delay_ms * 1000ULL));

  ESP_LOGI(TAG, "Đã hẹn giờ %lu ms. Hệ thống tiếp tục làm việc khác...",
           delay_ms);
}

/* ── Custom Event Base Definition ────────────────────────────── */
ESP_EVENT_DEFINE_BASE(APP_EVENTS);

/* ── Event Handlers ──────────────────────────────────────────── */
static bool regis_to_server(app_config_t cfg);

void app_event_post_enroll_done(uint16_t id) {
  esp_event_post(APP_EVENTS, APP_EVENT_ENROLL_DONE, &id, sizeof(id),
                 portMAX_DELAY);

  ESP_LOGI(TAG, "Enroll done event posted id=%d", id);
}

void app_event_register_enroll_done(app_event_enroll_done_cb_t cb) {
  s_enroll_done_callback = cb;
}

static void enroll_done_handler(void *handler_args, esp_event_base_t base,
                                int32_t id, void *event_data) {
  if (id != APP_EVENT_ENROLL_DONE)
    return;
  if (event_data == NULL)
    return;

  uint16_t enrolled_id = *(uint16_t *)event_data;
  ESP_LOGI(TAG, "Enroll done handler received id=%d", enrolled_id);
  if (s_enroll_done_callback) {
    s_enroll_done_callback(enrolled_id);
  }
}

static void mqtt_connected_handler(void *handler_args, esp_event_base_t base,
                                   int32_t id, void *event_data) {
  if (id != APP_EVENT_MQTT_CONNECTED)
    return;

  ESP_LOGI("APP_EVENT", "MQTT đã đăng ký thành công");
  // TODO: tiếp tục logic sau khi MQTT connected
}

static void get_value(const char *buf, const char *key, char *out,
                      size_t out_size, char terminator);

void get_bluetooth_mac_string(char *out_str) {
  uint8_t mac[6];

  esp_read_mac(mac, ESP_MAC_BT);

  snprintf(out_str, 18, "%02X%02X%02X%02X%02X%02X", mac[0], mac[1], mac[2],
           mac[3], mac[4], mac[5]);
}
/**
 * @brief Handler to save config when received from BLE/API
 */
static void config_save_handler(void *handler_args, esp_event_base_t base,
                                int32_t id, void *event_data) {
  if (id != APP_EVENT_CONFIG_RECEIVED) {
    return;
  }

  app_config_t *config = (app_config_t *)event_data;
  if (config == NULL) {
    ESP_LOGE(TAG, "Invalid config data");
    return;
  }

  ESP_LOGI(TAG, "[save_handler] Saving config to NVS...");
  config_print(config);

  esp_err_t err = config_saving(config);
  if (err == ESP_OK) {
    ESP_LOGI(TAG, "[save_handler] ✓ Config saved successfully!");
  } else {
    ESP_LOGE(TAG, "[save_handler] ✗ Failed to save config");
  }
}

/**
 * @brief Handler to log config when received
 */
static void config_log_handler(void *handler_args, esp_event_base_t base,
                               int32_t id, void *event_data) {
  if (id != APP_EVENT_CONFIG_RECEIVED) {
    return;
  }

  app_config_t *config = (app_config_t *)event_data;
  if (config == NULL) {
    return;
  }

  ESP_LOGI(TAG, "[log_handler] Config received event:");
  config_print(config);
}

static void wifi_connect_task(void *pv) {
  ESP_LOGI(TAG, "wifi_connect_task started");
  app_config_t cfg;
  config_load(&cfg);
  ESP_LOGI(TAG, "wifi_connect_task loaded config: ssid=%s", cfg.wifi_ssid);
  esp_err_t err = wifi_init_sta(cfg.wifi_ssid, cfg.wifi_pass);

  if (err != ESP_OK) {
    ESP_LOGE(TAG, "wifi_init_sta failed: %s", esp_err_to_name(err));
    vTaskDelete(NULL);
    return;
  }
  wifi_wait_connected();
  ESP_LOGI(TAG, "wifi_connect_task done");
  bool res = false;
  while (retry_count < 5 && !(res = regis_to_server(cfg))) {
    retry_count++;
  }

  if (res) {
    ESP_LOGI(TAG, "registed to server");
    free(provison_token);
    config_load(&cfg);
    config_print(&cfg);
    mqtt_app_start(cfg.mqtt_host, cfg.mqtt_port, cfg.mqtt_token);
  } else {
    ESP_LOGE(TAG, "error registing to server %d times", retry_count);

    // todo: led show error
  }

  vTaskDelete(NULL);
}

static bool regis_to_server(app_config_t cfg) {
  http_response_t response = {0};
  char body[512];
  char server[128]; // fix
  char hardwareId[32];
  get_bluetooth_mac_string(hardwareId);
  snprintf(body, sizeof(body),
           "{\"hardwareId\":\"%s\",\"provisionToken\":\"%s\"}", hardwareId,
           provison_token);
  sprintf(server, "http://%s:%d/device/confirm", cfg.server_host,
          cfg.server_port);
  // printf("URL : %s\n", server);
  // printf("BODY: %s\n", body);
  if (http_post(server, body, &response)) {
    ESP_LOGI(TAG, "Status: %d, Body: %s, len %d", response.status_code,
             response.response_body, response.response_len);
    char port[8];
    get_value(response.response_body, "\"mqttToken\":\"", cfg.mqtt_token,
              sizeof(cfg.mqtt_token), '\"');
    get_value(response.response_body, "\"mqttHost\":\"", cfg.mqtt_host,
              sizeof(cfg.mqtt_host), '\"');
    get_value(response.response_body, "\"mqttPort\":\"", port, sizeof(port),
              '\"');

    config_update_str("mqtt_token", cfg.mqtt_token);
    config_update_str("mqtt_host", cfg.mqtt_host);
    config_update_u16("mqtt_port", (uint16_t)atoi(port));

    http_response_free(&response);
  }

  return response.status_code == 201;
}

static void config_connect_wifi(void *handler_args, esp_event_base_t base,
                                int32_t id, void *event_data) {
  ESP_LOGI(TAG, "config_connect_wifi event received, creating wifi task");
  if (xTaskCreate(wifi_connect_task, "wifi_connect", 8192, NULL, 5, NULL) !=
      pdPASS) {
    ESP_LOGE(TAG, "Failed to create wifi_connect task");
  }
}

static void config_mqtt_connected(void *handler_args, esp_event_base_t base,
                                  int32_t id, void *event_data) {
  config_update_i32("configured", 1);
  app_config_t cfg;
  config_load(&cfg);
  config_print(&cfg);
  esp_restart();
}
/* ── Public API ──────────────────────────────────────────────── */

void app_event_init(void) {
  // Create default event loop
  ESP_ERROR_CHECK(esp_event_loop_create_default());

  esp_event_handler_register(APP_EVENTS, APP_EVENT_CONFIG_RECEIVED,
                             config_connect_wifi, NULL);

  esp_event_handler_register(APP_EVENTS, APP_EVENT_MQTT_CONNECTED,
                             config_mqtt_connected, NULL);

  esp_event_handler_register(APP_EVENTS, APP_EVENT_ENROLL_DONE,
                             enroll_done_handler, NULL);

  ESP_LOGI(TAG, "Event handlers registered");
}

void app_event_post_config_received(app_config_t *config) {
  if (config == NULL) {
    ESP_LOGE(TAG, "Config is NULL");
    return;
  }

  // Post event to default event loop
  esp_event_post(APP_EVENTS, APP_EVENT_CONFIG_RECEIVED, config,
                 sizeof(app_config_t), portMAX_DELAY);

  ESP_LOGI(TAG, "Config received event posted");
}

void app_event_post_mqtt_connected(void) {
  esp_event_post(APP_EVENTS, APP_EVENT_MQTT_CONNECTED, NULL, 0, portMAX_DELAY);

  ESP_LOGI(TAG, "MQTT connected event posted");
}

void get_chip_id_string(char *out_str) {
  uint8_t mac[6];
  // Đọc địa chỉ MAC của tầng Base MAC (Wi-Fi/Bluetooth)
  esp_read_mac(mac, ESP_MAC_WIFI_STA);

  // Chuyển thành chuỗi HEX viết hoa
  snprintf(out_str, 18, "%02X.%02X.%02X.%02X.%02X.%02X", mac[0], mac[1], mac[2],
           mac[3], mac[4], mac[5]);
}

static void get_value(const char *buf, const char *key, char *out,
                      size_t out_size, char terminator) {
  out[0] = '\0';

  const char *start = strstr(buf, key);
  if (!start)
    return;

  start += strlen(key);

  const char *end = strchr(start, terminator);
  if (!end)
    return;

  size_t len = end - start;
  if (len >= out_size)
    len = out_size - 1;

  memcpy(out, start, len);
  out[len] = '\0';
}

app_config_t parse_to_config_t(uint8_t *buf) {
  app_config_t cfg = {0};

  char port_str[8] = {0};

  get_value((char *)buf, "device_name=", cfg.device_name,
            sizeof(cfg.device_name), ';');

  get_value((char *)buf, "wifi_ssid=", cfg.wifi_ssid, sizeof(cfg.wifi_ssid),
            ';');

  get_value((char *)buf, "wifi_pass=", cfg.wifi_pass, sizeof(cfg.wifi_pass),
            ';');

  get_value((char *)buf, "server_host=", cfg.server_host,
            sizeof(cfg.server_host), ';');

  get_value((char *)buf, "server_port=", port_str, sizeof(port_str), ';');

  provison_token = (char *)malloc(sizeof(char) * 130);

  get_value((char *)buf, "provision_token=", provison_token, sizeof(char) * 130,
            ';');
  ESP_LOGI(TAG, "token: %s", provison_token);

  cfg.server_port = (uint16_t)atoi(port_str);

  config_print(&cfg);

  return cfg;
}

void status_send_task(void *arg) {
  while (1) {
    mqtt_publish_status();
    vTaskDelay(pdMS_TO_TICKS(5000 * 60));
  }
}

void create_status_send_task() {
  xTaskCreatePinnedToCore(status_send_task, // Function
                          "status",         // Name
                          2048,             // Stack size (AI cần nhiều hơn)
                          nullptr,          // Parameter
                          3,                // Priority (thấp hơn stream)
                          nullptr,          // Handle
                          1                 // Core 1
  );
}