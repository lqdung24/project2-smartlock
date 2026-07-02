#include "config.h"
#include "nvs_flash.h"
#include "nvs.h"
#include "esp_log.h"
#include <string.h>

static const char *TAG = "config";
static const char *NVS_NAMESPACE = "app_config";


void config_init_defaults_hust(app_config_t *config)
{
    if (config == NULL)
        return;

    config->configured = 1;

    strncpy(config->wifi_ssid, "Hust_B1", sizeof(config->wifi_ssid) - 1);
    config->wifi_ssid[sizeof(config->wifi_ssid) - 1] = '\0';

    strncpy(config->wifi_pass, "", sizeof(config->wifi_pass) - 1);
    config->wifi_pass[sizeof(config->wifi_pass) - 1] = '\0';

    strncpy(config->mqtt_host, "192.168.128.115", sizeof(config->mqtt_host) - 1);
    config->mqtt_host[sizeof(config->mqtt_host) - 1] = '\0';

    strncpy(config->mqtt_token, "0723635463ba45b139ba9ca4dac002cbc9473d66381719b530edf63cb322522a720171e2bae44fcc9703ce769e32ec9839f6cbf19193be6f7e215af25f4e2b5f", sizeof(config->mqtt_token) - 1);
    config->mqtt_token[sizeof(config->mqtt_token) - 1] = '\0';

    strncpy(config->server_host, "192.168.128.115", sizeof(config->server_host) - 1);
    config->server_host[sizeof(config->server_host) - 1] = '\0';

    config->server_port = 3030;

    config->mqtt_port = 1883;

    strncpy(config->device_name, "esp32s3_smartlock", sizeof(config->device_name) - 1);
    config->device_name[sizeof(config->device_name) - 1] = '\0';

}

void config_init_defaults(app_config_t *config)
{
    if (config == NULL)
        return;

    config->configured = 1;

    strncpy(config->wifi_ssid, "panda", sizeof(config->wifi_ssid) - 1);
    config->wifi_ssid[sizeof(config->wifi_ssid) - 1] = '\0';

    strncpy(config->wifi_pass, "mybirthday", sizeof(config->wifi_pass) - 1);
    config->wifi_pass[sizeof(config->wifi_pass) - 1] = '\0';

    strncpy(config->mqtt_host, "172.20.10.4", sizeof(config->mqtt_host) - 1);
    config->mqtt_host[sizeof(config->mqtt_host) - 1] = '\0';

    strncpy(config->mqtt_token, "0723635463ba45b139ba9ca4dac002cbc9473d66381719b530edf63cb322522a720171e2bae44fcc9703ce769e32ec9839f6cbf19193be6f7e215af25f4e2b5f", sizeof(config->mqtt_token) - 1);
    config->mqtt_token[sizeof(config->mqtt_token) - 1] = '\0';

    strncpy(config->server_host, "172.20.10.4", sizeof(config->server_host) - 1);
    config->server_host[sizeof(config->server_host) - 1] = '\0';

    config->server_port = 3030;

    config->mqtt_port = 1883;

    strncpy(config->device_name, "esp32s3_smartlock", sizeof(config->device_name) - 1);
    config->device_name[sizeof(config->device_name) - 1] = '\0';
}

void config_init_panda(app_config_t *config)
{
    if (config == NULL)
        return;

    config->configured = 1;

    strncpy(config->wifi_ssid, "panda", sizeof(config->wifi_ssid) - 1);
    config->wifi_ssid[sizeof(config->wifi_ssid) - 1] = '\0';

    strncpy(config->wifi_pass, "mybirthday", sizeof(config->wifi_pass) - 1);
    config->wifi_pass[sizeof(config->wifi_pass) - 1] = '\0';

    strncpy(config->mqtt_host, "172.20.10.4", sizeof(config->mqtt_host) - 1);
    config->mqtt_host[sizeof(config->mqtt_host) - 1] = '\0';

    strncpy(config->mqtt_token, "0723635463ba45b139ba9ca4dac002cbc9473d66381719b530edf63cb322522a720171e2bae44fcc9703ce769e32ec9839f6cbf19193be6f7e215af25f4e2b5f", sizeof(config->mqtt_token) - 1);
    config->mqtt_token[sizeof(config->mqtt_token) - 1] = '\0';

    strncpy(config->server_host, "172.20.10.4", sizeof(config->server_host) - 1);
    config->server_host[sizeof(config->server_host) - 1] = '\0';

    config->server_port = 3030;

    config->mqtt_port = 1883;

    strncpy(config->device_name, "esp32s3_smartlock", sizeof(config->device_name) - 1);
    config->device_name[sizeof(config->device_name) - 1] = '\0';
}

