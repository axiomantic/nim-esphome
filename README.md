# nim-esphome

[![CI](https://github.com/axiomantic/nim-esphome/actions/workflows/ci.yml/badge.svg)](https://github.com/axiomantic/nim-esphome/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**`nim-esphome`** brings the expressive power, compile-time safety, and zero-overhead performance of [Nim](https://nim-lang.org) to [ESPHome](https://esphome.io). Write custom ESP32/ESP8266 logic, embedded state machines, filters, and device drivers in Nim that compile directly into ESPHome\x27s PlatformIO and ESP-IDF build pipelines.

---

## Table of Contents

- [Why Nim for ESPHome?](#why-nim-for-esphome)
- [Key Features](#key-features)
- [Prerequisites](#prerequisites)
- [Installation & Integration](#installation--integration)
- [Quickstart: Blink / Heartbeat](#quickstart-blink--heartbeat)
- [Component Configuration](#component-configuration)
- [Embedded Architecture & Memory Model](#embedded-architecture--memory-model)
- [C++ / ESPHome Interoperability](#c--esphome-interoperability)
- [Testing & CI](#testing--ci)
- [Project Structure](#project-structure)
- [License](#license)

---

## Why Nim for ESPHome?

ESPHome is great for declaratively configuring hardware, but complex embedded logic often gets squeezed into long, unmaintainable C++ lambdas in YAML. C++ lambdas lack:
- Algebraic data types and pattern matching
- Compile-time verified state machines (e.g. typestates)
- High-level syntax with memory safety guarantees
- Fast local unit testing on host machines (macOS/Linux) without flashing hardware

`nim-esphome` solves this by giving you a first-class external component in ESPHome. You write idiomatic Nim code, and `nim-esphome` translates it to C++ on the fly, compiles it into your firmware binary, and links it directly against ESPHome\x27s runtime.

---

## Key Features

- ⚡ **Zero-Overhead Embedded Runtime**: Uses Nim\x27s deterministic ARC memory management (`--mm:arc`), `-d:useMalloc`, `--exceptions:goto`, and `--panics:on`. No heavy tracing garbage collector or thread overhead.
- 🔌 **Seamless External Component**: Plug-and-play via ESPHome\x27s standard `external_components`. Automatically generates and compiles `.cpp` files during `esphome compile` and `esphome run`.
- 🪵 **ESPHome Logging & Clock Bindings**: Native Nim wrappers for `ESP_LOGI`, `ESP_LOGW`, `ESP_LOGE`, `ESP_LOGD`, `millis()`, and `delay()`.
- 🔄 **Lifecycle Hooks**: Simple `esphomeSetup` and `esphomeLoop` templates integrated directly with ESPHome\x27s main loop.
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

Reference the `components` directory in your device\x27s ESPHome YAML:

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

The ESPHome build tool automatically invokes the Nim compiler, cross-compiling your Nim module into 32-bit C++ sources in PlatformIO\x27s build directory and compiling it into the final firmware binary.

---

## Component Configuration

Configure the `nim:` block in your ESPHome YAML:

```yaml
nim:
  # Path to the primary .nim source file (Required)
  source: src/my_logic.nim

  # Automated Nimble dependencies (installed into isolated build cache)
  requires:
    - https://github.com/elijahr/nim-typestates
    - zippy

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

---

## Automated Nimble Dependency Management

`nim-esphome` can automatically download, cache, and configure third-party Nimble packages during ESPHome compilation via the `requires:` key in your YAML configuration:

```yaml
nim:
  source: src/main.nim
  requires:
    - https://github.com/elijahr/nim-typestates
    - chroma
```

During build generation:
1. `nim-esphome` invokes `nimble install -y` targeting an isolated node build cache (`.esphome/build/<node>/.nimble`).
2. Packages and Git repositories are installed without polluting global environments or requiring host pre-installation.
3. The component automatically configures `--nimblePath` and package module paths directly into the embedded Nim transpilation command.

---

## Embedded Architecture & Memory Model

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

---

## C++ / ESPHome Interoperability

### Calling ESPHome APIs from Nim

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

---

## Testing & CI

You can write native tests using Nim\x27s standard `unittest` library and run them locally:

```bash
# Run unit tests
./scripts/test.sh

# Test C++ generation locally
./scripts/build.sh
```

GitHub Actions runs continuous integration across Linux and macOS on every push and pull request.

---

## Project Structure

```
nim-esphome/
├── components/
│   └── nim/
│       ├── __init__.py           # ESPHome external component hook & build step
│       ├── nim_component.h       # C++ ESPHome Component class definition
│       ├── nim_component.cpp     # C++ ESPHome Component implementation & bridge
│       └── nim_esphome_bridge.h  # C symbol bridge declarations
├── src/
│   ├── nim_esphome.nim           # Main library entrypoint
│   └── nim_esphome/
│       └── api.nim               # ESPHome C bindings (log, millis, delay)
├── examples/
│   └── blink/                    # Self-contained blink / heartbeat example
├── tests/
│   └── test_basic.nim            # Native host unit tests
├── scripts/
│   ├── build.sh                  # C++ compilation test script
│   └── test.sh                   # Native test runner script
└── nim_esphome.nimble            # Nimble package specification
```

---

## License

MIT © [Axiomantic](https://github.com/axiomantic) / [Elijah Rust](https://github.com/elijahr)
