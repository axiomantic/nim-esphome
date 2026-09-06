## `nim_esphome/dsl`: Unified entrypoint for ESPHome Domain-Specific Languages.
##
## Re-exports:
## - `dsl/entities`: `esphomeControls` macro for declarative Home Assistant UI controls.
## - `dsl/satellite`: Voice Assistant Satellite lifecycle state machine & `processing_sound` loop.
## - `dsl/dashboard`: `haDashboard` and `haCard` for Lovelace dashboard surfaces.
## - `dsl/actions`: `haService` and `haAction` for type-safe Home Assistant actions.
## - `dsl/schedule`: `haSchedule`, `every`, and `after` for non-blocking task scheduling.
## - `dsl/surface`: `haSurface` for composite multi-entity hardware surfaces.

import nim_esphome/dsl/entities
import nim_esphome/dsl/satellite
import nim_esphome/dsl/dashboard
import nim_esphome/dsl/actions
import nim_esphome/dsl/schedule
import nim_esphome/dsl/surface

export entities
export satellite
export dashboard
export actions
export schedule
export surface
