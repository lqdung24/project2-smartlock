#include "ai_handler.h"
#include "mqtt_connection.hpp"

#include "dl_image_define.hpp"
#include "esp_heap_caps.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/semphr.h"
#include "human_face_detect.hpp"
#include "img_converters.h"
#include "rgb_control.hpp"
#include "storage.hpp"
#include <atomic>
#include <cstdlib>
#include <new>
#include <time.h>
#include <vector>

static const char *TAG = "ai_handler";
// Khai báo Mutex
SemaphoreHandle_t ai_mutex = NULL;
/* ── State ───────────────────────────────────────────────── */
static std::atomic<bool> s_ai_enable{false};
static HumanFaceDetect *s_detector = nullptr;
static HumanFaceRecognizer *s_embedding = nullptr;

/* ── Public API ──────────────────────────────────────────── */
esp_err_t ai_init(void) {
  /* Lazy-load model: chỉ allocate wrapper, model load khi run() lần đầu */
  s_detector =
      new (std::nothrow) HumanFaceDetect(HumanFaceDetect::MSRMNP_S8_V1, true);
  if (!s_detector) {
    ESP_LOGE(TAG, "Failed to create HumanFaceDetect");
    return ESP_ERR_NO_MEM;
  }
  s_embedding = new (std::nothrow)
      HumanFaceRecognizer("/face/face_id.bin", HumanFaceFeat::MFN_S8_V1, true);
  if (!s_embedding) {
    ESP_LOGE(TAG, "Failed to create HumanFaceEmbedding");
    return ESP_ERR_NO_MEM;
  }
  ai_mutex = xSemaphoreCreateMutex();

  if (ai_mutex == NULL) {
    ESP_LOGE("AI", "Lỗi: Không tạo được Mutex!");
    return ESP_FAIL;
  }
  ESP_LOGI(TAG, "AI face detection model initialized (lazy load)");
  return ESP_OK;
}

int convert_2_rgb888(camera_fb_t *fb, uint8_t *rgb_buf) {
  if (!rgb_buf) {
    ESP_LOGE(TAG, "RGB buffer is not allocated");
    return 0;
  }

  bool ok = fmt2rgb888(fb->buf, fb->len, fb->format, rgb_buf);

  if (!ok) {
    ESP_LOGE(TAG, "RGB → RGB888 convert failed (format=%d)", fb->format);
    free(rgb_buf);
    return 0;
  }
  return 1;
}

