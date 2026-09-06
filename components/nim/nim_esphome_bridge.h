#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "esphome/core/log.h"
#include "esphome/core/hal.h"
#include "esphome/core/application.h"

#if defined(USE_ESP32) || defined(ESP32)
#include <esp_system.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

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

inline void nim_esp_yield(void) {
  esphome::delay(0);
}

inline void nim_esp_feed_wdt(void) {
  esphome::App.feed_wdt();
}

inline uint32_t nim_esp_get_free_heap(void) {
#if defined(USE_ESP32) || defined(ESP32)
  return esp_get_free_heap_size();
#else
  return 0;
#endif
}

inline void nim_esp_reboot(void) {
  esphome::App.safe_reboot();
}

#ifdef __cplusplus
}
#endif
