#include "touch_sensor.hpp"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "TOUCH_BTN";

// Biến static để lưu trạng thái cục bộ trong file này
static touch_pad_t g_pad_num;
static uint32_t g_threshold;
static touch_config_cb_t g_callback = NULL;

#define MIN_PRESS_TIME_MS 1000
#define TIMEOUT_RESET_MS 5000

// Hàm nội bộ đọc cảm biến
static bool is_touched() {
  uint32_t touch_value = 0;
  touch_pad_read_raw_data(g_pad_num, &touch_value);
  // ESP_LOGI(TAG, "touch: %d",touch_value);
  return (touch_value > g_threshold);
}

// Task chạy ngầm của FreeRTOS
static void touch_button_task(void *pvParameter) {
  touch_pad_init();
  touch_pad_config(g_pad_num);
  touch_pad_fsm_start();

  int valid_press_count = 0;
  uint32_t press_start_time = 0;
  uint32_t last_release_time = 0;
  bool is_pressing = false;

  while (1) {
    bool current_state = is_touched();
    uint32_t now = xTaskGetTickCount() * portTICK_PERIOD_MS;

    if (current_state && !is_pressing) {
      is_pressing = true;
      press_start_time = now;
    } else if (!current_state && is_pressing) {
      is_pressing = false;
      uint32_t duration = now - press_start_time;

      if (duration >= MIN_PRESS_TIME_MS) {
        valid_press_count++;
        ESP_LOGI(TAG, "Đã giữ >= 2s. Lần: %d", valid_press_count);

        if (valid_press_count == 2) {
          // Gọi callback nếu đã được đăng ký
          if (g_callback != NULL) {
            g_callback();
          }
          valid_press_count = 0;
        }
      }
      last_release_time = now;
    }

    if (!is_pressing && valid_press_count == 1 &&
        (now - last_release_time > TIMEOUT_RESET_MS)) {
      valid_press_count = 0;
    }

    vTaskDelay(pdMS_TO_TICKS(100));
  }
}

// Các hàm API public để gọi từ main
void touch_config_btn_init(touch_pad_t pad_num, uint32_t threshold) {
  g_pad_num = pad_num;
  g_threshold = threshold;
}

void touch_config_btn_set_callback(touch_config_cb_t cb) { g_callback = cb; }

void touch_config_btn_start(void) {
  // Không cần truyền trick con trỏ nữa, ném NULL thẳng vào
  xTaskCreate(touch_button_task, "touch_task", 4096, NULL, 5, NULL);
}