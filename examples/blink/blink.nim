import nim_esphome

var lastToggle: uint32 = 0
var bootCount: int32 = 0
let tempSensor = newSensor("temperature")
let statusLed = newSwitch("status_led")
let i2cDev = newI2CDevice(0x68)

esphomeSetup:
  info("BlinkNim", "Hello from Nim running on ESPHome!")
  bootCount = loadPreference("boot_count", 0'i32) + 1
  discard savePreference("boot_count", bootCount)
  statusLed.publishState(true)
  pinMode(2, Output)
  digitalWrite(2, High)

esphomeLoop:
  let now = millis()
  if now - lastToggle >= 2000:
    lastToggle = now
    info("BlinkNim", "Heartbeat tick from Nim loop!")
    tempSensor.publishState(24.2'f32)
    digitalWrite(2, Low)
    discard i2cDev.writeByte(0x6B, 0x00)
