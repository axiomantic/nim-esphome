#pragma once

#include "esphome/core/component.h"
#include "nim_esphome_bridge.h"

namespace esphome {
namespace nim {

class NimComponent : public Component {
 public:
  void setup() override;
  void loop() override;
  void dump_config() override;
  float get_setup_priority() const override { return setup_priority::DATA; }
};

}  // namespace nim
}  // namespace esphome
