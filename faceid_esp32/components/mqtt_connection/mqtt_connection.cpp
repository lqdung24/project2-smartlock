#include "mqtt_connection.hpp"
#include "ai_handler.h"
#include "cJSON.h"
#include "esp_log.h"
#include "event.hpp"
#include "http_connect.h"
#include "json_builder.hpp"
#include "mqtt_client.h"
#include "rgb_control.hpp"
#include "storage.hpp"
#include <stdio.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

static const char *TAG = "MQTT";
esp_mqtt_client_handle_t mqtt_client;
char status_topic[50];
char control_topic[50];
char event_topic[50];
static bool s_mqtt_connected = false;

// Hàm chuyên trị bóc tách JSON từ MQTT
// cJSON *parse_mqtt_json(const char *raw_data, int data_len)
// {
//     // ========================================================
//     // BƯỚC 1: BỌC LẠI CHUỖI BẰNG KÝ TỰ '\0' (CHỐNG TRÀN RAM)
//     // ========================================================
//     char *json_string = (char *)malloc(data_len + 1);
//     if (json_string == NULL)
//     {
//         ESP_LOGE(TAG, "Hết RAM, không thể parse JSON!");
//         return nullptr;
//     }
//     // Dùng thần chú %.*s để copy đúng số lượng byte
//     snprintf(json_string, data_len + 1, "%.*s", data_len, raw_data);

//     // ========================================================
//     // BƯỚC 2: TIẾN HÀNH PARSE
//     // ========================================================
//     cJSON *root = cJSON_Parse(json_string);
//     if (root == NULL)
//     {
//         ESP_LOGE(TAG, "Dữ liệu Server gửi không phải JSON hợp lệ!");
//         free(json_string); // Lỗi cũng phải trả lại RAM
//         return nullptr;
//     }

//     free(json_string); // Xóa chuỗi đệm tự tạo

//     return root;
// }

/**
 * @brief Hàm kiểm tra khớp topic 100% (An toàn với cả dữ liệu không có \0)
 */
static bool is_topic_match(const char *received_topic, int received_len,
                           const char *target_topic) {
  int target_len = strlen(target_topic);

  // Nếu độ dài lệch nhau -> Chắc chắn không phải, cút luôn cho nhanh
  if (received_len != target_len) {
    return false;
  }

  // Nếu độ dài bằng nhau -> So sánh từng ký tự
  return strncmp(received_topic, target_topic, received_len) == 0;
}

int get_cmd(cJSON *root) {
  cJSON *cmd_item = cJSON_GetObjectItem(root, "cmd");
  if (cJSON_IsString(cmd_item) && (cmd_item->valuestring != NULL)) {
    ESP_LOGI(TAG, "Trích xuất lệnh thành công: %s", cmd_item->valuestring);
    if (strcmp(cmd_item->valuestring, "open") == 0) {
      return MQTT_OPEN;
    } else if (strcmp(cmd_item->valuestring, "regis") == 0) {
      return MQTT_REGIS_FACE;
    } else if (strcmp(cmd_item->valuestring, "ai_enable") == 0) {
      return MQTT_AI_ENABLE;
    } else if (strcmp(cmd_item->valuestring, "sync_time") == 0 ||
               strcmp(cmd_item->valuestring, "time") == 0) {
      return MQTT_SYNC_TIME;
    } else {
      return MQTT_ERR;
    }
  } else {
    ESP_LOGI(TAG, "Khong tim thay cmd");
    return MQTT_ERR;
  }
}

void mqtt_publish_enroll_done(uint32_t face_id, const char *redis_key,
                              const float *features) {
  EnrollMessage_t msg;
  memset(&msg, 0, sizeof(msg));

  msg.face_id = face_id;

  if (redis_key != NULL) {
    strncpy(msg.redis_key, redis_key, sizeof(msg.redis_key) - 1);
  }
  if (face_id == -1) {
    esp_mqtt_client_publish(mqtt_client, event_topic, (const char *)&msg,
                            sizeof(msg), 1, 0);
    return;
  }
  if (features != NULL) {
    memcpy(msg.face_features, features, sizeof(msg.face_features));
  }

  int payload_size = sizeof(msg);
  int features_size = sizeof(msg.face_features);
  ESP_LOGI(TAG,
           "Publish mqtt: face_id=%lu, features_size=%d bytes (%d floats), "
           "total_payload=%d bytes",
           face_id, features_size, features_size / 4, payload_size);
  esp_mqtt_client_publish(mqtt_client, event_topic, (const char *)&msg,
                          payload_size, 1, 0);
}

