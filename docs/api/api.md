# Module: `nim_esphome/api`

Core ESPHome C++ runtime bindings, hardware clocks, FreeRTOS task scheduling, watchdog management, and system restart.

---

## Types

### `ConstCString`
```nim
type ConstCString* = cstring
```
Immutable C string pointer mapped directly to C++ `const char*` (`{.importc: "const char*".}`).
Prevents `-Wwrite-strings` compiler warnings when passing string literals to C++ APIs.

---

## Procedures

### `millis`
```nim
proc millis*(): uint32
```
Returns the number of milliseconds elapsed since the microcontroller booted.

---

### `micros`
```nim
proc micros*(): uint32
```
Returns the number of microseconds elapsed since the microcontroller booted. High-resolution timer useful for microsecond-level timing and PWM calculations.

---

### `delayMs`
```nim
proc delayMs*(ms: uint32)
```
Delays execution for `ms` milliseconds. On microcontrollers, invokes ESPHome's `delay()` wrapper which yields execution to FreeRTOS background tasks.

---

### `yieldToScheduler`
```nim
proc yieldToScheduler*()
```
Yields execution to the FreeRTOS scheduler and cooperative ESPHome background tasks. Use this inside tight loops to prevent starving network and WiFi stacks.

---

### `feedWatchdog`
```nim
proc feedWatchdog*()
```
Feeds the hardware and task watchdog timer to prevent spurious device reboots during long-running computational loops.

---

### `getFreeHeap`
```nim
proc getFreeHeap*(): uint32
```
Returns the currently available free heap memory in bytes. Useful for tracking heap usage and diagnosing memory fragmentation.

---

### `reboot`
```nim
proc reboot*()
```
Triggers an immediate software restart of the microcontroller.

---

## Logging Templates

These templates wrap ESPHome's internal logging macros (`ESP_LOGI`, `ESP_LOGW`, `ESP_LOGE`, `ESP_LOGD`), formatting output according to ESPHome's configured log level.

### `info`
```nim
template info*(tag: string, msg: string)
```
Logs an informational message under the specified `tag`.

### `warn`
```nim
template warn*(tag: string, msg: string)
```
Logs a warning message under the specified `tag`.

### `error`
```nim
template error*(tag: string, msg: string)
```
Logs an error message under the specified `tag`.

### `debug`
```nim
template debug*(tag: string, msg: string)
```
Logs a verbose debug message under the specified `tag`.
