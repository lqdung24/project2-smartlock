#include "qr_scanner.hpp"
#include "quirc.h"
#include "esp_log.h"
#include <cstring>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "camera_handler.h"

static const char *TAG = "QR_PROC";

QrProcessor::QrProcessor() : m_quircObj(nullptr), m_callback(nullptr), m_width(0), m_height(0) {}

QrProcessor::~QrProcessor() { end(); }

bool QrProcessor::begin(int width, int height, QrCallback callback)
{
    m_width = width;
    m_height = height;
    m_callback = callback;

    m_quircObj = quirc_new();
    if (!m_quircObj)
        return false;

    if (quirc_resize(m_quircObj, m_width, m_height) < 0)
    {
        end();
        return false;
    }
    return true;
}

bool QrProcessor::decodeFrame(const uint8_t *grayBuffer, int length)
{
    if (!m_quircObj)
        return false;

    // 1. Bơm dữ liệu vào vùng đệm nội bộ
    int w, h;
    uint8_t *quirc_buf = quirc_begin(m_quircObj, &w, &h);
    std::memcpy(quirc_buf, grayBuffer, length);

    // Hệ thống thực hiện Giai đoạn 1 & 2 (Nhị phân hóa và tìm ô định vị) khi gọi quirc_end
    quirc_end(m_quircObj);

    // 🎯 KIỂM TRA GIAI ĐOẠN 2: Có tìm thấy hình dáng mã QR không?
    int count = quirc_count(m_quircObj);
    if (count <= 0)
    {
        // Log này hiện ra nghĩa là: Chip KHÔNG nhận diện được 3 ô vuông góc (do lóa hoặc mờ tiêu cự)
        ESP_LOGD("QR_DEBUG", "[Giai đoạn 2] Thất bại: Không tìm thấy ô vuông định vị nào trong ảnh.");
        return false;
    }

    ESP_LOGI("QR_DEBUG", "[Giai đoạn 2] Ngon: Phát hiện %d vùng có cấu trúc giống mã QR!", count);

    struct quirc_code code;
    struct quirc_data data;

    // Giai đoạn 3: Trích xuất và nắn thẳng khung hình
    quirc_extract(m_quircObj, 0, &code);
    ESP_LOGI("QR_DEBUG", "[Giai đoạn 3] Đã lập lưới ma trận thành công. Kích thước lưới: %d x %d ô vuông.", code.size, code.size);

    // Giai đoạn 4: Giải mã toán học
    quirc_decode_error_t err = quirc_decode(&code, &data);
    if (err == QUIRC_SUCCESS)
    {
        if (m_callback)
        {
            m_callback(std::string(reinterpret_cast<char *>(data.payload)));
        }
        return true;
    }
    else
    {
        // 🎯 LOG CHÍ MẠNG: Nói cho mày biết tại sao lưới có mà dịch không ra chữ
        // Ví dụ: Lỗi lỗi checksum, lỗi định dạng (QUIRC_ERROR_DATA_ECC, QUIRC_ERROR_UNKNOWN_FORMAT...)
        ESP_LOGE("QR_DEBUG", "[Giai đoạn 4] Thất bại: Tìm thấy QR nhưng LỖI GIẢI MÃ TOÁN HỌC: %s", quirc_strerror(err));
    }

    return false;
}

void QrProcessor::end()
{
    if (m_quircObj)
    {
        quirc_destroy(m_quircObj);
        m_quircObj = nullptr;
    }
}

// Tạo một hàm Task bọc ngoài logic quét QR
void qr_scanner_freertos_task(void *pvParameters)
{
    ESP_LOGW(TAG, "=== CHẾ ĐỘ QUÉT QR TỪ ẢNH RGB ĐÃ ĐƯỢC THẢ XÍCH VÀO TASK ===");

    QrProcessor *qrProc = new QrProcessor();
    if (!qrProc->begin(320, 240, [](const std::string &payload)
                       { ESP_LOGW(TAG, "🎯 ĐÃ ĐỌC ĐƯỢC QR TRONG TASK: %s", payload.c_str()); }))
    {
        ESP_LOGE(TAG, "Không đủ RAM tạo bộ xử lý QR!");
        delete qrProc;
        vTaskDelete(NULL);
    }

    uint32_t gray_buf_size = 320 * 240;
    // Dùng mã này để ép cấp phát mảng tạm này vào hẳn PSRAM cho an toàn, tránh cướp RAM nội bộ
    uint8_t *gray_buf = (uint8_t *)heap_caps_malloc(gray_buf_size, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);

    if (!gray_buf)
    {
        // Nếu không có PSRAM, dùng malloc thường nhưng cần check kỹ RAM
        gray_buf = (uint8_t *)malloc(gray_buf_size);
    }

    if (!gray_buf)
    {
        ESP_LOGE(TAG, "Thất bại cấp phát mảng ảnh xám trung gian!");
        qrProc->end();
        delete qrProc;
        vTaskDelete(NULL);
    }
    int counter = 0;

    while (true)
    {
        counter++;
        camera_fb_t *fb = camera_capture(); // Gọi lấy frame an toàn bên trong Task
        if (fb)
        {
            counter %= 30;
            if (counter == 0)
            {
                // 🎯 LOG CHÍ MẠNG: Kiểm tra kích thước thực tế con mắt Camera OV3660 đang phun ra
                ESP_LOGI(TAG, "[Task-Log] Lấy Frame thành công: Định dạng=%d, Độ dài=%zu bytes, Rộng=%zu, Cao=%zu",
                         fb->format, fb->len, fb->width, fb->height);
            }

            // Kiểm tra kích thước chống tràn biên bộ nhớ
            if (fb->format == PIXFORMAT_RGB565 && fb->len >= (gray_buf_size * 2))
            {
                uint16_t *rgb_pixels = (uint16_t *)fb->buf;

                for (int i = 0; i < gray_buf_size; i++)
                {
                    uint16_t rgb565 = rgb_pixels[i];
                    uint8_t r = ((rgb565 >> 11) & 0x1F) << 3;
                    uint8_t g = ((rgb565 >> 5) & 0x3F) << 2;
                    uint8_t b = (rgb565 & 0x1F) << 3;

                    gray_buf[i] = (uint8_t)(0.299f * r + 0.587f * g + 0.114f * b);
                }

                bool isSuccess = qrProc->decodeFrame(gray_buf, gray_buf_size);
                camera_release(fb); // Giải phóng frame ngay

                if (isSuccess)
                {
                    ESP_LOGI(TAG, "Quét QR thành công! Giải phóng Task.");
                    break;
                }
            }
            else
            {
                ESP_LOGE(TAG, "Định dạng không khớp RGB565 hoặc Kích thước ảnh thực tế (%zu) sai lệch cấu hình QVGA!", fb->len);
                camera_release(fb);
                break;
            }
        }
        vTaskDelay(pdMS_TO_TICKS(40)); // Nghỉ 40ms (~25 FPS) để FreeRTOS dọn dẹp và nạp lại Watchdog
    }

    // Dọn dẹp dứt điểm trước khi hủy Task
    free(gray_buf);
    qrProc->end();
    delete qrProc;

    ESP_LOGW(TAG, "=== TASK QUÉT QR TỰ HỦY THÀNH CÔNG ===");
    vTaskDelete(NULL); // Lệnh tự sát an toàn của một FreeRTOS Task
}