void mqtt_publish_status() {
  char *msg = NULL;
  json_build_device_status(&msg);

  if (msg != NULL) {
    ESP_LOGI(TAG, "status ping: %s", msg);
    esp_mqtt_client_publish(mqtt_client, status_topic, msg, strlen(msg), 1, 0);
    free(msg);
  } else {
    ESP_LOGE(TAG, "Lỗi: Không build được chuỗi JSON status!");
  }
}

void mqtt_request_time() {
  uint32_t req_val = 0;
  int msg_id = esp_mqtt_client_publish(
      mqtt_client, event_topic, (const char *)&req_val, sizeof(req_val), 1, 0);
  if (msg_id >= 0) {
    ESP_LOGI(TAG, "Sent time request (uint32_t=0) to %s", event_topic);
  } else {
    ESP_LOGE(TAG, "Failed to publish time request to %s", event_topic);
  }
}

void mqtt_publish_unlock_event(int32_t status, uint32_t timestamp) {
  UnlockEventMessage_t msg;
  msg.event_type = -2;
  msg.status = status;
  msg.timestamp = timestamp;
  
  int msg_id = esp_mqtt_client_publish(
      mqtt_client, event_topic, (const char *)&msg, sizeof(msg), 1, 0);
  if (msg_id >= 0) {
    ESP_LOGI(TAG, "Published unlock event to %s: status=%d, timestamp=%lu", event_topic, status, (unsigned long)timestamp);
  } else {
    ESP_LOGE(TAG, "Failed to publish unlock event to %s", event_topic);
  }
}

bool mqtt_is_connected() {
  return s_mqtt_connected;
}

void mqtt_send_offline_logs() {
  FILE* f = fopen("/face/offline_log.bin", "r");
  if (f == NULL) {
    ESP_LOGI(TAG, "Không có tệp log offline để gửi. Gửi yêu cầu time sync cơ bản.");
    mqtt_request_time();
    return;
  }

  fseek(f, 0, SEEK_END);
  long file_size = ftell(f);
  fseek(f, 0, SEEK_SET);

  int entry_size = sizeof(OfflineLogEntry);
  int log_count = file_size / entry_size;

  ESP_LOGI(TAG, "Tìm thấy %d log offline trong file", log_count);

  OfflineLogEntry* entries = NULL;
  if (log_count > 0) {
    entries = (OfflineLogEntry*)malloc(file_size);
    if (entries != NULL) {
      fread(entries, entry_size, log_count, f);
    }
  }
  fclose(f);

  time_t esp_now;
  time(&esp_now);

  int payload_size = 4 + 4 + 4 + (log_count * entry_size);
  uint8_t* payload = (uint8_t*)malloc(payload_size);
  if (payload != NULL) {
    int32_t event_type = -3;
    uint32_t esp_time_val = (uint32_t)esp_now;
    uint32_t count_val = (uint32_t)log_count;

    memcpy(payload, &event_type, 4);
    memcpy(payload + 4, &esp_time_val, 4);
    memcpy(payload + 8, &count_val, 4);
    if (log_count > 0 && entries != NULL) {
      memcpy(payload + 12, entries, log_count * entry_size);
    }

    int msg_id = esp_mqtt_client_publish(
        mqtt_client, event_topic, (const char*)payload, payload_size, 1, 0);
    if (msg_id >= 0) {
      ESP_LOGI(TAG, "Đã gửi %d log offline + thời gian ESP (%lu) lên %s",
               log_count, (unsigned long)esp_now, event_topic);
      
      unlink("/face/offline_log.bin");
      FILE* new_f = fopen("/face/offline_log.bin", "w");
      if (new_f != NULL) {
        fclose(new_f);
      }
    } else {
      ESP_LOGE(TAG, "Gửi log offline thất bại!");
    }
    free(payload);
  }

  if (entries != NULL) {
    free(entries);
  }
}

static void enroll_done_cb(uint16_t id) {
  ESP_LOGI(TAG, "Enroll done callback id=%d", id);
}

