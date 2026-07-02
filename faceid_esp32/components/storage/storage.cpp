#include "storage.hpp"
#include <sys/dirent.h>
#include <esp_log.h>
#include <sys/stat.h>
#include <esp_littlefs.h>
#include <string.h>
#include <unistd.h>

static const char *TAG = "Storage";

UserRecord user_db[MAX_USERS];
UserFaceMap user_face_map[MAX_FACES];
int current_user_count = 0;

bool file_exists(const char* path) {
    struct stat st;
    return (stat(path, &st) == 0);
}

void load_users_from_flash() {
    // Set default inactive values
    for (int i = 0; i < MAX_USERS; i++) {
        user_db[i].is_active = false;
        user_db[i].name[0] = '\0';
        user_db[i].role = 1; // 1 = User thường
    }
    current_user_count = 0;

    FILE* f = fopen("/face/user_map.bin", "r");
    if (f != NULL) {
        fread(user_db, sizeof(UserRecord), MAX_USERS, f);
        fclose(f);
        
        // Count active users
        for (int i = 0; i < MAX_USERS; i++) {
            if (user_db[i].is_active) {
                current_user_count++;
            }
        }
        ESP_LOGI(TAG, "Đã tải %d users active lên RAM", current_user_count);
    } else {
        ESP_LOGI(TAG, "Chưa có file user_map.bin, khởi tạo mặc định");
    }
}

void save_all_users_to_flash() {
    FILE* f = fopen("/face/user_map.bin", "w");
    if (f != NULL) {
        fwrite(user_db, sizeof(UserRecord), MAX_USERS, f);
        fclose(f);
        ESP_LOGI(TAG, "Đã lưu toàn bộ user database vào Flash");
    } else {
        ESP_LOGE(TAG, "Không thể mở file user_map.bin để ghi!");
    }
}

void load_face_mappings_from_flash() {
    // Set default mapped values to -1
    for (int i = 0; i < MAX_FACES; i++) {
        user_face_map[i].user_id = -1;
    }

    FILE* f = fopen("/face/face_map.bin", "r");
    if (f != NULL) {
        fread(user_face_map, sizeof(UserFaceMap), MAX_FACES, f);
        fclose(f);
        ESP_LOGI(TAG, "Đã tải danh sách ánh xạ face -> user từ Flash");
    } else {
        ESP_LOGI(TAG, "Chưa có file face_map.bin, khởi tạo mặc định rỗng (-1)");
    }
}

void save_face_mappings_to_flash() {
    FILE* f = fopen("/face/face_map.bin", "w");
    if (f != NULL) {
        fwrite(user_face_map, sizeof(UserFaceMap), MAX_FACES, f);
        fclose(f);
        ESP_LOGI(TAG, "Đã lưu danh sách ánh xạ face -> user vào Flash");
    } else {
        ESP_LOGE(TAG, "Không thể mở file face_map.bin để ghi!");
    }
}

void save_user_to_db(int user_id, const char* name, uint8_t role) {
    if (user_id >= 0 && user_id < MAX_USERS) {
        strncpy(user_db[user_id].name, name, sizeof(user_db[user_id].name) - 1);
        user_db[user_id].name[sizeof(user_db[user_id].name) - 1] = '\0';
        user_db[user_id].role = role;
        user_db[user_id].is_active = true;
        save_all_users_to_flash();
        
        // Recount active users
        current_user_count = 0;
        for (int i = 0; i < MAX_USERS; i++) {
            if (user_db[i].is_active) current_user_count++;
        }
        ESP_LOGI(TAG, "Tạo/Cập nhật User thành công: id=%d, name=%s, active=true", user_id, name);
    } else {
        ESP_LOGE(TAG, "User ID %d vượt quá giới hạn mảng!", user_id);
    }
}

void save_face_mapping(int face_id, int user_id) {
    if (face_id >= 0 && face_id < MAX_FACES) {
        user_face_map[face_id].user_id = user_id;
        save_face_mappings_to_flash();
        ESP_LOGI(TAG, "Ghi nhận ánh xạ thành công: face_id=%d -> user_id=%d", face_id, user_id);
    } else {
        ESP_LOGE(TAG, "Face ID %d vượt quá giới hạn mảng!", face_id);
    }
}

int get_server_id_by_enroll_id(int enroll_id) {
    if (enroll_id >= 0 && enroll_id < MAX_FACES) {
        return user_face_map[enroll_id].user_id;
    }
    return -1;
}

