#ifndef QR_PROCESSOR_HPP
#define QR_PROCESSOR_HPP

#include <string>
#include <functional>
#include <cstdint>

struct quirc;

class QrProcessor
{
public:
    using QrCallback = std::function<void(const std::string &payload)>;

    QrProcessor();
    ~QrProcessor();

    // Khởi tạo bộ đệm giải mã dựa trên kích thước ảnh của Camera cấp vào
    bool begin(int width, int height, QrCallback callback);

    // 🎯 HÀM CHÍMẠNG: Nhận vào con trỏ buffer ảnh xám thô và kích thước để giải mã
    bool decodeFrame(const uint8_t *grayBuffer, int length);

    void end();

private:
    struct quirc *m_quircObj;
    QrCallback m_callback;
    int m_width;
    int m_height;
};

void qr_scanner_freertos_task(void *pvParameters);

#endif // QR_PROCESSOR_HPP