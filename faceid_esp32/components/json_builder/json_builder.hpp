#pragma once
#include <stddef.h>
#include <event.hpp>
#include "human_face_recognition.hpp"
#include "cJSON.h"

void json_build_faces_event(const std::__cxx11::list<dl::detect::result_t> &faces,
                            char **out_str);

cJSON *parse_mqtt_json(const char *raw_data, int data_len);
void json_build_device_status(char **out);