esp_err_t config_load(app_config_t *config)
{
    if (config == NULL)
    {
        return ESP_ERR_INVALID_ARG;
    }

    nvs_handle_t nvs_handle;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READONLY, &nvs_handle);

    if (err == ESP_ERR_NVS_NOT_INITIALIZED)
    {
        ESP_LOGW(TAG, "NVS not initialized, using defaults");
        config_init_defaults(config);
        return ESP_ERR_NVS_NOT_FOUND;
    }

    if (err != ESP_OK)
    {
        ESP_LOGW(TAG, "Failed to open NVS namespace, using defaults: %s", esp_err_to_name(err));
        config_init_defaults(config);
        return err;
    }

    // Initialize with defaults first
    config_init_defaults(config);

    // Try to read each field, use defaults for missing values
    size_t ssid_len = sizeof(config->wifi_ssid);
    size_t pass_len = sizeof(config->wifi_pass);
    size_t host_len = sizeof(config->mqtt_host);
    size_t name_len = sizeof(config->device_name);
    size_t token_len = sizeof(config->mqtt_token);
    size_t server_host_len = sizeof(config->server_host);

    int found_count = 0;

    if (nvs_get_str(nvs_handle, "wifi_ssid", config->wifi_ssid, &ssid_len) == ESP_OK)
        found_count++;
    if (nvs_get_str(nvs_handle, "wifi_pass", config->wifi_pass, &pass_len) == ESP_OK)
        found_count++;
    if (nvs_get_str(nvs_handle, "mqtt_host", config->mqtt_host, &host_len) == ESP_OK)
        found_count++;
    if (nvs_get_u16(nvs_handle, "mqtt_port", &config->mqtt_port) == ESP_OK)
        found_count++;
    if (nvs_get_str(nvs_handle, "server_host", config->server_host, &server_host_len) == ESP_OK)
        found_count++;
    if (nvs_get_u16(nvs_handle, "server_port", &config->server_port) == ESP_OK)
        found_count++;
    if (nvs_get_str(nvs_handle, "device_name", config->device_name, &name_len) == ESP_OK)
        found_count++;
    if (nvs_get_i32(nvs_handle, "configured", (int32_t *)&config->configured) == ESP_OK)
        found_count++;
    if (nvs_get_str(nvs_handle, "mqtt_token", config->mqtt_token, &token_len) == ESP_OK)
        found_count++;

    nvs_close(nvs_handle);

    if (found_count == 0)
    {
        ESP_LOGW(TAG, "No config values found in NVS, using all defaults");
        return ESP_ERR_NVS_NOT_FOUND;
    }

    ESP_LOGI(TAG, "Configuration loaded from NVS (found %d/%d fields)", found_count, 9);
    return ESP_OK;
}

esp_err_t config_saving(const app_config_t *config)
{
    if (config == NULL)
    {
        return ESP_ERR_INVALID_ARG;
    }

    nvs_handle_t nvs_handle;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &nvs_handle);

    if (err != ESP_OK)
    {
        ESP_LOGE(TAG, "Failed to open NVS namespace: %s", esp_err_to_name(err));
        return err;
    }

    // Save each field
    ESP_ERROR_CHECK(nvs_set_str(nvs_handle, "wifi_ssid", config->wifi_ssid));
    ESP_ERROR_CHECK(nvs_set_str(nvs_handle, "wifi_pass", config->wifi_pass));
    ESP_ERROR_CHECK(nvs_set_str(nvs_handle, "server_host", config->server_host));
    ESP_ERROR_CHECK(nvs_set_u16(nvs_handle, "server_port", config->server_port));
    ESP_ERROR_CHECK(nvs_set_str(nvs_handle, "mqtt_host", config->mqtt_host));
    ESP_ERROR_CHECK(nvs_set_str(nvs_handle, "mqtt_token", config->mqtt_token));
    ESP_ERROR_CHECK(nvs_set_u16(nvs_handle, "mqtt_port", config->mqtt_port));
    ESP_ERROR_CHECK(nvs_set_str(nvs_handle, "device_name", config->device_name));
    ESP_ERROR_CHECK(nvs_set_i32(nvs_handle, "configured", (int32_t)config->configured));

    // Commit changes
    err = nvs_commit(nvs_handle);
    nvs_close(nvs_handle);

    if (err == ESP_OK)
    {
        ESP_LOGI(TAG, "Configuration saved to NVS");
    }
    else
    {
        ESP_LOGE(TAG, "Failed to save configuration: %s", esp_err_to_name(err));
    }

    return err;
}

