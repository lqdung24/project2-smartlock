#pragma once

#include "esp_event.h"
#include "config.h"
#include "esp_system.h"
#include "esp_timer.h"

#ifdef __cplusplus
#include <vector>
extern "C"
{
#endif

    app_config_t parse_to_config_t(uint8_t *buf);

    /* ── Custom Event Base ────────────────────────────────────── */
    ESP_EVENT_DECLARE_BASE(APP_EVENTS);

    typedef enum
    {
        APP_EVENT_CONFIG_RECEIVED = 0, /**< BLE/API received new config */
        APP_EVENT_MQTT_CONNECTED,      /**< MQTT broker connected successfully */
        APP_EVENT_ENROLL_DONE,         /**< Enrollment completed */
    } app_event_id_t;

    /**
     * @brief Initialize event loop and register handlers
     */
    void app_event_init(void);

    /**
     * @brief Post config received event
     *
     * @param config Pointer to new config
     */
    void app_event_post_config_received(app_config_t *config);

    /**
     * @brief Post MQTT connected event
     */
    void app_event_post_mqtt_connected(void);

    void app_event_post_enroll_done(uint16_t id);
    typedef void (*app_event_enroll_done_cb_t)(uint16_t id);
    void app_event_register_enroll_done(app_event_enroll_done_cb_t cb);

#ifdef __cplusplus
}

#define DL_CLIP(x, low, high) ((x) < (low)) ? (low) : (((x) > (high)) ? (high) : (x))

typedef struct
{
    int category;              /*!< category index */
    float score;               /*!< score of box */
    std::vector<int> box;      /*!< [left_up_x, left_up_y, right_down_x, right_down_y] */
    std::vector<int> keypoint; /*!< [x1, y1, x2, y2, ...] */
    void limit_box(int width, int height)
    {
        box[0] = DL_CLIP(box[0], 0, width - 1);
        box[1] = DL_CLIP(box[1], 0, height - 1);
        box[2] = DL_CLIP(box[2], 0, width - 1);
        box[3] = DL_CLIP(box[3], 0, height - 1);
    }
    void limit_keypoint(int width, int height)
    {
        for (int i = 0; i < keypoint.size(); i++)
        {
            if (i % 2 == 0)
                keypoint[i] = DL_CLIP(keypoint[i], 0, width - 1);
            else
                keypoint[i] = DL_CLIP(keypoint[i], 0, height - 1);
        }
    }
    int box_area() const { return (box[2] - box[0]) * (box[3] - box[1]); }
} face_event_t;

#endif

void get_chip_id_string(char *out_str);

void get_bluetooth_mac_string(char *out_str);

// Định nghĩa trước kiểu dữ liệu callback cho dễ nhìn
typedef void (*timeout_cb_t)(void *arg);

// Biến giữ trạng thái timer để quản lý, chống rò rỉ RAM
static esp_timer_handle_t reusable_timer_handle = NULL;

void set_timeout(uint32_t delay_ms, timeout_cb_t callback_func, void *arg);
void create_status_send_task();
