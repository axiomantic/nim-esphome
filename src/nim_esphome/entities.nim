## `nim_esphome/entities`: Type-safe bindings for ESPHome entities.
##
## Allows Nim embedded code to interact directly with ESPHome components:
## - `Sensor`: Numerical floating-point sensor entities.
## - `BinarySensor`: Boolean digital sensor entities (e.g. motion, door contacts).
## - `Switch`: Boolean controllable switch entities (e.g. relays, toggles).
## - `TextSensor`: String/text status sensor entities.
## - `Select[T]`: Type-safe selection/dropdown entities (enums or strings).
## - `Number`: Bounded numerical sliders/inputs.
## - `Button`: Action trigger buttons.
##
## State updates published via `publishState` are forwarded to Home Assistant.
## Inbound state changes from Home Assistant trigger registered `onState` / `onPress` callbacks.

import std/tables
import std/strutils

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

  Select*[T] = object
    ## Type-safe handle to an ESPHome `select` component.
    id*: string

  Number* = object
    ## Type-safe handle to an ESPHome `number` component.
    id*: string
    min*: float32
    max*: float32
    step*: float32

  Button* = object
    ## Type-safe handle to an ESPHome `button` component.
    id*: string

  SelectCallback = proc(val: string)
  NumberCallback = proc(val: float32)
  SwitchCallback = proc(val: bool)
  ButtonCallback = proc()

var
  selectCallbacks* = initTable[string, seq[SelectCallback]]()
  numberCallbacks* = initTable[string, seq[NumberCallback]]()
  switchCallbacks* = initTable[string, seq[SwitchCallback]]()
  buttonCallbacks* = initTable[string, seq[ButtonCallback]]()

when not defined(esphome):
  var
    sensorStateTable* = initTable[string, float32]()
    binarySensorStateTable* = initTable[string, bool]()
    switchStateTable* = initTable[string, bool]()
    textSensorStateTable* = initTable[string, string]()
    selectStateTable* = initTable[string, string]()
    numberStateTable* = initTable[string, float32]()
    buttonPressCountTable* = initTable[string, int]()

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

proc newSelect*[T](id: string): Select[T] {.inline.} =
  ## Creates a handle to an ESPHome `select` component with type parameter `T`.
  Select[T](id: id)

proc newNumber*(id: string, min: float32 = 0.0, max: float32 = 100.0, step: float32 = 1.0): Number {.inline.} =
  ## Creates a handle to an ESPHome `number` slider/input.
  Number(id: id, min: min, max: max, step: step)

proc newButton*(id: string): Button {.inline.} =
  ## Creates a handle to an ESPHome `button` action component.
  Button(id: id)

# --- Callbacks Registration ---

proc onState*[T: enum](s: Select[T], cb: proc(val: T)) =
  ## Registers a callback invoked when this `Select` option changes in Home Assistant.
  ## String values are automatically mapped to enum `T`.
  let entityId = s.id
  if not selectCallbacks.hasKey(entityId):
    selectCallbacks[entityId] = @[]
  selectCallbacks[entityId].add(proc(strVal: string) =
    try:
      let parsed = parseEnum[T](strVal)
      cb(parsed)
    except ValueError:
      for e in low(T)..high(T):
        if $e == strVal:
          cb(e)
          return
  )

proc onState*(s: Select[string], cb: proc(val: string)) =
  ## Registers a callback invoked when this string `Select` option changes in Home Assistant.
  let entityId = s.id
  if not selectCallbacks.hasKey(entityId):
    selectCallbacks[entityId] = @[]
  selectCallbacks[entityId].add(cb)

proc onState*(n: Number, cb: proc(val: float32)) =
  ## Registers a callback invoked when this `Number` slider changes in Home Assistant.
  let entityId = n.id
  if not numberCallbacks.hasKey(entityId):
    numberCallbacks[entityId] = @[]
  numberCallbacks[entityId].add(cb)

proc onState*(sw: Switch, cb: proc(val: bool)) =
  ## Registers a callback invoked when this `Switch` toggle changes in Home Assistant.
  let entityId = sw.id
  if not switchCallbacks.hasKey(entityId):
    switchCallbacks[entityId] = @[]
  switchCallbacks[entityId].add(cb)

proc onPress*(b: Button, cb: proc()) =
  ## Registers a callback invoked when this `Button` is pressed in Home Assistant.
  let entityId = b.id
  if not buttonCallbacks.hasKey(entityId):
    buttonCallbacks[entityId] = @[]
  buttonCallbacks[entityId].add(cb)

# --- Dispatch Procs (Exported to C ABI) ---

proc nim_dispatch_select_state*(entityId: cstring, val: cstring) {.exportc: "nim_dispatch_select_state", cdecl.} =
  let id = $entityId
  let value = $val
  when not defined(esphome):
    selectStateTable[id] = value
  if selectCallbacks.hasKey(id):
    for cb in selectCallbacks[id]:
      cb(value)

