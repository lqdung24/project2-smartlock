#include "touch_sensor.hpp"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "TOUCH_BTN";

static touch_config_cb_t g_callback = NULL;
static touch_config_cb_t g_enroll_callback = NULL;

// Ngưỡng thời gian nhấn
#define SHORT_PRESS_MS  1000   // >= 1s: tính vào chuỗi enroll
#define LONG_PRESS_MS   5000   // >= 5s: tính vào chuỗi config
#define TIMEOUT_RESET_MS 15000 // Không nhấn thêm trong 15s → reset bộ đếm

static gpio_num_t g_gpio_num;

// Hàm nội bộ đọc trạng thái GPIO
static bool is_touched() {
  return (gpio_get_level(g_gpio_num) == 1);
}

// Task chạy ngầm của FreeRTOS
static void touch_button_task(void *pvParameter) {
  gpio_config_t io_conf = {
      .pin_bit_mask = (1ULL << g_gpio_num),
      .mode = GPIO_MODE_INPUT,
      .pull_up_en = GPIO_PULLUP_DISABLE,
      .pull_down_en = GPIO_PULLDOWN_ENABLE,
      .intr_type = GPIO_INTR_DISABLE
  };
  gpio_config(&io_conf);

  int valid_press_count = 0; // đếm số lần >= 1s (dùng cho enroll, 3 lần)
  int long_press_count  = 0; // đếm số lần >= 5s (dùng cho config, 2 lần)
  uint32_t press_start_time = 0;
  uint32_t last_release_time = 0;
  bool is_pressing = false;

  while (1) {
    bool current_state = is_touched();
    uint32_t now = xTaskGetTickCount() * portTICK_PERIOD_MS;

    if (current_state && !is_pressing) {
      // Phát hiện nhấn xuống
      is_pressing = true;
      press_start_time = now;

    } else if (!current_state && is_pressing) {
      // Phát hiện nhả ra
      is_pressing = false;
      uint32_t duration = now - press_start_time;

      if (duration >= LONG_PRESS_MS) {
        // ── Nhấn dài >= 5s ──────────────────────────────────────
        valid_press_count++;
        long_press_count++;
        ESP_LOGI(TAG, "LONG press (%.1fs). valid=%d, long=%d",
                 duration / 1000.0f, valid_press_count, long_press_count);

        if (long_press_count >= 2) {
          // 2 lần >= 5s → config mode
          ESP_LOGI(TAG, ">>> Trigger CONFIG (2x long-press)");
          if (g_callback != NULL) g_callback();
          valid_press_count = 0;
          long_press_count  = 0;
        } else if (valid_press_count >= 3) {
          // Đủ 3 lần hợp lệ trước khi đủ 2 lần dài → enroll
          ESP_LOGI(TAG, ">>> Trigger ENROLL (3x valid-press)");
          if (g_enroll_callback != NULL) g_enroll_callback();
          valid_press_count = 0;
          long_press_count  = 0;
        }

      } else if (duration >= SHORT_PRESS_MS) {
        // ── Nhấn ngắn >= 1s (và < 5s) ──────────────────────────
        valid_press_count++;
        ESP_LOGI(TAG, "SHORT press (%.1fs). valid=%d, long=%d",
                 duration / 1000.0f, valid_press_count, long_press_count);

        if (valid_press_count >= 3) {
          // 3 lần hợp lệ → enroll mode
          ESP_LOGI(TAG, ">>> Trigger ENROLL (3x valid-press)");
          if (g_enroll_callback != NULL) g_enroll_callback();
          valid_press_count = 0;
          long_press_count  = 0;
        }

      } else {
        ESP_LOGD(TAG, "Press too short (%ums), ignored", (unsigned)duration);
      }

      last_release_time = now;
    }

    // Timeout: nếu không nhấn thêm trong TIMEOUT_RESET_MS → reset bộ đếm
    if (!is_pressing && valid_press_count > 0 &&
        (now - last_release_time > TIMEOUT_RESET_MS)) {
      ESP_LOGI(TAG, "Timeout reset (valid=%d, long=%d)", valid_press_count, long_press_count);
      valid_press_count = 0;
      long_press_count  = 0;
    }

    vTaskDelay(pdMS_TO_TICKS(100));
  }
}

// Các hàm API public
void touch_config_btn_init(gpio_num_t gpio_num) {
  g_gpio_num = gpio_num;
}

void touch_config_btn_set_callback(touch_config_cb_t cb) { g_callback = cb; }

void touch_config_btn_set_enroll_callback(touch_config_cb_t cb) { g_enroll_callback = cb; }

void touch_config_btn_start(void) {
  xTaskCreate(touch_button_task, "touch_task", 4096, NULL, 5, NULL);
}