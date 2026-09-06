## `nim_esphome/dsl`: Unified entrypoint for ESPHome Domain-Specific Languages.
##
## Re-exports:
## - `dsl/entities`: `esphomeControls` macro for declarative Home Assistant UI controls.
## - `dsl/satellite`: Voice Assistant Satellite lifecycle state machine & `processing_sound` loop.

import nim_esphome/dsl/entities
import nim_esphome/dsl/satellite

export entities
export satellite
