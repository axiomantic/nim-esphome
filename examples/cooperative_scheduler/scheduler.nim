## Cooperative RTOS Background Task Scheduler Example
## Demonstrates `haSchedule`, `every`, `after`, and non-blocking timers in the ESPHome loop.

import nim_esphome
import nim_esphome/dsl/schedule

var
  audioTickCount: int = 0
  sensorPollCount: int = 0
  heartbeatCount: int = 0
  watchdogTriggered: bool = false
  sensorReading: float32 = 0.0'f32
  activityLed = newSwitch("activity_led")
  telemetrySensor = newSensor("telemetry_counter")

# 1. Register cooperative non-blocking tasks
haSchedule:
  every 50.ms:
    # High-speed periodic DSP / audio tick
    audioTickCount += 1
    if audioTickCount mod 20 == 0:
      # Toggle LED every 1 second
      activityLed.publishState(audioTickCount mod 40 == 0)

  every 2.seconds:
    # Periodic sensor polling
    sensorPollCount += 1
    sensorReading = float32(sensorPollCount * 10)
    telemetrySensor.publishState(sensorReading)
    info("Scheduler", "Sensor polled: count=" & $sensorPollCount & " val=" & $sensorReading)

  every 30.seconds:
    # System health heartbeat
    heartbeatCount += 1
    info("Scheduler", "Heartbeat #" & $heartbeatCount & " uptime=" & $(millis() div 1000) & "s")

  after 10.seconds:
    # One-shot watchdog or initialization delay
    watchdogTriggered = true
    info("Scheduler", "One-shot 10-second warm-up phase complete!")

esphomeSetup:
  info("Scheduler", "Cooperative scheduler initialized with 4 background tasks")

esphomeLoop:
  tickSchedules(millis())
