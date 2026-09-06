# RTOS Background Task & Schedule DSL

Smart home devices frequently need background cooperative tasks:
- Advancing audio synthesized loops or LED breathing patterns.
- Periodically reading I2C sensor registries.
- Publishing heartbeat telemetry (Wi-Fi RSSI, free heap memory).
- One-shot timeouts and watchdog alarms.

Spawning dedicated FreeRTOS threads for simple timers incurs stack overhead (typically 2-4 KB per task) and introduces concurrency/thread-safety risks.

The **RTOS Schedule DSL** (`nim_esphome/dsl/schedule`) provides non-blocking, cooperative scheduling directly integrated into ESPHome's main execution loop.

---

## Core Features

- **Ergonomic Duration Helpers**: Define durations naturally: `50.ms`, `500.milliseconds`, `5.seconds`, `30.minutes`, `2.hours`.
- **Zero-Allocation**: Timers run cooperatively inside the main loop without creating OS threads.
- **Both Periodic and One-Shot Delays**: Register recurring intervals with `every` or delayed callbacks with `after`.
- **Full Lifecycle Control**: Cancel timers with `task.cancel()` or reactivate them with `task.reset()`.
- **Deterministic Testing**: Simulate time progression in unit tests with `tickSchedules(timestamp)`.

---

## Syntax & Quickstart

```nim
import nim_esphome/dsl/schedule

haSchedule:
  every 50.ms:
    # High-rate DSP or audio loop advancement
    stepAudioPipeline()

  every 5.seconds:
    # Periodic sensor polling and telemetry publication
    publishTelemetry()

  after 30.seconds:
    # One-shot warm-up calibration complete
    finalizeCalibration()
```

---

## Integration with ESPHome Main Loop

In your device's `esphomeLoop` template or C++ main loop:

```nim
import nim_esphome

esphomeLoop:
  # Advances all registered tasks against the monotonic millisecond clock
  tickSchedules(millis())
```

---

## Programmatic Task Management & Cancellation

```nim
# Register a cancelable timeout
let watchdog = after(10.seconds):
  echo "Watchdog timer expired!"

# Cancel if an event occurs earlier
if commandReceived:
  watchdog.cancel()

# Reset and reuse the timer
watchdog.reset(millis())
```

---

## Unit Testing Schedules on Host

Because scheduling relies on timestamp evaluation rather than blocking OS sleeps, you can test long-running schedules instantly:

```nim
let reg = ScheduleRegistry(tasks: @[])
var count = 0

haSchedule(reg):
  every 1.hours:
    count += 1

# Advance time through ticks
tickSchedules(0, reg)        # Initialization
tickSchedules(1800000, reg)  # 30 mins: count is still 0
assert count == 0

tickSchedules(3600000, reg)  # 60 mins (1 hr): count increments to 1
assert count == 1

tickSchedules(7200000, reg)  # 120 mins (2 hrs): count increments to 2
assert count == 2
```
