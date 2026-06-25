#include "json_builder.hpp"
#include <stdio.h>
#include "cJSON.h"
#include <vector>
#include "string.h"

static const char *TAG = "JSON_PARSER";

void json_build_faces_event(const std::__cxx11::list<dl::detect::result_t>  &faces,
                            char **out_str) {
    cJSON *root = cJSON_CreateObject();

    cJSON_AddStringToObject(root, "type", "esp_event");
    cJSON_AddStringToObject(root, "name", "face_detected");
    cJSON_AddNumberToObject(root, "count", faces.size());

    cJSON *arr = cJSON_CreateArray();

    for (auto &f : faces) {
        cJSON *item = cJSON_CreateObject();

        cJSON_AddNumberToObject(item, "category", f.category);
        cJSON_AddNumberToObject(item, "score", f.score);

        cJSON_AddItemToObject(
            item, "box",
            cJSON_CreateIntArray(f.box.data(), f.box.size()));

        cJSON_AddItemToObject(
            item, "keypoint",
            cJSON_CreateIntArray(f.keypoint.data(), f.keypoint.size()));

        cJSON_AddItemToArray(arr, item);
    }

    cJSON_AddItemToObject(root, "faces", arr);

    *out_str = cJSON_PrintUnformatted(root);

    cJSON_Delete(root);
}


// Hàm chuyên trị bóc tách JSON từ MQTT
cJSON *parse_mqtt_json(const char *raw_data, int data_len) {
    // ========================================================
    // BƯỚC 1: BỌC LẠI CHUỖI BẰNG KÝ TỰ '\0' (CHỐNG TRÀN RAM)
    // ========================================================
    char *json_string = (char *)malloc(data_len + 1);
    if (json_string == NULL) {
        ESP_LOGE(TAG, "Hết RAM, không thể parse JSON!");
        return nullptr;
    }
    // Dùng thần chú %.*s để copy đúng số lượng byte
    snprintf(json_string, data_len + 1, "%.*s", data_len, raw_data);

    // ========================================================
    // BƯỚC 2: TIẾN HÀNH PARSE
    // ========================================================
    cJSON *root = cJSON_Parse(json_string);
    if (root == NULL) {
        ESP_LOGE(TAG, "Dữ liệu Server gửi không phải JSON hợp lệ!");
        free(json_string); // Lỗi cũng phải trả lại RAM
        return nullptr;
    }

    free(json_string);    // Xóa chuỗi đệm tự tạo

    return root;
}

void json_build_device_status(char **out){
    cJSON *root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "status", "ping");
    *out = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
}