# nim-esphome

**`nim-esphome`** brings the expressive power, type safety, and zero-overhead performance of [Nim](https://nim-lang.org) to [ESPHome](https://esphome.io). Write custom components, device logic, sensors, and complex state machines in Nim that compile directly into ESPHome's PlatformIO / ESP-IDF build pipeline.

---

## Highlights

- ⚡ **Zero-Overhead C++ Interop**: Compiles Nim directly to C++ using `--mm:arc` and `-d:useMalloc`, seamlessly integrating with ESP32 / ESP-IDF memory management without a heavy tracing GC.
- 🔌 **ESPHome External Component**: Plug-and-play via ESPHome's `external_components`. Compiles your `.nim` source automatically during `esphome compile` / `esphome run`.
- 🪵 **Native ESPHome Logging & Timing**: Built-in Nim bindings for `ESP_LOGI`, `ESP_LOGW`, `ESP_LOGE`, `ESP_LOGD`, `millis()`, and `delay()`.
- 🔄 **Optional Typestate Safety**: Integrate seamlessly with [`elijahr/nim-typestates`](https://github.com/elijahr/nim-typestates) to guarantee valid device states (e.g. voice satellites, robot controllers) at compile time.

---

## Quickstart

### 1. Minimal Nim Component (`logic.nim`)

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

### 2. ESPHome Configuration (`device.yaml`)

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

Run `esphome run device.yaml` as usual. The Nim compiler will translate your code to C++ and PlatformIO will build and flash the firmware.

---

## Optional: Compile-Time State Machines with `nim-typestates`

`nim-esphome` is completely general-purpose, but pairs especially well with [`elijahr/nim-typestates`](https://github.com/elijahr/nim-typestates) for state machines where illegal transitions must be impossible at compile time (such as voice assistant satellites or multi-step actuators).

```nim
import nim_esphome
import typestates

type
  SatelliteContext* = object
    wakeWord*: string

  Idle* = distinct SatelliteContext
  Woken* = distinct SatelliteContext
  Listening* = distinct SatelliteContext
  Thinking* = distinct SatelliteContext
  Replying* = distinct SatelliteContext

typestate SatelliteFSM:
  consumeOnTransition = false
  states Idle, Woken, Listening, Thinking, Replying
  transitions:
    Idle -> Woken
    Woken -> Listening
    Listening -> Thinking
    Thinking -> Replying
    Replying -> Idle

proc onWakeWord*(s: Idle, word: string): Woken {.transition.} =
  info("Satellite", "Detected wake word: " & word)
  result = Woken(SatelliteContext(wakeWord: word))

proc onChimeFinished*(s: Woken): Listening {.transition.} =
  info("Satellite", "Chime complete; opening microphone")
  result = Listening(SatelliteContext(s))

verifyTypestates()
```

If code attempts to transition from `Idle` directly to `Thinking`, the Nim compiler will reject the build before firmware is ever flashed to the device.

See [examples/satellite_typestates](examples/satellite_typestates) for a complete Voice Satellite implementation.

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
