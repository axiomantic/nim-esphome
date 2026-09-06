#pragma once

#include <stdint.h>
#include "esphome/core/log.h"
#include "esphome/core/hal.h"

#ifdef __cplusplus
extern "C" {
#endif

// Bridge functions exposed to Nim
inline void nim_esp_log_i(const char *tag, const char *msg) {
  esp_log_printf_(ESPHOME_LOG_LEVEL_INFO, tag, __LINE__, "%s", msg);
}

inline void nim_esp_log_w(const char *tag, const char *msg) {
  esp_log_printf_(ESPHOME_LOG_LEVEL_WARN, tag, __LINE__, "%s", msg);
}

inline void nim_esp_log_e(const char *tag, const char *msg) {
  esp_log_printf_(ESPHOME_LOG_LEVEL_ERROR, tag, __LINE__, "%s", msg);
}

inline void nim_esp_log_d(const char *tag, const char *msg) {
  esp_log_printf_(ESPHOME_LOG_LEVEL_DEBUG, tag, __LINE__, "%s", msg);
}

inline uint32_t nim_esp_millis(void) {
  return esphome::millis();
}

inline uint32_t nim_esp_micros(void) {
  return esphome::micros();
}

inline void nim_esp_delay(uint32_t ms) {
  esphome::delay(ms);
}

#ifdef __cplusplus
}
#endif
