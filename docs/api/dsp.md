# Module: `nim_esphome/dsp`

Embedded Digital Signal Processing, closed-loop PID control, statistical filters, and input debouncers. All types and algorithms are stack-allocated with zero heap overhead.

---

## PID Controller

### `PIDController`
```nim
type
  PIDController* = object
    kp*, ki*, kd*: float32
    minOutput*, maxOutput*: float32
    integral*: float32
    prevError*: float32
    hasPrev*: bool
```
32-bit floating point PID controller with anti-windup clamping.

---

### `newPIDController`
```nim
proc newPIDController*(
    kp, ki, kd: float32,
    minOutput: float32 = -1.0e9'f32,
    maxOutput: float32 = 1.0e9'f32
): PIDController
```
Initializes a new PID controller with proportional, integral, and derivative gains and saturation output bounds.

**Parameters:**
| Name | Type | Default | Description |
|---|---|---|---|
| `kp` | `float32` | | Proportional gain coefficient. |
| `ki` | `float32` | | Integral gain coefficient. |
| `kd` | `float32` | | Derivative gain coefficient. |
| `minOutput` | `float32` | `-1.0e9` | Lower actuator saturation limit. |
| `maxOutput` | `float32` | `1.0e9` | Upper actuator saturation limit. |

**Returns:**
- `PIDController`: A new initialized `PIDController` instance.

---

### `reset` (PIDController)
```nim
proc reset*(pid: var PIDController)
```
Clears accumulated integral error and previous derivative history.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `pid` | `var PIDController` | Target `PIDController` to reset. |

---

### `update` (PIDController)
```nim
proc update*(pid: var PIDController, setpoint, measured, dt: float32): float32
```
Computes control effort given target `setpoint`, current `measured` value, and delta time `dt` in seconds. Automatically performs anti-windup clamping on the integral term when saturated.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `pid` | `var PIDController` | Target `PIDController` state machine. |
| `setpoint` | `float32` | Desired target reference value. |
| `measured` | `float32` | Current sensor measurement. |
| `dt` | `float32` | Elapsed delta time since previous update in seconds. |

**Returns:**
- `float32`: Computed control effort output, clamped within `[minOutput, maxOutput]`.

---

## Moving Average Filter

### `MovingAverage[N]`
```nim
type
  MovingAverage*[N: static int] = object
```
Stack-allocated circular buffer sliding mean filter of $N$ samples. Insertion and updates occur in $O(1)$ constant time.

---

### `newMovingAverage`
```nim
proc newMovingAverage*[N: static int](): MovingAverage[N]
```
Initializes an empty moving average filter with window size `N`.

**Returns:**
- `MovingAverage[N]`: An empty `MovingAverage[N]` filter instance.

---

### `reset` (MovingAverage)
```nim
proc reset*[N: static int](ma: var MovingAverage[N])
```
Resets buffer contents and cumulative sum to zero.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `ma` | `var MovingAverage[N]` | Target `MovingAverage[N]` filter to clear. |

---

### `update` (MovingAverage)
```nim
proc update*[N: static int](ma: var MovingAverage[N], val: float32): float32
```
Inserts sample `val` and returns the updated arithmetic mean.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `ma` | `var MovingAverage[N]` | Target `MovingAverage[N]` filter. |
| `val` | `float32` | New sample value. |

**Returns:**
- `float32`: Updated arithmetic mean of samples currently in the window.

---

### `value` (MovingAverage)
```nim
proc value*[N: static int](ma: MovingAverage[N]): float32
```
Returns the current arithmetic mean without inserting a new sample.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `ma` | `MovingAverage[N]` | Target `MovingAverage[N]` filter. |

**Returns:**
- `float32`: Current arithmetic mean of samples.

---

## Moving Median Filter

### `MovingMedian[N]`
```nim
type
  MovingMedian*[N: static int] = object
```
Stack-allocated sliding median filter of $N$ samples. Uses in-place stack sorting to reject impulse noise without heap allocations.

---

### `newMovingMedian`
```nim
proc newMovingMedian*[N: static int](): MovingMedian[N]
```
Initializes an empty moving median filter with window size `N`.

**Returns:**
- `MovingMedian[N]`: An empty `MovingMedian[N]` filter instance.

---

### `reset` (MovingMedian)
```nim
proc reset*[N: static int](mm: var MovingMedian[N])
```
Clears all samples in the buffer.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `mm` | `var MovingMedian[N]` | Target `MovingMedian[N]` filter to clear. |

---

### `value` (MovingMedian)
```nim
proc value*[N: static int](mm: MovingMedian[N]): float32
```
Computes and returns the median of the current samples.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `mm` | `MovingMedian[N]` | Target `MovingMedian[N]` filter. |