void config_print(const app_config_t *config)
{
    if (config == NULL)
        return;

    ESP_LOGI(TAG, "========== Configuration ==========");
    ESP_LOGI(TAG, "Configured: %s", config->configured ? "YES" : "NO");
    ESP_LOGI(TAG, "WiFi SSID: %s", config->wifi_ssid);
    ESP_LOGI(TAG, "WiFi Pass: %s", config->wifi_pass);
    ESP_LOGI(TAG, "Server Host: %s", config->server_host);
    ESP_LOGI(TAG, "Server Port: %u", config->server_port);
    ESP_LOGI(TAG, "MQTT Host: %s", config->mqtt_host);
    ESP_LOGI(TAG, "MQTT Port: %u", config->mqtt_port);
    ESP_LOGI(TAG, "MQTT Token: %s", config->mqtt_token);
    ESP_LOGI(TAG, "Device Name: %s", config->device_name);
    ESP_LOGI(TAG, "====================================");
}

esp_err_t config_update_str(const char *key, const char *value)
{
    if (key == NULL || value == NULL)
    {
        return ESP_ERR_INVALID_ARG;
    }

    nvs_handle_t nvs_handle;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &nvs_handle);

    if (err != ESP_OK)
    {
        ESP_LOGE(TAG, "Failed to open NVS namespace: %s", esp_err_to_name(err));
        return err;
    }

    err = nvs_set_str(nvs_handle, key, value);
    if (err != ESP_OK)
    {
        ESP_LOGE(TAG, "Failed to set string key '%s': %s", key, esp_err_to_name(err));
        nvs_close(nvs_handle);
        return err;
    }

    err = nvs_commit(nvs_handle);
    nvs_close(nvs_handle);

    if (err == ESP_OK)
    {
        ESP_LOGI(TAG, "Updated config key '%s'", key);
    }
    else
    {
        ESP_LOGE(TAG, "Failed to commit config: %s", esp_err_to_name(err));
    }

    return err;
}

esp_err_t config_update_u16(const char *key, uint16_t value)
{
    if (key == NULL)
    {
        return ESP_ERR_INVALID_ARG;
    }

    nvs_handle_t nvs_handle;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &nvs_handle);

    if (err != ESP_OK)
    {
        ESP_LOGE(TAG, "Failed to open NVS namespace: %s", esp_err_to_name(err));
        return err;
    }

    err = nvs_set_u16(nvs_handle, key, value);
    if (err != ESP_OK)
    {
        ESP_LOGE(TAG, "Failed to set u16 key '%s': %s", key, esp_err_to_name(err));
        nvs_close(nvs_handle);
        return err;
    }

    err = nvs_commit(nvs_handle);
    nvs_close(nvs_handle);

    if (err == ESP_OK)
    {
        ESP_LOGI(TAG, "Updated config key '%s' to %u", key, value);
    }
    else
    {
        ESP_LOGE(TAG, "Failed to commit config: %s", esp_err_to_name(err));
    }

    return err;
}

esp_err_t config_update_i32(const char *key, int32_t value)
{
    if (key == NULL)
    {
        return ESP_ERR_INVALID_ARG;
    }

    nvs_handle_t nvs_handle;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &nvs_handle);

    if (err != ESP_OK)
    {
        ESP_LOGE(TAG, "Failed to open NVS namespace: %s", esp_err_to_name(err));
        return err;
    }

    err = nvs_set_i32(nvs_handle, key, value);
    if (err != ESP_OK)
    {
        ESP_LOGE(TAG, "Failed to set i32 key '%s': %s", key, esp_err_to_name(err));
        nvs_close(nvs_handle);
        return err;
    }

    err = nvs_commit(nvs_handle);
    nvs_close(nvs_handle);

    if (err == ESP_OK)
    {
        ESP_LOGI(TAG, "Updated config key '%s' to %ld", key, value);
    }
    else
    {
        ESP_LOGE(TAG, "Failed to commit config: %s", esp_err_to_name(err));
    }

    return err;
}

