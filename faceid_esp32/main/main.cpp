/**
 * @file main.cpp
 * @brief ESP32-S3 Smart Lock – Main Application
 *
 * Luồng khởi tạo:
 *   1. NVS Flash init
 *   2. WiFi STA init → đợi có IP
 *   3. Camera OV3660 init
 *   4. AI face detection init
 *   5. WebSocket init → connect đến server
 *   6. Tạo stream_task (Core 0) và ai_task (Core 1)
 */

#include <cstring>
#include <atomic>
#include <vector>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nvs_flash.h"
#include "esp_log.h"

#include "wifi_handler.h"
#include "camera_handler.h"
#include "websocket_handler.h"
#include "ai_handler.h"
#include "dl_detect_define.hpp"
#include "event.hpp"

#include "app_manager.hpp"

/* ── Entry point ─────────────────────────────────────────── */
extern "C" void app_main(void)
{
    app_event_init();

    app_manager_start();
}