void mqtt_event_data_callback(esp_mqtt_event_handle_t event) {
  if (is_topic_match(event->topic, event->topic_len, control_topic)) {
    cJSON *root = parse_mqtt_json(event->data, event->data_len);
    switch (get_cmd(root)) {
    case MQTT_OPEN:
      set_green();
      set_timeout(5000, turn_off, NULL);
      break;

    case MQTT_REGIS_FACE: {
      cJSON *url_item = cJSON_GetObjectItem(root, "img_url");
      cJSON *user_id_item = cJSON_GetObjectItem(root, "user_id");
      cJSON *redis_key_item = cJSON_GetObjectItem(root, "redis_key");

      // Sửa user_id_valid thành IsNumber
      bool url_valid =
          cJSON_IsString(url_item) && url_item->valuestring != NULL;
      bool user_id_valid = cJSON_IsNumber(user_id_item);
      bool redis_key_valid =
          cJSON_IsString(redis_key_item) && redis_key_item->valuestring != NULL;

      if (url_valid && user_id_valid && redis_key_valid) {
        const char *url = url_item->valuestring;
        int user_id = user_id_item->valueint; // Lấy giá trị kiểu int
        const char *redis_key = redis_key_item->valuestring;

        ESP_LOGI(TAG, "REGIS_FACE - Image URL: %s", url);
        ESP_LOGI(TAG, "REGIS_FACE - user_id: %d", user_id);
        ESP_LOGI(TAG, "REGIS_FACE - redis_key: %s", redis_key);

        // Download image từ URL
        uint8_t *jpeg_buffer = NULL;
        size_t jpeg_size = 0;

        if (!http_download_image(url, &jpeg_buffer, &jpeg_size)) {
          ESP_LOGE(TAG, "REGIS_FACE - Failed to download image from %s", url);
          break;
        }

        // Tạo context với dữ liệu ảnh JPEG
        EnrollCtx *ctx = new EnrollCtx();
        ctx->user_id = user_id;
        ctx->imgs = jpeg_buffer; // Con trỏ ảnh JPEG (uint8_t*)
        ctx->len = jpeg_size;    // Kích thước ảnh (bytes)
        memset(ctx->redis_key, 0, sizeof(ctx->redis_key));
        strncpy(ctx->redis_key, redis_key, sizeof(ctx->redis_key) - 1);

        // Tạo task để xử lý enrollment
        if (xTaskCreate(enroll_task,   // Hàm task
                        "enroll_task", // Tên task
                        8192,          // Stack size
                        (void *)ctx,   // Context (argument)
                        5,             // Priority
                        NULL           // Task handle
                        ) != pdPASS) {
          ESP_LOGE(TAG, "REGIS_FACE - Failed to create enroll task");
          free(jpeg_buffer);
          delete ctx;
        }
      } else {
        ESP_LOGW(
            TAG,
            "REGIS_FACE - Invalid payload. img_url=%d user_id=%d redis_key=%d",
            url_valid, user_id_valid, redis_key_valid);
      }
      break;
    }

    case MQTT_DELETE_FACE: {

      break;
    }
    case MQTT_AI_ENABLE: {
      cJSON *enable_item = cJSON_GetObjectItem(root, "status");
      ai_set_enable(enable_item->valueint);
      break;
    }
    case MQTT_SYNC_TIME: {
      cJSON *time_item = cJSON_GetObjectItem(root, "timestamp");
      if (cJSON_IsNumber(time_item)) {
        uint32_t timestamp = time_item->valueint;
        struct timeval tv;
        tv.tv_sec = timestamp;
        tv.tv_usec = 0;
        settimeofday(&tv, NULL);

        // Set timezone (Vietnam GMT+7)
        setenv("TZ", "ICT-7", 1);
        tzset();

        time_t now;
        struct tm timeinfo;
        time(&now);
        localtime_r(&now, &timeinfo);
        char time_str[64];
        strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", &timeinfo);
        ESP_LOGI("TIME_SYNC", "Đã đồng bộ thời gian thành công: %s", time_str);
      } else {
        ESP_LOGW("TIME_SYNC", "Không tìm thấy timestamp hợp lệ");
      }
      break;
    }
    case MQTT_ERR:
      ESP_LOGI(TAG, "Error");
      break;
    default:
      ESP_LOGI(TAG, "Command not found: %.*s", event->data_len, event->data);
    }
  }
}

