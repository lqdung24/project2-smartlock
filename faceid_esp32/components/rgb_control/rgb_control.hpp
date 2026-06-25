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

// #ifdef __cplusplus
// }
// #endif
