idf_component_register(SRCS "app_manager.cpp"
    INCLUDE_DIRS "."
    REQUIRES nvs_flash 
                bt 
                common 
                ble_connect
                mqtt_connection
                wifi_handler
                camera_handler
                ai_handler
                driver
                touch_sensor
                rgb_control
                storage
                tft_display
)