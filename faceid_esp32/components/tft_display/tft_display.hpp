#pragma once
#include <cstdint>

// Định nghĩa cấu hình chân (Mày có thể sửa lại cho hợp mạch của mày)
#define LCD_HOST SPI2_HOST
#define PIN_NUM_SCLK 47
#define PIN_NUM_MOSI 21
#define PIN_NUM_MISO -1
#define PIN_NUM_LCD_DC 20
#define PIN_NUM_LCD_RST 19
#define PIN_NUM_LCD_CS 14

// Khởi tạo màn hình TFT
void tft_display_init(void);

// Đẩy khung hình RGB565 từ Camera lên TFT
void tft_display_show_frame(uint16_t *cam_buf, int width, int height);

void tft_test_red();