// Chuẩn cấu hình tham số C++
static void mqtt_event_handler(void *handler_args, esp_event_base_t base,
                               int32_t event_id, void *event_data) {
  // Chuẩn ép kiểu tường minh trong C++
  esp_mqtt_event_handle_t event = (esp_mqtt_event_handle_t)event_data;
  esp_mqtt_client_handle_t client = event->client;

  switch ((esp_mqtt_event_id_t)event_id) {
  case MQTT_EVENT_CONNECTED:
    s_mqtt_connected = true;
    ESP_LOGI(TAG, "MQTT_EVENT_CONNECTED: Đã kết nối Broker thành công!");

    app_config_t cfg;
    config_load(&cfg);
    if (!cfg.configured) {
      app_event_post_mqtt_connected();
    }
    // Post app event when MQTT registration/connection succeeds

    // SỬA TẠI ĐÂY: Đăng ký nhận lệnh từ topic động chứa MAC ID của chính nó
    esp_mqtt_client_subscribe(client, control_topic, 0);
    // esp_mqtt_client_subscribe(client, status_topic, 0);
    // esp_mqtt_client_subscribe(client, event_topic, 0);

    ESP_LOGI(TAG, "Đã đăng ký lắng nghe tại phòng chat: %s, %s, %s",
             control_topic, status_topic, event_topic);

    // Gửi thời gian ESP32 hiện tại và danh sách offline logs lên server
    mqtt_send_offline_logs();
    break;

  case MQTT_EVENT_DISCONNECTED:
    s_mqtt_connected = false;
    ESP_LOGI(TAG, "MQTT_EVENT_DISCONNECTED: Mất kết nối Broker!");
    break;

  case MQTT_EVENT_DATA:
    ESP_LOGI(TAG, "MQTT_EVENT_DATA: Nhận được dữ liệu từ Server!");
    // In debug ra màn hình máy tính để kiểm tra
    printf("TOPIC=%.*s\r\n", event->topic_len, event->topic);
    printf("DATA=%.*s\r\n", event->data_len, event->data);

    mqtt_event_data_callback(event);

    break;

  case MQTT_EVENT_ERROR:
    ESP_LOGE(TAG, "MQTT_EVENT_ERROR: Có lỗi xảy ra");
    break;

  default:
    break;
  }
}

void mqtt_app_start(char *server_url, uint16_t port, char *mqtt_token) {
  char chip_id[18];
  get_bluetooth_mac_string(chip_id); // Hàm lấy MAC ID ở các câu trước

  // Khởi tạo tên topic động dựa trên ID phần cứng
  snprintf(status_topic, sizeof(status_topic), "esp32/%s/status", chip_id);
  snprintf(control_topic, sizeof(control_topic), "esp32/%s/control", chip_id);
  snprintf(event_topic, sizeof(event_topic), "esp32/%s/event", chip_id);

  esp_mqtt_client_config_t mqtt_cfg = {};
  char buf[256];
  snprintf(buf, sizeof(buf), "mqtt://%s:%u", server_url, port);
  mqtt_cfg.broker.address.uri = buf;
  // 3. TĂNG BUFFER SIZE để sửa lỗi "Subscribe message cannot be created"
  // Đúng chuẩn ESP-IDF v5.x: nó nằm trong struct buffer_t (tên biến là buffer)
  mqtt_cfg.buffer.size = 1024 * 4;     // Bộ đệm nhận dữ liệu
  mqtt_cfg.buffer.out_size = 1024 * 4; // Bộ đệm gửi dữ liệu
  // QUY ĐỊNH BẢO MẬT ĐỘNG:
  mqtt_cfg.credentials.username =
      chip_id; // Username gửi lên luôn là Chip ID của chính nó
  mqtt_cfg.credentials.authentication.password = mqtt_token;

  mqtt_client = esp_mqtt_client_init(&mqtt_cfg);
  esp_mqtt_client_register_event(mqtt_client, MQTT_EVENT_ANY,
                                 mqtt_event_handler, NULL);
  esp_mqtt_client_start(mqtt_client);
}
