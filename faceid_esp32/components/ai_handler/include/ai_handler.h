#pragma once
#include <vector>
#include "esp_err.h"
#include "esp_camera.h"
#include "dl_detect_define.hpp"
#include "event.hpp"
#include "human_face_recognition.hpp"
#include "dl_image_jpeg.hpp"

typedef struct
{
    uint8_t *imgs;
    size_t len;
    int user_id;
    char redis_key[32];
} EnrollCtx;

void enroll_task(void *arg);

void enroll_face();

/**
 * @brief Khởi tạo AI face detection model.
 *
 * Model sử dụng lazy loading – chỉ load vào RAM khi lần đầu chạy detect.
 *
 * @return ESP_OK nếu init thành công
 */
esp_err_t ai_init(void);

/**
 * @brief Chạy face detection trên một JPEG frame từ camera.
 *
 * Hàm này sẽ:
 * 1. Decode JPEG → RGB888
 * 2. Chạy HumanFaceDetect model
 * 3. Trả về số mặt phát hiện được
 *
 * @param fb Frame buffer JPEG nhận từ camera_capture()
 * @return Số lượng face detected (0 nếu không có hoặc lỗi)
 */
int ai_detect_faces(camera_fb_t *fb, std::__cxx11::list<dl::detect::result_t> &out);

void ai_set_enable(bool enbale);

bool ai_is_enable(void);