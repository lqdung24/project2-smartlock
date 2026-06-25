#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "led_strip.h"
#include "esp_log.h"

static const char *TAG = "RGB_LED";

// Định nghĩa chân và số lượng LED
#define BLINK_GPIO 48
#define LED_NUMBERS 1

// Khai báo biến handle của dải LED
static led_strip_handle_t led_strip;
void configure_led(void)
{
    ESP_LOGI(TAG, "Đang khởi tạo LED RGB WS2812...");

    /* 1. Cấu hình cơ bản (Chuẩn C++) */
    led_strip_config_t strip_config = {}; // Khởi tạo rỗng toàn bộ vùng nhớ
    strip_config.strip_gpio_num = BLINK_GPIO;
    strip_config.max_leds = LED_NUMBERS;
    strip_config.led_model = LED_MODEL_WS2812;

    // strip_config.led_pixel_format = LED_PIXEL_FORMAT_GRB; // <-- Đã xóa dòng này vì bản thư viện của m tự mặc định là GRB rồi

    strip_config.flags.invert_out = false; // Gán lẻ như này thì C++ mới chịu

    /* 2. Cấu hình bộ RMT */
    led_strip_rmt_config_t rmt_config = {};
    rmt_config.resolution_hz = 10 * 1000 * 1000; // 10MHz
    rmt_config.flags.with_dma = false;

    // 3. Tạo object LED
    ESP_ERROR_CHECK(led_strip_new_rmt_device(&strip_config, &rmt_config, &led_strip));

    // Tắt LED lúc mới khởi động
    led_strip_clear(led_strip);
}

void turn_off(void *arg)
{
    (void)arg; // unused when called as timeout callback
    led_strip_clear(led_strip);
}

void set_red()
{
    // ESP_LOGI(TAG, "Màu Đỏ");
    led_strip_set_pixel(led_strip, 0, 25, 0, 0);
    led_strip_refresh(led_strip);
}

void set_green()
{
    // ESP_LOGI(TAG, "Màu Xanh Lá");
    led_strip_set_pixel(led_strip, 0, 0, 25, 0);
    led_strip_refresh(led_strip);
}

void set_blue()
{
    // Bật màu XANH BIỂN (Red: 0, Green: 0, Blue: 25)
    // ESP_LOGI(TAG, "Màu Xanh Biển");
    led_strip_set_pixel(led_strip, 0, 0, 0, 25);
    led_strip_refresh(led_strip);
}
