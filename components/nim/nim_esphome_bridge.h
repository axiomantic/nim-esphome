#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

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

bool esphome_nim_publish_sensor(const char *entity_id, float value);
bool esphome_nim_publish_binary_sensor(const char *entity_id, bool value);
bool esphome_nim_publish_switch(const char *entity_id, bool value);
bool esphome_nim_publish_text_sensor(const char *entity_id, const char *value);

void nim_gpio_pin_mode(uint8_t pin, uint8_t mode);
void nim_gpio_digital_write(uint8_t pin, bool val);
bool nim_gpio_digital_read(uint8_t pin);

bool nim_i2c_write(uint8_t address, const uint8_t *data, size_t len);
bool nim_i2c_read(uint8_t address, uint8_t *data, size_t len);
bool nim_i2c_write_read(uint8_t address, const uint8_t *write_data, size_t write_len, uint8_t *read_data, size_t read_len);

bool nim_esp_save_preference(uint32_t key, const void *data, size_t len);
bool nim_esp_load_preference(uint32_t key, void *data, size_t len);

#ifdef __cplusplus
}
#endif
