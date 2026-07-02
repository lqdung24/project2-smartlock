// #pragma once

// #ifdef __cplusplus
// extern "C"
// {
// #endif

void configure_led(void);
// Callback signature compatible with timeout_cb_t (void *arg)
void turn_off(void *arg);
void set_red(void);
void set_green(void);
void set_blue(void);

void set_yellow();

// Nhấp nháy vàng (chế độ chờ đăng ký khuôn mặt)
void blink_yellow_start(void);
void blink_yellow_stop(void);
bool blink_yellow_is_running(void);

// #ifdef __cplusplus
// }
// #endif
