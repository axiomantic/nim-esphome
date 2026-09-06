# API Reference Overview

The `nim-esphome` API is organized into modular packages under the `nim_esphome` namespace.

---

## Module Index

| Module | Purpose | Key Symbols |
|---|---|---|
| [**`nim_esphome`**](core.md) | Umbrella entrypoint, lifecycle hooks, and C++ export macro | `esphomeSetup`, `esphomeLoop`, `exportEsphome` |
| [**`nim_esphome/api`**](api.md) | ESPHome C runtime bindings: logging, high-resolution clocks, RTOS scheduling, watchdog, heap inspection, reboot | `info`, `warn`, `error`, `debug`, `millis`, `micros`, `delayMs`, `yieldToScheduler`, `feedWatchdog`, `getFreeHeap`, `reboot` |
| [**`nim_esphome/entities`**](entities.md) | Type-safe handles to ESPHome entities and Home Assistant state publishing | `Sensor`, `BinarySensor`, `Switch`, `TextSensor`, `publishState` |
| [**`nim_esphome/gpio`**](gpio.md) | Direct microcontroller GPIO configuration, digital read, and digital write | `PinMode`, `PinState`, `pinMode`, `digitalWrite`, `digitalRead` |
| [**`nim_esphome/i2c`**](i2c.md) | I2C bus transactions, register reads/writes, and peripheral communication | `I2CDevice`, `write`, `writeRegister`, `writeByte`, `read`, `readRegister`, `readByte` |
| [**`nim_esphome/preferences`**](preferences.md) | Flash-backed Non-Volatile Storage (NVS) persistence with FNV-1a keying | `fnv1a`, `savePreference`, `loadPreference` |
| [**`nim_esphome/dsp`**](dsp.md) | Stack-allocated embedded signal processing and closed-loop control algorithms | `PIDController`, `MovingAverage`, `MovingMedian`, `LowPassFilter`, `Debouncer` |

---

## Zero-Cost Abstraction Guarantees

All public procedures, templates, and macros in `nim-esphome` follow strict embedded design principles:

- **Zero Heap Overhead**: Operations default to stack allocation or direct hardware registers.
- **Zero GC Pauses**: Fully compatible with Nim's ARC deterministic memory management (`--mm:arc`).
- **Zero C++ Exception Bloat**: Compiles cleanly with `--exceptions:goto` and `--panics:on`.
- **Zero Flash Docstring Overhead**: Nim compiler docstrings (`##`) are stripped completely during transpilation to C++, ensuring that comprehensive API documentation consumes 0 bytes of microcontroller flash memory.
