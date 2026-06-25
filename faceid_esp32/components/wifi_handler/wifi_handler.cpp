#include "wifi_handler.h"

#include <cstring>
#include "esp_log.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"

static const char *TAG = "wifi_handler";

/* ── Event group ─────────────────────────────────────────── */
#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT BIT1
#define MAX_RETRY 10

static EventGroupHandle_t s_wifi_event_group = nullptr;
static int s_retry_num = 0;
static char s_ip_str[16] = "0.0.0.0";

/* ── Event handler ───────────────────────────────────────── */
static void wifi_event_handler(void *arg, esp_event_base_t event_base,
                               int32_t event_id, void *event_data)
{
    if (event_base == WIFI_EVENT)
    {
        switch (event_id)
        {
        case WIFI_EVENT_STA_START:
            ESP_LOGI(TAG, "WiFi STA started, connecting...");
            esp_wifi_connect();
            break;

        case WIFI_EVENT_STA_DISCONNECTED:
            if (s_retry_num < MAX_RETRY)
            {
                s_retry_num++;
                ESP_LOGW(TAG, "Disconnected. Retry %d/%d ...", s_retry_num, MAX_RETRY);
                esp_wifi_connect();
            }
            else
            {
                ESP_LOGE(TAG, "Max retries reached, giving up.");
                xEventGroupSetBits(s_wifi_event_group, WIFI_FAIL_BIT);
            }
            break;

        default:
            break;
        }
    }
    else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP)
    {
        auto *event = static_cast<ip_event_got_ip_t *>(event_data);
        snprintf(s_ip_str, sizeof(s_ip_str), IPSTR, IP2STR(&event->ip_info.ip));
        ESP_LOGI(TAG, "Got IP: %s", s_ip_str);
        s_retry_num = 0;
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
    }
}

/* ── Public API ──────────────────────────────────────────── */
esp_err_t wifi_init_sta(const char *ssid, const char *password)
{
    ESP_LOGI(TAG, "wifi_init_sta called");
    ESP_LOGI(TAG, "Creating WiFi event group");
    s_wifi_event_group = xEventGroupCreate();

    ESP_LOGI(TAG, "Initializing TCP/IP stack");
    ESP_ERROR_CHECK(esp_netif_init());

    ESP_LOGI(TAG, "Creating default WiFi STA netif");
    esp_netif_create_default_wifi_sta();

    ESP_LOGI(TAG, "Initializing WiFi driver");
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    ESP_LOGI(TAG, "Registering WiFi event handler");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(
        WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, nullptr, nullptr));
    ESP_LOGI(TAG, "Registering IP event handler");
    ESP_ERROR_CHECK(esp_event_handler_instance_register(
        IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, nullptr, nullptr));

    ESP_LOGI(TAG, "Configuring WiFi STA settings");
    wifi_config_t wifi_cfg = {};
    strlcpy(reinterpret_cast<char *>(wifi_cfg.sta.ssid),
            ssid, sizeof(wifi_cfg.sta.ssid));
    strlcpy(reinterpret_cast<char *>(wifi_cfg.sta.password),
            password, sizeof(wifi_cfg.sta.password));
    if (strlen(password) == 0)
    {
        wifi_cfg.sta.threshold.authmode = WIFI_AUTH_OPEN;
    }
    else
    {
        wifi_cfg.sta.threshold.authmode = WIFI_AUTH_WPA2_PSK;
    }

    ESP_LOGI(TAG, "Setting WiFi mode to STA");
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_LOGI(TAG, "Applying WiFi configuration");
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_cfg));
    ESP_LOGI(TAG, "Starting WiFi");
    ESP_ERROR_CHECK(esp_wifi_start());

    ESP_LOGI(TAG, "wifi_init_sta() done. Waiting for connection...");

    return ESP_OK;
}

void wifi_scan_task(void *pv)
{
    uint16_t number = 5;
    wifi_ap_record_t *ap_info =
        (wifi_ap_record_t *)malloc(sizeof(wifi_ap_record_t) * number);
    uint16_t ap_count = 0;

    esp_wifi_scan_start(NULL, true);

    esp_wifi_scan_get_ap_records(&number, ap_info);
    esp_wifi_scan_get_ap_num(&ap_count);

    for (int i = 0; i < ap_count; i++)
    {
        ESP_LOGI("WIFI", "SSID: %s RSSI: %d",
                 ap_info[i].ssid, ap_info[i].rssi);
    }

    free(ap_info);
    vTaskDelete(NULL);
}

void wifi_wait_connected(void)
{
    EventBits_t bits = xEventGroupWaitBits(
        s_wifi_event_group,
        WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
        pdFALSE, pdFALSE, portMAX_DELAY);

    if (bits & WIFI_CONNECTED_BIT)
    {
        ESP_LOGI(TAG, "Connected! IP = %s", s_ip_str);
    }
    else
    {
        ESP_LOGE(TAG, "Failed to connect to WiFi.");
    }
}

const char *wifi_get_ip_str(void)
{
    return s_ip_str;
}
