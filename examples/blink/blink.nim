import nim_esphome

var lastToggle: uint32 = 0
let tempSensor = newSensor("temperature")
let statusLed = newSwitch("status_led")

esphomeSetup:
  info("BlinkNim", "Hello from Nim running on ESPHome!")
  statusLed.publishState(true)

esphomeLoop:
  let now = millis()
  if now - lastToggle >= 2000:
    lastToggle = now
    info("BlinkNim", "Heartbeat tick from Nim loop!")
    tempSensor.publishState(24.2'f32)
