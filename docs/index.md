# nim-esphome Documentation

Welcome to the official documentation for **`nim-esphome`**.

`nim-esphome` is an external component for [ESPHome](https://esphome.io) that allows developers to write custom microcontroller firmware logic, state machines, signal processing filters, and device drivers in [Nim](https://nim-lang.org).

---

## Why Nim on ESPHome?

ESPHome is an exceptional declarative platform for IoT hardware configuration. However, when complex embedded logic is required—such as multi-state voice pipelines, sensor fusion, closed-loop PID control, or custom peripheral protocols—developers are often forced to write raw C++ inside multi-line YAML lambdas.

Writing C++ in YAML lambdas presents serious drawbacks:

- ❌ **No compile-time state guarantees**: Asynchronous network events and callbacks easily cause race conditions and invalid state transitions.
- ❌ **Difficult host testing**: Verifying logic requires repeatedly compiling PlatformIO firmware and flashing physical microcontrollers.
- ❌ **C++ verbosity & memory hazards**: Pointer arithmetic and unmanaged state introduce subtle memory corruptions.

**`nim-esphome` solves this:**

```mermaid
flowchart LR
    A["Your Nim Logic<br/>(src/main.nim)"] -->|"esphome compile"| B["nim cpp<br/>(--mm:arc, -d:danger)"]
    B --> C["Standard C++ Output<br/>(.esphome/build/.../src/)"]
    C --> D["ESPHome / PlatformIO<br/>(ESP-IDF or Arduino)"]
    D --> E["Firmware Binary<br/>(ESP32, RISC-V, RP2040)"]
```

- ⚡ **Zero-Overhead Embedded C++ Transpilation**: Nim compiles to clean, standard C++ without an interpreter or heavy runtime.
- 🧠 **ARC Deterministic Memory**: Memory is managed deterministically via ARC (`--mm:arc`) and FreeRTOS heap (`-d:useMalloc`) with zero GC pause times.
- 🧪 **Hardware-Free Host Unit Testing**: Run automated test suites instantly on macOS and Linux (`nim c -r`) without needing physical hardware attached.
- 🛡️ **Compile-Time Typestates (with [`nim-typestates`](https://github.com/elijahr/nim-typestates))**: Model complex state machines where illegal transitions (e.g. triggering wake words during OTA updates) are rejected at compile time. See the [Verified Voice Satellite Case Study](guides/esphome-satellite.md) for an in-depth implementation.

---

## Documentation Roadmap

Explore the comprehensive guides and API references:

### 📖 Guides & Tutorials
- [**Getting Started**](guides/getting-started.md): Install prerequisites, set up the external component, and build your first blink firmware.
- [**YAML Configuration**](guides/configuration.md): Complete reference for all `nim:` schema options, compiler flags, and target CPU overrides.
- [**Nimble Dependencies**](guides/dependencies.md): Automatically install and link packages from Nimble and Git repositories.
- [**Target Architectures & Cross-Compilation**](guides/architectures.md): Deep dive into Xtensa, RISC-V, ARM RP2040 targets, pointer widths, and exception elimination.
- [**Entities & Home Assistant**](guides/entities.md): Publish state directly to ESPHome sensors, switches, and text sensors.
- [**Hardware Buses (GPIO & I2C)**](guides/hardware.md): Control microcontroller pins and interface with I2C peripherals.
- [**Flash Preferences (NVS)**](guides/storage.md): Persist calibration values, counters, and configurations across power cycles.
- [**DSP & Closed-Loop Control**](guides/dsp-control.md): Use stack-allocated PID controllers, moving average/median filters, and switch debouncers.
- [**C++ Interoperability**](guides/interop.md): Export Nim procedures to ESPHome YAML lambdas using `{.exportEsphome.}`.
- [**Verified Voice Satellite (Case Study)**](guides/esphome-satellite.md): Explore `esphome-satellite`, a real-world 14-state verified typestate voice assistant.
- [**Project Templating & 1-Click Distribution**](guides/distribution.md): Set up ESP-Web-Tools browser flashing, My Home Assistant dashboard import, and automated CI factory binary releases.

### 📚 API Reference
- [**API Reference Index**](api/index.md): Module catalog and architecture overview.
- [**nim_esphome**](api/core.md): Core lifecycle templates (`esphomeSetup`, `esphomeLoop`) and `exportEsphome` macro.
- [**nim_esphome/api**](api/api.md): ESPHome runtime bindings (logging, timing, watchdog, heap, reboot).
- [**nim_esphome/entities**](api/entities.md): First-class entity handles and `publishState` bindings.
- [**nim_esphome/gpio**](api/gpio.md): GPIO pin modes, digital writes, and digital reads.
- [**nim_esphome/i2c**](api/i2c.md): I2C device handles, register writes, and multi-byte reads.
- [**nim_esphome/preferences**](api/preferences.md): Flash NVS persistence and FNV-1a hashing.
- [**nim_esphome/dsp**](api/dsp.md): Digital signal processing, PID controllers, and debouncers.
