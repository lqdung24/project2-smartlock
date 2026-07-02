#ifndef TOUCH_CONFIG_BTN_H
#define TOUCH_CONFIG_BTN_H

#include <stdint.h>
#include "driver/touch_pad.h"
#include "driver/gpio.h" 

// Định nghĩa kiểu con trỏ hàm cho callback
typedef void (*touch_config_cb_t)(void);

// Khởi tạo thông số nút bấm
void touch_config_btn_init(gpio_num_t gpio_num);

// Đăng ký hàm sẽ chạy khi nhấn 2 lần >= 1s (chế độ cấu hình/reboot)
void touch_config_btn_set_callback(touch_config_cb_t cb);

// Đăng ký hàm sẽ chạy khi nhấn 3 lần >= 1s (chế độ đăng ký khuôn mặt local)
void touch_config_btn_set_enroll_callback(touch_config_cb_t cb);

// Chạy task giám sát ngầm
void touch_config_btn_start(void);

#endif // TOUCH_CONFIG_BTN_H