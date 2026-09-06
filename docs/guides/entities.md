# First-Class Entity Bindings & Home Assistant

This guide explains how to interact with ESPHome sensors, binary sensors, switches, and text sensors directly from Nim, and how updates propagate to Home Assistant.

---

## Entity Types Overview

`nim_esphome/entities` provides type-safe object handles corresponding to standard ESPHome entity platforms:

| Nim Handle Type | ESPHome Platform | State Type | Typical Uses |
|---|---|---|---|
| `Sensor` | `sensor:` | `float32` | Temperature, humidity, power, battery voltage, signal strength |
| `BinarySensor` | `binary_sensor:` | `bool` | PIR motion sensors, reed door contacts, water leak detectors |
| `Switch` | `switch:` | `bool` | Power relays, output toggles, operational mode flags |
| `TextSensor` | `text_sensor:` | `string` | State machine names, error logs, firmware build metadata |
| `Select[T]` | `select:` | `enum` / `string` | Sound profiles, mode selection, audio feedback styles |
| `Number` | `number:` | `float32` | Volume sliders, timeout thresholds, gain controls |
| `Button` | `button:` | Trigger | Test sound triggers, device reboot, recalibration |

---

## Publishing State

You instantiate entity handles using their string IDs as defined in your ESPHome YAML:

```nim
import nim_esphome

# Create handles matching your YAML entity IDs
let
  tempSensor = newSensor("living_room_temperature")
  motionDetector = newBinarySensor("front_door_motion")
  lightSwitch = newSwitch("porch_light")
  statusMessage = newTextSensor("device_status")

esphomeSetup:
  info("Main", "Publishing initial entity states...")
  statusMessage.publishState("System Initialized")

esphomeLoop:
  # Publish sensor readings
  tempSensor.publishState(21.4'f32)
  motionDetector.publishState(false)
  lightSwitch.publishState(true)
```

---

## How It Works Under the Hood

```mermaid
sequenceDiagram
    participant Nim as Nim Embedded Logic
    participant Bridge as C ABI Bridge
    participant App as ESPHome App Registry
    participant HA as Home Assistant

    Nim->>Bridge: publishState(tempSensor, 21.4)
    Bridge->>App: App.get_sensor_by_key("living_room_temperature")
    App->>App: sensor->publish_state(21.4)
    App->>HA: Native API State Update Event
```

1. **Embedded Mode (`-d:esphome`)**:
   - `publishState` calls the C ABI helper `esphome_nim_publish_sensor(...)`.
   - The helper queries ESPHome's internal `App` singleton to look up the component pointer matching the string ID.
   - It invokes the component's native `publish_state(...)` method.
   - ESPHome's Native API immediately pushes the new state to Home Assistant over the encrypted TCP connection.

2. **Host Test Mode (Local machine without hardware)**:
   - When compiled natively (`nim c -r tests/test_entities.nim`), the bindings write into an in-memory test table.
   - You can verify your logic using `getSensorState()`, `getBinarySensorState()`, `getSwitchState()`, and `getTextSensorState()`.

---

## Example ESPHome YAML

Here is a matching ESPHome YAML configuration demonstrating template entities published by Nim:

```yaml
sensor:
  - platform: template
    id: living_room_temperature
    name: "Living Room Temperature"
    unit_of_measurement: "°C"
    accuracy_decimals: 1

binary_sensor:
  - platform: template
    id: front_door_motion
    name: "Front Door Motion"
    device_class: motion

switch:
  - platform: template
    id: porch_light
    name: "Porch Light"
    optimistic: true

text_sensor:
  - platform: template
    id: device_status
    name: "Device Status"

select:
  - platform: template
    id: processing_sound
    name: "Processing Sound"
    optimistic: true
    options:
      - "Silent"
      - "Spinner"
      - "Pulse"
      - "Sonar"

number:
  - platform: template
    id: feedback_volume
    name: "Feedback Volume"
    min_value: 0
    max_value: 100
    step: 5
    optimistic: true

button:
  - platform: template
    id: test_chime
    name: "Test Chime"
```

---

## Declarative Controls DSL (`esphomeControls`)

`nim_esphome/dsl` provides the `esphomeControls` macro to define Home Assistant configuration controls, reactive callbacks, and Flash NVS persistence in a single declarative block:

```nim
import nim_esphome

type ProcessingSoundStyle* = enum
  psSilent     = "Silent"
  psSpinner    = "Spinner"
  psPulse      = "Pulse"
  psSonar      = "Sonar"

esphomeControls:
  # 1. Type-safe Select with compile-time enum parsing
  select[ProcessingSoundStyle]("processing_sound"):
    name = "Processing Sound Style"
    default = psSpinner
    persist = true  # Automatically saved to Flash NVS
    onSelect(style):
      setProcessingAudioStyle(style)

  # 2. Bounded Number slider
  number("feedback_volume"):
    name = "Feedback Volume"
    min = 0.0
    max = 100.0
    step = 5.0
    default = 75.0
    persist = true
    onChange(vol):
      setMasterVolume(vol / 100.0)

  # 3. Switch toggle
  switch("wake_chime"):
    name = "Wake Chime"
    default = true
    persist = true
    onToggle(enabled):
      enableWakeChime(enabled)

  # 4. Action button
  button("test_chime"):
    name = "Play Test Chime"
    onPress:
      triggerPreviewSound()
```

### Automatic Flash NVS Persistence
When `persist = true` is specified:
1. The control loads its last-saved setting from flash memory on boot.
2. If no setting exists in flash yet, it initializes to `default`.
3. Whenever the user modifies the setting in Home Assistant, the new value is automatically persisted across reboots via `preferences.nim`.

