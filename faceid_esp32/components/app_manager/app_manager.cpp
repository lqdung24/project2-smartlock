#include "config.h"
#include "nvs_flash.h"
#include "ble_connect.h"
#include "esp_log.h"
#include "esp_system.h"
#include "wifi_handler.h"
#include "mqtt_connection.hpp"
#include "camera_handler.h"
#include "ai_handler.h"
#include "driver/touch_pad.h"
#include "touch_sensor.hpp"
#include "rgb_control.hpp"
#include "storage.hpp"
#include "tft_display.hpp"

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
            // /* Gửi kết quả detect về server */
            // if (face > 0 && websocket_is_connected()) {
            //     char *json;
            //     // json_build_faces_event(result, &json);

            //     // websocket_send_text(json);

            //     free(json);
            // }
            // ESP_LOGI(TAG, "Cam fb found!");
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
    config_init_panda(&cfg);
    config_saving(&cfg);

    config_load(&cfg);
    config_print(&cfg);

    tft_display_init();

    touch_config_btn_init(TOUCH_PAD_NUM14, 30000);
    
    // 2. Trỏ callback về hàm xử lý
    touch_config_btn_set_callback(reboot_to_ops_mode);
    
    // 3. Chạy task giám sát
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