**Returns:**
- `float32`: Current median value of samples in the window.

---

### `update` (MovingMedian)
```nim
proc update*[N: static int](mm: var MovingMedian[N], val: float32): float32
```
Inserts sample `val` and returns the updated median.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `mm` | `var MovingMedian[N]` | Target `MovingMedian[N]` filter. |
| `val` | `float32` | New sample value. |

**Returns:**
- `float32`: Updated median value after inserting `val`.

---

## Low-Pass Exponential Filter

### `LowPassFilter`
```nim
type
  LowPassFilter* = object
    alpha*: float32
    currentVal*: float32
    initialized*: bool
```
Single-pole IIR low pass filter: $y[n] = \alpha \cdot x[n] + (1 - \alpha) \cdot y[n-1]$.

---

### `newLowPassFilter`
```nim
proc newLowPassFilter*(alpha: float32, initialVal: float32 = 0.0'f32): LowPassFilter
```
Initializes filter with smoothing factor `alpha` in range $[0.0, 1.0]$.

**Parameters:**
| Name | Type | Default | Description |
|---|---|---|---|
| `alpha` | `float32` | | Smoothing factor coefficient in `[0.0, 1.0]`. |
| `initialVal` | `float32` | `0.0` | Initial baseline output value. |

**Returns:**
- `LowPassFilter`: A new initialized `LowPassFilter` instance.

---

### `reset` (LowPassFilter)
```nim
proc reset*(lpf: var LowPassFilter, initialVal: float32 = 0.0'f32)
```
Resets filter value to `initialVal`.

**Parameters:**
| Name | Type | Default | Description |
|---|---|---|---|
| `lpf` | `var LowPassFilter` | | Target `LowPassFilter` to reset. |
| `initialVal` | `float32` | `0.0` | Value to set the filter output to. |

---

### `update` (LowPassFilter)
```nim
proc update*(lpf: var LowPassFilter, val: float32): float32
```
Filters sample `val` and returns smoothed result.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `lpf` | `var LowPassFilter` | Target `LowPassFilter`. |
| `val` | `float32` | New unfiltered input sample. |

**Returns:**
- `float32`: Filtered output value.

---

### `value` (LowPassFilter)
```nim
proc value*(lpf: LowPassFilter): float32
```
Returns the most recent smoothed output value.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `lpf` | `LowPassFilter` | Target `LowPassFilter`. |

**Returns:**
- `float32`: Most recent output value without updating state.

---

## Debouncer

### `Debouncer`
```nim
type
  Debouncer* = object
    debounceTimeMs*: uint32
    stableState*: bool
    lastRawState*: bool
    lastDebounceTime*: uint32
    justRose*: bool
    justFell*: bool
```
Time-based edge-detecting software debouncer for mechanical switches and contacts.

---

### `newDebouncer`
```nim
proc newDebouncer*(debounceTimeMs: uint32, initialVal: bool = false): Debouncer
```
Initializes debouncer with `debounceTimeMs` stability threshold.

**Parameters:**
| Name | Type | Default | Description |
|---|---|---|---|
| `debounceTimeMs` | `uint32` | | Minimum stability duration in milliseconds. |
| `initialVal` | `bool` | `false` | Initial boolean state. |

**Returns:**
- `Debouncer`: A new `Debouncer` instance.

---

### `update` (Debouncer)
```nim
proc update*(d: var Debouncer, rawVal: bool, nowMs: uint32): bool
```
Updates state with latest `rawVal` and current timestamp `nowMs`. Returns stable filtered state.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `d` | `var Debouncer` | Target `Debouncer` state machine. |
| `rawVal` | `bool` | Instantaneous raw digital input state. |
| `nowMs` | `uint32` | Current monotonic timestamp in milliseconds (e.g. from `millis()`). |

**Returns:**
- `bool`: Stable debounced state.

---

### `state`
```nim
proc state*(d: Debouncer): bool
```
Returns the current stable debounced state.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `d` | `Debouncer` | Target `Debouncer`. |

**Returns:**
- `bool`: Stable boolean state.

---

### `rose`
```nim
proc rose*(d: Debouncer): bool
```
Returns `true` if a rising edge occurred during the last `update`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `d` | `Debouncer` | Target `Debouncer`. |

**Returns:**
- `bool`: `true` if rising edge occurred on last update.

---

### `fell`
```nim
proc fell*(d: Debouncer): bool
```
Returns `true` if a falling edge occurred during the last `update`.

**Parameters:**
| Name | Type | Description |
|---|---|---|
| `d` | `Debouncer` | Target `Debouncer`. |

**Returns:**
- `bool`: `true` if falling edge occurred on last update.
