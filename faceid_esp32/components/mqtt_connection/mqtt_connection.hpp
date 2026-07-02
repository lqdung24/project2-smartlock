#include <stdio.h>
#include "esp_log.h"
#include "mqtt_client.h"
#include "esp_mac.h"

#define MQTT_ERR -1
#define MQTT_OPEN 1
#define MQTT_REGIS_FACE 2
#define MQTT_DELETE_FACE 3
#define MQTT_AI_ENABLE 4
#define MQTT_SYNC_TIME 5
#define MQTT_RESET 6
#define MQTT_PING 7
#define MQTT_RETURN_REGIS 8  // Server trả về face_id thật sau khi nhận faceregis

// Global variables
extern esp_mqtt_client_handle_t mqtt_client;
extern char status_topic[50];
extern char control_topic[50];
extern char event_topic[50];

#pragma pack(push, 1)
typedef struct
{
    uint32_t face_id;
    char redis_key[32];
    float face_features[512];
} EnrollMessage_t;

typedef struct
{
    int32_t event_type;  // -2
    int32_t status;      // user_id or -1
    uint32_t timestamp;  // epoch time
} UnlockEventMessage_t;
#pragma pack(pop)

// Function declarations
void get_chip_id_string(char *out_str);
void mqtt_app_start(char *server_url, uint16_t port, char *mqtt_token);
void mqtt_publish_enroll_done(
    uint32_t face_id, 
    const float *features
);
void mqtt_publish_status();
void mqtt_publish_pong();
void mqtt_request_time();
void mqtt_publish_unlock_event(int32_t status, uint32_t timestamp);
bool mqtt_is_connected();
void mqtt_send_offline_logs();

/**
 * @brief Publish s\u1ef1 ki\u1ec7n \u0111\u0103ng k\u00fd khu\u00f4n m\u1eb7t local qua MQTT.
 *
 * JSON format: { "event": "faceregis", "enroll_id": <id>,
 *                "embed": "<base64 float[512]>", "img": "<base64 jpeg>" }
 *
 * @param enroll_id  enrolled_id tr\u1ea3 v\u1ec1 sau khi enroll
 * @param features   Con tr\u1ecf float[512] embedding vector
 * @param jpeg_buf   Buffer JPEG c\u1ee7a nh\u1eef khu\u00f4n m\u1eb7t
 * @param jpeg_len   K\u00edch th\u01b0\u1edbc JPEG (bytes)
 */
void mqtt_publish_local_enroll(uint16_t enroll_id, const float *features,
                               const uint8_t *jpeg_buf, size_t jpeg_len);
