# Module: `nim_esphome/entities`

Type-safe handles and state publishing procedures for ESPHome entities (`Sensor`, `BinarySensor`, `Switch`, `TextSensor`).

---

## Types

### `Sensor`
```nim
type Sensor* = object
  id*: string
```
Handle to an ESPHome floating-point numerical `sensor` component.

---

### `BinarySensor`
```nim
type BinarySensor* = object
  id*: string
```
Handle to an ESPHome boolean `binary_sensor` component.

---

### `Switch`
```nim
type Switch* = object
  id*: string
```
Handle to an ESPHome boolean `switch` component.

---

### `TextSensor`
```nim
type TextSensor* = object
  id*: string
```
Handle to an ESPHome string `text_sensor` component.

---

## Constructors

### `newSensor`
```nim
proc newSensor*(id: string): Sensor
```
Creates a new `Sensor` handle corresponding to the entity with YAML ID `id`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `id` | `string` | The entity ID defined in ESPHome YAML. |

**Returns:**
- `Sensor`: A new `Sensor` handle.

---

### `newBinarySensor`
```nim
proc newBinarySensor*(id: string): BinarySensor
```
Creates a new `BinarySensor` handle corresponding to the entity with YAML ID `id`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `id` | `string` | The entity ID defined in ESPHome YAML. |

**Returns:**
- `BinarySensor`: A new `BinarySensor` handle.

---

### `newSwitch`
```nim
proc newSwitch*(id: string): Switch
```
Creates a new `Switch` handle corresponding to the entity with YAML ID `id`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `id` | `string` | The entity ID defined in ESPHome YAML. |

**Returns:**
- `Switch`: A new `Switch` handle.

---

### `newTextSensor`
```nim
proc newTextSensor*(id: string): TextSensor
```
Creates a new `TextSensor` handle corresponding to the entity with YAML ID `id`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `id` | `string` | The entity ID defined in ESPHome YAML. |

**Returns:**
- `TextSensor`: A new `TextSensor` handle.

---

## Publishing State

### `publishState (Sensor)`
```nim
proc publishState*(s: Sensor, val: float32): bool {.discardable.}
```
Publishes a numerical float state `val` to the sensor identified by `s.id`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `s` | `Sensor` | Target `Sensor` handle. |
| `val` | `float32` | 32-bit floating point state to publish. |

**Returns:**
- `bool`: `true` if entity was located and state was dispatched.

---

### `publishState (BinarySensor)`
```nim
proc publishState*(bs: BinarySensor, val: bool): bool {.discardable.}
```
Publishes a boolean state `val` (`true` / `false`) to the binary sensor identified by `bs.id`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `bs` | `BinarySensor` | Target `BinarySensor` handle. |
| `val` | `bool` | Boolean state to publish. |

**Returns:**
- `bool`: `true` if entity was located and state was dispatched.

---

### `publishState (Switch)`
```nim
proc publishState*(sw: Switch, val: bool): bool {.discardable.}
```
Publishes a boolean state `val` (`true` / `false`) to the switch identified by `sw.id`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `sw` | `Switch` | Target `Switch` handle. |
| `val` | `bool` | Boolean switch state to publish. |

**Returns:**
- `bool`: `true` if entity was located and state was dispatched.

---

### `publishState (TextSensor)`
```nim
proc publishState*(ts: TextSensor, val: string): bool {.discardable.}
```
Publishes a text string state `val` to the text sensor identified by `ts.id`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `ts` | `TextSensor` | Target `TextSensor` handle. |
| `val` | `string` | String message or state to publish. |

**Returns:**
- `bool`: `true` if entity was located and state was dispatched.

---

## Host Testing Helpers

These procedures are available when compiled without `-d:esphome` for headless unit testing on macOS/Linux:

- `getSensorState*(id: string): float32`: Returns current value in test mock table.
- `getBinarySensorState*(id: string): bool`: Returns current value in test mock table.
- `getSwitchState*(id: string): bool`: Returns current value in test mock table.
- `getTextSensorState*(id: string): string`: Returns current value in test mock table.
