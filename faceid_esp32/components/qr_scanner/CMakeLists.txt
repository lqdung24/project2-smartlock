idf_component_register(
    SRCS "qr_scanner.cpp"
    INCLUDE_DIRS "."
    REQUIRES
        esp32-camera quirc camera_handler
)