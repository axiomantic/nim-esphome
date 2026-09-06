#pragma once

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

void nim_esp_log_i(const char *tag, const char *msg);
void nim_esp_log_w(const char *tag, const char *msg);
void nim_esp_log_e(const char *tag, const char *msg);
void nim_esp_log_d(const char *tag, const char *msg);

uint32_t nim_esp_millis(void);
uint32_t nim_esp_micros(void);
void nim_esp_delay(uint32_t ms);
void nim_esp_yield(void);
void nim_esp_feed_wdt(void);
uint32_t nim_esp_get_free_heap(void);
void nim_esp_reboot(void);

#ifdef __cplusplus
}
#endif
