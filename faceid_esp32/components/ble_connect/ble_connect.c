#include <stdio.h>
#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "nvs_flash.h"
#include "esp_log.h"

#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"

#include "host/ble_hs.h"
#include "host/util/util.h"

#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"

#include "ble_connect.h"
#include "config.h"
#include "event.hpp"

static const char *TAG = "BLE_SERVER";

static uint16_t char_attr_handle;
static uint16_t conn_handle;
static uint8_t ble_addr_type;


static int ble_gap_event(struct ble_gap_event *event, void *arg);

static int ble_gatt_cb(uint16_t conn_handle,
                       uint16_t attr_handle,
                       struct ble_gatt_access_ctxt *ctxt,
                       void *arg);

static void ble_app_advertise(void);

static void ble_app_on_sync(void);

static void ble_host_task(void *param);

/* =========================================================
 * GATT Service Definition
 * =========================================================
 */

static const struct ble_gatt_svc_def ble_svc_gatt_defs[] = {
    {
        .type = BLE_GATT_SVC_TYPE_PRIMARY,

        .uuid = BLE_UUID16_DECLARE(BLE_SERVICE_UUID),

        .characteristics = (struct ble_gatt_chr_def[]){
            {
                .uuid = BLE_UUID16_DECLARE(BLE_CHARACTERISTIC_UUID),

                .access_cb = ble_gatt_cb,

                .flags = BLE_GATT_CHR_F_READ |
                         BLE_GATT_CHR_F_WRITE |
                         BLE_GATT_CHR_F_NOTIFY,

                .val_handle = &char_attr_handle,
            },

            {
                0,
            }},
    },

    {
        0,
    }};

/* =========================================================
 * GATT Callback
 * =========================================================
 */

static int ble_gatt_cb(uint16_t conn_handle,
                       uint16_t attr_handle,
                       struct ble_gatt_access_ctxt *ctxt,
                       void *arg)
{
    switch (ctxt->op)
    {

    case BLE_GATT_ACCESS_OP_READ_CHR:
    {
        ESP_LOGI(TAG, "Client rading data");

        const char *msg = "220 Hello from ESP32-S3";

        os_mbuf_append(ctxt->om, msg, strlen(msg));

        return 0;
    }

    case BLE_GATT_ACCESS_OP_WRITE_CHR:
    {
        ESP_LOGI(TAG, "Client wrote data");

        uint8_t buf[512] = {0};

        uint16_t len = ctxt->om->om_len;

        if (len >= sizeof(buf))
        {
            len = sizeof(buf) - 1;
        }

        os_mbuf_copydata(ctxt->om, 0, len, buf);

        ESP_LOGI(TAG, "Received: %s", buf);

        app_config_t cfg = parse_to_config_t(buf);

        config_update_str("wifi_ssid", cfg.wifi_ssid);
        config_update_str("wifi_pass", cfg.wifi_pass);
        config_update_str("device_name", cfg.device_name);
        config_update_str("server_host", cfg.server_host);
        config_update_u16("server_port", (uint16_t) cfg.server_port);
        config_update_i32("configured", 1);
        config_load(&cfg);
        config_print(&cfg);
        app_event_post_config_received(&cfg);

        const char *msg = "250 OK";

        os_mbuf_append(ctxt->om, msg, strlen(msg));

        return 0;
    }

    default:
        return BLE_ATT_ERR_UNLIKELY;
    }
}

/* =========================================================
 * BLE Advertising
 * =========================================================
 */

static void ble_app_advertise(void)
{
    struct ble_gap_adv_params adv_params;
    struct ble_hs_adv_fields fields;

    int rc;

    memset(&fields, 0, sizeof(fields));

    fields.flags =
        BLE_HS_ADV_F_DISC_GEN |
        BLE_HS_ADV_F_BREDR_UNSUP;

    fields.name = (uint8_t *)BLE_DEVICE_NAME;

    fields.name_len = strlen(BLE_DEVICE_NAME);

    fields.name_is_complete = 1;

    rc = ble_gap_adv_set_fields(&fields);

    if (rc != 0)
    {
        ESP_LOGE(TAG, "Failed to set advertising data: %d", rc);
        return;
    }

    memset(&adv_params, 0, sizeof(adv_params));

    adv_params.conn_mode = BLE_GAP_CONN_MODE_UND;

    adv_params.disc_mode = BLE_GAP_DISC_MODE_GEN;

    rc = ble_gap_adv_start(
        ble_addr_type,
        NULL,
        BLE_HS_FOREVER,
        &adv_params,
        ble_gap_event,
        NULL);

    if (rc != 0)
    {
        ESP_LOGE(TAG, "Failed to start advertising: %d", rc);
        return;
    }

    ESP_LOGI(TAG, "BLE Advertising started");
}

