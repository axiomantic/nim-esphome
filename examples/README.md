# `nim-esphome` Example Projects

This directory contains standalone, production-ready example projects demonstrating `nim-esphome` APIs, hardware drivers, closed-loop DSP control, and Domain-Specific Languages (DSLs) for Home Assistant surfaces.

All example projects are **compiled for embedded 32-bit ESP32 targets** and **validated against the ESPHome configuration schema** in the automated test suite (`tests/test_examples.nim`).

The code shown in the official documentation guides is pulled directly from these files.

---

## Projects Overview

| Directory | Core Focus | Home Assistant Surface & Features |
|---|---|---|
| [**`blink/`**](blink/) | Core Lifecycle & Peripherals | Basic GPIO pin toggling, I2C device register manipulation, Flash NVS storage, and digital filtering. |
| [**`voice_satellite/`**](voice_satellite/) | Voice Satellite & Audio Loop | Declarative controls (`esphomeControls`), voice pipeline lifecycle, active processing sound loop, and Lovelace card generation. |
| [**`smart_thermostat/`**](smart_thermostat/) | Composite Hardware Surface | Unified `haSurface` definition, temperature number slider, eco switch, HVAC mode selector, PID control loop, and `"boost_heating"` action. |
| [**`custom_actions/`**](custom_actions/) | Custom Actions & Services | Type-safe Home Assistant actions (`haService` / `haAction`) with bounds checking, automatic default fallbacks, and execution context getters. |
| [**`cooperative_scheduler/`**](cooperative_scheduler/) | RTOS Background Task Scheduler | Non-blocking cooperative tasks (`every 50.ms`, `every 2.seconds`, `every 30.seconds`, `after 10.seconds`) without OS thread stack overhead. |
| [**`dashboard_surface/`**](dashboard_surface/) | Lovelace Dashboard Synthesis | `haDashboard` and `haCard` multi-view configurations generating `entities` and `glance` cards published to an ESPHome `text_sensor`. |

---

## Building and Flashing Examples

To compile and flash any example to your connected microcontroller (e.g. ESP32 / ESP32-S3):

```bash
# Validate configuration
esphome config examples/voice_satellite/voice_satellite.yaml

# Compile firmware binary
esphome compile examples/voice_satellite/voice_satellite.yaml

# Flash to connected device via USB
esphome run examples/voice_satellite/voice_satellite.yaml
```

---

## Testing Examples on Host

To run the automated verification suite that compiles all examples for embedded ESP32 targets and checks ESPHome YAML validity:

```bash
# Run the examples compilation and validation suite
nim c -r -p:src tests/test_examples.nim
```
