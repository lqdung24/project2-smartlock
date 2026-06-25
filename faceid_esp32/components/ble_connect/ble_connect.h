#ifndef BLE_CONNECT_H
#define BLE_CONNECT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* =========================================================
 * BLE Configuration
 * =========================================================
 */

#define BLE_DEVICE_NAME           "ESP32_BLE"

#define BLE_SERVICE_UUID          0x180A

#define BLE_CHARACTERISTIC_UUID   0x2A57

/* =========================================================
 * Public Functions
 * =========================================================
 */

void ble_server_init(void);

void ble_server_send_notify(uint8_t *data, uint16_t len);

#ifdef __cplusplus
}
#endif

#endif