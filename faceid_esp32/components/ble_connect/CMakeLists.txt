idf_component_register(SRCS "ble_connect.c"
                    INCLUDE_DIRS "."
                    REQUIRES nvs_flash bt common)