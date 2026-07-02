#pragma once
#include <stdint.h>
#include <stddef.h>

#define MAX_USERS 100
#define MAX_FACES 500

struct __attribute__((packed)) UserRecord {
    char name[30];         // Tên user (giới hạn 30 ký tự)
    uint8_t role;          // Quyền: 0 = Admin, 1 = User thường
    bool is_active;        // Trạng thái kích hoạt
};

struct __attribute__((packed)) UserFaceMap {
    int16_t user_id;
};

struct __attribute__((packed)) OfflineLogEntry {
    int32_t user_id;
    uint32_t timestamp;
};

extern UserRecord user_db[MAX_USERS];
extern UserFaceMap user_face_map[MAX_FACES];
extern int current_user_count;

void init_littlefs();
void load_users_from_flash();
void save_all_users_to_flash();
void load_face_mappings_from_flash();
void save_face_mappings_to_flash();
void save_user_to_db(int user_id, const char* name, uint8_t role);
void save_face_mapping(int face_id, int user_id);
int get_server_id_by_enroll_id(int enroll_id);
void delete_face_mapping(int face_id);
void save_user_to_csv(int face_id, int user_id, const char* label);
bool lookup_user_by_face_id(int server_face_id, int &out_user_id, char *out_label, size_t label_max_len);
void delete_user_from_csv(int server_face_id);
int find_enrolled_id_by_server_face_id(int server_face_id);
void save_offline_log(int32_t user_id, uint32_t timestamp);
