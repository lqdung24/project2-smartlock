#include "tft_display.hpp"
#include "esp_lcd_panel_io.h"
#include "esp_lcd_panel_vendor.h"
#include "esp_lcd_panel_ops.h"
#include "driver/spi_master.h"
#include "esp_lcd_ili9341.h"
#include "esp_log.h"
#include <cstring>
#include "esp_heap_caps.h" // Thêm thư viện này ở đầu file để dùng hàm cấp phát đặc biệt

#define CHUNK_LINES 20

static const char *TAG = "tft_component";
static esp_lcd_panel_handle_t panel_handle = NULL;

void tft_display_init(void)
{
    ESP_LOGI(TAG, "Initializing SPI bus...");
    spi_bus_config_t buscfg;
    std::memset(&buscfg, 0, sizeof(buscfg));
    buscfg.sclk_io_num = PIN_NUM_SCLK;
    buscfg.mosi_io_num = PIN_NUM_MOSI;
    buscfg.miso_io_num = PIN_NUM_MISO;
    buscfg.quadwp_io_num = -1;
    buscfg.quadhd_io_num = -1;
    
    // 1. SỬA: Giới hạn dung lượng truyền gói nhỏ để tối ưu GDMA (ví dụ 20 dòng ảnh)
    buscfg.max_transfer_sz = 320 * 20 * 2; 
    
    // 2. SỬA: Thêm cờ bắt buộc để kích hoạt GDMA bốc RAM ngoài (PSRAM)
    buscfg.flags = SPICOMMON_BUSFLAG_MASTER; 

    esp_err_t ret = spi_bus_initialize(LCD_HOST, &buscfg, SPI_DMA_CH_AUTO);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "SPI bus initialization failed!");
        return;
    }

    ESP_LOGI(TAG, "Configuring LCD IO...");
    esp_lcd_panel_io_handle_t io_handle = NULL;
    esp_lcd_panel_io_spi_config_t io_config;
    std::memset(&io_config, 0, sizeof(io_config));
    io_config.dc_gpio_num = PIN_NUM_LCD_DC;
    io_config.cs_gpio_num = PIN_NUM_LCD_CS;
    io_config.pclk_hz = 20 * 1000 * 1000; // Để tạm 20MHz test độ ổn định, sau này ngon có thể nâng lên 40MHz
    io_config.lcd_cmd_bits = 8;
    io_config.lcd_param_bits = 8;
    io_config.spi_mode = 0;
    io_config.trans_queue_depth = 10;
    esp_lcd_new_panel_io_spi((esp_lcd_spi_bus_handle_t)LCD_HOST, &io_config, &io_handle);

    ESP_LOGI(TAG, "Installing ILI9341 driver for TPM408...");
    esp_lcd_panel_dev_config_t panel_config;
    std::memset(&panel_config, 0, sizeof(panel_config));
    panel_config.reset_gpio_num = PIN_NUM_LCD_RST;
    panel_config.rgb_endian = LCD_RGB_ENDIAN_BGR; // ILI9341 thường dùng hệ BGR
    panel_config.bits_per_pixel = 16;             // RGB565 (16 bits)

    // Khởi tạo panel driver ILI9341
    esp_lcd_new_panel_ili9341(io_handle, &panel_config, &panel_handle);

    // 3. SỬA: Thực hiện reset và init panel phần cứng TRƯỚC
    esp_lcd_panel_reset(panel_handle);
    esp_lcd_panel_init(panel_handle);
    
    // 4. SỬA: Chỉ gọi hàm lật/xoay màn hình SAU KHI đã gọi hàm init thành công
    esp_lcd_panel_mirror(panel_handle, true, false); 
    
    esp_lcd_panel_disp_on_off(panel_handle, true);
    ESP_LOGI(TAG, "TFT Display initialized successfully.");
}

void tft_display_show_frame(uint16_t *cam_buf, int width, int height)
{
    if (panel_handle == NULL || cam_buf == NULL) return;

    // Khởi tạo một trạm trung chuyển nằm TRONG SRAM NỘI BỘ và HỖ TRỢ DMA
    // Sử dụng từ khóa static để chỉ cấp phát DUY NHẤT một lần khi chạy lần đầu, không bị rò rỉ RAM (Memory Leak)
    static uint16_t *sram_dma_buf = NULL;
    
    if (sram_dma_buf == NULL) {
        // Ép hệ thống cấp phát chuẩn 12.800 Bytes trong Internal SRAM hỗ trợ DMA
        sram_dma_buf = (uint16_t *)heap_caps_malloc(width * CHUNK_LINES * sizeof(uint16_t), MALLOC_CAP_DMA | MALLOC_CAP_INTERNAL);
        if (sram_dma_buf == NULL) {
            ESP_LOGE(TAG, "Critical: Failed to allocate SRAM DMA Buffer for transition!");
            return;
        }
    }

    // Vòng lặp cắt nhỏ khung hình từ PSRAM ra để đẩy đi
    for (int i = 0; i < height; i += CHUNK_LINES) {
        // Tính toán số dòng thực tế cần vẽ (đoạn cuối có thể ít hơn CHUNK_LINES)
        int lines_to_draw = (i + CHUNK_LINES > height) ? (height - i) : CHUNK_LINES;
        
        // Bước 1: CPU bốc dữ liệu từ con trỏ lỗi (PSRAM) sang vùng RAM nội (SRAM DMA)
        // Hàm memcpy ở tầng thấp của C chạy bằng lệnh assembly tối ưu nên cực kỳ nhanh, không lo tụt FPS
        std::memcpy(sram_dma_buf, &cam_buf[i * width], width * lines_to_draw * sizeof(uint16_t));
        
        // Bước 2: Đẩy dữ liệu đã được chuẩn hóa từ SRAM ra LCD qua DMA phần cứng
        // Vì sram_dma_buf nằm ở SRAM nội, driver SPI sẽ bốc thẳng đi mà không bao giờ đòi tạo thêm "priv TX buffer" nữa!
        esp_lcd_panel_draw_bitmap(panel_handle, 0, i, width, i + lines_to_draw, sram_dma_buf);
    }
}

void tft_test_red() {
    // 1. Chỉ cấp phát một bộ đệm nhỏ tương đương 20 dòng ảnh trong PSRAM (hoặc SRAM đều được)
    #define TEST_LINES 20
    uint16_t *test_color_buf = (uint16_t *)heap_caps_malloc(320 * TEST_LINES * sizeof(uint16_t), MALLOC_CAP_SPIRAM);
    
    if (test_color_buf != NULL) {
        // Đổ màu Đỏ (0xF800) vào block 20 dòng này
        for (int i = 0; i < 320 * TEST_LINES; i++) {
            test_color_buf[i] = 0xF800; 
        }
        
        ESP_LOGI(TAG, "Testing screen with RED color by chunks...");
        
        // 2. VÒNG LẶP CHÍ MẠNG: Cắt màn hình 240 dòng ra thành nhiều phát vẽ, mỗi phát vẽ đúng 20 dòng
        for (int y = 0; y < 240; y += TEST_LINES) {
            // Đẩy từng block 12.8KB đi. Kích thước này <= max_transfer_sz nên GDMA sẽ bốc thẳng từ PSRAM chạy vèo vèo!
            esp_lcd_panel_draw_bitmap(panel_handle, 0, y, 320, y + TEST_LINES, test_color_buf);
        }
        
        heap_caps_free(test_color_buf);
    }
}