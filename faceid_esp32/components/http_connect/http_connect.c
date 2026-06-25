#include "http_connect.h"
#include "esp_http_client.h"
#include "esp_log.h"
#include "esp_heap_caps.h"
#include "esp_crt_bundle.h"
#include <string.h>
#include <stdlib.h>

static const char *TAG = "HTTP_CONNECT";

/* =========================================================
 * Static Variables
 * =========================================================
 */

static esp_http_client_handle_t client = NULL;

/* =========================================================
 * Static Helper Functions
 * =========================================================
 */

static esp_err_t http_event_handler(esp_http_client_event_t *evt)
{
    http_response_t *response = (http_response_t *)evt->user_data;

    switch (evt->event_id)
    {
    case HTTP_EVENT_ON_DATA:
        if (response && response->response_body && evt->data && evt->data_len > 0)
        {
            const size_t max_response_size = 2 * 1024 * 1024 + 1;
            size_t required = (size_t)response->response_len + evt->data_len + 1;
            if (required > max_response_size)
            {
                ESP_LOGE(TAG, "http_event_handler: response too large (%zu bytes)", required);
                return ESP_FAIL;
            }
            if (required > response->response_capacity)
            {
                size_t new_capacity = response->response_capacity * 2;
                if (new_capacity < required)
                {
                    new_capacity = required;
                }
                if (new_capacity > max_response_size)
                {
                    new_capacity = max_response_size;
                }
                if (new_capacity < required)
                {
                    ESP_LOGE(TAG, "http_event_handler: capacity limit reached (%zu bytes)", required);
                    return ESP_FAIL;
                }
                char *new_buf = heap_caps_realloc(response->response_body,
                                                  new_capacity,
                                                  MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
                if (!new_buf)
                {
                    ESP_LOGE(TAG, "http_event_handler: realloc failed (%zu bytes)", new_capacity);
                    return ESP_FAIL;
                }
                response->response_body = new_buf;
                response->response_capacity = new_capacity;
            }
            memcpy(response->response_body + response->response_len, evt->data, evt->data_len);
            response->response_len += evt->data_len;
            response->response_body[response->response_len] = '\0';
        }
        break;
    case HTTP_EVENT_ON_FINISH:
        if (response && response->response_body)
        {
            response->response_body[response->response_len] = '\0';
        }
        break;
    default:
        break;
    }

    return ESP_OK;
}

static esp_http_client_method_t http_method_to_esp(http_method_t method)
{
    switch (method)
    {
    case HTTP_CONNECT_METHOD_GET:
        return HTTP_METHOD_GET;
    case HTTP_CONNECT_METHOD_POST:
        return HTTP_METHOD_POST;
    case HTTP_CONNECT_METHOD_PUT:
        return HTTP_METHOD_PUT;
    case HTTP_CONNECT_METHOD_DELETE:
        return HTTP_METHOD_DELETE;
    case HTTP_CONNECT_METHOD_PATCH:
        return HTTP_METHOD_PATCH;
    default:
        return HTTP_METHOD_GET;
    }
}

/* =========================================================
 * Public Functions Implementation
 * =========================================================
 */

void http_client_init(void)
{
    ESP_LOGI(TAG, "Initializing HTTP client");
    /* Client will be created per-request */
}

bool http_request(http_method_t method, const char *url,
                  const char *body, http_response_t *response)
{
    if (!url || !response)
    {
        ESP_LOGE(TAG, "Invalid parameters");
        return false;
    }

    /* Allocate buffer for response in PSRAM */
    response->response_capacity = 4096;
    response->response_body = (char *)heap_caps_malloc(
        response->response_capacity,
        MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
    if (!response->response_body)
    {
        ESP_LOGE(TAG, "Failed to allocate response buffer in PSRAM");
        esp_http_client_cleanup(client);
        return false;
    }
    response->response_len = 0;
    response->response_body[0] = '\0';

    esp_http_client_config_t config = {
        .url = url,
        .method = http_method_to_esp(method),
        .timeout_ms = HTTP_DEFAULT_TIMEOUT_MS,
        .event_handler = http_event_handler,
        .user_data = response,
        .crt_bundle_attach = esp_crt_bundle_attach, // Enable HTTPS/SSL support
    };

    if (client)
    {
        esp_http_client_cleanup(client);
        client = NULL;
    }
    client = esp_http_client_init(&config);
    if (!client)
    {
        ESP_LOGE(TAG, "Failed to initialize HTTP client");
        heap_caps_free(response->response_body);
        response->response_body = NULL;
        return false;
    }

    /* Set request body if provided */
    if (body)
    {
        esp_http_client_set_post_field(client, body, strlen(body));
        esp_http_client_set_header(client, "Content-Type", "application/json");
    }

    esp_err_t err = esp_http_client_perform(client);
    if (err != ESP_OK)
    {
        ESP_LOGE(TAG, "HTTP request failed: %s", esp_err_to_name(err));
        heap_caps_free(response->response_body);
        response->response_body = NULL;
        esp_http_client_cleanup(client);
        client = NULL;
        return false;
    }

    response->status_code = esp_http_client_get_status_code(client);
    ESP_LOGI(TAG,
             "status=%d content_length=%lld chunked=%d",
             response->status_code,
             esp_http_client_get_content_length(client),
             esp_http_client_is_chunked_response(client));

    esp_http_client_cleanup(client);
    client = NULL;
    ESP_LOGI(TAG, "HTTP request completed with status code: %d", response->status_code);

    return true;
}

bool http_get(const char *url, http_response_t *response)
{
    return http_request(HTTP_CONNECT_METHOD_GET, url, NULL, response);
}

bool http_post(const char *url, const char *body, http_response_t *response)
{
    return http_request(HTTP_CONNECT_METHOD_POST, url, body, response);
}

void http_response_free(http_response_t *response)
{
    if (response && response->response_body)
    {
        heap_caps_free(response->response_body);
        response->response_body = NULL;
        response->response_len = 0;
        response->response_capacity = 0;
    }
}

bool http_download_image(const char *url, uint8_t **out_buffer, size_t *out_size)
{
    if (!url || !out_buffer || !out_size)
    {
        ESP_LOGE(TAG, "http_download_image: Invalid parameters");
        return false;
    }

    http_response_t response = {0};

    // 1. HTTP GET request
    ESP_LOGI(TAG, "Downloading image from: %s", url);
    if (!http_get(url, &response))
    {
        ESP_LOGE(TAG, "http_download_image: HTTP GET failed");
        return false;
    }

    // 2. Check HTTP status code
    if (response.status_code != 200)
    {
        ESP_LOGE(TAG, "http_download_image: HTTP status %d (expected 200)", response.status_code);
        http_response_free(&response);
        return false;
    }

    // 3. Validate image size
    if (response.response_len <= 0 || response.response_len > 2 * 1024 * 1024)
    {
        // Max 2MB for image
        ESP_LOGE(TAG, "http_download_image: Invalid size %d bytes", response.response_len);
        http_response_free(&response);
        return false;
    }

    // 4. Transfer downloaded PSRAM buffer directly to caller
    *out_buffer = (uint8_t *)response.response_body;
    *out_size = response.response_len;

    response.response_body = NULL;
    response.response_len = 0;
    response.response_capacity = 0;

    ESP_LOGI(TAG, "http_download_image: Success! Size=%zu bytes", *out_size);
    return true;
}

void http_client_cleanup(void)
{
    if (client)
    {
        esp_http_client_cleanup(client);
        client = NULL;
    }
    ESP_LOGI(TAG, "HTTP client cleaned up");
}
