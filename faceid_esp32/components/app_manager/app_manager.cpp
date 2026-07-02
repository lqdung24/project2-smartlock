#include "config.h"
#include "nvs_flash.h"
#include "ble_connect.h"
#include "esp_log.h"
#include <stdio.h>
#include <time.h>
#include <new>
#include <list>
#include "esp_system.h"
#include "esp_heap_caps.h"
#include "wifi_handler.h"
#include "mqtt_connection.hpp"
#include "camera_handler.h"
#include "img_converters.h"
#include "ai_handler.h"
#include "driver/touch_pad.h"
#include "touch_sensor.hpp"
#include "rgb_control.hpp"
#include "storage.hpp"
#include "tft_display.hpp"
#include "driver/gpio.h"

static const char *TAG = "app_manager";


/* ── AI Task: face detection (chỉ khi enabled) ──────────── */
static void ai_task(void *arg)
{
    ESP_LOGI(TAG, "ai_task running on core %d", xPortGetCoreID());

    while (true) { 
        if (!ai_is_enable()) {
            vTaskDelay(pdMS_TO_TICKS(500));
            continue;
        }

        // vTaskDelay(pdMS_TO_TICKS(1000));
        
        camera_fb_t *fb = camera_capture();

        if (fb) {
            std::__cxx11::list<dl::detect::result_t> result;
            int face = ai_detect_faces(fb, result);
            // tft_display_show_frame((uint16_t *)fb->buf, fb->width, fb->height);
            camera_release(fb);
        }else{
            ESP_LOGI(TAG, "Cam fb not found!");
        }

        /* AI chạy chậm hơn stream, ~5 FPS */
        vTaskDelay(pdMS_TO_TICKS(200));
    }
}

static void reboot_to_ops_mode(){
    app_config_t cfg;
    config_load(&cfg);
    if(cfg.configured == 0){
        config_update_i32("configured", 1);
    }else{
        config_update_i32("configured", 0);
    }
    
    esp_restart();
}

/* ── Local Enroll Mode (nhấn nút 3 lần) ──────────────────── */
#define LOCAL_ENROLL_TIMEOUT_MS 60000  // 60 giây chờ

static void local_enroll_task(void *arg)
{
    ESP_LOGI(TAG, "=== Bắt đầu chế độ đăng ký khuôn mặt local ===");

    // Chiếm mutex ngay — block hoàn toàn ai_task trong suốt quá trình chờ detect
    ESP_LOGI(TAG, "Waiting for ai_mutex...");
    xSemaphoreTake(ai_mutex, portMAX_DELAY);
    ESP_LOGI(TAG, "ai_mutex acquired, ai_task blocked");

    // Nhấp nháy vàng trong khi chờ detect khuôn mặt
    blink_yellow_start();

    uint32_t start_ms = xTaskGetTickCount() * portTICK_PERIOD_MS;
    bool done = false;

    // --- Chờ detect khuôn mặt (tối đa 60s) ---
    while (!done) {
        uint32_t now_ms = xTaskGetTickCount() * portTICK_PERIOD_MS;
        if ((now_ms - start_ms) >= LOCAL_ENROLL_TIMEOUT_MS) {
            ESP_LOGW(TAG, "Hết 60s, không đăng ký được khuôn mặt");
            break;
        }

        camera_fb_t *fb = camera_capture();
        if (!fb) {
            vTaskDelay(pdMS_TO_TICKS(200));
            continue;
        }

        // Detect (ai_mutex đang được giữ, ai_detect_faces_raw không cần take lại)
        std::__cxx11::list<dl::detect::result_t> detect_result;
        int face_count = ai_detect_faces_raw(fb, detect_result);

        if (face_count > 0) {
            // Phát hiện khuôn mặt → đèn xanh biển
            blink_yellow_stop();
            vTaskDelay(pdMS_TO_TICKS(100));
            set_blue();
            ESP_LOGI(TAG, "Phát hiện khuôn mặt, convert RGB và enroll...");

            // Convert frame → RGB888 (PSRAM) để truyền cho enroll_task
            int w = fb->width;
            int h = fb->height;
            size_t rgb_len = (size_t)w * h * 3;

            uint8_t *rgb_buf = (uint8_t *)heap_caps_malloc(
                rgb_len, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);

            bool ok = (rgb_buf != NULL) &&
                      fmt2rgb888(fb->buf, fb->len, fb->format, rgb_buf);

            camera_release(fb);
            fb = NULL;

            if (ok) {
                ESP_LOGI(TAG, "RGB888 buffer ready (%dx%d, %u bytes)",
                         w, h, (unsigned)rgb_len);

                EnrollCtx *ctx = new (std::nothrow) EnrollCtx();
                if (ctx) {
                    ctx->imgs          = NULL;
                    ctx->len           = 0;
                    ctx->local_enroll  = true;
                    ctx->rgb_buf       = rgb_buf;
                    ctx->rgb_width     = w;
                    ctx->rgb_height    = h;
                    ctx->face_id       = 9001;
                    ctx->user_id       = 9001;
                    snprintf(ctx->label, sizeof(ctx->label), "LocalUser");

                    // Nhả mutex TRƯỚC khi spawn enroll_task
                    // enroll_task sẽ tự take mutex của nó
                    xSemaphoreGive(ai_mutex);
                    ESP_LOGI(TAG, "ai_mutex released, spawning enroll_task");

                    if (xTaskCreate(enroll_task, "enroll_local", 16000,
                                    ctx, 3, NULL) != pdPASS) {
                        ESP_LOGE(TAG, "Không tạo được enroll_task");
                        heap_caps_free(rgb_buf);
                        delete ctx;
                    } else {
                        done = true;
                    }
                } else {
                    heap_caps_free(rgb_buf);
                    // Nếu alloc ctx fail, give mutex và retry
                    xSemaphoreGive(ai_mutex);
                    xSemaphoreTake(ai_mutex, portMAX_DELAY);
                }
            } else {
                if (rgb_buf) heap_caps_free(rgb_buf);
                ESP_LOGW(TAG, "fmt2rgb888 failed, retry...");
                vTaskDelay(pdMS_TO_TICKS(200));
            }
        } else {
            camera_release(fb);
            fb = NULL;
            if (!blink_yellow_is_running()) blink_yellow_start();
            vTaskDelay(pdMS_TO_TICKS(200));
        }
    }

    // --- Kết thúc local_enroll_task ---
    blink_yellow_stop();

    if (!done) {
        // Timeout: nhả mutex trước khi exit
        xSemaphoreGive(ai_mutex);
        ESP_LOGI(TAG, "ai_mutex released (timeout)");
        ESP_LOGW(TAG, "=== Đăng ký khuôn mặt local thất bại (timeout) ===");
        set_red();
        vTaskDelay(pdMS_TO_TICKS(3000));
        turn_off(NULL);
    }

    vTaskDelete(NULL);
}

