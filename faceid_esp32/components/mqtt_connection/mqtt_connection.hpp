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
    const char *redis_key, 
    const float *features
);
void mqtt_publish_status();
void mqtt_request_time();
void mqtt_publish_unlock_event(int32_t status, uint32_t timestamp);
bool mqtt_is_connected();
void mqtt_send_offline_logs();
