when defined(esphome):
  import nim_esphome/api

type
  Sensor* = object
    id*: string

  BinarySensor* = object
    id*: string

  Switch* = object
    id*: string

  TextSensor* = object
    id*: string

proc newSensor*(id: string): Sensor {.inline.} =
  Sensor(id: id)

proc newBinarySensor*(id: string): BinarySensor {.inline.} =
  BinarySensor(id: id)

proc newSwitch*(id: string): Switch {.inline.} =
  Switch(id: id)

proc newTextSensor*(id: string): TextSensor {.inline.} =
  TextSensor(id: id)

when defined(esphome):
  proc esphome_nim_publish_sensor(entityId: ConstCString, val: cfloat): bool {.importc, cdecl.}
  proc esphome_nim_publish_binary_sensor(entityId: ConstCString, val: bool): bool {.importc, cdecl.}
  proc esphome_nim_publish_switch(entityId: ConstCString, val: bool): bool {.importc, cdecl.}
  proc esphome_nim_publish_text_sensor(entityId: ConstCString, val: ConstCString): bool {.importc, cdecl.}

  proc publishState*(s: Sensor, val: float32): bool {.discardable.} =
    esphome_nim_publish_sensor(s.id.cstring, val.cfloat)

  proc publishState*(bs: BinarySensor, val: bool): bool {.discardable.} =
    esphome_nim_publish_binary_sensor(bs.id.cstring, val)

  proc publishState*(sw: Switch, val: bool): bool {.discardable.} =
    esphome_nim_publish_switch(sw.id.cstring, val)

  proc publishState*(ts: TextSensor, val: string): bool {.discardable.} =
    esphome_nim_publish_text_sensor(ts.id.cstring, val.cstring)
else:
  import std/tables

  var
    sensorStateTable* = initTable[string, float32]()
    binarySensorStateTable* = initTable[string, bool]()
    switchStateTable* = initTable[string, bool]()
    textSensorStateTable* = initTable[string, string]()

  proc publishState*(s: Sensor, val: float32): bool {.discardable.} =
    sensorStateTable[s.id] = val
    true

  proc publishState*(bs: BinarySensor, val: bool): bool {.discardable.} =
    binarySensorStateTable[bs.id] = val
    true

  proc publishState*(sw: Switch, val: bool): bool {.discardable.} =
    switchStateTable[sw.id] = val
    true

  proc publishState*(ts: TextSensor, val: string): bool {.discardable.} =
    textSensorStateTable[ts.id] = val
    true

  proc getSensorState*(id: string): float32 =
    sensorStateTable.getOrDefault(id, 0.0'f32)

  proc getBinarySensorState*(id: string): bool =
    binarySensorStateTable.getOrDefault(id, false)

  proc getSwitchState*(id: string): bool =
    switchStateTable.getOrDefault(id, false)

  proc getTextSensorState*(id: string): string =
    textSensorStateTable.getOrDefault(id, "")
