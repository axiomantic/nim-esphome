# nim-esphome

**`nim-esphome`** brings the expressive power, type safety, and zero-overhead performance of [Nim](https://nim-lang.org) to [ESPHome](https://esphome.io). Write custom components, device logic, sensors, and state machines in Nim that compile directly into ESPHome's PlatformIO / ESP-IDF build pipeline.

---

## Highlights

- ⚡ **Zero-Overhead C++ Interop**: Compiles Nim directly to C++ using `--mm:arc` and `-d:useMalloc`, seamlessly integrating with ESP32 / ESP-IDF memory management without a heavy tracing GC.
- 🔌 **ESPHome External Component**: Plug-and-play via ESPHome's `external_components`. Compiles your `.nim` source automatically during `esphome compile` / `esphome run`.
- 🪵 **Native ESPHome Logging & Timing**: Built-in Nim bindings for `ESP_LOGI`, `ESP_LOGW`, `ESP_LOGE`, `ESP_LOGD`, `millis()`, and `delay()`.
- 🧩 **First-Class Component Lifecycle**: Simple templates for `esphomeSetup` and `esphomeLoop` hooked into ESPHome's event loop.

---

## Quickstart

### 1. Write Your Nim Component (`logic.nim`)

```nim
import nim_esphome

var lastTick: uint32 = 0

esphomeSetup:
  info("MyNim", "Nim runtime initialized successfully on ESPHome!")

esphomeLoop:
  let now = millis()
  if now - lastTick >= 5000:
    lastTick = now
    info("MyNim", "Periodic 5s heartbeat from Nim loop")

# Export a function callable from ESPHome C++ lambdas or automations
proc addNumbers*(a, b: int32): int32 {.exportEsphome.} =
  result = a + b
```

### 2. Configure ESPHome (`device.yaml`)

```yaml
esphome:
  name: nim-demo

esp32:
  board: esp32dev
  framework:
    type: esp-idf

logger:
  level: INFO

external_components:
  - source:
      type: local
      path: path/to/nim-esphome/components
    components: [nim]

nim:
  source: logic.nim
```

Run `esphome run device.yaml` as usual. The Nim compiler translates your code to C++ and PlatformIO builds and flashes the firmware.

---

## Component Configuration Options

| Option | Type | Default | Description |
|---|---|---|---|
| `source` | `string` | **Required** | Path to the main `.nim` source file |
| `nim_flags` | `list` | `[]` | Extra compiler flags passed to `nim cpp` (e.g. `-d:danger`) |
| `nimble_paths` | `list` | `[]` | Additional search directories for Nimble packages |
| `nim_path` | `string` | `"nim"` | Path to the `nim` compiler executable |

---

## License

MIT © [Elijah Rust](https://github.com/elijahr)
