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
static std::atomic<bool> s_ai_enable{true};
static HumanFaceDetect *s_detector = nullptr;
static HumanFaceRecognizer *s_embedding = nullptr;
// enrolled_id của lần local enroll cuối, chờ server xác nhận face_id thật
static std::atomic<int> s_pending_local_enrolled_id{-1};

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

    if (results.size() == 0) {
      set_yellow();
    }

    // ESP_LOGI(TAG, "AI detect time: %.2f ms, Detected %d face(s)",
    //          (t1 - t0) / 1000.0, results.size());

    t0 = esp_timer_get_time();
    auto reco_results = s_embedding->recognize(img, results);
    t1 = esp_timer_get_time();

    xSemaphoreGive(ai_mutex);

    // ESP_LOGI(TAG, "AI recognize time: %.2f ms, size: %d", (t1 - t0) / 1000.0,
    //          reco_results.size());

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

    char matched_label[64] = "Unknown";
    int server_face_id = -1;
    if (matched) {
      server_face_id = get_server_id_by_enroll_id(best_face_id);
      if (server_face_id != -1) {
        if (!lookup_user_by_face_id(server_face_id, matched_user_id,
                                    matched_label, sizeof(matched_label))) {
          matched_user_id = server_face_id; // fallback if no CSV entry
        }

        // Call green LED
        set_green();
        set_timeout(5000, turn_off, NULL);
        ai_set_enable(false);

        // Log details
        ESP_LOGI("ACCESS_LOG",
                 "==================================================");
        ESP_LOGI("ACCESS_LOG", "MỞ CỬA THÀNH CÔNG (Id: %d, Sim: %.4f)", best_face_id, best_similarity);
        ESP_LOGI("ACCESS_LOG", "User ID: %d", matched_user_id);
        ESP_LOGI("ACCESS_LOG", "Face ID (Server): %d", server_face_id);
        ESP_LOGI("ACCESS_LOG", "Label: %s", matched_label);
        ESP_LOGI("ACCESS_LOG", "Time   : %s", time_str);
        ESP_LOGI("ACCESS_LOG",
                 "==================================================");

        // Publish hoặc lưu offline qua notifier
        ai_noti_handler(best_face_id);
      } else {
        // Khớp trong model nhưng không có mapping (đã bị xóa trên server/local map) -> Coi như người lạ
        set_red();
        set_timeout(5000, turn_off, NULL);
        ESP_LOGI("ACCESS_LOG",
                 "==================================================");
        ESP_LOGI("ACCESS_LOG", "THẤT BẠI: KHUÔN MẶT ĐÃ BỊ XÓA HOẶC KHÔNG CÓ ÁNH XẠ (Id: %d, Sim: %.4f)", best_face_id, best_similarity);
        ESP_LOGI("ACCESS_LOG", "Time   : %s", time_str);
        ESP_LOGI("ACCESS_LOG",
                 "==================================================");

        // Publish hoặc lưu offline qua notifier dưới dạng stranger
        ai_noti_handler(-1);
      }
    } else if (!results.empty()) {
      set_red();
      set_timeout(5000, turn_off, NULL);
    //   ai_set_enable(false);
      // Có mặt nhưng không khớp -> Người lạ
      ESP_LOGI("ACCESS_LOG",
               "==================================================");
      ESP_LOGI("ACCESS_LOG", "PHÁT HIỆN NGƯỜI LẠ / THẤT BẠI");
      ESP_LOGI("ACCESS_LOG", "Time   : %s", time_str);
      ESP_LOGI("ACCESS_LOG",
               "==================================================");

      // Publish hoặc lưu offline qua notifier
      ai_noti_handler(-1);
    }
  }

  free(rgb_buf);
  return results.size();
}

/**
 * @brief Ch\u1ec9 ch\u1ea1y face detection (kh\u00f4ng recognize), d\u00f9ng \u0111\u1ec3 ki\u1ec3m tra c\u00f3 m\u1eb7t trong frame.
 */
