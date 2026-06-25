idf_component_register(SRCS "http_connect.c"
                    INCLUDE_DIRS "."
                    REQUIRES esp_http_client esp_netif common)
