#pragma once

#include "esphome/core/component.h"
#ifdef USE_I2C
#include "esphome/components/i2c/i2c_bus.h"
#endif
#include "nim_esphome_bridge.h"

namespace esphome {
namespace nim {

#ifdef USE_I2C
void set_i2c_bus(i2c::I2CBus *bus);
#endif

class NimComponent : public Component {
 public:
  void setup() override;
  void loop() override;
  void dump_config() override;
  float get_setup_priority() const override { return setup_priority::DATA; }
#ifdef USE_I2C
  void set_i2c_bus(i2c::I2CBus *bus) { ::esphome::nim::set_i2c_bus(bus); }
#endif
};

}  // namespace nim
}  // namespace esphome

