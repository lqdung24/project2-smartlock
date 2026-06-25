idf_component_register(
    SRCS "mqtt_connection.cpp"
    INCLUDE_DIRS "."
    REQUIRES
        mqtt
        common
        json_builder
        json
        rgb_control
        ai_handler
)
