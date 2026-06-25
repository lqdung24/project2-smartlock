idf_component_register(
    INCLUDE_DIRS "include"
    SRCS "config.c" "event.cpp"
    REQUIRES
        nvs_flash
        esp_event
        wifi_handler
        http_connect
        mqtt_connection
)
