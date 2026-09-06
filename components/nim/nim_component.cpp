#include "nim_component.h"
#include "esphome/core/log.h"
#include "esphome/core/application.h"

#if defined(USE_ESP32) || defined(ESP32)
#include <esp_system.h>
#include <driver/gpio.h>
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
#ifdef USE_I2C
#include "esphome/components/i2c/i2c_bus.h"
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

  void nim_gpio_pin_mode(uint8_t pin, uint8_t mode) {
  #if defined(USE_ESP32) || defined(ESP32)
    gpio_num_t gpin = (gpio_num_t)pin;
    if (mode == 1) {
      gpio_set_direction(gpin, GPIO_MODE_OUTPUT);
    } else {
      gpio_set_direction(gpin, GPIO_MODE_INPUT);
      if (mode == 2) {
        gpio_set_pull_mode(gpin, GPIO_PULLUP_ONLY);
      } else if (mode == 3) {
        gpio_set_pull_mode(gpin, GPIO_PULLDOWN_ONLY);
      } else {
        gpio_set_pull_mode(gpin, GPIO_FLOATING);
      }
    }
  #elif defined(USE_ARDUINO)
    if (mode == 1) pinMode(pin, OUTPUT);
    else if (mode == 2) pinMode(pin, INPUT_PULLUP);
    #ifdef INPUT_PULLDOWN
    else if (mode == 3) pinMode(pin, INPUT_PULLDOWN);
    #endif
    else pinMode(pin, INPUT);
  #endif
  }

  void nim_gpio_digital_write(uint8_t pin, bool val) {
  #if defined(USE_ESP32) || defined(ESP32)
    gpio_set_level((gpio_num_t)pin, val ? 1 : 0);
  #elif defined(USE_ARDUINO)
    digitalWrite(pin, val ? HIGH : LOW);
  #endif
  }

  bool nim_gpio_digital_read(uint8_t pin) {
  #if defined(USE_ESP32) || defined(ESP32)
    return gpio_get_level((gpio_num_t)pin) != 0;
  #elif defined(USE_ARDUINO)
    return digitalRead(pin) != LOW;
  #else
    return false;
  #endif
  }

  bool nim_i2c_write(uint8_t address, const uint8_t *data, size_t len) {
  #ifdef USE_I2C
    for (auto *comp : esphome::App.get_components()) {
      auto *bus = dynamic_cast<esphome::i2c::I2CBus *>(comp);
      if (bus != nullptr) {
        return bus->write(address, data, len) == esphome::i2c::ERROR_OK;
      }
    }
  #endif
    return false;
  }

  bool nim_i2c_read(uint8_t address, uint8_t *data, size_t len) {
  #ifdef USE_I2C
    for (auto *comp : esphome::App.get_components()) {
      auto *bus = dynamic_cast<esphome::i2c::I2CBus *>(comp);
      if (bus != nullptr) {
        return bus->read(address, data, len) == esphome::i2c::ERROR_OK;
      }
    }
  #endif
    return false;
  }

  bool nim_i2c_write_read(uint8_t address, const uint8_t *write_data, size_t write_len, uint8_t *read_data, size_t read_len) {
  #ifdef USE_I2C
    for (auto *comp : esphome::App.get_components()) {
      auto *bus = dynamic_cast<esphome::i2c::I2CBus *>(comp);
      if (bus != nullptr) {
        return bus->write_readv(address, write_data, write_len, read_data, read_len) == esphome::i2c::ERROR_OK;
      }
    }
  #endif
    return false;
  }

  class NimPrefProxy : public esphome::ESPPreferenceObject {
   public:
    NimPrefProxy(const esphome::ESPPreferenceObject &base) : esphome::ESPPreferenceObject(base) {}
    bool raw_save(const uint8_t *data, size_t len) {
      if (this->backend_ == nullptr) return false;
      return this->backend_->save(data, len);
    }
    bool raw_load(uint8_t *data, size_t len) {
      if (this->backend_ == nullptr) return false;
      return this->backend_->load(data, len);
    }
  };

  bool nim_esp_save_preference(uint32_t key, const void *data, size_t len) {
    if (esphome::global_preferences == nullptr || data == nullptr || len == 0) return false;
    auto pref = esphome::global_preferences->make_preference(len, key, true);
    NimPrefProxy proxy(pref);
    bool ok = proxy.raw_save(static_cast<const uint8_t *>(data), len);
    if (ok) {
      esphome::global_preferences->sync();
    }
    return ok;
  }

  bool nim_esp_load_preference(uint32_t key, void *data, size_t len) {
    if (esphome::global_preferences == nullptr || data == nullptr || len == 0) return false;
    auto pref = esphome::global_preferences->make_preference(len, key, true);
    NimPrefProxy proxy(pref);
    return proxy.raw_load(static_cast<uint8_t *>(data), len);
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
