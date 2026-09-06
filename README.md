# nim-esphome

[![CI](https://github.com/axiomantic/nim-esphome/actions/workflows/ci.yml/badge.svg)](https://github.com/axiomantic/nim-esphome/actions/workflows/ci.yml)
[![Documentation](https://img.shields.io/badge/docs-zensical-blue.svg)](https://axiomantic.github.io/nim-esphome/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**`nim-esphome`** lets you write ESPHome custom components and embedded logic in [Nim](https://nim-lang.org). Write clean, memory-safe code for ESP32 and ESP8266 devices that compiles directly into ESPHome's PlatformIO and ESP-IDF build pipelines.

> 📚 **Complete Documentation & API Reference**: Browse the full static documentation site built with [Zensical](https://github.com/squidfunk/zensical) in [`docs/`](docs/index.md) or online at [**axiomantic.github.io/nim-esphome**](https://axiomantic.github.io/nim-esphome/).

---

## Table of Contents

- [Why Nim for ESPHome?](#why-nim-for-esphome)
- [Key Features](#key-features)
- [Prerequisites](#prerequisites)
- [Installation & Integration](#installation--integration)
- [Quickstart: Blink / Heartbeat](#quickstart-blink--heartbeat)
- [Documentation & Guides](#documentation--guides)
- [Example Projects](#example-projects)
- [Component Configuration](#component-configuration)
- [Automated Nimble Dependency Management](#automated-nimble-dependency-management)
- [Embedded Architecture & Multi-CPU Target Alignment](#embedded-architecture--multi-cpu-target-alignment)
- [Core APIs & ESPHome Interoperability](#core-apis--esphome-interoperability)
  - [Logging & Microcontroller Timing](#logging--microcontroller-timing)
  - [First-Class Entity Bindings](#first-class-entity-bindings)
  - [Hardware Bus & Peripheral Abstractions (GPIO & I2C)](#hardware-bus--peripheral-abstractions-gpio--i2c)
  - [Flash Preferences / Non-Volatile Storage (NVS)](#flash-preferences--non-volatile-storage-nvs)
  - [Embedded Control & DSP Utilities](#embedded-control--dsp-utilities)
  - [Calling Nim Procs from ESPHome C++](#calling-nim-procs-from-esphome-c)
- [Projects Using nim-esphome](#projects-using-nim-esphome)
- [Project Templating & Distribution](#project-templating--distribution)
- [Testing & CI](#testing--ci)
- [Project Structure](#project-structure)
- [Changelog](#changelog)
- [License](#license)

---

## Why Nim for ESPHome?

ESPHome is great for declaratively configuring hardware, but complex embedded logic often gets squeezed into long, unmaintainable C++ lambdas in YAML. C++ lambdas lack:

- Algebraic data types and pattern matching
- High-level syntax with memory safety guarantees
- Fast local unit testing on host machines (macOS/Linux) without flashing hardware

`nim-esphome` solves this by giving you a first-class external component in ESPHome. You write idiomatic Nim code, and `nim-esphome` translates it to C++ on the fly, compiles it into your firmware binary, and links it directly against ESPHome's runtime.

---

## Key Features

- ⚡ **Zero-Overhead Embedded Runtime**: Uses Nim's deterministic ARC memory management (`--mm:arc`), `-d:useMalloc`, `--exceptions:goto`, and `--panics:on`. No heavy tracing garbage collector or thread overhead.
- 🔌 **First-Class External Component**: Plug-and-play via ESPHome's standard `external_components`. Automatically generates and compiles `.cpp` files during `esphome compile` and `esphome run`.
- 🪵 **ESPHome Logging & Clock Bindings**: Native Nim wrappers for `ESP_LOGI`, `ESP_LOGW`, `ESP_LOGE`, `ESP_LOGD`, `millis()`, and `delay()`.
- 🔄 **Lifecycle Hooks**: Simple `esphomeSetup` and `esphomeLoop` templates integrated directly with ESPHome's main loop.
- 🔗 **Exporting to C++ Lambdas**: Convenient `{.exportEsphome.}` pragma to expose C ABI functions callable directly from ESPHome YAML lambdas.
- 🧪 **Hardware-Free Local Testing**: Write unit tests for your device logic in Nim and run them instantly on macOS or Linux using standard `nim c -r`.

---

## Prerequisites

- **Nim**: Version 2.0.0 or later installed on the build machine (the computer running ESPHome CLI or Home Assistant builder).
  ```bash
  # macOS
  brew install nim

  # Linux (Debian/Ubuntu)
  sudo apt-get install nim
  # or via choosenim:
  curl https://nim-lang.org/choosenim/init.sh -sSf | sh
  ```
- **ESPHome**: Version 2024.x or later with ESP-IDF or Arduino framework.

---

## Installation & Integration

### Option A: Local Directory (Recommended for Development)

Clone `nim-esphome` to your local development machine:

```bash
git clone https://github.com/axiomantic/nim-esphome.git ~/Development/nim-esphome
```

Reference the `components` directory in your device's ESPHome YAML:

```yaml
external_components:
  - source:
      type: local
      path: /Users/username/Development/nim-esphome/components
    components: [nim]
```

### Option B: Remote Git Repository

Directly point ESPHome to the GitHub repository:

```yaml
external_components:
  - source:
      type: git
      url: https://github.com/axiomantic/nim-esphome
    components: [nim]
```

---

## Quickstart: Blink / Heartbeat

### 1. Write the Nim Logic (`my_logic.nim`)

```nim
import nim_esphome

var lastHeartbeat: uint32 = 0

esphomeSetup:
  info("MyDevice", "Nim logic initialized successfully!")

esphomeLoop:
  let now = millis()
  if now - lastHeartbeat >= 5000:
    lastHeartbeat = now
    info("MyDevice", "Periodic 5s heartbeat from Nim runtime")

# Export a function to ESPHome C++ lambdas
proc computeTargetLevel*(ambientLight: int32): int32 {.exportEsphome.} =
  if ambientLight < 100:
    return 255
  elif ambientLight < 500:
    return 128
  else:
    return 0
```

### 2. Configure ESPHome (`device.yaml`)

```yaml
esphome:
  name: my-esp32-device

esp32:
  board: esp32dev
  framework:
    type: esp-idf

logger:
  level: INFO

external_components:
  - source:
      type: local
      path: /path/to/nim-esphome/components
    components: [nim]

nim:
  source: my_logic.nim

sensor:
  - platform: template
    name: "Computed Target Level"
    update_interval: 10s
    lambda: |-
      extern int32_t computeTargetLevel(int32_t);
      return computeTargetLevel(50);
```

### 3. Build & Flash

```bash
esphome run device.yaml
```

The ESPHome build tool automatically invokes the Nim compiler, cross-compiling your Nim module into 32-bit C++ sources in PlatformIO's build directory and compiling it into the final firmware binary.

> 📖 **Getting Started Guide**: See the complete [Getting Started Guide](docs/guides/getting-started.md) for step-by-step setup and local development tips.

---

## Documentation & Guides

Comprehensive guides and API references are available in the [`docs/`](docs/index.md) directory and online at [**axiomantic.github.io/nim-esphome**](https://axiomantic.github.io/nim-esphome/):

- 🚀 [**Getting Started**](docs/guides/getting-started.md): Installation, build pipeline, and first project.
- ⚙️ [**YAML Configuration**](docs/guides/configuration.md): Complete schema options, flags, and architecture overrides.
- 📦 [**Nimble Dependencies**](docs/guides/dependencies.md): Automated package downloads, Git repository URLs, and caching.
- ⚡ [**Target Architectures & Cross-Compilation**](docs/guides/architectures.md): Multi-CPU alignment (Xtensa, RISC-V, ARM), pointer widths, and ARC memory.
- 🎛️ [**Entities & Home Assistant**](docs/guides/entities.md): Numerical sensors, binary sensors, switches, select, number, and button controls.
- 📊 [**Lovelace Dashboard Surfaces DSL**](docs/guides/dashboard-dsl.md): Declaratively define and export Home Assistant Lovelace cards directly from firmware.
- ⚡ [**Custom Actions & Services DSL**](docs/guides/actions-dsl.md): Type-safe Home Assistant actions and service handlers.
- ⏱️ [**RTOS Task & Schedule DSL**](docs/guides/schedule-dsl.md): Cooperative, non-blocking periodic task scheduling and one-shot delays.
- 🖥️ [**Composite Hardware Surfaces DSL**](docs/guides/surface-dsl.md): Unified domain models combining controls, telemetry, and matched dashboard cards.
- 🔌 [**Hardware Buses (GPIO & I2C)**](docs/guides/hardware.md): Microcontroller pin modes and I2C peripheral register transfers.
- 💾 [**Flash Preferences (NVS)**](docs/guides/storage.md): Non-volatile parameter storage across power cycles.
- 📈 [**Embedded DSP & Closed-Loop Control**](docs/guides/dsp-control.md): PID controllers, sliding statistics, and contact debouncers.
- 🔗 [**C++ Interoperability**](docs/guides/interop.md): Exporting Nim procs to YAML lambdas and calling C++ libraries.
- 🎙️ [**Verified Voice Satellite Case Study**](docs/guides/esphome-satellite.md): Real-world on-device state supervisor for ESPHome voice satellites.
- 🌐 [**Project Templating & 1-Click Distribution**](docs/guides/distribution.md): ESP-Web-Tools browser flashing, My Home Assistant import, and CI factory binary releases.
- 📚 [**Full API Reference**](docs/api/index.md): Complete reference for all public types, procedures, and macros.

---

## Example Projects

The [`examples/`](examples/README.md) directory contains complete, standalone, buildable ESPHome projects illustrating idiomatic Nim firmware architectures and all Home Assistant DSLs. Every example is tested in CI for embedded 32-bit compilation and ESPHome configuration validity:

| Example | Domain / DSL | Description |
|---|---|---|
| [**Blink & Peripherals**](examples/blink/) | Core Runtime | GPIO toggling, I2C register transfers, Flash preferences, and low-pass filtering. |
| [**Voice Satellite**](examples/voice_satellite/) | `esphomeControls` & Satellite | 14-state voice satellite pipeline with asynchronous audio loop (`psSpinner`) and Lovelace controls card. |
| [**Smart Thermostat**](examples/smart_thermostat/) | `haSurface` & `haSchedule` | Composite HVAC surface combining temperature telemetry, target setpoints, boost action, and PID loop. |
| [**Custom Actions**](examples/custom_actions/) | `haService` / `haAction` | Type-safe Home Assistant action definitions with automatic YAML schema generation and input validation. |
| [**Cooperative Scheduler**](examples/cooperative_scheduler/) | `haSchedule` | Non-blocking periodic routines (`every 50.ms`, `every 2.seconds`) and delayed execution (`after 10.seconds`). |
| [**Dashboard Surfaces**](examples/dashboard_surface/) | `haDashboard` & `haCard` | Multi-view Lovelace dashboard generation pushed directly to Home Assistant via an ESPHome `text_sensor`. |

To run the automated embedded compilation and schema validation suite across all examples:
```bash
nimble test  # or ./scripts/test.sh
```

---

## Component Configuration

Configure the `nim:` block in your ESPHome YAML:

```yaml
nim:
  # Path to the primary .nim source file (Required)
  source: src/my_logic.nim

  # Automated Nimble dependencies (installed into isolated build cache)
  requires:
    - jsony
    - chroma

  # Additional manual include paths for external packages (Optional)
  nimble_paths:
    - /path/to/external/pkg/src

  # Extra flags passed directly to `nim cpp` (Optional)
  nim_flags:
    - "-d:danger"
    - "--opt:size"

  # Target CPU override: esp (Xtensa), riscv32, arm (Optional, auto-detected)
  target_cpu: esp

  # Path to the nim executable (Default: "nim")
  nim_path: "/usr/local/bin/nim"
```

| Option | Type | Default | Description |
|---|---|---|---|
| `source` | `string` | **Required** | Absolute or relative path to the entrypoint `.nim` file |
| `requires` | `list` | `[]` | Automated Nimble packages or Git repositories installed at build time |
| `nim_flags` | `list` | `[]` | Extra arguments passed to `nim cpp` |
| `nimble_paths` | `list` | `[]` | Additional search paths for Nim packages |
| `nim_path` | `string` | `"nim"` | Path to the `nim` compiler executable |
| `target_cpu` | `string` | Auto | Target CPU architecture (`esp`, `riscv32`, `arm`). Auto-detected from board. |

> 📖 **Full Guide**: See the [YAML Configuration Guide](docs/guides/configuration.md) for detailed descriptions, platform defaults, and optimization flags.

---

## Automated Nimble Dependency Management

`nim-esphome` can automatically download, cache, and configure third-party Nimble packages during ESPHome compilation via the `requires:` key in your YAML configuration:

```yaml
nim:
  source: src/main.nim
  requires:
    - jsony
    - chroma
```

During build generation:
1. `nim-esphome` invokes `nimble install -y` targeting an isolated node build cache (`.esphome/build/<node>/.nimble`).
2. Packages and Git repositories are installed without polluting global environments or requiring host pre-installation.
3. The component automatically configures `--nimblePath` and package module paths directly into the embedded Nim transpilation command.

> 📖 **Full Guide**: See the [Automated Nimble Dependencies Guide](docs/guides/dependencies.md) for caching architecture and offline development.

---

## Embedded Architecture & Multi-CPU Target Alignment

ESPHome targets resource-constrained microcontrollers spanning multiple 32-bit CPU architectures. `nim-esphome` transparently configures the target compiler environment based on your board:

1. **Multi-Architecture Auto-Detection**:
   - **ESP32 / ESP32-S2 / ESP32-S3**: Automatically sets `--cpu:esp` (32-bit Xtensa).
   - **ESP32-C2 / ESP32-C3 / ESP32-C6 / ESP32-H2 / ESP32-P4**: Automatically sets `--cpu:riscv32` (32-bit RISC-V).
   - **Raspberry Pi RP2040**: Automatically sets `--cpu:arm --os:any` (Cortex-M0+).
   - Can be overridden explicitly via `target_cpu: riscv32` or via `nim_flags: ["--cpu:..."]`.
2. **Target Pointer Alignment**: Enforces 32-bit microcontroller pointer width (`sizeof(NI) == 4`).
3. **C++ Exception Handling**: ESP-IDF defaults to `-fno-exceptions`. `nim-esphome` configures `--exceptions:goto` and `--panics:on`, eliminating C++ `try/catch` and libsupc++ overhead.
4. **Deterministic Memory**: Uses `--mm:arc` with `-d:useMalloc` to delegate all allocations to FreeRTOS's heap allocator without GC pause times.
5. **Const C-Strings**: Provides `ConstCString` mapped to `const char*` to avoid `-Wwrite-strings` C++ compiler warnings on modern GCC/Clang.

> 📖 **Full Guide**: See [Target Architectures & Cross-Compilation](docs/guides/architectures.md) for deep-dive technical details on embedded memory and code generation.

---

## Core APIs & ESPHome Interoperability

### Logging & Microcontroller Timing

```nim
import nim_esphome

# Logging
info("Tag", "Information message")
warn("Tag", "Warning message")
error("Tag", "Error message")
debug("Tag", "Debug message")

# Timing
let t: uint32 = millis()
delay(100) # milliseconds
```

> 📚 **API Reference**: See [`nim_esphome/api`](docs/api/api.md) for logging macros, microsecond clocks, watchdog feeding, and system reboot.

### First-Class Entity Bindings

Publish state directly to ESPHome entities (`sensor`, `binary_sensor`, `switch`, `text_sensor`) from Nim using type-safe handles:

```nim
import nim_esphome

let tempSensor = newSensor("living_room_temperature")
let motionSensor = newBinarySensor("hallway_motion")
let relaySwitch = newSwitch("main_relay")
let statusMsg = newTextSensor("device_status")

# Publish numerical, boolean, or string state
tempSensor.publishState(21.5'f32)
motionSensor.publishState(true)
relaySwitch.publishState(false)
statusMsg.publishState("Running")
```

When compiled for embedded firmware, `publishState` looks up registered entities dynamically in the ESPHome `Application` registry and executes `publish_state(...)`. In local unit tests on host machines, a mock registry is maintained for headless verification.

> 📖 **Full Guide & API**: See [Entities & Home Assistant Guide](docs/guides/entities.md) and [`nim_esphome/entities`](docs/api/entities.md).

### Domain-Specific Languages (DSLs) for Home Assistant Surfaces

`nim-esphome` includes a suite of declarative DSLs (`nim_esphome/dsl`) that bridge low-level microcontroller silicon to high-level Home Assistant surfaces:

#### 1. Declarative Controls DSL (`esphomeControls`)
Declare `select`, `number`, `switch`, and `button` controls with automatic flash NVS persistence:

```nim
esphomeControls:
  select[AudioStyle]("sound_style"):
    name = "Sound Style"
    default = asSpinner
    persist = true
    onSelect(style): setStyle(style)

  number("volume"):
    name = "Volume"
    min = 0.0; max = 100.0; step = 5.0; default = 75.0
    persist = true
    onChange(vol): setVolume(vol)
```
> 📖 See [Entities & Controls Guide](docs/guides/entities.md) and [`nim_esphome/dsl/entities`](docs/api/dsl.md#home-assistant-controls-dsl).

#### 2. Lovelace Dashboard Surface DSL (`haDashboard` / `haCard`)
Generate production-ready Home Assistant dashboard cards and multi-view configurations directly from firmware code:

```nim
let satelliteCard = haCard(ctEntities, "Voice Satellite", "mdi:microphone"):
  card.addEntity "select.sound_style", name = "Audio Feedback"
  card.addEntity "number.volume", name = "Volume"
  card.addEntity "switch.mute", name = "Muted"

echo satelliteCard.toYaml()
```
> 📖 See [Lovelace Dashboard Surfaces Guide](docs/guides/dashboard-dsl.md) and [`nim_esphome/dsl/dashboard`](docs/api/dsl.md#lovelace-dashboard-surface-dsl).

#### 3. Custom Actions & Services DSL (`haService` / `haAction`)
Expose type-safe actions callable from Home Assistant automations and scripts:

```nim
haService("play_tone"):
  description = "Plays an audio tone on the satellite speaker"
  param "frequency", pkInt, min = 100.0, max = 10000.0, defaultVal = "440"
  param "duration_ms", pkInt, min = 10.0, max = 5000.0, defaultVal = "200"
  onExecute(ctx):
    playTone(ctx.getInt("frequency"), ctx.getInt("duration_ms"))
```
> 📖 See [Custom Actions & Services Guide](docs/guides/actions-dsl.md) and [`nim_esphome/dsl/actions`](docs/api/dsl.md#custom-actions--service-calls-dsl).

#### 4. RTOS Task & Schedule DSL (`haSchedule`)
Cooperative, non-blocking periodic task scheduling and one-shot delays inside ESPHome's main loop without thread overhead:

```nim
haSchedule:
  every 50.ms:
    stepAudioPipeline()
  every 5.seconds:
    publishTelemetry()
  after 30.seconds:
    finalizeCalibration()
```
> 📖 See [RTOS Task & Schedule Guide](docs/guides/schedule-dsl.md) and [`nim_esphome/dsl/schedule`](docs/api/dsl.md#rtos-background-task--schedule-dsl).

#### 5. Composite Hardware Surfaces DSL (`haSurface`)
Unify hardware metadata, controls, telemetry sensors, and matched dashboard cards into a single cohesive domain model:

```nim
let satellite = haSurface("voice_satellite"):
  surface.name = "Living Room Voice Satellite"
  surface.model = "ReSpeaker XVF3800"
  surface.manufacturer = "Seeed Studio"
  surface.addControl(sekSelect, "sound_style", name = "Sound Style")
  surface.addControl(sekNumber, "volume", name = "Volume")
  surface.addTelemetry(sekSensor, "wifi_rssi", name = "Signal", unit = "dBm")

echo satellite.generateLovelaceYaml()
echo satellite.generateEsphomeYaml()
```
> 📖 See [Composite Hardware Surfaces Guide](docs/guides/surface-dsl.md) and [`nim_esphome/dsl/surface`](docs/api/dsl.md#composite-hardware-device-dsl).

#### 6. Web Installer & Dynamic Flashing DSL (`esphomeInstaller`)
Generate interactive ESP-Web-Tools web installers with customizable form fields (file uploads, dropdown selects, text, checkboxes), dynamic WebSerial manifest construction, and verified collision-free flash partition calculations:

```nim
let satelliteInstaller = esphomeInstaller("voice-satellite"):
  installer.title = "Voice Satellite Web Installer"
  installer.chipFamily = "ESP32-S3"
  installer.factoryBinPath = "firmware-factory.bin"

  installer.addFileField(
    name = "custom_audio",
    label = "Custom Processing Sound (.wav)",
    partition = "sound_data",
    maxSize = 262144
  )

writeFile("partitions.csv", satelliteInstaller.generatePartitionsCsv(flashSizeMb = 4))
writeFile("web/index.html", satelliteInstaller.generateHtml())
```
> 📖 See [Web Installer & Dynamic Flashing Guide](docs/guides/installer-dsl.md) and [`nim_esphome/dsl/installer`](docs/guides/installer-dsl.md).

### Hardware Bus & Peripheral Abstractions (GPIO & I2C)

Control microcontroller GPIO pins and communicate over I2C buses directly from Nim:

#### GPIO Manipulation

```nim
import nim_esphome

# Configure pin mode
pinMode(2, Output)
pinMode(4, InputPullup)

# Digital write and read
digitalWrite(2, High)
let pinState: PinState = digitalRead(4)
if pinState == Low:
  info("Button", "Pressed!")
```

#### I2C Bus Transfers

```nim
import nim_esphome

# Instantiate peripheral with target 7-bit I2C address
let accelerometer = newI2CDevice(0x68)

# Write to registers
accelerometer.writeByte(0x6B, 0x00) # Wake device
accelerometer.writeRegister(0x1C, [0x08'u8])

# Read raw bytes or register contents
let chipId: uint8 = accelerometer.readByte(0x75)
let rawData: seq[uint8] = accelerometer.readRegister(0x3B, 6)
```

> 📖 **Full Guide & API**: See [Hardware Buses Guide](docs/guides/hardware.md), [`nim_esphome/gpio`](docs/api/gpio.md), and [`nim_esphome/i2c`](docs/api/i2c.md).

### Flash Preferences / Non-Volatile Storage (NVS)

Persist calibration constants, runtime counters, and configurations across power cycles and reboots via ESPHome's NVS storage backend:

```nim
import nim_esphome

# Load with type inference and fallback defaults
var bootCount = loadPreference("boot_count", 0'i32) + 1
discard savePreference("boot_count", bootCount)

var targetTemp = loadPreference("target_temp", 21.0'f32)
discard savePreference("target_temp", 22.5'f32)

var wifiSsid = loadPreference("wifi_ssid", "DefaultSSID")
discard savePreference("wifi_ssid", "HomeIoT")
```

> 📖 **Full Guide & API**: See [Flash Preferences Guide](docs/guides/storage.md) and [`nim_esphome/preferences`](docs/api/preferences.md).

### Embedded Control & DSP Utilities

Deterministic, zero-heap-allocation control algorithms and signal filtering utilities tailored for microcontrollers:

#### PID Closed-Loop Controller
```nim
import nim_esphome

var pid = newPIDController(kp = 2.0'f32, ki = 0.5'f32, kd = 0.1'f32, minOutput = 0.0'f32, maxOutput = 100.0'f32)

# Compute control effort with anti-windup clamping
let controlEffort = pid.update(setpoint = 25.0'f32, measured = currentTemp, dt = 1.0'f32)
```

#### Moving Average & Moving Median
```nim
import nim_esphome

# Fixed-size stack-allocated circular buffer of 5 samples
var avg = newMovingAverage[5]()
let smoothed = avg.update(rawAdcSample)

# Moving median filter to reject sensor noise spikes and outliers
var med = newMovingMedian[5]()
let filteredVal = med.update(noisySensorReading)
```

#### Low-Pass Exponential Filter
```nim
import nim_esphome

var lpf = newLowPassFilter(alpha = 0.15'f32)
let smoothedSignal = lpf.update(noisyInput)
```

#### Input Debouncer & Edge Detection
```nim
import nim_esphome

var buttonDebouncer = newDebouncer(debounceTimeMs = 50'u32)
if buttonDebouncer.update(digitalRead(4) == Low, millis()):
  if buttonDebouncer.rose:
    info("Button", "Clean button press event!")
```

> 📖 **Full Guide & API**: See [Embedded DSP & Control Guide](docs/guides/dsp-control.md) and [`nim_esphome/dsp`](docs/api/dsp.md).

### Calling Nim Procs from ESPHome C++

Define your procedure in Nim with `{.exportEsphome.}`:

```nim
proc setSensitivity*(threshold: int32) {.exportEsphome.} =
  info("NimCore", "Sensitivity threshold updated")
```

Declare and invoke the symbol in ESPHome YAML:

```yaml
button:
  - platform: template
    name: "Tune Sensitivity"
    on_press:
      - lambda: |-
          extern void setSensitivity(int32_t);
          setSensitivity(42);
```

> 📖 **Full Guide & API**: See [C++ Interoperability Guide](docs/guides/interop.md) and [`nim_esphome` Core](docs/api/core.md).

---

## Projects Using nim-esphome

### [esphome-satellite](https://github.com/axiomantic/esphome-satellite)

A 14-state voice satellite firmware state machine for [ESPHome](https://esphome.io) and Home Assistant (analogous to Home Assistant's `wyoming-satellite`, but executing directly on the ESP32 microcontroller).

- **Problem Solved**: Conventional voice satellites distribute state across asynchronous Home Assistant network events and C++ callbacks, causing split-brain race conditions: premature chime clipping, false "stop" word clobbering, audio ducking failures, and offline phantom triggers.
- **Solution**: Implements a complete 14-state verified typestate FSM directly on-device using `nim-esphome` and [`nim-typestates`](https://github.com/elijahr/nim-typestates). Illegal state transitions (such as triggering wake words during OTA flashing, hardware privacy mute, or pipeline errors) are statically rejected at compile time.
- **Supported Hardware**: Seeed Studio ReSpeaker XVF3800, Home Assistant Voice PE, ESP32-S3-BOX-3, and any standard ESP32 voice satellite.

> 📖 **Case Study**: Read the complete [Verified Voice Satellite Case Study](docs/guides/esphome-satellite.md) for architectural details and state machine diagrams.


#### Quick Integration

In your ESPHome device YAML:

```yaml
external_components:
  - source:
      type: git
      url: https://github.com/axiomantic/nim-esphome
      ref: main
    components: [nim]

# Include the pre-packaged esphome-satellite FSM
packages:
  satellite_fsm: github://axiomantic/esphome-satellite/packages/satellite_nim_fsm.yaml
```

---

## Project Templating & Distribution

`nim-esphome` establishes a standard distribution template for embedded Nim projects, enabling end-users to flash hardware without compiling code or editing YAML:

1. **In-Browser Web Flashing (ESP-Web-Tools)**: Host a zero-install WebSerial installer on GitHub Pages. Users plug in their ESP32 via USB and flash factory binaries directly from Chrome or Edge.
2. **Modular Remote Packages & Adoption**: Provide standalone device packages (`packages: github://...`) with `dashboard_import:` metadata for adoption into local ESPHome Dashboards.
3. **Automated Factory Binary Builds in CI**: GitHub Actions workflows merge bootloaders, partition tables, and firmware into flashable `firmware-factory.bin` bundles attached to releases.

> 📖 **Full Guide**: Read [**Project Templating & Distribution**](docs/guides/distribution.md) for the complete directory layout, ESP-Web-Tools HTML templates, and CI packaging scripts.

---

## Testing & CI

You can write native tests using Nim's standard `unittest` library and run them locally:

```bash
# Run unit tests and embedded C++ transpilation checks
./scripts/build.sh
```

GitHub Actions runs continuous integration across Linux and macOS on every push and pull request, validating host unit tests, python component schemas, and multi-architecture embedded cross-compilation (Xtensa, RISC-V, ARM).

---

## Project Structure

```
nim-esphome/
├── components/
│   └── nim/
│       ├── __init__.py           # ESPHome external component hook, dependency resolver & compiler
│       ├── nim_component.h       # C++ ESPHome Component class definition
│       ├── nim_component.cpp     # C++ ESPHome Component implementation & ABI bridge
│       └── nim_esphome_bridge.h  # C symbol bridge declarations
├── src/
│   ├── nim_esphome.nim           # Main library entrypoint & exports
│   └── nim_esphome/
│       ├── api.nim               # ESPHome C runtime bindings (logging, timing, reboot, wdt)
│       ├── entities.nim          # First-class Sensor, BinarySensor, Switch, TextSensor bindings
│       ├── gpio.nim              # Microcontroller GPIO pinMode, digitalWrite, digitalRead
│       ├── i2c.nim               # I2C bus transactions, register reads/writes
│       ├── preferences.nim       # Non-volatile flash storage (NVS) savePreference / loadPreference
│       └── dsp.nim               # PID controller, moving average/median, filters, debouncer
├── examples/
│   └── blink/                    # Self-contained embedded example showcasing all APIs
├── tests/
│   ├── test_basic.nim            # Core API and lifecycle unit tests
│   ├── test_entities.nim         # Entity binding unit tests
│   ├── test_peripherals.nim      # GPIO & I2C abstraction unit tests
│   ├── test_preferences.nim      # Non-volatile storage unit tests
│   ├── test_dsp.nim              # DSP algorithms & PID controller unit tests
│   └── test_nimble_mgmt.py       # Python component & Nimble resolution unit tests
├── scripts/
│   └── build.sh                  # Comprehensive test runner & multi-target C++ cross-compiler
└── nim_esphome.nimble            # Nimble package specification
```

## Changelog

All notable changes are documented in [CHANGELOG.md](CHANGELOG.md) in [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

---

## License

MIT © [Axiomantic](https://github.com/axiomantic) / [Elijah Rust](https://github.com/elijahr)
