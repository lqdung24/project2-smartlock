#ifndef TOUCH_CONFIG_BTN_H
#define TOUCH_CONFIG_BTN_H

#include <stdint.h>
#include "driver/touch_pad.h"

// Định nghĩa kiểu con trỏ hàm cho callback
typedef void (*touch_config_cb_t)(void);

// Khởi tạo thông số nút bấm
void touch_config_btn_init(touch_pad_t pad_num, uint32_t threshold);

// Đăng ký hàm sẽ chạy khi thỏa mãn điều kiện (dí 2 lần)
void touch_config_btn_set_callback(touch_config_cb_t cb);

// Chạy task giám sát ngầm
void touch_config_btn_start(void);

#endif // TOUCH_CONFIG_BTN_H