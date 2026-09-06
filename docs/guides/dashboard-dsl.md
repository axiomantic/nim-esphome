# Lovelace Dashboard Surface DSL

Firmware developers frequently face a disconnect between embedded hardware capabilities and user interfaces in Home Assistant. When a device exposes multiple controls—such as volume sliders, mode selectors, switches, or status sensors—users typically have to construct custom Lovelace dashboard cards manually.

The **Lovelace Dashboard Surface DSL** (`nim_esphome/dsl/dashboard`) allows you to define, style, and generate production-ready Home Assistant dashboard cards directly alongside your firmware code.

---

## Core Concepts

The dashboard DSL operates at compile time to construct structured representations of Lovelace card components:

- **[`DashboardCard`](../api/dsl.md)**: Encapsulates card types (`entities`, `tile`, `glance`, `grid`, `button`, `custom`), card headers, icons, column counts, and entity rows.
- **[`DashboardEntity`](../api/dsl.md)**: Represents an individual entity row, supporting custom display names, icons, and secondary info (`last-changed`, `last-updated`).
- **[`LovelaceDashboard`](../api/dsl.md)**: A complete multi-view dashboard specification.
- **Serialization**: Instant compilation to **JSON** (`toJson()`) and **YAML** (`toYaml()`) matching Home Assistant's dashboard schema.

---

## Quickstart Example

```nim
import nim_esphome/dsl/dashboard

let satelliteCard = haCard(ctEntities, "Voice Satellite Controls", "mdi:microphone"):
  card.addEntity "select.processing_sound", name = "Audio Feedback", icon = "mdi:progress-clock"
  card.addEntity "number.processing_sound_volume", name = "Processing Volume"
  card.addEntity "switch.wake_chime", name = "Wake Chime", icon = "mdi:bell-ring"
  card.addEntity "sensor.satellite_status", name = "Status", secondaryInfo = "last-changed"

echo satelliteCard.toYaml()
```

### Generated Lovelace YAML Output

```yaml
type: entities
title: "Voice Satellite Controls"
icon: "mdi:microphone"
entities:
  - entity: select.processing_sound
    name: "Audio Feedback"
    icon: "mdi:progress-clock"
  - entity: number.processing_sound_volume
    name: "Processing Volume"
  - entity: switch.wake_chime
    name: "Wake Chime"
    icon: "mdi:bell-ring"
  - entity: sensor.satellite_status
    name: "Status"
    secondary_info: "last-changed"
```

---

## Supported Card Types

| Card Type | DSL Identifier | Description |
|---|---|---|
| **Entities** | `ctEntities` | The standard vertical list of entities with interactive controls. |
| **Tile** | `ctTile` | Modern Home Assistant rounded card with primary and secondary states. |
| **Glance** | `ctGlance` | Horizontal multi-column overview showing icons and current states. |
| **Grid** | `ctGrid` | Multi-card grid container with configurable column counts. |
| **Button** | `ctButton` | Large action button for triggering scripts, scenes, or services. |
| **Custom** | `ctCustom` | Community Lovelace cards (e.g. `custom:mushroom-entity-card`). |

### Multi-Column Glance Card Example

```nim
let glanceCard = haCard(ctGlance, "Quick Status"):
  card.setColumns 3
  card.addEntity "binary_sensor.wifi_status", name = "Wi-Fi"
  card.addEntity "sensor.voice_state", name = "State"
  card.addEntity "switch.mic_mute", name = "Muted"
```

---

## Defining Complete Multi-View Dashboards

Use `haDashboard` and `newLovelaceView` to author full dashboards:

```nim
let homeDashboard = haDashboard "Smart Satellite Dashboard":
  var voiceTab = newLovelaceView("Voice Controls", path = "voice", icon = "mdi:microphone")
  voiceTab.addCard(satelliteCard)
  dash.addView(voiceTab)

  var diagnosticTab = newLovelaceView("Diagnostics", path = "diagnostics", icon = "mdi:wrench")
  diagnosticTab.addCard(glanceCard)
  dash.addView(diagnosticTab)

echo homeDashboard.toYaml()
```

---

## Deploying Configurations to Home Assistant

1. **Dashboard Raw Configuration**:
   Copy the output of `card.toYaml()` and paste it into Home Assistant via **Edit Dashboard** -> **Raw configuration editor** or add an **Entities** card via manual code view.
2. **ESPHome Embedded Web Server**:
   Host the JSON output directly on the device using ESPHome's `web_server`, enabling Home Assistant dashboard integrations to dynamically fetch the card schema.
3. **Diagnostic Sensor**:
   Publish `card.toYaml()` as the attribute of an ESPHome `text_sensor` for zero-touch auto-discovery.
