## `nim_esphome/entities`: Type-safe bindings for ESPHome entities.
##
## Allows Nim embedded code to interact directly with ESPHome components:
## - `Sensor`: Numerical floating-point sensor entities.
## - `BinarySensor`: Boolean digital sensor entities (e.g. motion, door contacts).
## - `Switch`: Boolean controllable switch entities (e.g. relays).
## - `TextSensor`: String/text status sensor entities.
##
## State updates published via `publishState` are propagated across ESPHome's internal
## event bus and forwarded to Home Assistant via the Native API or MQTT.

when defined(esphome):
  import nim_esphome/api

type
  Sensor* = object
    ## Type-safe handle to an ESPHome numerical `sensor` component.
    id*: string

  BinarySensor* = object
    ## Type-safe handle to an ESPHome `binary_sensor` component.
    id*: string

  Switch* = object
    ## Type-safe handle to an ESPHome `switch` component.
    id*: string

  TextSensor* = object
    ## Type-safe handle to an ESPHome `text_sensor` component.
    id*: string

proc newSensor*(id: string): Sensor {.inline.} =
  ## Creates a handle to an ESPHome numerical `sensor` by its YAML entity `id`.
  Sensor(id: id)

proc newBinarySensor*(id: string): BinarySensor {.inline.} =
  ## Creates a handle to an ESPHome `binary_sensor` by its YAML entity `id`.
  BinarySensor(id: id)

proc newSwitch*(id: string): Switch {.inline.} =
  ## Creates a handle to an ESPHome `switch` by its YAML entity `id`.
  Switch(id: id)

proc newTextSensor*(id: string): TextSensor {.inline.} =
  ## Creates a handle to an ESPHome `text_sensor` by its YAML entity `id`.
  TextSensor(id: id)

when defined(esphome):
  proc esphome_nim_publish_sensor(entityId: ConstCString, val: cfloat): bool {.importc, cdecl.}
  proc esphome_nim_publish_binary_sensor(entityId: ConstCString, val: bool): bool {.importc, cdecl.}
  proc esphome_nim_publish_switch(entityId: ConstCString, val: bool): bool {.importc, cdecl.}
  proc esphome_nim_publish_text_sensor(entityId: ConstCString, val: ConstCString): bool {.importc, cdecl.}

  proc publishState*(s: Sensor, val: float32): bool {.discardable.} =
    ## Publishes a new numerical value to the ESPHome sensor identified by `s.id`.
    esphome_nim_publish_sensor(s.id.cstring, val.cfloat)

  proc publishState*(bs: BinarySensor, val: bool): bool {.discardable.} =
    ## Publishes a boolean state (`true`/`false`) to the ESPHome binary sensor identified by `bs.id`.
    esphome_nim_publish_binary_sensor(bs.id.cstring, val)

  proc publishState*(sw: Switch, val: bool): bool {.discardable.} =
    ## Publishes a boolean state (`true`/`false`) to the ESPHome switch identified by `sw.id`.
    esphome_nim_publish_switch(sw.id.cstring, val)

  proc publishState*(ts: TextSensor, val: string): bool {.discardable.} =
    ## Publishes a text string state to the ESPHome text sensor identified by `ts.id`.
    esphome_nim_publish_text_sensor(ts.id.cstring, val.cstring)
else:
  import std/tables

  var
    sensorStateTable* = initTable[string, float32]()
    binarySensorStateTable* = initTable[string, bool]()
    switchStateTable* = initTable[string, bool]()
    textSensorStateTable* = initTable[string, string]()

  proc publishState*(s: Sensor, val: float32): bool {.discardable.} =
    ## Publishes a numerical value into the host mock sensor registry.
    sensorStateTable[s.id] = val
    true

  proc publishState*(bs: BinarySensor, val: bool): bool {.discardable.} =
    ## Publishes a boolean state into the host mock binary sensor registry.
    binarySensorStateTable[bs.id] = val
    true

  proc publishState*(sw: Switch, val: bool): bool {.discardable.} =
    ## Publishes a boolean state into the host mock switch registry.
    switchStateTable[sw.id] = val
    true

  proc publishState*(ts: TextSensor, val: string): bool {.discardable.} =
    ## Publishes a string state into the host mock text sensor registry.
    textSensorStateTable[ts.id] = val
    true

  proc getSensorState*(id: string): float32 =
    ## Returns the latest published sensor state for `id` from the host mock registry.
    sensorStateTable.getOrDefault(id, 0.0'f32)

  proc getBinarySensorState*(id: string): bool =
    ## Returns the latest published binary sensor state for `id` from the host mock registry.
    binarySensorStateTable.getOrDefault(id, false)

  proc getSwitchState*(id: string): bool =
    ## Returns the latest published switch state for `id` from the host mock registry.
    switchStateTable.getOrDefault(id, false)

  proc getTextSensorState*(id: string): string =
    ## Returns the latest published text sensor state for `id` from the host mock registry.
    textSensorStateTable.getOrDefault(id, "")

