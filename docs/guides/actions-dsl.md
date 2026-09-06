# Custom Actions & Service Calls DSL

In Home Assistant, **Actions** (historically called **Services**) allow users, automations, and scripts to trigger device-specific routines with custom arguments (e.g. `satellite.play_custom_tone(frequency=880, duration_ms=500)`).

Implementing custom services in native ESPHome C++ requires managing untyped argument maps, manual string parsing, and verbose lambda bindings.

The **Custom Actions DSL** (`nim_esphome/dsl/actions`) enables firmware authors to declare typed Home Assistant actions directly in Nim.

---

## Core Features

- **Type-Safe Argument Parsing**: Supports `string`, `int`, `float`, and `bool` parameters.
- **Automatic Fallback Defaults**: If an automation omits an optional argument, default values are automatically supplied.
- **Bounds Checking**: Define optional `min` and `max` constraints for numerical arguments.
- **ESPHome YAML Generation**: Automatically generates the corresponding `api.services` YAML declaration via `toEsphomeYaml()`.
- **Host Testability**: Validate service invocations on your development machine using `triggerServiceCall()` without flashing microcontrollers.

---

## Declaring an Action

```nim
import nim_esphome/dsl/actions

haService("play_custom_tone"):
  description = "Plays an audio tone on the satellite speaker"
  param "frequency", pkInt, min = 100.0, max = 10000.0, defaultVal = "440", description = "Tone frequency in Hertz"
  param "duration_ms", pkInt, min = 10.0, max = 5000.0, defaultVal = "200", description = "Tone duration in milliseconds"
  param "style", pkString, defaultVal = "sine", description = "Waveform shape (sine, square, triangle)"
  param "alert", pkBool, defaultVal = "false", description = "Override active media playback"

  onExecute(ctx):
    let freq = ctx.getInt("frequency")
    let dur = ctx.getInt("duration_ms")
    let style = ctx.getString("style")
    let isAlert = ctx.getBool("alert")

    echo "Executing tone: ", freq, " Hz, ", dur, " ms, style=", style, " alert=", isAlert
```

---

## Generating ESPHome YAML

You can inspect the exact ESPHome `api.services` definition by calling `toEsphomeYaml()`:

```nim
let serviceDef = getService("play_custom_tone").get()
echo serviceDef.toEsphomeYaml()
```

### Generated ESPHome YAML Output

```yaml
  - service: play_custom_tone
    variables:
      frequency: int
      duration_ms: int
      style: string
      alert: bool
    then:
      - lambda: |-
          // Dispatch play_custom_tone into Nim runtime
```

---

## Unit Testing on Host Machines

You can verify that your action logic handles parameters and default fallbacks correctly without connecting hardware:

```nim
# Call with full arguments
let success1 = triggerServiceCall("play_custom_tone", [
  ("frequency", newParamValue(880)),
  ("duration_ms", newParamValue(500)),
  ("style", newParamValue("square")),
  ("alert", newParamValue(true))
])
assert success1 == true

# Call with missing optional arguments (uses configured defaults)
let success2 = triggerServiceCall("play_custom_tone", [
  ("frequency", newParamValue(1000))
])
assert success2 == true
```

---

## Complete Working Project

The following code is pulled directly from [`examples/custom_actions/`](https://github.com/axiomantic/nim-esphome/tree/main/examples/custom_actions), which is compiled for embedded ESP32 targets and validated against ESPHome in the automated test suite:

=== "Nim Source (`custom_actions.nim`)"
    ```nim
--8<-- "examples/custom_actions/custom_actions.nim"
    ```

=== "ESPHome YAML (`custom_actions.yaml`)"
    ```yaml
--8<-- "examples/custom_actions/custom_actions.yaml"
    ```