proc nim_dispatch_number_state*(entityId: cstring, val: cfloat) {.exportc: "nim_dispatch_number_state", cdecl.} =
  let id = $entityId
  let value = float32(val)
  when not defined(esphome):
    numberStateTable[id] = value
  if numberCallbacks.hasKey(id):
    for cb in numberCallbacks[id]:
      cb(value)

proc nim_dispatch_switch_state*(entityId: cstring, val: bool) {.exportc: "nim_dispatch_switch_state", cdecl.} =
  let id = $entityId
  when not defined(esphome):
    switchStateTable[id] = val
  if switchCallbacks.hasKey(id):
    for cb in switchCallbacks[id]:
      cb(val)

proc nim_dispatch_button_press*(entityId: cstring) {.exportc: "nim_dispatch_button_press", cdecl.} =
  let id = $entityId
  when not defined(esphome):
    buttonPressCountTable[id] = buttonPressCountTable.getOrDefault(id, 0) + 1
  if buttonCallbacks.hasKey(id):
    for cb in buttonCallbacks[id]:
      cb()

# --- Publishing State to ESPHome & Home Assistant ---

when defined(esphome):
  proc esphome_nim_publish_sensor(entityId: ConstCString, val: cfloat): bool {.importc, cdecl.}
  proc esphome_nim_publish_binary_sensor(entityId: ConstCString, val: bool): bool {.importc, cdecl.}
  proc esphome_nim_publish_switch(entityId: ConstCString, val: bool): bool {.importc, cdecl.}
  proc esphome_nim_publish_text_sensor(entityId: ConstCString, val: ConstCString): bool {.importc, cdecl.}
  proc esphome_nim_publish_select(entityId: ConstCString, val: ConstCString): bool {.importc, cdecl.}
  proc esphome_nim_publish_number(entityId: ConstCString, val: cfloat): bool {.importc, cdecl.}
  proc esphome_nim_publish_button(entityId: ConstCString): bool {.importc, cdecl.}

  proc publishState*(s: Sensor, val: float32): bool {.discardable.} =
    esphome_nim_publish_sensor(s.id.cstring, val.cfloat)

  proc publishState*(bs: BinarySensor, val: bool): bool {.discardable.} =
    esphome_nim_publish_binary_sensor(bs.id.cstring, val)

  proc publishState*(sw: Switch, val: bool): bool {.discardable.} =
    esphome_nim_publish_switch(sw.id.cstring, val)

  proc publishState*(ts: TextSensor, val: string): bool {.discardable.} =
    esphome_nim_publish_text_sensor(ts.id.cstring, val.cstring)

  proc publishState*[T](s: Select[T], val: T): bool {.discardable.} =
    esphome_nim_publish_select(s.id.cstring, ($val).cstring)

  proc publishState*(n: Number, val: float32): bool {.discardable.} =
    esphome_nim_publish_number(n.id.cstring, val.cfloat)

  proc press*(b: Button): bool {.discardable.} =
    esphome_nim_publish_button(b.id.cstring)

else:
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

  proc publishState*[T](s: Select[T], val: T): bool {.discardable.} =
    selectStateTable[s.id] = $val
    true

  proc publishState*(n: Number, val: float32): bool {.discardable.} =
    numberStateTable[n.id] = val
    true

  proc press*(b: Button): bool {.discardable.} =
    buttonPressCountTable[b.id] = buttonPressCountTable.getOrDefault(b.id, 0) + 1
    true

  # Host inspection procs
  proc getSensorState*(id: string): float32 = sensorStateTable.getOrDefault(id, 0.0'f32)
  proc getBinarySensorState*(id: string): bool = binarySensorStateTable.getOrDefault(id, false)
  proc getSwitchState*(id: string): bool = switchStateTable.getOrDefault(id, false)
  proc getTextSensorState*(id: string): string = textSensorStateTable.getOrDefault(id, "")
  proc getSelectState*(id: string): string = selectStateTable.getOrDefault(id, "")
  proc getNumberState*(id: string): float32 = numberStateTable.getOrDefault(id, 0.0'f32)
  proc getButtonPressCount*(id: string): int = buttonPressCountTable.getOrDefault(id, 0)

  # Host simulation trigger procs
  proc triggerSelectState*(id: string, val: string) =
    nim_dispatch_select_state(id.cstring, val.cstring)

  proc triggerNumberState*(id: string, val: float32) =
    nim_dispatch_number_state(id.cstring, val.cfloat)

  proc triggerSwitchState*(id: string, val: bool) =
    nim_dispatch_switch_state(id.cstring, val)

  proc triggerButtonPress*(id: string) =
    nim_dispatch_button_press(id.cstring)


