# C++ Interoperability & YAML Lambdas

This guide explains how to expose procedures written in Nim to ESPHome C++ lambdas, and how to call external C/C++ functions from Nim.

---

## Exposing Nim Procs to C++ (`{.exportEsphome.}`)

The `{.exportEsphome.}` macro decorates a Nim procedure with `{.exportc, cdecl.}` pragmas, generating standard C ABI symbol linkage. This allows ESPHome C++ lambdas, actions, and custom C++ components to call Nim procedures directly without name mangling.

### Step 1: Define the Procedure in Nim
In your Nim file (e.g. `src/main.nim`):

```nim
import nim_esphome

var currentThreshold: int32 = 100

proc setThreshold*(newVal: int32) {.exportEsphome.} =
  currentThreshold = newVal
  info("Config", "Threshold updated from C++ lambda: " & $newVal)

proc calculateEffort*(ambientLight: int32): int32 {.exportEsphome.} =
  if ambientLight < currentThreshold:
    return 255
  else:
    return 0
```

### Step 2: Declare and Call in ESPHome YAML
In your ESPHome configuration YAML, declare the external C symbol inside any `lambda:` block:

```yaml
sensor:
  - platform: template
    name: "Calculated Dimmer Effort"
    update_interval: 5s
    lambda: |-
      extern int32_t calculateEffort(int32_t);
      return calculateEffort(45);

button:
  - platform: template
    name: "Reset Threshold"
    on_press:
      - lambda: |-
          extern void setThreshold(int32_t);
          setThreshold(150);
```

---

## Calling External C/C++ Functions from Nim

You can call any C or C++ function available in the ESP-IDF / Arduino SDK from Nim using Nim's native `{.importc, cdecl.}` pragmas:

```nim
# Call ESP-IDF internal chip temperature sensor
proc esp_err_to_name(code: int32): cstring {.importc: "esp_err_to_name", cdecl.}

# Call Arduino / FreeRTOS APIs
proc vTaskDelay(ticks: uint32) {.importc: "vTaskDelay", cdecl.}
```

### Handling C Strings (`ConstCString`)
When passing literal strings or `const char*` parameters into C++ libraries, use `ConstCString` from `nim_esphome/api` to prevent modern C++ compilers from emitting `-Wwrite-strings` warnings:

```nim
import nim_esphome/api

proc custom_c_api(name: ConstCString) {.importc: "custom_c_api", cdecl.}

custom_c_api("Device_1")
```