static void trigger_local_enroll(void)
{
    ESP_LOGI(TAG, "Nút bấm 3 lần: Kích hoạt chế độ đăng ký khuôn mặt local");
    xTaskCreate(local_enroll_task, "local_enroll", 16000, NULL, 3, NULL);
}


void device_reset(void)
{
    // ESP_LOGI(TAG, "Device reset initiated: deleting database files and resetting NVS configuration...");

    // // 1. Danh sách các file cần xóa trong LittleFS
    // const char *files_to_delete[] = {
    //     "/face/face_id.bin",
    //     "/face/user_map.bin",
    //     "/face/face_map.bin",
    //     "/face/users.csv",
    //     "/face/offline_log.bin"
    // };

    // for (size_t i = 0; i < sizeof(files_to_delete) / sizeof(files_to_delete[0]); i++) {
    //     if (remove(files_to_delete[i]) == 0) {
    //         ESP_LOGI(TAG, "Deleted file: %s", files_to_delete[i]);
    //     } else {
    //         ESP_LOGW(TAG, "File does not exist or failed to delete: %s", files_to_delete[i]);
    //     }
    // }
}

static void enter_config_mode()
{
    // ble_provisioning_start();
    ble_server_init();
}



static void enter_running_mode(app_config_t cfg)
{

    ESP_ERROR_CHECK(wifi_init_sta(cfg.wifi_ssid, cfg.wifi_pass));
    wifi_wait_connected();

    mqtt_app_start(cfg.mqtt_host, cfg.mqtt_port, cfg.mqtt_token);
    configure_led();   

    ESP_ERROR_CHECK(camera_init());

    init_littlefs();
    
    create_status_send_task();

    mqtt_request_time();

    ESP_ERROR_CHECK(ai_init());
    // tft_test_red();
    ESP_LOGI(TAG, "Init ok");
    ai_set_enable(true);

    xTaskCreatePinnedToCore(
        ai_task,            // Function
        "ai_task",          // Name
        15000,               // Stack size (AI cần nhiều hơn)
        nullptr,            // Parameter
        3,                  // Priority (thấp hơn stream)
        nullptr,            // Handle
        1                   // Core 1
    );
}


void app_manager_start(void)
{

    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND)
    {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);
    app_config_t cfg;
    // config_init_defaults(&cfg);
    // config_init_defaults_hust(&cfg);
    // config_init_panda(&cfg);
    // config_saving(&cfg);

    config_load(&cfg);
    config_print(&cfg);

    tft_display_init();

    touch_config_btn_init(GPIO_NUM_14);
    
    // 2. Trỏ callback về hàm xử lý 2 lần bấm >= 5s (reboot/config)
    touch_config_btn_set_callback(reboot_to_ops_mode);
    
    // 3. Trỏ enroll callback về hàm xử lý 3 lần bấm >= 1s (local enroll)
    touch_config_btn_set_enroll_callback(trigger_local_enroll);
    
    // 4. Chạy task giám sát
    touch_config_btn_start();

    if (!cfg.configured)
    {
        ESP_LOGI(TAG, "Enter configure mode");
        enter_config_mode();
    }
    else
    {
        // enter_config_mode(cfg);
        ESP_LOGI(TAG, "Enter running mode");
        
        // app_event_register_enroll_done();
        enter_running_mode(cfg);
    }
}
