# Composite Hardware Device Surface DSL

In conventional firmware development, hardware devices are expressed as disjointed collections of independent sensors, switches, and numbers. In Home Assistant, however, users interact with **cohesive physical surfaces**—such as a smart speaker, climate thermostat, air quality station, or multi-zone light controller.

The **Composite Hardware Device Surface DSL** (`nim_esphome/dsl/surface`) provides a unified domain model representing an entire physical device surface.

---

## Core Capabilities

- **Unified Surface Definition**: Combine hardware metadata (model, manufacturer, suggested area), controls, and telemetry into a single object.
- **Automatic Lovelace Card Synthesis**: Call `surface.generateDashboardCard()` to instantly generate a matching Home Assistant dashboard card.
- **Automatic ESPHome YAML Generation**: Call `surface.generateEsphomeYaml()` to generate complete ESPHome template entity declarations.
- **Home Assistant Device Registry Cohesion**: Ensures all exposed entities share device metadata and appear grouped in the Home Assistant Devices list.

---

## Quickstart Example

```nim
import nim_esphome/dsl/surface

let satellite = haSurface("living_room_satellite"):
  surface.name = "Living Room Voice Satellite"
  surface.model = "ReSpeaker XVF3800"
  surface.manufacturer = "Seeed Studio"
  surface.area = "Living Room"

  # Interactive Controls
  surface.addControl(sekSelect, "processing_sound", name = "Processing Sound", icon = "mdi:progress-clock")
  surface.addControl(sekNumber, "volume", name = "Volume", icon = "mdi:volume-high")
  surface.addControl(sekSwitch, "wake_chime", name = "Wake Chime", icon = "mdi:bell-ring")

  # Read-only Telemetry
  surface.addTelemetry(sekSensor, "wifi_rssi", name = "Wi-Fi Signal", unit = "dBm", deviceClass = "signal_strength")
  surface.addTelemetry(sekBinarySensor, "voice_active", name = "Voice Active", deviceClass = "sound")
```

---

## Generating Dashboard UI & ESPHome Configuration

### 1. Generating Lovelace Dashboard YAML

```nim
echo satellite.generateLovelaceYaml()
```

Output:

```yaml
type: entities
title: "Living Room Voice Satellite"
entities:
  - entity: select.processing_sound
    name: "Processing Sound"
    icon: "mdi:progress-clock"
  - entity: number.volume
    name: "Volume"
    icon: "mdi:volume-high"
  - entity: switch.wake_chime
    name: "Wake Chime"
    icon: "mdi:bell-ring"
  - entity: sensor.wifi_rssi
    name: "Wi-Fi Signal"
  - entity: binary_sensor.voice_active
    name: "Voice Active"
```

### 2. Generating ESPHome Component YAML

```nim
echo satellite.generateEsphomeYaml()
```

Output:

```yaml
# =============================================================================
# Generated Hardware Surface: Living Room Voice Satellite (ReSpeaker XVF3800)
# =============================================================================

select:
  - platform: template
    id: processing_sound
    name: "Processing Sound"
    icon: "mdi:progress-clock"
    optimistic: true

number:
  - platform: template
    id: volume
    name: "Volume"
    icon: "mdi:volume-high"
    optimistic: true

switch:
  - platform: template
    id: wake_chime
    name: "Wake Chime"
    icon: "mdi:bell-ring"
    optimistic: true

sensor:
  - platform: template
    id: wifi_rssi
    name: "Wi-Fi Signal"
    unit_of_measurement: "dBm"
    device_class: "signal_strength"

binary_sensor:
  - platform: template
    id: voice_active
    name: "Voice Active"
    device_class: "sound"
```

---

## Complete Working Project

The following code is pulled directly from [`examples/smart_thermostat/`](https://github.com/axiomantic/nim-esphome/tree/main/examples/smart_thermostat), which is compiled for embedded ESP32 targets and validated against ESPHome in the automated test suite:

=== "Nim Source (`smart_thermostat.nim`)"
    ```nim
--8<-- "examples/smart_thermostat/smart_thermostat.nim"
    ```

=== "ESPHome YAML (`smart_thermostat.yaml`)"
    ```yaml
--8<-- "examples/smart_thermostat/smart_thermostat.yaml"
    ```

