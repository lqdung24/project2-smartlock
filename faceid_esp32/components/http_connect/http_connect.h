#ifndef HTTP_CONNECT_H
#define HTTP_CONNECT_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C"
{
#endif

    /* =========================================================
     * HTTP Configuration
     * =========================================================
     */

#define HTTP_DEFAULT_TIMEOUT_MS 5000

    /* =========================================================
     * HTTP Request Types
     * =========================================================
     */

    typedef enum
    {
        HTTP_CONNECT_METHOD_GET,
        HTTP_CONNECT_METHOD_POST,
        HTTP_CONNECT_METHOD_PUT,
        HTTP_CONNECT_METHOD_DELETE,
        HTTP_CONNECT_METHOD_PATCH
    } http_method_t;

    /* =========================================================
     * HTTP Response Structure
     * =========================================================
     */

    typedef struct
    {
        int status_code;
        char *response_body;
        int response_len;
        size_t response_capacity;
    } http_response_t;

    /* =========================================================
     * Public Functions
     * =========================================================
     */

    /**
     * @brief Initialize HTTP client
     */
    void http_client_init(void);

    /**
     * @brief Perform HTTP request
     *
     * @param method HTTP method (GET, POST, etc.)
     * @param url Target URL
     * @param body Request body (NULL for GET requests)
     * @param response Pointer to response structure
     * @return true if successful, false otherwise
     */
    bool http_request(http_method_t method, const char *url,
                      const char *body, http_response_t *response);

    /**
     * @brief Perform HTTP GET request
     *
     * @param url Target URL
     * @param response Pointer to response structure
     * @return true if successful, false otherwise
     */
    bool http_get(const char *url, http_response_t *response);

    /**
     * @brief Perform HTTP POST request
     *
     * @param url Target URL
     * @param body Request body
     * @param response Pointer to response structure
     * @return true if successful, false otherwise
     */
    bool http_post(const char *url, const char *body, http_response_t *response);

    /**
     * @brief Download image from URL to PSRAM
     *
     * @param url Image URL
     * @param out_buffer Pointer to store PSRAM buffer address (caller takes ownership)
     * @param out_size Pointer to store image size in bytes
     * @return true if successful, false otherwise
     *
     * @note The returned buffer is allocated in PSRAM and should be freed by the caller.
     */
    bool http_download_image(const char *url, uint8_t **out_buffer, size_t *out_size);

    /**
     * @brief Free HTTP response resources
     *
     * @param response Pointer to response structure
     */
    void http_response_free(http_response_t *response);

    /**
     * @brief Cleanup HTTP client
     */
    void http_client_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif /* HTTP_CONNECT_H */
