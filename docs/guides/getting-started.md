# Getting Started with nim-esphome

This guide walks you through setting up `nim-esphome`, creating a minimal embedded Nim application, and building your firmware with ESPHome.

---

## Prerequisites

Before using `nim-esphome`, ensure you have the following tools installed on your build machine (the computer running ESPHome CLI or your Home Assistant build server):

1. **Nim (>= 2.0.0)**:
   ```bash
   # macOS via Homebrew
   brew install nim

   # Linux via APT
   sudo apt-get update && sudo apt-get install -y nim

   # Or install via choosenim (official toolchain manager)
   curl https://nim-lang.org/choosenim/init.sh -sSf | sh
   ```
   Verify installation:
   ```bash
   nim --version
   ```

2. **ESPHome (>= 2024.x)**:
   ```bash
   pip install esphome
   esphome version
   ```

---

## Installation & Setup

You can integrate `nim-esphome` into your ESPHome project using either a local clone or directly from GitHub.

### Method A: Local Development (Recommended)

Clone the repository locally:
```bash
git clone https://github.com/axiomantic/nim-esphome.git ~/Development/nim-esphome
```

Add the component to your ESPHome device YAML:
```yaml
external_components:
  - source:
      type: local
      path: /Users/username/Development/nim-esphome/components
    components: [nim]
```

### Method B: Remote Git Repository

Directly point ESPHome to the GitHub repository:
```yaml
external_components:
  - source:
      type: git
      url: https://github.com/axiomantic/nim-esphome
      ref: main
    components: [nim]
```

---

## Creating Your First Project

Let's create a complete ESPHome project that blinks an LED and logs diagnostic data every 5 seconds.

### Step 1: Write the Nim Entrypoint (`src/main.nim`)

Create a file named `src/main.nim`:

```nim
import nim_esphome

const
  LedPin = 2'u8
  HeartbeatIntervalMs = 5000'u32

var
  lastHeartbeat: uint32 = 0
  ledState: PinState = Low

esphomeSetup:
  info("BlinkApp", "Initializing microcontroller peripherals from Nim...")
  pinMode(LedPin, Output)
  digitalWrite(LedPin, ledState)
  info("BlinkApp", "GPIO pin 2 configured as Output")

esphomeLoop:
  let now = millis()
  if now - lastHeartbeat >= HeartbeatIntervalMs:
    lastHeartbeat = now

    # Toggle LED
    ledState = if ledState == Low: High else: Low
    digitalWrite(LedPin, ledState)

    let freeHeap = getFreeHeap()
    info("BlinkApp", "Heartbeat! LED state toggled. Free heap: " & $freeHeap & " bytes")
```

### Step 2: Configure ESPHome (`blink_device.yaml`)

Create `blink_device.yaml`:

```yaml
esphome:
  name: blink-demo

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
  source: src/main.nim
```

### Step 3: Compile and Flash

Run the standard ESPHome compilation command:

```bash
esphome run blink_device.yaml
```

What happens under the hood:
1. ESPHome loads the `nim` component hook during configuration generation.
2. The component invokes `nim cpp` targeting 32-bit embedded C++ (`--cpu:esp --os:any --mm:arc -d:danger`).
3. Nim transpiles `src/main.nim` into standard `.cpp` source files placed directly inside PlatformIO's build tree (`.esphome/build/blink-demo/src/`).
4. PlatformIO's GCC compiler compiles both the ESPHome runtime and your Nim C++ files together into a single binary image.
5. ESPHome flashes the binary over USB or OTA.

---

## Next Steps

- Learn about all configuration options in the [**YAML Configuration Guide**](configuration.md).
- Learn how to manage external Nim libraries in the [**Nimble Dependencies Guide**](dependencies.md).
- Explore hardware pin control and I2C peripherals in the [**Hardware Buses Guide**](hardware.md).