int ai_detect_faces_raw(camera_fb_t *fb,
                        std::__cxx11::list<dl::detect::result_t> &results) {
  if (!s_detector || !fb || !fb->buf) return 0;

  int w = fb->width;
  int h = fb->height;
  if (w <= 0 || h <= 0) return 0;

  size_t rgb_len = w * h * 3;
  uint8_t *rgb_buf =
      (uint8_t *)heap_caps_malloc(rgb_len, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
  if (!rgb_buf) {
    ESP_LOGE(TAG, "ai_detect_faces_raw: Failed to allocate RGB buffer");
    return 0;
  }

  bool ok = fmt2rgb888(fb->buf, fb->len, fb->format, rgb_buf);
  if (!ok) {
    free(rgb_buf);
    return 0;
  }

  dl::image::img_t img = {};
  img.data     = rgb_buf;
  img.width    = w;
  img.height   = h;
  img.pix_type = dl::image::DL_IMAGE_PIX_TYPE_RGB888;

  // Không take mutex ở đây — caller (local_enroll_task) đã giữ mutex rồi
  results = s_detector->run(img);

  free(rgb_buf);
  return (int)results.size();
}

void enroll_task(void *arg) {
  EnrollCtx *ctx = (EnrollCtx *)arg;
  int face_id       = ctx->face_id;
  int user_id       = ctx->user_id;
  bool local_enroll = ctx->local_enroll;
  char label[32] = {0};
  strncpy(label, ctx->label, sizeof(label) - 1);

  ESP_LOGI("ENROLL", "Face: %d, User: %d, Label: %s, local=%d",
           face_id, user_id, label, local_enroll);

  // ================================================================
  // Giải phóng ctx và lấy ownership buffer
  // ================================================================
  dl::image::img_t img = {};   // sẽ điền ngay sau
  uint8_t *jpeg_buf_to_free = NULL; // buffer cần free sau khi decode (path JPEG)
  uint8_t *rgb_buf          = ctx->rgb_buf; // RGB path
  int      rgb_w            = ctx->rgb_width;
  int      rgb_h            = ctx->rgb_height;
  uint8_t *imgs_buf         = ctx->imgs;
  size_t   imgs_len         = ctx->len;

  ctx->imgs    = NULL;
  ctx->rgb_buf = NULL;
  delete ctx;
  ctx = NULL;

  if (local_enroll) {
    // ================================================================
    // PATH 2 – Local enroll: dùng RGB888 buffer trực tiếp (không JPEG decode)
    // ================================================================
    if (!rgb_buf || rgb_w <= 0 || rgb_h <= 0) {
      ESP_LOGE("ENROLL", "local_enroll: invalid RGB buffer");
      vTaskDelete(NULL);
      return;
    }
    img.data     = rgb_buf;
    img.width    = rgb_w;
    img.height   = rgb_h;
    img.pix_type = dl::image::DL_IMAGE_PIX_TYPE_RGB888;
  } else {
    // ================================================================
    // PATH 1 – Server enroll: decode JPEG → RGB888
    // ================================================================
    if (!imgs_buf || imgs_len == 0) {
      ESP_LOGE("ENROLL", "invalid JPEG buffer");
      vTaskDelete(NULL);
      return;
    }
    dl::image::jpeg_img_t jpeg_img;
    jpeg_img.data     = imgs_buf;
    jpeg_img.data_len = imgs_len;
    img = dl::image::sw_decode_jpeg(jpeg_img, dl::image::DL_IMAGE_PIX_TYPE_RGB888);
    jpeg_buf_to_free = imgs_buf; // free JPEG buffer sau
    if (img.data == NULL) {
      ESP_LOGW("ENROLL", "Decode JPEG failed");
      heap_caps_free(imgs_buf);
      vTaskDelete(NULL);
      return;
    }
  }

  if (xSemaphoreTake(ai_mutex, portMAX_DELAY) == pdTRUE) {
    // =========================
    // 2. Detect face
    // =========================
    auto detect_res = s_detector->run(img);
    ESP_LOGI(TAG, "enroll detected: %d", detect_res.size());

    // =========================
    // 3. Check/Create User
    // =========================
    if (user_id >= 0 && user_id < MAX_USERS) {
      if (!user_db[user_id].is_active) {
        char default_name[30];
        snprintf(default_name, sizeof(default_name), "User_%d", user_id);
        save_user_to_db(user_id, default_name, 1);
      }
    }

    // =========================
    // 4. Extract feature & Enroll
    // =========================
    uint16_t enrolled_id = 0;
    auto res = s_embedding->enroll(img, detect_res, &enrolled_id);

    xSemaphoreGive(ai_mutex);

    if (res == ESP_FAIL) {
      ESP_LOGW("ENROLL", "Feature extraction failed");
      if (!local_enroll) mqtt_publish_enroll_done(face_id, nullptr);
      if (jpeg_buf_to_free) heap_caps_free(jpeg_buf_to_free);
      if (rgb_buf)          heap_caps_free(rgb_buf);
      vTaskDelete(NULL);
      return;
    }

    // =========================
    // 5. Map faceid -> userid
    // =========================
    save_face_mapping(enrolled_id, face_id);
    save_user_to_csv(face_id, user_id, label);
    app_event_post_enroll_done(enrolled_id);

    const float *feature_ptr = s_embedding->get_feat_by_id(enrolled_id);
    if (feature_ptr == NULL) {
      ESP_LOGW("ENROLL", "get_feat_by_id failed for id=%d", enrolled_id);
    } else {
      ESP_LOGI("ENROLL", "get_feat_by_id ok, enrolled_id=%d", enrolled_id);

      if (local_enroll) {
        // ================================================================
        // Enroll xong → mới nén RGB888 → JPEG → publish MQTT
        // ================================================================
        if (mqtt_is_connected()) {
          uint8_t *out_jpeg  = NULL;
          size_t   out_len   = 0;
          bool ok = fmt2jpg(rgb_buf, (size_t)rgb_w * rgb_h * 3,
                            (uint16_t)rgb_w, (uint16_t)rgb_h,
                            PIXFORMAT_RGB888, 80,
                            &out_jpeg, &out_len);
          if (ok && out_jpeg && out_len > 0) {
            ESP_LOGI("ENROLL", "local_enroll: JPEG compressed %u bytes, publishing...",
                     (unsigned)out_len);
            mqtt_publish_local_enroll(enrolled_id, feature_ptr, out_jpeg, out_len);
            free(out_jpeg);
            // Lưu enrolled_id để sau khi server trả về face_id thật
            s_pending_local_enrolled_id.store((int)enrolled_id);
            ESP_LOGI("ENROLL", "Pending enrolled_id=%d, chờ server xác nhận...", enrolled_id);
          } else {
            ESP_LOGW("ENROLL", "local_enroll: fmt2jpg failed, skip publish");
          }
        } else {
          ESP_LOGW("ENROLL", "local_enroll: MQTT not connected, skip publish");
        }
      } else {
        // Server enroll → format cũ
        mqtt_publish_enroll_done(face_id, feature_ptr);
      }
    }
  }

  // Free buffers
  if (jpeg_buf_to_free) heap_caps_free(jpeg_buf_to_free);
  if (rgb_buf)          heap_caps_free(rgb_buf);
  vTaskDelete(NULL);
}

void ai_set_enable(bool enable) {
  s_ai_enable.store(enable);
  ESP_LOGI(TAG, "AI %s", enable ? "ENABLED" : "DISABLED");
}

bool ai_is_enable(void) { return s_ai_enable.load(); }

esp_err_t ai_delete_face(uint16_t server_face_id) {
  if (!s_embedding) {
    return ESP_ERR_INVALID_STATE;
  }
  int enrolled_id = find_enrolled_id_by_server_face_id(server_face_id);
  if (enrolled_id == -1) {
    ESP_LOGW(TAG,
             "Không tìm thấy enrolled_id tương ứng với server_face_id = %d",
             server_face_id);
    return ESP_ERR_NOT_FOUND;
  }
  esp_err_t ret = ESP_FAIL;
  if (xSemaphoreTake(ai_mutex, portMAX_DELAY) == pdTRUE) {
    ret = s_embedding->delete_feat(enrolled_id);
    ESP_LOGI(TAG, "%d",  s_embedding->get_num_feats());
    xSemaphoreGive(ai_mutex);
  }
  if (ret == ESP_OK) {
    delete_face_mapping(enrolled_id);
    delete_user_from_csv(server_face_id);
  }
  return ret;
}

/**
 * @brief Nhận face_id thật từ server (return_regis), cập nhật mapping
 *        enrolled_id (local model) → newServerFaceId.
 *
 * Gọi sau khi server gửi { "cmd": "return_regis", "face_id": newServerFaceId }.
 */
esp_err_t ai_remap_local_enroll(int new_server_face_id) {
  int enrolled_id = s_pending_local_enrolled_id.load();
  if (enrolled_id < 0) {
    ESP_LOGW(TAG, "ai_remap_local_enroll: không có pending enrolled_id");
    return ESP_ERR_INVALID_STATE;
  }

  ESP_LOGI(TAG, "Remap: enrolled_id=%d → server_face_id=%d",
           enrolled_id, new_server_face_id);

  // Xóa mapping placeholder cũ (face_id=9001)
  delete_face_mapping(enrolled_id);
  delete_user_from_csv(9001);

  // Tạo mapping mới với face_id thật từ server
  save_face_mapping(enrolled_id, new_server_face_id);
  save_user_to_csv(new_server_face_id, new_server_face_id, "LocalUser");

  // Xóa pending sau khi đã map xong
  s_pending_local_enrolled_id.store(-1);

  ESP_LOGI(TAG, "Remap hoàn tất: enrolled_id=%d ↔ server_face_id=%d",
           enrolled_id, new_server_face_id);
  return ESP_OK;
}

void ai_noti_handler(int best_face_id) {
  static int64_t last_noti_time_us = -10000000;
  static int last_sent_face_id = -99;
  int64_t now_us = esp_timer_get_time();

  // Bỏ qua cooldown 5s nếu sự kiện hiện tại là nhận diện khuôn mặt thành công (accept)
  // và ID khuôn mặt khác với ID đã gửi thành công trước đó (để tránh spam trùng lặp).
  bool bypass_cooldown = (best_face_id != -1 && best_face_id != last_sent_face_id);

  if (!bypass_cooldown && (now_us - last_noti_time_us < 10000000)) {
    ESP_LOGI("AI_NOTI", "Bỏ qua thông báo (cooldown 10s)");
    return;
  }
  last_noti_time_us = now_us;
  last_sent_face_id = best_face_id;

  time_t now;
  time(&now);

  int server_face_id = -1;
  if (best_face_id != -1) {
    server_face_id = get_server_id_by_enroll_id(best_face_id);
    // if (server_face_id != -1) {
    //   char temp_label[64] = {0};
    //   if (!lookup_user_by_face_id(server_face_id, server_user_id, temp_label, sizeof(temp_label))) {
    //     server_user_id = server_face_id; // fallback
    //   }
    // } else {
    //   server_user_id = best_face_id; // fallback
    // }
  }

  if (mqtt_is_connected()) {
    mqtt_publish_unlock_event(server_face_id, (uint32_t)now);
  } else {
    save_offline_log(server_face_id, (uint32_t)now);
  }
}

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