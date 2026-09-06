# Module: `nim_esphome/gpio`

Direct microcontroller General-Purpose Input/Output (GPIO) pin configuration and digital I/O operations.

---

## Types

### `PinMode`
```nim
type
  PinMode* = enum
    Input = 0          ## High-impedance digital input.
    Output = 1         ## Push-pull digital output.
    InputPullup = 2    ## Digital input with internal pull-up resistor enabled.
    InputPulldown = 3  ## Digital input with internal pull-down resistor enabled.
```
Electrical configuration mode for a microcontroller GPIO pin.

---

### `PinState`
```nim
type
  PinState* = enum
    Low = 0   ## 0V / GND logic low.
    High = 1  ## VCC / 3.3V logic high.
```
Digital logic level of a GPIO pin.

---

## Procedures

### `pinMode`
```nim
proc pinMode*(pin: uint8, mode: PinMode)
```
Configures the electrical mode of the specified physical GPIO `pin`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `pin` | `uint8` | Physical microcontroller GPIO pin index. |
| `mode` | `PinMode` | Desired electrical operating mode (`Input`, `Output`, `InputPullup`, `InputPulldown`). |

#### Example
```nim
import nim_esphome

# Configure pin 0 as input with pullup (e.g. boot button)
pinMode(0, InputPullup)

# Configure pin 2 as digital output (e.g. status LED)
pinMode(2, Output)
```

---

### `digitalWrite` (PinState)
```nim
proc digitalWrite*(pin: uint8, state: PinState)
```
Writes a digital logic level (`High` or `Low`) to the specified GPIO `pin`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `pin` | `uint8` | Physical microcontroller GPIO pin index. |
| `state` | `PinState` | Desired digital logic level (`High` or `Low`). |

---

### `digitalWrite` (bool)
```nim
proc digitalWrite*(pin: uint8, val: bool)
```
Convenience overload writing a boolean state (`true` -> `High`, `false` -> `Low`) to the specified GPIO `pin`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `pin` | `uint8` | Physical microcontroller GPIO pin index. |
| `val` | `bool` | Boolean output value. |

---

### `digitalRead`
```nim
proc digitalRead*(pin: uint8): PinState
```
Reads and returns the current digital logic level (`High` or `Low`) of `pin`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `pin` | `uint8` | Physical microcontroller GPIO pin index to read. |

**Returns:**
- `PinState`: Measured digital logic level (`High` or `Low`).
