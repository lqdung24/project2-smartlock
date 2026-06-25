#pragma once

#include <stdint.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C"
{
#endif

    /**
     * @brief Application configuration structure stored in NVS
     */
    typedef struct
    {
        int configured;
        char wifi_ssid[32]; /**< WiFi SSID (max 31 chars + null) */
        char wifi_pass[64]; /**< WiFi password (max 63 chars + null) */
        char server_host[64];
        uint16_t server_port;
        char mqtt_host[64]; /**< MQTT broker host/IP */
        char mqtt_token[256];
        uint16_t mqtt_port;   /**< MQTT broker port */
        char device_name[32]; /**< Device name (max 31 chars + null) */
    } app_config_t;

    /**
     * @brief Load configuration from NVS. If not found, use defaults.
     *
     * @param[out] config Pointer to app_config_t struct to fill
     * @return ESP_OK if successful, ESP_ERR_NVS_NOT_FOUND if using defaults
     */
    esp_err_t config_load(app_config_t *config);

    /**
     * @brief Save configuration to NVS
     *
     * @param config Pointer to app_config_t struct to save
     * @return ESP_OK if successful
     */
    esp_err_t config_saving(const app_config_t *config);

    /**
     * @brief Initialize configuration with default values
     *
     * @param[out] config Pointer to app_config_t struct to initialize
     */
    void config_init_defaults(app_config_t *config);
    void config_init_defaults_hust(app_config_t *config);
    /**
     * @brief Print current configuration (debug)
     *
     * @param config Pointer to app_config_t struct
     */
    void config_print(const app_config_t *config);

    /**
     * @brief Update a string field directly in NVS
     *
     * @param key The field key name
     * @param value The value to set
     * @return ESP_OK if successful
     */
    esp_err_t config_update_str(const char *key, const char *value);

    /**
     * @brief Update a uint16_t field directly in NVS
     *
     * @param key The field key name
     * @param value The value to set
     * @return ESP_OK if successful
     */
    esp_err_t config_update_u16(const char *key, uint16_t value);

    /**
     * @brief Update an int32_t field directly in NVS
     *
     * @param key The field key name
     * @param value The value to set
     * @return ESP_OK if successful
     */
    esp_err_t config_update_i32(const char *key, int32_t value);

    /**
     * @brief Update device name in NVS
     *
     * @param device_name The device name to set
     * @return ESP_OK if successful
     */
    esp_err_t config_update_device_name(const char *device_name);

    /**
     * @brief Update WiFi SSID in NVS
     *
     * @param ssid The WiFi SSID to set
     * @return ESP_OK if successful
     */
    esp_err_t config_update_wifi_ssid(const char *ssid);

    /**
     * @brief Update WiFi password in NVS
     *
     * @param pass The WiFi password to set
     * @return ESP_OK if successful
     */
    esp_err_t config_update_wifi_pass(const char *pass);

    void config_init_panda(app_config_t *config);

#ifdef __cplusplus
}
#endif