void init_littlefs() {
    esp_vfs_littlefs_conf_t conf = {}; 
    
    conf.base_path = "/face";
    conf.partition_label = "face";
    conf.format_if_mount_failed = true;
    conf.dont_mount = false;
    
    esp_err_t ret = esp_vfs_littlefs_register(&conf);
    
    if (ret != ESP_OK) {
        if (ret == ESP_FAIL) {
            ESP_LOGE("LittleFS", "Mount hoặc Format phân vùng thất bại!");
        } else if (ret == ESP_ERR_NOT_FOUND) {
            ESP_LOGE("LittleFS", "Không tìm thấy phân vùng mang tên 'face' trong CSV!");
        } else {
            ESP_LOGE("LittleFS", "Lỗi khởi tạo LittleFS (%s)", esp_err_to_name(ret));
        }
        return;
    }

    DIR* dir = opendir("/face");
    if (dir == NULL) {
        ESP_LOGE("LittleFS", "Không thể mở thư mục gốc!");
        return;
    }

    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        ESP_LOGI("LittleFS", "file: %s", entry->d_name);
    }
    closedir(dir);

    // Kiểm tra và khởi tạo file users.csv
    if (!file_exists("/face/users.csv")) {
        ESP_LOGI("LittleFS", "File users.csv chưa có. Tiến hành tạo mới...");
        FILE* f = fopen("/face/users.csv", "w");
        if (f != NULL) {
            fprintf(f, "faceid,user_id,label\n");
            fclose(f);
            ESP_LOGI("LittleFS", "Khởi tạo file users.csv thành công!");
        }
    }

    // Kiểm tra và khởi tạo file log offline
    if (!file_exists("/face/offline_log.bin")) {
        ESP_LOGI("LittleFS", "File offline_log.bin chưa có. Tiến hành tạo mới...");
        FILE* f = fopen("/face/offline_log.bin", "w");
        if (f != NULL) {
            fclose(f);
            ESP_LOGI("LittleFS", "Khởi tạo file offline_log.bin thành công!");
        }
    }

    // Tải dữ liệu từ flash lên RAM
    load_users_from_flash();
    load_face_mappings_from_flash();
}



void delete_face_mapping(int face_id) {
    if (face_id >= 0 && face_id < MAX_FACES) {
        user_face_map[face_id].user_id = -1;
        save_face_mappings_to_flash();
        ESP_LOGI(TAG, "Đã xóa ánh xạ cho face_id=%d", face_id);
    } else {
        ESP_LOGE(TAG, "Face ID %d vượt quá giới hạn mảng!", face_id);
    }
}

void save_user_to_csv(int face_id, int user_id, const char* label) {
    FILE* f = fopen("/face/users.csv", "a");
    if (f != NULL) {
        fprintf(f, "%d,%d,%s\n", face_id, user_id, label);
        fclose(f);
        ESP_LOGI("Storage", "Đã ghi record vào users.csv: faceid=%d, user_id=%d, label=%s", face_id, user_id, label);
    } else {
        ESP_LOGE("Storage", "Không thể mở file users.csv để ghi!");
    }
}

bool lookup_user_by_face_id(int server_face_id, int &out_user_id, char *out_label, size_t label_max_len) {
    FILE* f = fopen("/face/users.csv", "r");
    if (f == NULL) {
        return false;
    }
    
    char line[128];
    // Read header line
    if (fgets(line, sizeof(line), f) == NULL) {
        fclose(f);
        return false;
    }
    
    bool found = false;
    while (fgets(line, sizeof(line), f) != NULL) {
        int csv_face_id = -1;
        int csv_user_id = -1;
        char csv_label[64] = {0};
        
        int parsed = sscanf(line, "%d,%d,%63[^,\n\r]", &csv_face_id, &csv_user_id, csv_label);
        if (parsed >= 2 && csv_face_id == server_face_id) {
            out_user_id = csv_user_id;
            if (parsed >= 3) {
                strncpy(out_label, csv_label, label_max_len - 1);
                out_label[label_max_len - 1] = '\0';
            } else {
                strncpy(out_label, "Unknown", label_max_len - 1);
                out_label[label_max_len - 1] = '\0';
            }
            found = true;
            break;
        }
    }
    fclose(f);
    return found;
}

void delete_user_from_csv(int server_face_id) {
    FILE* f = fopen("/face/users.csv", "r");
    if (f == NULL) return;
    
    FILE* temp = fopen("/face/users_temp.csv", "w");
    if (temp == NULL) {
        fclose(f);
        return;
    }
    
    char line[128];
    // Copy header
    if (fgets(line, sizeof(line), f) != NULL) {
        fputs(line, temp);
    }
    
    while (fgets(line, sizeof(line), f) != NULL) {
        int csv_face_id = -1;
        if (sscanf(line, "%d,", &csv_face_id) == 1 && csv_face_id == server_face_id) {
            continue; // skip deleted line
        }
        fputs(line, temp);
    }
    
    fclose(f);
    fclose(temp);
    
    unlink("/face/users.csv");
    rename("/face/users_temp.csv", "/face/users.csv");
    ESP_LOGI("Storage", "Đã xóa record khỏi users.csv cho faceid=%d", server_face_id);
}

int find_enrolled_id_by_server_face_id(int server_face_id) {
    for (int i = 0; i < MAX_FACES; i++) {
        if (user_face_map[i].user_id == server_face_id) {
            return i;
        }
    }
    return -1;
}

void save_offline_log(int32_t user_id, uint32_t timestamp) {
    FILE* f = fopen("/face/offline_log.bin", "a");
    if (f != NULL) {
        OfflineLogEntry entry;
        entry.user_id = user_id;
        entry.timestamp = timestamp;
        fwrite(&entry, sizeof(OfflineLogEntry), 1, f);
        fclose(f);
        ESP_LOGI("Storage", "Đã ghi log offline thành công: user_id=%ld, timestamp=%lu", (long)user_id, (unsigned long)timestamp);
    } else {
        ESP_LOGE("Storage", "Không thể mở file offline_log.bin để ghi!");
    }
}