/* =========================================================
 * GAP Event Callback
 * =========================================================
 */

static int ble_gap_event(struct ble_gap_event *event, void *arg)
{
    switch (event->type)
    {

    case BLE_GAP_EVENT_CONNECT:

        ESP_LOGI(TAG,
                 "Connection %s",
                 event->connect.status == 0 ? "successful" : "failed");

        if (event->connect.status == 0)
        {

            conn_handle = event->connect.conn_handle;

            ESP_LOGI(TAG,
                     "Connected, conn_handle = %d",
                     conn_handle);
        }
        else
        {

            ble_app_advertise();
        }

        break;

    case BLE_GAP_EVENT_DISCONNECT:

        ESP_LOGI(TAG, "Disconnected");

        ble_app_advertise();

        break;

    case BLE_GAP_EVENT_ADV_COMPLETE:

        ESP_LOGI(TAG, "Advertising complete");

        ble_app_advertise();

        break;

    default:
        break;
    }

    return 0;
}

/* =========================================================
 * BLE Sync Callback
 * =========================================================
 */

static void ble_app_on_sync(void)
{
    int rc;

    rc = ble_hs_id_infer_auto(0, &ble_addr_type);

    if (rc != 0)
    {

        ESP_LOGE(TAG,
                 "Failed to infer address type: %d",
                 rc);

        return;
    }

    ble_app_advertise();
}

/* =========================================================
 * NimBLE Host Task
 * =========================================================
 */

static void ble_host_task(void *param)
{
    nimble_port_run();

    nimble_port_freertos_deinit();
}

/* =========================================================
 * BLE Server Init
 * =========================================================
 */

void ble_server_init(void)
{
    esp_err_t ret;

    /* Init NVS */

    ret = nvs_flash_init();

    if (ret == ESP_ERR_NVS_NO_FREE_PAGES ||
        ret == ESP_ERR_NVS_NEW_VERSION_FOUND)
    {
        ESP_ERROR_CHECK(nvs_flash_erase());

        ret = nvs_flash_init();
    }

    ESP_ERROR_CHECK(ret);

    /* Init NimBLE */

    nimble_port_init();

    /* GAP + GATT */

    ble_svc_gap_init();

    ble_svc_gatt_init();

    /* Device name */

    ble_svc_gap_device_name_set(BLE_DEVICE_NAME);

    /* Sync callback */
    ble_hs_cfg.sync_cb = ble_app_on_sync;

    /* Register services */

    ble_gatts_count_cfg(ble_svc_gatt_defs);

    ble_gatts_add_svcs(ble_svc_gatt_defs);

    /* Start NimBLE task */

    nimble_port_freertos_init(ble_host_task);

    ESP_LOGI(TAG, "BLE Server Initialized");
}

/* =========================================================
 * Notify Function
 * =========================================================
 */

void ble_server_send_notify(uint8_t *data, uint16_t len)
{
    if (conn_handle == 0)
    {
        ESP_LOGW(TAG, "No client connected");
        return;
    }

    struct os_mbuf *om =
        ble_hs_mbuf_from_flat(data, len);

    if (om == NULL)
    {

        ESP_LOGE(TAG,
                 "Failed to allocate mbuf");

        return;
    }

    int rc = ble_gatts_notify_custom(
        conn_handle,
        char_attr_handle,
        om);

    if (rc != 0)
    {

        ESP_LOGE(TAG,
                 "Notify failed: %d",
                 rc);
    }
    else
    {

        ESP_LOGI(TAG,
                 "Notify sent");
    }
}