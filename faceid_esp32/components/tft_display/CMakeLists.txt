idf_component_register(
    SRCS "tft_display.cpp"
    INCLUDE_DIRS "."
    REQUIRES
        spiffs
        log
)
