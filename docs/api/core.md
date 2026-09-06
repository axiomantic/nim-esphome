# Module: `nim_esphome`

The main umbrella library module. Re-exports all submodules (`api`, `entities`, `gpio`, `i2c`, `preferences`, `dsp`) and provides lifecycle hook templates and C++ export macros.

---

## Templates

### `esphomeSetup`
```nim
template esphomeSetup*(body: untyped)
```
Registers initialization logic invoked once during ESPHome's setup phase.

The code inside `body` executes when the ESPHome `Component::setup()` lifecycle method is called, after system hardware and peripherals are initialized.

#### Parameters
- `body`: Untyped Nim code block to execute during setup.

#### Example
```nim
import nim_esphome

esphomeSetup:
  info("Main", "Initializing hardware peripherals...")
  pinMode(2, Output)
```

---

### `esphomeLoop`
```nim
template esphomeLoop*(body: untyped)
```
Registers logic executed repeatedly during ESPHome's cooperative loop cycle.

The code inside `body` executes on every iteration of ESPHome's `Component::loop()` method. Keep operations non-blocking and cooperative.

#### Parameters
- `body`: Untyped Nim code block to execute on every loop cycle.

#### Example
```nim
import nim_esphome

var lastTick: uint32 = 0

esphomeLoop:
  let now = millis()
  if now - lastTick >= 1000:
    lastTick = now
    info("Main", "1 second tick")
```

---

## Macros

### `exportEsphome`
```nim
macro exportEsphome*(def: untyped): untyped
```
Decorates a procedure with `{.exportc, cdecl.}` pragmas so that ESPHome YAML lambdas and external C++ components can invoke it directly via standard C ABI linkage without name mangling.

#### Example
```nim
import nim_esphome

proc computeTargetLevel*(ambientLight: int32): int32 {.exportEsphome.} =
  if ambientLight < 100: 255 else: 0
```

#### Calling from ESPHome YAML:
```yaml
sensor:
  - platform: template
    name: "Target Level"
    lambda: |-
      extern int32_t computeTargetLevel(int32_t);
      return computeTargetLevel(50);
```