int ai_detect_faces(camera_fb_t *fb,
                    std::__cxx11::list<dl::detect::result_t> &results) {
  if (!s_ai_enable.load() || !s_detector || !fb || !fb->buf) {
    return 0;
  }

  int w = fb->width;
  int h = fb->height;
  if (w <= 0 || h <= 0)
    return 0;

  size_t rgb_len = w * h * 3;

  uint8_t *rgb_buf =
      (uint8_t *)heap_caps_malloc(rgb_len, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);

  if (!rgb_buf) {
    ESP_LOGE(TAG, "Failed to allocate RGB buffer");
    return 0;
  }

  bool ok = fmt2rgb888(fb->buf, fb->len, fb->format, rgb_buf);

  if (!ok) {
    ESP_LOGE(TAG, "RGB → RGB888 convert failed (format=%d)", fb->format);
    free(rgb_buf);
    return 0;
  }

  dl::image::img_t img = {};
  img.data = rgb_buf;
  img.width = w;
  img.height = h;
  img.pix_type = dl::image::DL_IMAGE_PIX_TYPE_RGB888;

  if (xSemaphoreTake(ai_mutex, portMAX_DELAY) == pdTRUE) {
    int64_t t0 = esp_timer_get_time();
    results = s_detector->run(img);
    int64_t t1 = esp_timer_get_time();

    ESP_LOGI(TAG, "AI detect time: %.2f ms, Detected %d face(s)",
             (t1 - t0) / 1000.0, results.size());

    t0 = esp_timer_get_time();
    auto reco_results = s_embedding->recognize(img, results);
    t1 = esp_timer_get_time();

    xSemaphoreGive(ai_mutex);

    ESP_LOGI(TAG, "AI recognize time: %.2f ms, size: %d", (t1 - t0) / 1000.0,
             reco_results.size());

    bool matched = false;
    int matched_user_id = -1;
    float best_similarity = 0.0f;
    int best_face_id = -1;

    for (auto &r : reco_results) {
      ESP_LOGI(TAG, "id=%d similarity=%.4f", r.id, r.similarity);
      if (r.similarity > 0.5f && r.similarity > best_similarity) {
        best_similarity = r.similarity;
        best_face_id = r.id;
        matched = true;
      }
    }

    time_t now;
    time(&now);
    struct tm timeinfo;
    localtime_r(&now, &timeinfo);
    char time_str[64];
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", &timeinfo);

    if (matched) {
      matched_user_id = get_user_id_by_face_id(best_face_id);

      // Call green LED
      set_green();
      set_timeout(5000, turn_off, NULL);

      // Log details
      ESP_LOGI("ACCESS_LOG",
               "==================================================");
      ESP_LOGI("ACCESS_LOG", "MỞ CỬA THÀNH CÔNG (Sim: %.4f)", best_similarity);
      ESP_LOGI("ACCESS_LOG", "User ID: %d", matched_user_id);
      ESP_LOGI("ACCESS_LOG", "Face ID: %d", best_face_id);
      ESP_LOGI("ACCESS_LOG", "Time   : %s", time_str);
      ESP_LOGI("ACCESS_LOG",
               "==================================================");

      // Publish hoặc lưu offline
      if (mqtt_is_connected()) {
        mqtt_publish_unlock_event(matched_user_id, (uint32_t)now);
      } else {
        save_offline_log(matched_user_id, (uint32_t)now);
      }
    } else if (!results.empty()) {
      // Có mặt nhưng không khớp -> Người lạ
      ESP_LOGI("ACCESS_LOG",
               "==================================================");
      ESP_LOGI("ACCESS_LOG", "PHÁT HIỆN NGƯỜI LẠ / THẤT BẠI");
      ESP_LOGI("ACCESS_LOG", "Time   : %s", time_str);
      ESP_LOGI("ACCESS_LOG",
               "==================================================");

      // Publish hoặc lưu offline
      if (mqtt_is_connected()) {
        mqtt_publish_unlock_event(-1, (uint32_t)now);
      } else {
        save_offline_log(-1, (uint32_t)now);
      }
    }

    for (auto &r : results) {
      // 🔹 log bbox
      ESP_LOGI(TAG, "box=[%d,%d,%d,%d] score=%.2f", r.box[0], r.box[1],
               r.box[2], r.box[3], r.score);

      // 🔹 log keypoints
      int kp_size = r.keypoint.size();

      if (kp_size % 2 != 0) {
        ESP_LOGW(TAG, "Invalid keypoint size: %d", kp_size);
        continue;
      }

      printf("  keypoints (%d): ", kp_size / 2);

      for (int i = 0; i < kp_size; i += 2) {
        printf("(%d,%d) ", r.keypoint[i], r.keypoint[i + 1]);
      }
      printf("\n");
    }
  }

  free(rgb_buf);
  return results.size();
}

