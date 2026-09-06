## Smart Thermostat Surface Example
## Demonstrates `haSurface`, `haService`, `haSchedule`, and embedded DSP PID control.

import nim_esphome
import nim_esphome/dsl/surface
import nim_esphome/dsl/actions
import nim_esphome/dsl/schedule
import nim_esphome/dsl/dashboard
import nim_esphome/dsp

var
  currentTemp: float32 = 21.5'f32
  targetTemp: float32 = 22.0'f32
  heatingPower: float32 = 0.0'f32
  isBoosting: bool = false
  thermostatPid = newPIDController(kp = 5.0'f32, ki = 0.2'f32, kd = 1.0'f32, minOutput = 0.0'f32, maxOutput = 100.0'f32)
  tempSensor = newSensor("current_temperature")
  powerSensor = newSensor("heating_power")

# 1. Composite Hardware Surface definition
let thermostatSurface* = haSurface("smart_thermostat"):
  surf.name = "Living Room Climate Controller"
  surf.model = "Nim Climate Pro"
  surf.manufacturer = "Axiomantic"
  surf.area = "Living Room"

  surf.addControl(sekNumber, "target_temperature", name = "Target Temperature", unit = "°C", icon = "mdi:thermometer")
  surf.addControl(sekSwitch, "eco_mode", name = "Eco Mode", icon = "mdi:leaf")
  surf.addControl(sekSelect, "hvac_mode", name = "HVAC Mode", icon = "mdi:hvac")

  surf.addTelemetry(sekSensor, "current_temperature", name = "Current Temperature", unit = "°C", deviceClass = "temperature")
  surf.addTelemetry(sekSensor, "heating_power", name = "Heating Output", unit = "%", deviceClass = "power_factor")

# 2. Custom Actions callable from Home Assistant automations
haService("boost_heating"):
  def.description = "Temporarily boosts heating setpoint by specified delta degrees"
  param "delta_celsius", pkFloat, min = 1.0, max = 5.0, defaultVal = "2.0", description = "Temperature boost in degrees Celsius"
  param "duration_minutes", pkInt, min = 5.0, max = 120.0, defaultVal = "30", description = "Boost duration in minutes"

  onExecute(ctx):
    let delta = float32(ctx.getFloat("delta_celsius"))
    let dur = ctx.getInt("duration_minutes")
    targetTemp += delta
    isBoosting = true
    info("Thermostat", "Heating boosted by " & $delta & "°C for " & $dur & " minutes")

# 3. Non-blocking RTOS schedule for closed-loop PID control
haSchedule:
  every 5.seconds:
    # Read simulated temperature and update PID controller
    heatingPower = thermostatPid.update(targetTemp, currentTemp, 5.0'f32)
    tempSensor.publishState(currentTemp)
    powerSensor.publishState(heatingPower)
    info("Thermostat", "Loop tick: current=" & $currentTemp & " target=" & $targetTemp & " output=" & $heatingPower & "%")

  every 1.minutes:
    # Heartbeat telemetry
    info("Thermostat", "System healthy. Uptime: " & $(millis() div 1000) & "s")

proc generateThermostatCard*(): string =
  thermostatSurface.generateLovelaceYaml()

esphomeSetup:
  info("Thermostat", "Smart Thermostat surface initialized successfully")

esphomeLoop:
  tickSchedules(millis())
