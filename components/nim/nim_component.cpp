#include "nim_component.h"
#include "esphome/core/log.h"
#include "esphome/core/application.h"

#if defined(USE_ESP32) || defined(ESP32)
#include <esp_system.h>
#endif

#ifdef USE_SENSOR
#include "esphome/components/sensor/sensor.h"
#endif
#ifdef USE_BINARY_SENSOR
#include "esphome/components/binary_sensor/binary_sensor.h"
#endif
#ifdef USE_SWITCH
#include "esphome/components/switch/switch.h"
#endif
#ifdef USE_TEXT_SENSOR
#include "esphome/components/text_sensor/text_sensor.h"
#endif

static const char *const TAG = "nim";

extern "C" {
  void NimMain(void) __attribute__((weak));
  void nim_on_setup(void) __attribute__((weak));
  void nim_on_loop(void) __attribute__((weak));

  void nim_esp_log_i(const char *tag, const char *msg) {
    esphome::esp_log_printf_(ESPHOME_LOG_LEVEL_INFO, tag, __LINE__, "%s", msg);
  }

  void nim_esp_log_w(const char *tag, const char *msg) {
    esphome::esp_log_printf_(ESPHOME_LOG_LEVEL_WARN, tag, __LINE__, "%s", msg);
  }

  void nim_esp_log_e(const char *tag, const char *msg) {
    esphome::esp_log_printf_(ESPHOME_LOG_LEVEL_ERROR, tag, __LINE__, "%s", msg);
  }

  void nim_esp_log_d(const char *tag, const char *msg) {
    esphome::esp_log_printf_(ESPHOME_LOG_LEVEL_DEBUG, tag, __LINE__, "%s", msg);
  }

  uint32_t nim_esp_millis(void) {
    return esphome::millis();
  }

  uint32_t nim_esp_micros(void) {
    return esphome::micros();
  }

  void nim_esp_delay(uint32_t ms) {
    esphome::delay(ms);
  }

  void nim_esp_yield(void) {
    esphome::delay(0);
  }

  void nim_esp_feed_wdt(void) {
    esphome::App.feed_wdt();
  }

  uint32_t nim_esp_get_free_heap(void) {
  #if defined(USE_ESP32) || defined(ESP32)
    return esp_get_free_heap_size();
  #else
    return 0;
  #endif
  }

  void nim_esp_reboot(void) {
    esphome::App.safe_reboot();
  }

  bool esphome_nim_publish_sensor(const char *entity_id, float value) {
  #ifdef USE_SENSOR
    for (auto *s : esphome::App.get_sensors()) {
      if (s != nullptr && (s->get_name() == entity_id || s->get_object_id() == entity_id)) {
        s->publish_state(value);
        return true;
      }
    }
  #endif
    return false;
  }

  bool esphome_nim_publish_binary_sensor(const char *entity_id, bool value) {
  #ifdef USE_BINARY_SENSOR
    for (auto *bs : esphome::App.get_binary_sensors()) {
      if (bs != nullptr && (bs->get_name() == entity_id || bs->get_object_id() == entity_id)) {
        bs->publish_state(value);
        return true;
      }
    }
  #endif
    return false;
  }

  bool esphome_nim_publish_switch(const char *entity_id, bool value) {
  #ifdef USE_SWITCH
    for (auto *sw : esphome::App.get_switches()) {
      if (sw != nullptr && (sw->get_name() == entity_id || sw->get_object_id() == entity_id)) {
        sw->publish_state(value);
        return true;
      }
    }
  #endif
    return false;
  }

  bool esphome_nim_publish_text_sensor(const char *entity_id, const char *value) {
  #ifdef USE_TEXT_SENSOR
    for (auto *ts : esphome::App.get_text_sensors()) {
      if (ts != nullptr && (ts->get_name() == entity_id || ts->get_object_id() == entity_id)) {
        ts->publish_state(value);
        return true;
      }
    }
  #endif
    return false;
  }
}

namespace esphome {
namespace nim {

void NimComponent::setup() {
  ESP_LOGI(TAG, "Initializing Nim runtime...");
  if (NimMain) {
    NimMain();
  }
  if (nim_on_setup) {
    nim_on_setup();
  }
}

void NimComponent::loop() {
  if (nim_on_loop) {
    nim_on_loop();
  }
}

void NimComponent::dump_config() {
  ESP_LOGCONFIG(TAG, "Nim ESPHome Component initialized");
}

}  // namespace nim
}  // namespace esphome