void enroll_task(void *arg) {
  EnrollCtx *ctx = (EnrollCtx *)arg;
  int user_id = ctx->user_id;

  ESP_LOGI("ENROLL", "User: %d", user_id);

  uint8_t *buf = ctx->imgs;
  size_t len = ctx->len;

  char redis_key[32] = {0};

  if (!buf || len == 0) {
    ESP_LOGE("ENROLL", "invalid image buffer");
    delete ctx;
    vTaskDelete(NULL);
    return;
  }

  // Copy redis_key locally so we can release ctx before publishing.
  memcpy(redis_key, ctx->redis_key, sizeof(redis_key));

  // Transfer ownership of the PSRAM image buffer directly and avoid an extra
  // SRAM copy.
  ctx->imgs = NULL;
  ctx->len = 0;
  delete ctx;
  ctx = NULL;

  // =========================
  // 1. Decode JPEG
  // =========================
  dl::image::jpeg_img_t jpeg_img;
  jpeg_img.data = buf;
  jpeg_img.data_len = len;
  dl::image::img_t img =
      dl::image::sw_decode_jpeg(jpeg_img, dl::image::DL_IMAGE_PIX_TYPE_RGB888);
  if (img.data == NULL) {
    ESP_LOGW("ENROLL", "Decode failed img");
    heap_caps_free(buf);
    vTaskDelete(NULL);
    return;
  }

  if (xSemaphoreTake(ai_mutex, portMAX_DELAY) == pdTRUE) {
    // =========================
    // 2. Detect face
    // =========================
    auto detect_res = s_detector->run(img);
    ESP_LOGI(TAG, "enroll detected: %d", detect_res.size());

    // =========================
    // 3. Check/Create User if active == false
    // =========================
    if (user_id >= 0 && user_id < MAX_USERS) {
      if (!user_db[user_id].is_active) {
        char default_name[30];
        snprintf(default_name, sizeof(default_name), "User_%d", user_id);
        save_user_to_db(user_id, default_name, 1); // 1 = User thường
      }
    }

    // =========================
    // 4. Extract feature & Enroll
    // =========================
    uint16_t enrolled_id = 0;
    auto res = s_embedding->enroll(img, detect_res, &enrolled_id);

    xSemaphoreGive(ai_mutex);

    if (res == ESP_FAIL) {
      ESP_LOGW("ENROLL", "Feature fail img ");
      mqtt_publish_enroll_done(-1, redis_key, nullptr);
      heap_caps_free(buf);
      vTaskDelete(NULL);
      return;
    }

    // =========================
    // 5. Map faceid -> userid
    // =========================
    save_face_mapping(enrolled_id, user_id);

    app_event_post_enroll_done(enrolled_id);

    const float *feature_ptr = s_embedding->get_feat_by_id(enrolled_id);
    if (feature_ptr == NULL) {
      ESP_LOGW("ENROLL", "get_feat_by_id failed for id=%d", enrolled_id);
    } else {
      ESP_LOGI("ENROLL", "get_feat_by_id succeeded for id=%d", enrolled_id);
      mqtt_publish_enroll_done(enrolled_id, redis_key, feature_ptr);
    }
  }

  heap_caps_free(buf);
  vTaskDelete(NULL);
}

void ai_set_enable(bool enable) {
  s_ai_enable.store(enable);
  ESP_LOGI(TAG, "AI %s", enable ? "ENABLED" : "DISABLED");
}

bool ai_is_enable(void) { return s_ai_enable.load(); }

// /* ── AI Task: face detection (chỉ khi enabled) ──────────── */
// static void ai_task(void *arg)
// {
//     ESP_LOGI(TAG, "ai_task running on core %d", xPortGetCoreID());

//     while (true) {
//         if (!ai_is_running()) {
//             vTaskDelay(pdMS_TO_TICKS(500));
//             continue;
//         }

//         camera_fb_t *fb = camera_capture();

//         if (fb) {
//             std::__cxx11::list<dl::detect::result_t> result;
//             int face = ai_detect_faces(fb, result);

//             /* Gửi kết quả detect về server */
//             if (face > 0 && websocket_is_connected()) {
//                 char *json;
//                 json_build_faces_event(result, &json);

//                 websocket_send_text(json);

//                 free(json);
//             }

//             camera_release(fb);
//         }

//         /* AI chạy chậm hơn stream, ~5 FPS */
//         vTaskDelay(pdMS_TO_TICKS(200));
//     }
// }