#pragma once
#include "dl_detect_define.hpp"
#include "dl_image_jpeg.hpp"
#include "esp_camera.h"
#include "esp_err.h"
#include "event.hpp"
#include "freertos/semphr.h"
#include "human_face_recognition.hpp"
#include <vector>

extern SemaphoreHandle_t ai_mutex; // Mutex bảo vệ model AI

typedef struct {
  /* ── Path 1: JPEG input (enroll t\u1eeb server download) ───────── */
  uint8_t *imgs;       // JPEG buffer (enroll_task s\u1ebd free sau khi dùng)
  size_t len;

  /* ── Path 2: RGB888 input (enroll t\u1eeb n\u00fat b\u1ea5m local) ────── */
  // N\u1ebfu local_enroll == true, imgs/len c\u00f3 th\u1ec3 NULL, s\u1eed d\u1ee5ng rgb_buf
  bool local_enroll;   // true = enroll t\u1eeb n\u00fat, enroll_task s\u1ebd publish MQTT sau khi xong
  uint8_t *rgb_buf;    // RGB888 buffer (PSRAM), kích th\u01b0\u1edbc = rgb_w * rgb_h * 3
  int rgb_width;
  int rgb_height;

  /* ── Chung ───────────────────────────────────────────────── */
  int face_id;
  int user_id;
  char label[32];
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
 * @brief Chạy face detection + recognition trên một JPEG frame từ camera.
 *
 * @param fb Frame buffer JPEG nhận từ camera_capture()
 * @return Số lượng face detected (0 nếu không có hoặc lỗi)
 */
int ai_detect_faces(camera_fb_t *fb,
                    std::__cxx11::list<dl::detect::result_t> &out);

/**
 * @brief Chỉ chạy face detection (không recognize), dùng để kiểm tra có mặt trong frame.
 *
 * @param fb Frame buffer từ camera_capture()
 * @param results Danh sách kết quả detect
 * @return Số khuôn mặt phát hiện được
 */
int ai_detect_faces_raw(camera_fb_t *fb,
                        std::__cxx11::list<dl::detect::result_t> &results);

void ai_set_enable(bool enbale);

bool ai_is_enable(void);

esp_err_t ai_delete_face(uint16_t face_id);

/**
 * @brief Nhận face_id thật từ server (return_regis) và cập nhật mapping
 *        enrolled_id (local model) → newServerFaceId.
 */
esp_err_t ai_remap_local_enroll(int new_server_face_id);

/**
 * @brief Gửi thông báo sự kiện nhận diện (MQTT / Offline Log) với tính năng hạn chế tần suất (cooldown 5s).
 *
 * @param best_face_id ID nội bộ của khuôn mặt nhận diện được, hoặc -1 nếu là người lạ / không khớp.
 */
void ai_noti_handler(int best_face_id);