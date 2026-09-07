#include <span>
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
#ifdef USE_SELECT
#include "esphome/components/select/select.h"
#endif
#ifdef USE_NUMBER
#include "esphome/components/number/number.h"
#endif
#ifdef USE_BUTTON
#include "esphome/components/button/button.h"
#endif
#ifdef USE_I2C
#include "esphome/components/i2c/i2c_bus.h"
#endif

static const char *const TAG = "nim";

namespace {

inline bool entity_matches_id(const esphome::EntityBase *entity, const char *entity_id) {
  if (entity == nullptr || entity_id == nullptr) {
    return false;
  }
  if (entity->get_name() == entity_id) {
    return true;
  }
  char buf[esphome::OBJECT_ID_MAX_LEN];
  auto id_ref = entity->get_object_id_to(std::span<char, esphome::OBJECT_ID_MAX_LEN>(buf));
  return (id_ref == entity_id);
}

}  // namespace

namespace esphome {
namespace nim {
#ifdef USE_I2C
static i2c::I2CBus *s_i2c_bus = nullptr;
void set_i2c_bus(i2c::I2CBus *bus) {
  s_i2c_bus = bus;
}
#endif
}  // namespace nim
}  // namespace esphome

// When Nim compiles with 'nim cpp', NimMain has C++ linkage (_Z7NimMainv)
void NimMain(void) __attribute__((weak));

extern "C" {
  void nim_on_setup(void) __attribute__((weak));
  void nim_on_loop(void) __attribute__((weak));

  void nim_dispatch_select_state(const char *entity_id, const char *value) __attribute__((weak));
  void nim_dispatch_number_state(const char *entity_id, float value) __attribute__((weak));
  void nim_dispatch_switch_state(const char *entity_id, bool value) __attribute__((weak));
  void nim_dispatch_button_press(const char *entity_id) __attribute__((weak));

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
      if (entity_matches_id(s, entity_id)) {
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
      if (entity_matches_id(bs, entity_id)) {
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
      if (entity_matches_id(sw, entity_id)) {
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
      if (entity_matches_id(ts, entity_id)) {
        ts->publish_state(value);
        return true;
      }
    }
  #endif
    return false;
  }

  bool esphome_nim_publish_select(const char *entity_id, const char *value) {
  #ifdef USE_SELECT
    for (auto *s : esphome::App.get_selects()) {
      if (entity_matches_id(s, entity_id)) {
        s->publish_state(value);
        return true;
      }
    }
  #endif
    return false;
  }

  bool esphome_nim_publish_number(const char *entity_id, float value) {
  #ifdef USE_NUMBER
    for (auto *n : esphome::App.get_numbers()) {
      if (entity_matches_id(n, entity_id)) {
        n->publish_state(value);
        return true;
      }
    }
  #endif
    return false;
  }

  bool esphome_nim_publish_button(const char *entity_id) {
  #ifdef USE_BUTTON
    for (auto *b : esphome::App.get_buttons()) {
      if (entity_matches_id(b, entity_id)) {
        b->press();
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
    if (esphome::nim::s_i2c_bus != nullptr) {
      return esphome::nim::s_i2c_bus->write(address, data, len) == esphome::i2c::ERROR_OK;
    }
  #endif
    return false;
  }

  bool nim_i2c_read(uint8_t address, uint8_t *data, size_t len) {
  #ifdef USE_I2C
    if (esphome::nim::s_i2c_bus != nullptr) {
      return esphome::nim::s_i2c_bus->read(address, data, len) == esphome::i2c::ERROR_OK;
    }
  #endif
    return false;
  }

  bool nim_i2c_write_read(uint8_t address, const uint8_t *write_data, size_t write_len, uint8_t *read_data, size_t read_len) {
  #ifdef USE_I2C
    if (esphome::nim::s_i2c_bus != nullptr) {
      return esphome::nim::s_i2c_bus->write_readv(address, write_data, write_len, read_data, read_len) == esphome::i2c::ERROR_OK;
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

#ifdef USE_SELECT
  for (auto *s : esphome::App.get_selects()) {
    if (s != nullptr) {
      s->add_on_state_callback([s](size_t index) {
        if (nim_dispatch_select_state) {
          const char *opt = s->option_at(index);
          char id_buf[esphome::OBJECT_ID_MAX_LEN];
          s->get_object_id_to(std::span<char, esphome::OBJECT_ID_MAX_LEN>(id_buf));
          nim_dispatch_select_state(id_buf, opt != nullptr ? opt : "");
        }
      });
    }
  }
#endif
#ifdef USE_NUMBER
  for (auto *n : esphome::App.get_numbers()) {
    if (n != nullptr) {
      n->add_on_state_callback([n](float value) {
        if (nim_dispatch_number_state) {
          char id_buf[esphome::OBJECT_ID_MAX_LEN];
          n->get_object_id_to(std::span<char, esphome::OBJECT_ID_MAX_LEN>(id_buf));
          nim_dispatch_number_state(id_buf, value);
        }
      });
    }
  }
#endif
#ifdef USE_SWITCH
  for (auto *sw : esphome::App.get_switches()) {
    if (sw != nullptr) {
      sw->add_on_state_callback([sw](bool state) {
        if (nim_dispatch_switch_state) {
          char id_buf[esphome::OBJECT_ID_MAX_LEN];
          sw->get_object_id_to(std::span<char, esphome::OBJECT_ID_MAX_LEN>(id_buf));
          nim_dispatch_switch_state(id_buf, state);
        }
      });
    }
  }
#endif
#ifdef USE_BUTTON
  for (auto *b : esphome::App.get_buttons()) {
    if (b != nullptr) {
      b->add_on_press_callback([b]() {
        if (nim_dispatch_button_press) {
          char id_buf[esphome::OBJECT_ID_MAX_LEN];
          b->get_object_id_to(std::span<char, esphome::OBJECT_ID_MAX_LEN>(id_buf));
          nim_dispatch_button_press(id_buf);
        }
      });
    }
  }
#endif

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
